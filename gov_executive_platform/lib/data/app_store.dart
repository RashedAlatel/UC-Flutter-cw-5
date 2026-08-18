import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/approval_request.dart';
import '../models/audit_log_entry.dart';
import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/custom_role.dart';
import '../models/dashboard_widget_config.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/report.dart';
import '../models/risk.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'default_departments.dart';
import 'demo_data.dart';
import 'ministry_import_data.dart';

/// طبقة إدارة الحالة المركزية للمنصة، مبنية بالكامل على Firebase:
/// - المصادقة: Firebase Authentication (بريد إلكتروني/كلمة مرور)
/// - البيانات: Cloud Firestore (استماع لحظي real-time لكل المجموعات)
/// - العمليات الحساسة (اعتماد الطلبات، إرسال الإشعارات): Cloud Functions
///
/// لا تُجرى أي عملية اعتماد (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي) مباشرة من
/// هذا الملف؛ كل ما يفعله الطلب هو إنشاء وثيقة "طلب موافقة" في Firestore، والتنفيذ
/// الفعلي يتم حصرياً داخل Cloud Functions بعد تحقق الخادم من صلاحية مسؤول النظام.
class AppStore extends ChangeNotifier {
  final _auth = fb_auth.FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  // يجب أن تطابق المنطقة (region) المحددة في functions/src/index.ts
  // (setGlobalOptions)، وإلا تفشل كل استدعاءات httpsCallable بصمت.
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  AppUser? currentUser;
  bool _ready = false;
  bool get ready => _ready;

  List<Department> departments = [];
  List<Project> projects = [];
  List<ProjectTask> tasks = [];
  List<ProjectRisk> risks = [];
  List<ProjectBlocker> blockers = [];
  List<DailyUpdate> dailyUpdates = [];
  List<ApprovalRequest> approvalRequests = [];
  List<AuditLogEntry> auditLog = [];
  List<ReportSnapshot> reports = [];
  List<AppUser> users = []; // يُملأ فقط لمسؤول النظام (إدارة المستخدمين)
  List<DashboardWidgetConfig> dashboardWidgets = DashboardWidgetConfig.defaults();
  List<CustomRole> customRoles = [];

  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _themeSub;
  final List<StreamSubscription> _dataSubs = [];

  Future<void> init() async {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    // ألوان الهوية تُطبَّق فوراً عند بدء التشغيل بمعزل عن حالة تسجيل الدخول
    // (تظهر حتى في شاشتي الدخول والتسجيل)، وتحدَّث لحظياً إن غيّرها مسؤول النظام.
    _themeSub = _db.collection('settings').doc('theme').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) {
        AppColors.resetBrand();
      } else {
        AppColors.applyBrand(
          primary: Color(data['primary'] as int? ?? AppColors.defaultPrimary.toARGB32()),
          accent: Color(data['accent'] as int? ?? AppColors.defaultAccent.toARGB32()),
        );
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _themeSub?.cancel();
    _cancelDataSubs();
    super.dispose();
  }

  void _cancelDataSubs() {
    for (final s in _dataSubs) {
      s.cancel();
    }
    _dataSubs.clear();
    departments = [];
    projects = [];
    tasks = [];
    risks = [];
    blockers = [];
    dailyUpdates = [];
    approvalRequests = [];
    auditLog = [];
    reports = [];
    users = [];
    dashboardWidgets = DashboardWidgetConfig.defaults();
    customRoles = [];
  }

  Future<void> _onAuthChanged(fb_auth.User? user) async {
    await _userDocSub?.cancel();
    _cancelDataSubs();
    if (user == null) {
      currentUser = null;
      _ready = true;
      notifyListeners();
      return;
    }
    _userDocSub = _db.collection('users').doc(user.uid).snapshots().listen((doc) async {
      final wasApproved = currentUser?.status == UserStatus.approved;
      currentUser = doc.exists ? AppUser.fromDoc(doc) : null;
      if (!wasApproved && currentUser?.status == UserStatus.approved) {
        // تحديث Custom Claims المخزّنة في التوكن بعد اعتماد الحساب لأول مرة
        await user.getIdToken(true);
      }
      if (currentUser?.status == UserStatus.approved) {
        // يُلغي أي اشتراكات سابقة قبل إعادة الاشتراك دائماً، لأن مستند
        // المستخدم قد يتغيّر لأسباب لا علاقة لها بنطاق البيانات (مثل أي
        // تحديث بسيط من مسؤول آخر)؛ بدون هذا الإلغاء تتراكم مستمعات مكررة
        // على نفس المجموعات (بينها dashboardConfig)، وقد يُعيد أحدها لاحقاً
        // نسخة قديمة مخزَّنة محلياً فيبدو الأمر وكأن الحفظ "لم يُحفظ".
        _cancelDataSubs();
        _subscribeAppData();
      } else {
        _cancelDataSubs();
      }
      _ready = true;
      notifyListeners();
    }, onError: (_) {
      _ready = true;
      notifyListeners();
    });
  }

  void _subscribeAppData() {
    final officer = isOfficer;
    final manager = isManager;
    final scopedDept = (canViewAllDepartments || officer || manager) ? null : currentUser?.departmentId;

    _dataSubs.add(_db.collection('departments').orderBy('name').snapshots().listen((snap) {
      departments = snap.docs.map(Department.fromDoc).toList();
      notifyListeners();
    }));

    // مدير المشروع (officer) يُقيَّد بمشروعه المُسنَد إليه تحديداً (عبر managerUid).
    // مدير الإدارة (manager) قد يدير أكثر من إدارة، فيُقيَّد بقائمة departmentIds
    // كاملة (whereIn) بدل مطابقة إدارة واحدة فقط.
    Query<Map<String, dynamic>> scoped(String collection) {
      final col = _db.collection(collection);
      if (officer) return col.where('managerUid', isEqualTo: currentUser?.id);
      if (manager) {
        final ids = myDepartmentIds;
        return ids.isEmpty
            ? col.where('departmentId', isEqualTo: '__none__')
            : col.where('departmentId', whereIn: ids.length > 30 ? ids.sublist(0, 30) : ids);
      }
      return scopedDept == null ? col : col.where('departmentId', isEqualTo: scopedDept);
    }

    _dataSubs.add(scoped('projects').snapshots().listen((snap) {
      projects = snap.docs.map(Project.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(scoped('tasks').snapshots().listen((snap) {
      tasks = snap.docs.map(ProjectTask.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(scoped('risks').snapshots().listen((snap) {
      risks = snap.docs.map(ProjectRisk.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(scoped('blockers').snapshots().listen((snap) {
      blockers = snap.docs.map(ProjectBlocker.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(scoped('dailyUpdates').snapshots().listen((snap) {
      dailyUpdates = snap.docs.map(DailyUpdate.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(_db.collection('approvalRequests').snapshots().listen((snap) {
      approvalRequests = snap.docs
          .map(ApprovalRequest.fromDoc)
          .where((r) => canViewAll(r))
          .toList();
      notifyListeners();
    }));
    _dataSubs.add(_db.collection('reports').snapshots().listen((snap) {
      reports = snap.docs.map(ReportSnapshot.fromDoc).toList()
        ..sort((a, b) => b.generatedDate.compareTo(a.generatedDate));
      notifyListeners();
    }));
    _dataSubs.add(_db.collection('roles').orderBy('name').snapshots().listen((snap) {
      customRoles = snap.docs.map(CustomRole.fromDoc).toList();
      notifyListeners();
    }));
    _dataSubs.add(_db.collection('dashboardConfig').doc('main').snapshots().listen((doc) {
      final widgets = doc.data()?['widgets'] as List?;
      dashboardWidgets = widgets == null || widgets.isEmpty
          ? DashboardWidgetConfig.defaults()
          : widgets.map((w) => DashboardWidgetConfig.fromMap(Map<String, dynamic>.from(w as Map))).toList();
      notifyListeners();
    }));

    if (canViewAuditLog) {
      _dataSubs.add(_db.collection('auditLog').orderBy('timestamp', descending: true).limit(300).snapshots().listen((snap) {
        auditLog = snap.docs.map(AuditLogEntry.fromDoc).toList();
        notifyListeners();
      }));
    }
    // قائمة المستخدمين مطلوبة لأي مستخدم معتمد (وليس فقط من يدير المستخدمين):
    // قوائم اختيار "مدير المشروع" و"المنفذون" تحتاج أسماء المستخدمين
    // المسجَّلين، وقواعد Firestore تسمح أصلاً بقراءة المجموعة لأي مستخدم
    // معتمد (allow list: if isApproved()) فلا يوجد كشف صلاحيات إضافي هنا.
    _dataSubs.add(_db.collection('users').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      users = snap.docs.map(AppUser.fromDoc).toList();
      notifyListeners();
    }));
  }

  bool canViewAll(ApprovalRequest r) {
    if (isAdmin || isExecutive) return true;
    if (r.requestedByUid == currentUser?.id) return true;
    if (r.departmentId != null && r.departmentId == currentUser?.departmentId) return true;
    return false;
  }

  // ------------------------- المصادقة -------------------------

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'تعذر تسجيل الدخول، تأكد من إعداد Firebase بشكل صحيح.';
    }
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole requestedRole,
    String? requestedDepartmentId,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final uid = cred.user!.uid;
      final now = DateTime.now();
      final user = AppUser(
        id: uid,
        name: name,
        email: email.trim(),
        phone: phone,
        role: UserRole.projectOfficer,
        departmentId: requestedDepartmentId,
        status: UserStatus.pending,
        createdAt: now,
      );
      await _db.collection('users').doc(uid).set(user.toMap());
      await _db.collection('approvalRequests').add(ApprovalRequest(
            id: '',
            type: ApprovalType.registration,
            status: DecisionStatus.pending,
            title: 'طلب تسجيل عضو جديد: $name',
            description: 'الدور المطلوب: ${requestedRole.label}',
            priority: PriorityLevel.medium,
            delayImpactDays: 0,
            departmentId: requestedDepartmentId,
            requestedByUid: uid,
            requestedByName: name,
            requestedDate: now,
            payload: {
              'uid': uid,
              'name': name,
              'email': email.trim(),
              'phone': phone,
              'requestedRole': requestedRole.name,
              'requestedDepartmentId': requestedDepartmentId,
            },
          ).toMap());
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _mapAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجّل مسبقاً';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل)';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'too-many-requests':
        return 'محاولات كثيرة، الرجاء المحاولة لاحقاً';
      default:
        return e.message ?? 'حدث خطأ غير متوقع';
    }
  }

  // ------------------------- الصلاحيات -------------------------

  bool get isAdmin => currentUser?.role == UserRole.systemAdmin;
  bool get isExecutive => currentUser?.role == UserRole.executiveViewer;
  bool get isManager => currentUser?.role == UserRole.departmentManager;
  bool get isOfficer => currentUser?.role == UserRole.projectOfficer;

  /// الدور المخصص الفعلي للمستخدم الحالي (إن وُجد)، محمَّل من مجموعة roles.
  CustomRole? get myCustomRole {
    if (currentUser?.role != UserRole.custom || currentUser?.customRoleId == null) return null;
    final match = customRoles.where((r) => r.id == currentUser!.customRoleId);
    return match.isEmpty ? null : match.first;
  }

  bool get canViewAllDepartments => isAdmin || isExecutive || (myCustomRole?.viewAllDepartments ?? false);
  bool get canManageUsers => isAdmin;
  // سجل التدقيق، الموافقة على تسجيل الأعضاء/المشاريع/المواعيد النهائية، وإضافة
  // المستخدمين تبقى دائماً حصراً لمسؤول النظام — لا يملك أي دور مخصص تجاوزها.
  bool get canViewAuditLog => isAdmin;
  bool get canManageReports => isAdmin || isExecutive || (myCustomRole?.manageReports ?? false);
  bool get canManageDashboard => isAdmin || (myCustomRole?.manageDashboard ?? false);

  /// اعتماد "قرار تنفيذي" عام يجوز للمسؤول أو المستخدم التنفيذي أو دور مخصص
  /// يملك صلاحية "اعتماد القرارات التنفيذية العامة" صراحة.
  /// أما تسجيل عضو / إضافة مشروع / تعديل موعد نهائي فلا يعتمدها إلا مسؤول النظام حصرياً،
  /// ولا يمكن لأي دور مخصص تجاوز هذا القيد مهما كانت صلاحياته.
  bool canApprove(ApprovalRequest r) {
    if (r.type == ApprovalType.decision) return isAdmin || isExecutive || (myCustomRole?.approveGeneralDecisions ?? false);
    return isAdmin;
  }

  /// إدارة/إدارات مدير الإدارة الحالي (دور departmentManager فقط قد يملك أكثر من إدارة).
  List<String> get myDepartmentIds => currentUser?.departmentIds ?? const [];

  bool canEditProject(Project project) {
    if (currentUser == null) return false;
    if (isAdmin) return true;
    if (isExecutive) return false;
    if (isOfficer) return project.managerUid == currentUser!.id;
    if (isManager) return myDepartmentIds.contains(project.departmentId);
    return currentUser!.departmentId == project.departmentId;
  }

  bool canSubmitDailyUpdate(Project project) => canEditProject(project);

  bool canRequestNewProject(String departmentId) {
    if (currentUser == null) return false;
    if (isAdmin) return true;
    return isManager && myDepartmentIds.contains(departmentId);
  }

  bool canViewDepartment(String departmentId) {
    if (currentUser == null) return false;
    if (canViewAllDepartments) return true;
    if (isOfficer) return false;
    if (isManager) return myDepartmentIds.contains(departmentId);
    return currentUser!.departmentId == departmentId;
  }

  List<Department> get visibleDepartments {
    if (canViewAllDepartments) return departments;
    if (isOfficer) return const [];
    if (isManager) return departments.where((d) => myDepartmentIds.contains(d.id)).toList();
    return departments.where((d) => d.id == currentUser?.departmentId).toList();
  }

  /// مشاريع "مدير المشروع" مقيَّدة بالمشروع (أو المشاريع) المُسنَدة إليه تحديداً
  /// عبر managerUid، بمعزل تام عن بقية مشاريع إدارته. أما مدير الإدارة فيرى
  /// مشاريع إدارته أو إداراته (قد تكون أكثر من إدارة واحدة) فقط.
  List<Project> get visibleProjects {
    if (canViewAllDepartments) return projects;
    if (isOfficer) return projects.where((p) => p.managerUid == currentUser?.id).toList();
    if (isManager) return projects.where((p) => myDepartmentIds.contains(p.departmentId)).toList();
    return projects.where((p) => p.departmentId == currentUser?.departmentId).toList();
  }

  List<Project> projectsForDepartment(String departmentId) =>
      projects.where((p) => p.departmentId == departmentId).toList();

  // ------------------------- دوال مساعدة -------------------------

  Department? departmentById(String id) {
    final match = departments.where((d) => d.id == id);
    return match.isEmpty ? null : match.first;
  }

  Project? projectById(String id) {
    final match = projects.where((p) => p.id == id);
    return match.isEmpty ? null : match.first;
  }

  List<ProjectTask> tasksForProject(String projectId) =>
      tasks.where((t) => t.projectId == projectId).toList()
        ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

  List<ProjectRisk> risksForProject(String projectId) => risks.where((r) => r.projectId == projectId).toList();

  List<ProjectBlocker> blockersForProject(String projectId) =>
      blockers.where((b) => b.projectId == projectId).toList();

  List<ApprovalRequest> requestsForProject(String projectId) =>
      approvalRequests.where((r) => r.projectId == projectId).toList();

  List<DailyUpdate> updatesForProject(String projectId) =>
      dailyUpdates.where((u) => u.projectId == projectId).toList()..sort((a, b) => b.date.compareTo(a.date));

  double departmentProgress(String departmentId) {
    final list = projectsForDepartment(departmentId);
    if (list.isEmpty) return 0;
    return list.map((p) => p.progressPercent).reduce((a, b) => a + b) / list.length;
  }

  double departmentAvgDelay(String departmentId) {
    final list = projectsForDepartment(departmentId);
    if (list.isEmpty) return 0;
    return list.map((p) => p.delayDays).reduce((a, b) => a + b) / list.length;
  }

  int departmentRiskCount(String departmentId) =>
      risks.where((r) => projectById(r.projectId)?.departmentId == departmentId && r.status == ItemStatus.open).length;

  int departmentBlockerCount(String departmentId) => blockers
      .where((b) => projectById(b.projectId)?.departmentId == departmentId && b.status == ItemStatus.open)
      .length;

  List<MapEntry<Department, double>> get departmentRanking {
    final list = departments.map((d) => MapEntry(d, departmentProgress(d.id))).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  double get overallProgress {
    if (projects.isEmpty) return 0;
    return projects.map((p) => p.progressPercent).reduce((a, b) => a + b) / projects.length;
  }

  double get overallAvgDelay {
    if (projects.isEmpty) return 0;
    return projects.map((p) => p.delayDays).reduce((a, b) => a + b) / projects.length;
  }

  int get openRisksCount => risks.where((r) => r.status == ItemStatus.open).length;
  int get openBlockersCount => blockers.where((b) => b.status == ItemStatus.open).length;
  int get pendingApprovalsCount => approvalRequests.where((r) => r.status == DecisionStatus.pending).length;

  List<ApprovalRequest> get pendingApprovalsSorted {
    final list = approvalRequests.where((r) => r.status == DecisionStatus.pending).toList();
    list.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return b.delayImpactDays.compareTo(a.delayImpactDays);
    });
    return list;
  }

  // ------------------------- عمليات الكتابة (بيانات تشغيلية) -------------------------

  Future<void> addDailyUpdate({
    required Project project,
    required String achievements,
    required List<String> completedTasks,
    required List<String> newRisks,
    required List<String> blockersText,
    required List<String> decisionsRequired,
    required double progressPercent,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();

    final updateRef = _db.collection('dailyUpdates').doc();
    batch.set(
      updateRef,
      {
        ...DailyUpdate(
          id: updateRef.id,
          projectId: project.id,
          departmentId: project.departmentId,
          authorUid: currentUser?.id ?? '',
          authorName: currentUser?.name ?? 'غير معروف',
          date: now,
          achievements: achievements,
          completedTasks: completedTasks,
          newRisks: newRisks,
          blockers: blockersText,
          decisionsRequired: decisionsRequired,
          progressPercent: progressPercent,
        ).toMap(),
        'managerUid': project.managerUid,
      },
    );

    ProjectStatus newStatus = project.status;
    if (progressPercent >= 100) {
      newStatus = ProjectStatus.completed;
    } else if (project.delayDays > 5) {
      newStatus = ProjectStatus.delayed;
    } else if (newRisks.isNotEmpty || blockersText.isNotEmpty) {
      newStatus = ProjectStatus.atRisk;
    } else if (progressPercent > project.progressPercent) {
      newStatus = ProjectStatus.onTrack;
    }
    batch.update(_db.collection('projects').doc(project.id), {
      'progressPercent': progressPercent,
      'status': newStatus.name,
    });

    for (final r in newRisks) {
      final ref = _db.collection('risks').doc();
      batch.set(
        ref,
        {
          ...ProjectRisk(
            id: ref.id,
            projectId: project.id,
            departmentId: project.departmentId,
            description: r,
            level: RiskLevel.medium,
            status: ItemStatus.open,
            dateRaised: now,
          ).toMap(),
          'managerUid': project.managerUid,
        },
      );
    }
    for (final b in blockersText) {
      final ref = _db.collection('blockers').doc();
      batch.set(
        ref,
        {
          ...ProjectBlocker(
            id: ref.id,
            projectId: project.id,
            departmentId: project.departmentId,
            description: b,
            status: ItemStatus.open,
            dateRaised: now,
          ).toMap(),
          'managerUid': project.managerUid,
        },
      );
    }
    for (final d in decisionsRequired) {
      final ref = _db.collection('approvalRequests').doc();
      batch.set(
        ref,
        ApprovalRequest(
          id: ref.id,
          type: ApprovalType.decision,
          status: DecisionStatus.pending,
          title: d,
          description: 'قرار مطلوب ضمن التحديث اليومي بتاريخ ${Formatters.shortDate(now)} بواسطة ${currentUser?.name ?? ''}',
          priority: PriorityLevel.medium,
          delayImpactDays: 5,
          departmentId: project.departmentId,
          projectId: project.id,
          requestedByUid: currentUser?.id ?? '',
          requestedByName: currentUser?.name ?? '',
          requestedDate: now,
        ).toMap(),
      );
    }

    await batch.commit();
    await _log('تحديث يومي', 'أضاف ${currentUser?.name} تحديثاً يومياً لمشروع "${project.name}"');
  }

  Future<void> updateTaskStatus(ProjectTask task, TaskStatus status) async {
    await _db.collection('tasks').doc(task.id).update({
      'status': status.name,
      'lastUpdated': Timestamp.now(),
      if (status == TaskStatus.done) 'progressPercent': 100.0,
    });
    await _log('تحديث مهمة', 'تم تغيير حالة المهمة "${task.title}" إلى ${status.label}');
  }

  Future<void> updateTaskProgress(ProjectTask task, double progress) async {
    await _db.collection('tasks').doc(task.id).update({
      'progressPercent': progress,
      'lastUpdated': Timestamp.now(),
    });
    await _log('تحديث تقدم مهمة', 'تم تحديث نسبة إنجاز المهمة "${task.title}" إلى ${progress.toStringAsFixed(0)}٪');
  }

  Future<void> addTask(ProjectTask task) async {
    final managerUid = projectById(task.projectId)?.managerUid;
    await _db.collection('tasks').doc(task.id).set({...task.toMap(), 'managerUid': managerUid});
    await _log('إضافة مهمة', 'تمت إضافة مهمة جديدة "${task.title}"');
  }

  // ------------------------- طلبات الموافقة -------------------------

  Future<void> submitProjectRequest({
    required String departmentId,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime dueDate,
    required PriorityLevel priority,
    List<String> executorNames = const [],
  }) async {
    final now = DateTime.now();
    await _db.collection('approvalRequests').add(ApprovalRequest(
          id: '',
          type: ApprovalType.projectCreate,
          status: DecisionStatus.pending,
          title: 'طلب إضافة مشروع جديد: $name',
          description: description,
          priority: priority,
          delayImpactDays: 0,
          departmentId: departmentId,
          requestedByUid: currentUser?.id ?? '',
          requestedByName: currentUser?.name ?? '',
          requestedDate: now,
          payload: {
            'name': name,
            'description': description,
            'departmentId': departmentId,
            'startDate': startDate.toIso8601String(),
            'dueDate': dueDate.toIso8601String(),
            'priority': priority.name,
            'executorNames': executorNames,
          },
        ).toMap());
    await _log('طلب مشروع جديد', 'قدّم ${currentUser?.name} طلب إضافة مشروع "$name"');
  }

  /// إضافة مشروع مباشرة (مسؤول النظام فقط) دون المرور بدورة طلب/اعتماد،
  /// لأن موافقته الذاتية كمسؤول نظام تُعد كافية أصلاً.
  Future<void> createProjectDirect({
    required String departmentId,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime dueDate,
    required PriorityLevel priority,
    List<String> executorNames = const [],
    String? managerUid,
  }) async {
    final ref = _db.collection('projects').doc();
    await ref.set(Project(
      id: ref.id,
      departmentId: departmentId,
      name: name,
      description: description,
      startDate: startDate,
      dueDate: dueDate,
      status: ProjectStatus.onTrack,
      priority: priority,
      progressPercent: 0,
      executorNames: executorNames,
      createdByUid: currentUser?.id ?? '',
      managerUid: managerUid,
    ).toMap());
    await _log('إضافة مشروع', 'أضاف ${currentUser?.name} مشروعاً جديداً "$name" مباشرة');
  }

  /// تعيين/تغيير "مدير المشروع" (مسؤول النظام فقط) — الحساب المعيَّن هنا هو
  /// الوحيد الذي سيرى هذا المشروع إن كان دوره "مدير مشروع".
  Future<void> setProjectManager(Project project, String? managerUid) async {
    await _db.collection('projects').doc(project.id).update({'managerUid': managerUid});
    await _log('تعيين مدير مشروع', 'تم تعيين مدير المشروع لمشروع "${project.name}"');
  }

  /// تحديث قائمة الأشخاص المنفذين للمشروع (يمكن أن يكون أكثر من شخص).
  Future<void> updateProjectExecutors(Project project, List<String> executorNames) async {
    await _db.collection('projects').doc(project.id).update({'executorNames': executorNames});
    await _log('تحديث المنفذين', 'تم تحديث قائمة منفذي مشروع "${project.name}"');
  }

  Future<void> submitDeadlineChangeRequest({
    required Project project,
    required DateTime newDueDate,
    required String reason,
  }) async {
    final now = DateTime.now();
    await _db.collection('approvalRequests').add(ApprovalRequest(
          id: '',
          type: ApprovalType.deadlineChange,
          status: DecisionStatus.pending,
          title: 'طلب تعديل الموعد النهائي: ${project.name}',
          description: reason,
          priority: PriorityLevel.medium,
          delayImpactDays: newDueDate.difference(project.dueDate).inDays.abs(),
          departmentId: project.departmentId,
          projectId: project.id,
          requestedByUid: currentUser?.id ?? '',
          requestedByName: currentUser?.name ?? '',
          requestedDate: now,
          payload: {
            'projectId': project.id,
            'oldDueDate': project.dueDate.toIso8601String(),
            'newDueDate': newDueDate.toIso8601String(),
            'reason': reason,
          },
        ).toMap());
    await _log('طلب تعديل موعد', 'قدّم ${currentUser?.name} طلب تعديل الموعد النهائي لمشروع "${project.name}"');
  }

  Future<String?> approveRequest(ApprovalRequest request, {String? note}) async {
    try {
      await _functions.httpsCallable('approveRequest').call({'requestId': request.id, 'note': note});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر اعتماد الطلب';
    }
  }

  Future<String?> rejectRequest(ApprovalRequest request, {String? note}) async {
    try {
      await _functions.httpsCallable('rejectRequest').call({'requestId': request.id, 'note': note});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر رفض الطلب';
    }
  }

  Future<bool> checkBootstrapNeeded() async {
    try {
      final result = await _functions.httpsCallable('checkBootstrapNeeded').call();
      return (result.data as Map)['needed'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> bootstrapFirstAdmin() async {
    try {
      await _functions.httpsCallable('bootstrapFirstAdmin').call();
      await _auth.currentUser?.getIdToken(true);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر تنفيذ العملية';
    }
  }

  // ------------------------- إدارة المستخدمين -------------------------

  Future<String?> adminCreateUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? customRoleId,
    String? departmentId,
    List<String>? departmentIds,
  }) async {
    try {
      await _functions.httpsCallable('adminCreateUser').call({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role.name,
        'customRoleId': customRoleId,
        'departmentId': departmentId,
        'departmentIds': departmentIds,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر إنشاء المستخدم';
    }
  }

  Future<String?> setUserRole(
    AppUser user, {
    required UserRole role,
    String? customRoleId,
    String? departmentId,
    List<String>? departmentIds,
  }) async {
    try {
      await _functions.httpsCallable('setUserRole').call({
        'uid': user.id,
        'role': role.name,
        'customRoleId': customRoleId,
        'departmentId': departmentId,
        'departmentIds': departmentIds,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر تعديل دور المستخدم';
    }
  }

  // ------------------------- الأدوار المخصصة -------------------------

  Future<void> saveCustomRole(CustomRole role) async {
    final ref = role.id.isEmpty ? _db.collection('roles').doc() : _db.collection('roles').doc(role.id);
    await ref.set(role.toMap());
    await _log('إدارة الأدوار', 'تم حفظ الدور المخصص "${role.name}"');
  }

  Future<void> deleteCustomRole(CustomRole role) async {
    await _db.collection('roles').doc(role.id).delete();
    await _log('إدارة الأدوار', 'تم حذف الدور المخصص "${role.name}"');
  }

  Future<String?> setUserStatus(AppUser user, UserStatus status) async {
    try {
      await _functions.httpsCallable('setUserStatus').call({'uid': user.id, 'status': status.name});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر تحديث حالة المستخدم';
    }
  }

  /// إرسال إشعار (بريد و/أو واتساب) لمستخدم واحد أو أكثر دفعة واحدة.
  Future<String?> sendUserNotification({
    required List<AppUser> users,
    required NotifyChannel channel,
    required String subject,
    required String message,
  }) async {
    try {
      await _functions.httpsCallable('sendUserNotification').call({
        'uids': users.map((u) => u.id).toList(),
        'channel': channel.name,
        'subject': subject,
        'message': message,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذر إرسال الإشعار';
    }
  }

  // ------------------------- الإدارات -------------------------

  Future<void> addDepartment(Department dept) async {
    await _db.collection('departments').doc(dept.id).set(dept.toMap());
    await _log('إدارة الإدارات', 'تمت إضافة إدارة جديدة "${dept.name}"');
  }

  Future<void> seedDefaultDepartments() async {
    final batch = _db.batch();
    for (final d in DefaultDepartments.suggestions()) {
      batch.set(_db.collection('departments').doc(d.id), d.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    await _log('إدارة الإدارات', 'تم استيراد الإدارات الافتراضية');
  }

  /// استيراد بيانات وزارة العدل الحقيقية (من ملف Excel الذي زوّدنا به مسؤول
  /// النظام): الإدارات الأربع الظاهرة بالملف + كل بند عمل كمشروع مستقل بمنفذه.
  /// معرّفات ثابتة (merge) بحيث يكون تكرار الاستيراد آمناً دون تكرار السجلات.
  Future<void> importMinistryData() async {
    final batch = _db.batch();
    for (final d in MinistryImportData.departments()) {
      batch.set(_db.collection('departments').doc(d.id), d.toMap(), SetOptions(merge: true));
    }
    for (final p in MinistryImportData.projects()) {
      batch.set(_db.collection('projects').doc(p.id), p.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    await _log('استيراد بيانات', 'قام ${currentUser?.name} باستيراد بيانات وزارة العدل من ملف Excel');
  }

  /// توليد بيانات تجريبية كاملة (إدارات + مشاريع + مهام + مخاطر/عوائق +
  /// تحديثات يومية + قرار تنفيذي واحد بانتظار الاعتماد) لمعاينة لوحة القيادة
  /// وبقية الشاشات فوراً دون انتظار إدخال بيانات حقيقية. آمنة التكرار
  /// (معرّفات ثابتة + merge)، ولا تُنشئ أي حساب مستخدم أو تمس بوابات الموافقة
  /// الثلاث بأي شكل.
  Future<void> seedDemoData() async {
    final batch = _db.batch();
    for (final d in DefaultDepartments.suggestions()) {
      batch.set(_db.collection('departments').doc(d.id), d.toMap(), SetOptions(merge: true));
    }
    for (final p in DemoData.projects()) {
      batch.set(_db.collection('projects').doc(p.id), p.toMap(), SetOptions(merge: true));
    }
    for (final t in DemoData.tasks()) {
      batch.set(_db.collection('tasks').doc(t.id), {...t.toMap(), 'managerUid': null}, SetOptions(merge: true));
    }
    for (final r in DemoData.risks()) {
      batch.set(_db.collection('risks').doc(r.id), {...r.toMap(), 'managerUid': null}, SetOptions(merge: true));
    }
    for (final b in DemoData.blockers()) {
      batch.set(_db.collection('blockers').doc(b.id), {...b.toMap(), 'managerUid': null}, SetOptions(merge: true));
    }
    for (final u in DemoData.dailyUpdates()) {
      batch.set(_db.collection('dailyUpdates').doc(u.id), {...u.toMap(), 'managerUid': null}, SetOptions(merge: true));
    }
    batch.set(
      _db.collection('approvalRequests').doc('demo_decision_1'),
      DemoData.decisionRequest(requestedByUid: currentUser?.id ?? '', requestedByName: currentUser?.name ?? 'مسؤول النظام'),
      SetOptions(merge: true),
    );
    await batch.commit();
    await _log('بيانات تجريبية', 'تم توليد بيانات تجريبية لاختبار المنصة');
  }

  // ------------------------- تخصيص لوحة القيادة -------------------------

  List<DailyUpdate> get recentUpdates {
    final list = dailyUpdates.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list.take(8).toList();
  }

  Future<void> saveDashboardWidgets(List<DashboardWidgetConfig> widgets) async {
    await _db.collection('dashboardConfig').doc('main').set({
      'widgets': widgets.map((w) => w.toMap()).toList(),
    });
    await _log('تخصيص لوحة القيادة', 'قام ${currentUser?.name} بتحديث تخطيط لوحة القيادة الرئيسية');
  }

  // ------------------------- إعدادات المظهر (مسؤول النظام فقط) -------------------------

  Color get brandPrimary => AppColors.primary;
  Color get brandAccent => AppColors.accent;

  /// حفظ لوني الهوية المخصّصين. يُطبَّقان فوراً على كل المستخدمين عبر
  /// الاستماع اللحظي لمستند settings/theme، دون الحاجة لإعادة نشر الموقع.
  Future<void> saveBrandColors({required Color primary, required Color accent}) async {
    await _db.collection('settings').doc('theme').set({
      'primary': primary.toARGB32(),
      'accent': accent.toARGB32(),
    });
    await _log('إعدادات المظهر', 'قام ${currentUser?.name} بتخصيص ألوان الهوية');
  }

  Future<void> resetBrandColors() async {
    await _db.collection('settings').doc('theme').delete();
    await _log('إعدادات المظهر', 'قام ${currentUser?.name} بإعادة ألوان الهوية للوضع الافتراضي');
  }

  // ------------------------- التقارير -------------------------

  Future<ReportSnapshot> generateReport(ReportPeriod period) async {
    final ranking =
        departmentRanking.map((e) => MapEntry(e.key.name, double.parse(e.value.toStringAsFixed(1)))).toList();
    final topDept = ranking.isNotEmpty ? ranking.first : null;
    final weakDept = ranking.isNotEmpty ? ranking.last : null;

    final summary = StringBuffer();
    summary.writeln(
      'خلال هذه الفترة (${period.label}) بلغت نسبة الإنجاز العام على مستوى الوزارة ${overallProgress.toStringAsFixed(1)}٪، '
      'بمتوسط تأخير قدره ${overallAvgDelay.toStringAsFixed(1)} يوم عن الخطة الزمنية المعتمدة.',
    );
    if (topDept != null) {
      summary.writeln('تصدّرت "${topDept.key}" ترتيب الإدارات من حيث الأداء بنسبة إنجاز ${topDept.value}٪.');
    }
    if (weakDept != null && weakDept.key != topDept?.key) {
      summary.writeln('في المقابل, تحتاج "${weakDept.key}" إلى دعم ومتابعة إضافية بنسبة إنجاز ${weakDept.value}٪.');
    }
    summary.writeln(
      'تم رصد $openRisksCount مخاطر قائمة و $openBlockersCount عوائق نشطة، '
      'مع وجود $pendingApprovalsCount طلب بانتظار اعتماد القيادة التنفيذية.',
    );

    final ref = _db.collection('reports').doc();
    final report = ReportSnapshot(
      id: ref.id,
      period: period,
      generatedDate: DateTime.now(),
      executiveSummary: summary.toString().trim(),
      avgProgress: overallProgress,
      avgDelayDays: overallAvgDelay,
      totalRisks: openRisksCount,
      totalBlockers: openBlockersCount,
      pendingDecisions: pendingApprovalsCount,
      departmentRanking: ranking,
    );
    await ref.set(report.toMap());
    await _log('تقرير', 'تم توليد تقرير ${period.label} بتاريخ ${Formatters.shortDate(report.generatedDate)}');
    return report;
  }

  Future<void> updateReportComment(ReportSnapshot report, String comment) async {
    report.manualComment = comment;
    await _db.collection('reports').doc(report.id).update({'manualComment': comment});
  }

  // ------------------------- سجل التدقيق -------------------------

  Future<void> _log(String action, String details) async {
    final ref = _db.collection('auditLog').doc();
    await ref.set(AuditLogEntry(
      id: ref.id,
      userName: currentUser?.name ?? 'النظام',
      action: action,
      details: details,
      timestamp: DateTime.now(),
    ).toMap());
  }
}
