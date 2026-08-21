import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:flutter/material.dart';

import '../models/alert_rules.dart';
import '../models/registration_policy.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/attachment.dart';
import '../models/approval_request.dart';
import '../models/audit_log_entry.dart';
import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/custom_role.dart';
import '../models/dashboard_widget_config.dart';
import '../models/department.dart';
import '../models/department_section.dart';
import '../models/enums.dart';
import '../models/feedback_item.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/report.dart';
import '../models/role_permissions.dart';
import '../models/risk.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_picker.dart';
import '../utils/formatters.dart';
import '../utils/safe_file_name.dart';
import 'default_departments.dart';
import 'demo_data.dart';
import 'ministry_import_data.dart';
import 'ministry_projects_2026.dart';

/// طبقة إدارة الحالة المركزية للمنصة، مبنية بالكامل على Firebase:
/// - المصادقة: Firebase Authentication (بريد إلكتروني/كلمة مرور)
/// - البيانات: Cloud Firestore (استماع لحظي real-time لكل المجموعات)
/// - العمليات الحساسة (اعتماد الطلبات، إرسال الإشعارات): Cloud Functions
///
/// لا تُجرى أي عملية اعتماد (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي) مباشرة من
/// هذا الملف؛ كل ما يفعله الطلب هو إنشاء وثيقة "طلب موافقة" في Firestore، والتنفيذ
/// الفعلي يتم حصرياً داخل Cloud Functions بعد تحقق الخادم من صلاحية مسؤول النظام.
class AppStore extends ChangeNotifier {
  // مقيَّمة بكسل (late) لا فور الإنشاء: هذا يسمح ببناء AppStore في اختبارات
  // المعاينة وملء حقوله ببيانات تجريبية مباشرةً دون تهيئة Firebase، فنتمكن من
  // تصيير الشاشات ومراجعتها بصرياً. في التشغيل الفعلي لا يتغير شيء — أول
  // استخدام لأي منها يهيّئه تماماً كما كان.
  late final _auth = fb_auth.FirebaseAuth.instance;
  late final _db = FirebaseFirestore.instance;
  // يجب أن تطابق المنطقة (region) المحددة في functions/src/index.ts
  // (setGlobalOptions)، وإلا تفشل كل استدعاءات httpsCallable بصمت.
  late final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

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
  /// تخطيط لوحة القيادة على ثلاث طبقات، تُقرأ من الأخصّ إلى الأعمّ:
  /// لوحة المستخدم نفسه ← لوحة دوره ← اللوحة العامة ← الودجات الافتراضية.
  /// راجع [dashboardWidgets] للتخطيط الفعلي المعروض.
  List<DashboardWidgetConfig> globalDashboardWidgets = DashboardWidgetConfig.defaults();
  final Map<String, List<DashboardWidgetConfig>> _roleDashboards = {};
  List<DashboardWidgetConfig>? _myDashboard;

  List<DashboardWidgetConfig> projectsPageWidgets = [];
  List<PlatformAnnouncement> announcements = [];
  AlertRulesConfig alertRules = const AlertRulesConfig();
  RegistrationPolicy registrationPolicy = const RegistrationPolicy();
  List<CustomRole> customRoles = [];

  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _themeSub;
  final List<StreamSubscription> _dataSubs = [];

  /// أخطاء قراءة البيانات من الخادم، مفتاحها اسم المجموعة.
  ///
  /// كانت مستمعات Firestore كلها بلا `onError`، فرفض الصلاحية يعود **صامتاً
  /// تماماً**: تبقى القوائم فارغة بلا رسالة، فيظن المستخدم أن لا بيانات
  /// بينما الحقيقة أن الخادم رفض قراءته. وهذا ما جعل مدير الإدارة يرى منصة
  /// خالية — لا مشاريعه ولا حتى التعميمات العامة — بلا أي دليل على السبب.
  ///
  /// تُجمع هنا فتُعرض في لافتة أعلى المنصة، فيصير الرفض معلومة تُقرأ وتُصوَّر
  /// بدل شاشة فارغة غامضة.
  final Map<String, String> dataErrors = {};

  /// المشاريع من مصادرها الثلاثة قبل الدمج — راجع `publishProjects`.
  List<Project> _projectsByScope = [];
  List<Project> _projectsByMembership = [];
  List<Project> _projectsByExecution = [];

  /// الأعمال وطلبات الاعتماد كذلك: لكل نطاق تدفّقه، ثم تُدمج — راجع `_mergeById`.
  List<WorkItem> _worksByScope = [];
  List<WorkItem> _worksByAssignment = [];
  List<ApprovalRequest> _requestsByScope = [];
  List<ApprovalRequest> _requestsByMine = [];
  List<FeedbackItem> _feedbackAll = [];
  List<FeedbackItem> _feedbackMine = [];

  /// هل رُفضت قراءة أي مجموعة؟ يُستخدم لإظهار اللافتة.
  bool get hasDataErrors => dataErrors.isNotEmpty;

  /// هل يبدو الرفض ناتجاً عن صلاحيات ناقصة (لا عن انقطاع شبكة)؟ يحدّد نصّ
  /// اللافتة: نقص الصلاحيات له علاج (مزامنة بطاقة الدخول)، والانقطاع لا.
  bool get hasPermissionErrors =>
      dataErrors.values.any((e) => e.contains('permission-denied') || e.contains('PERMISSION_DENIED'));

  void _noteDataError(String label, Object error) {
    final text = error.toString();
    if (dataErrors[label] == text) return;
    dataErrors[label] = text;
    notifyListeners();
  }

  /// يشترك في تدفّق بيانات **مع معالج خطأ دائماً**. لا يُشترك في أي تدفّق
  /// خارج هذه الدالة، حتى لا يعود الصمت من باب جديد.
  void _listen<T>(String label, Stream<T> stream, void Function(T) onData) {
    _dataSubs.add(stream.listen(
      (value) {
        if (dataErrors.remove(label) != null) notifyListeners();
        onData(value);
      },
      onError: (Object e) => _noteDataError(label, e),
    ));
  }

  // ودجات مخصصة لكل مشروع على حدة (صفحة المشروع) — تُشترَك عند الطلب فقط
  // (وليس مسبقاً لكل المشاريع دفعة واحدة) توفيراً للاستدعاءات.
  final Map<String, List<DashboardWidgetConfig>> _projectWidgets = {};
  final Set<String> _projectWidgetsSubscribed = {};

  List<DashboardWidgetConfig> projectWidgetsFor(String projectId) => _projectWidgets[projectId] ?? const [];

  // ------------------------- طبقات لوحة القيادة -------------------------

  /// مفتاح دور المستخدم الحالي في تخزين لوحات الأدوار.
  ///
  /// الأدوار الأساسية تُخزَّن باسمها (`executiveViewer`، `departmentManager`...)،
  /// والأدوار المخصّصة يحمل كل دور منها مفتاحه الخاص حتى لا يتشارك دوران
  /// مخصّصان مختلفان لوحة واحدة.
  String? get dashboardRoleKey {
    final role = currentUser?.role;
    if (role == null) return null;
    if (role == UserRole.custom) {
      final id = currentUser?.customRoleId;
      return id == null ? null : 'custom_$id';
    }
    return role.name;
  }

  /// التخطيط الفعلي الذي يراه المستخدم الحالي.
  ///
  /// الأخصّ يفوز: إن خصّص المستخدم لوحته رآها، وإلا فلوحة دوره التي ضبطها
  /// مسؤول النظام، وإلا فاللوحة العامة. قائمة فارغة تعني "لم يُضبط" لا
  /// "لوحة بلا ودجات"، فتُتخطّى إلى الطبقة التالية.
  List<DashboardWidgetConfig> get dashboardWidgets {
    final key = dashboardRoleKey;
    return DashboardWidgetConfig.resolveLayers(
      personal: _myDashboard,
      role: key == null ? null : _roleDashboards[key],
      global: globalDashboardWidgets,
    );
  }

  /// هل خصّص المستخدم الحالي لوحته الخاصة؟ (لإظهار زر "العودة للوحة الافتراضية")
  bool get hasPersonalDashboard => (_myDashboard ?? const []).isNotEmpty;

  /// تخطيط دور معيّن كما هو مخزَّن (فارغ إن لم يُضبط بعد) — لشاشة التخصيص.
  List<DashboardWidgetConfig> roleDashboardWidgets(String roleKey) => _roleDashboards[roleKey] ?? const [];

  /// هل يملك المستخدم الحالي ضبط لوحات الأدوار واللوحة العامة لغيره؟
  /// تخصيص لوحته الشخصية متاح للجميع ولا يمرّ من هنا.
  bool get canManageSharedDashboards => hasPermission(RolePermission.manageDashboard);

  static List<DashboardWidgetConfig> _parseWidgets(Object? raw) {
    if (raw is! List || raw.isEmpty) return const [];
    return DashboardWidgetConfig.dedupe(
      raw.map((w) => DashboardWidgetConfig.fromMap(Map<String, dynamic>.from(w as Map))).toList(),
    );
  }

  /// حفظ لوحة المستخدم الحالي وحده. متاح لكل مستخدم معتمَد على مستنده هو.
  Future<void> saveMyDashboardWidgets(List<DashboardWidgetConfig> widgets) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _db.collection('userDashboards').doc(uid).set({
      'widgets': DashboardWidgetConfig.dedupe(widgets).map((w) => w.toMap()).toList(),
    });
  }

  /// إلغاء تخصيص المستخدم الحالي فيعود لرؤية لوحة دوره أو اللوحة العامة.
  Future<void> resetMyDashboardWidgets() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _db.collection('userDashboards').doc(uid).delete();
  }

  /// حفظ لوحة دور كامل (مسؤول النظام أو من يملك صلاحية التحكم باللوحة).
  Future<void> saveRoleDashboardWidgets(String roleKey, List<DashboardWidgetConfig> widgets) async {
    await _db.collection('dashboardConfig').doc('role_$roleKey').set({
      'widgets': DashboardWidgetConfig.dedupe(widgets).map((w) => w.toMap()).toList(),
    });
    await _log('تخصيص لوحة القيادة', 'قام ${currentUser?.name} بتحديث تخطيط لوحة القيادة لدور $roleKey');
  }

  void ensureProjectWidgetsSubscribed(String projectId) {
    if (_projectWidgetsSubscribed.contains(projectId)) return;
    _projectWidgetsSubscribed.add(projectId);
    _listen('projectWidgets', _db.collection('projectWidgets').doc(projectId).snapshots(), (doc) {
      final widgets = doc.data()?['widgets'] as List?;
      _projectWidgets[projectId] = widgets == null
          ? []
          : DashboardWidgetConfig.dedupe(widgets.map((w) => DashboardWidgetConfig.fromMap(Map<String, dynamic>.from(w as Map))).toList());
      notifyListeners();
    });
  }

  Future<void> saveProjectWidgets(String projectId, List<DashboardWidgetConfig> widgets) async {
    await _db.collection('projectWidgets').doc(projectId).set({
      'widgets': DashboardWidgetConfig.dedupe(widgets).map((w) => w.toMap()).toList(),
    });
    await _log('تخصيص ودجات المشروع', 'قام ${currentUser?.name} بتحديث الودجات المخصصة لأحد المشاريع');
  }

  Future<void> saveProjectsPageWidgets(List<DashboardWidgetConfig> widgets) async {
    await _db.collection('dashboardConfig').doc('projectsPage').set({
      'widgets': DashboardWidgetConfig.dedupe(widgets).map((w) => w.toMap()).toList(),
    });
    await _log('تخصيص صفحة المشاريع', 'قام ${currentUser?.name} بتحديث الودجات المخصصة في صفحة المشاريع');
  }

  // ------------------------- إشعارات عامة على المنصة (مسؤول النظام فقط) -------------------------

  Future<void> addAnnouncement(String message, AnnouncementStyle style) async {
    final ref = _db.collection('announcements').doc();
    await ref.set(PlatformAnnouncement(
      id: ref.id,
      message: message,
      style: style,
      createdAt: DateTime.now(),
      createdByName: currentUser?.name ?? '',
    ).toMap());
    await _log('إشعار عام جديد', 'أضاف ${currentUser?.name} إشعاراً عاماً لكل المستخدمين');
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
    await _log('حذف إشعار عام', 'حذف ${currentUser?.name} إشعاراً عاماً');
  }

  Future<void> saveAlertRules(AlertRulesConfig config) async {
    await _db.collection('settings').doc('alertRules').set(config.toMap());
    await _log('تحديث التنبيهات الذكية', 'قام ${currentUser?.name} بتحديث إعدادات التنبيهات التلقائية');
  }

  Future<void> saveRegistrationPolicy(RegistrationPolicy policy) async {
    await _db.collection('settings').doc('registration').set(policy.toMap());
    await _log('تحديث سياسة التسجيل',
        'قام ${currentUser?.name} بتحديث نطاقات البريد المقبولة للتسجيل');
  }

  /// يقرأ سياسة التسجيل **قبل تسجيل الدخول**.
  ///
  /// شاشة التسجيل لا مستخدم فيها بعد، فلا اشتراك بيانات ولا `registrationPolicy`
  /// محمَّلة. وقاعدة `settings` تسمح بالقراءة للجميع، فتُقرأ مباشرةً هنا.
  Future<RegistrationPolicy> loadRegistrationPolicy() async {
    try {
      final doc = await _db.collection('settings').doc('registration').get();
      return RegistrationPolicy.fromMap(doc.data());
    } catch (_) {
      // تعذّرت القراءة: لا نمنع التسجيل بسبب عطل في قراءة إعداد اختياري.
      return const RegistrationPolicy();
    }
  }

  // ------------------------- تأكيد البريد -------------------------

  /// هل أكّد المستخدم الحالي بريده؟ يقرأ حالة الحساب من خادم المصادقة.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// هل يلزم هذا المستخدمَ تأكيدُ بريده قبل عرض طلبه على مسؤول النظام؟
  ///
  /// الاستثناء يمنحه مسؤول النظام على سجل المستخدم، ولا يستطيع المستخدم
  /// منحه لنفسه (قاعدة `/users/{uid}` تمنعه من تعديل سجلّه).
  bool get needsEmailVerification {
    if (currentUser?.emailVerificationExempt == true) return false;
    if (!registrationPolicy.requireEmailVerification) return false;
    return !isEmailVerified;
  }

  /// يرسل رسالة تأكيد البريد للمستخدم الحالي.
  Future<String?> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      // كثرة الطلب أشهر أسباب الفشل، ورسالتها الافتراضية إنجليزية غامضة.
      if (e.code == 'too-many-requests') {
        return 'أُرسلت رسائل كثيرة خلال وقت قصير. انتظر دقائق ثم أعد المحاولة.';
      }
      return e.message ?? 'تعذّر إرسال رسالة التأكيد';
    }
  }

  /// يعيد تحميل حالة الحساب من الخادم بعد أن يضغط المستخدم رابط التأكيد.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    // التوكن يحمل `email_verified`، فيجب تجديده وإلا بقيت القواعد ترى القديم.
    await user.getIdToken(true);
    notifyListeners();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// يمنح مستخدماً استثناءً من تأكيد البريد أو يسحبه — لمسؤول النظام.
  Future<String?> setEmailVerificationExempt(AppUser user, bool exempt) async {
    try {
      await _db.collection('users').doc(user.id).update({'emailVerificationExempt': exempt});
      await _log('استثناء تأكيد البريد',
          '${exempt ? 'مُنح' : 'سُحب'} استثناء تأكيد البريد للمستخدم "${user.name}"');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ------------------------- الأعمال التشغيلية -------------------------

  /// بنود العمل التشغيلية المستقلة عن المشاريع (مجموعة `works`).
  List<WorkItem> works = [];

  /// الشكاوى والاقتراحات (مجموعة `feedback`)، مرتّبة بالأحدث.
  List<FeedbackItem> feedback = [];

  bool get canSubmitFeedback => hasPermission(RolePermission.submitFeedback);
  bool get canManageFeedback => hasPermission(RolePermission.manageFeedback);

  /// ما رفعه المستخدم الحالي — يراه دائماً ولو لم يعد يملك صلاحية الرفع.
  List<FeedbackItem> get myFeedback =>
      feedback.where((f) => f.submittedByUid == currentUser?.id).toList();

  /// الوارد لمن يتابع الشكاوى. مسؤول النظام وحامل «متابعة الشكاوى» فقط.
  List<FeedbackItem> get incomingFeedback => canManageFeedback ? feedback : const [];

  int get openFeedbackCount =>
      canManageFeedback ? feedback.where((f) => f.isOpen).length : 0;

  /// يرفع شكوى أو اقتراحاً باسم المستخدم الحالي.
  ///
  /// المعرّف يُؤخذ من الحساب لا من الواجهة، والقاعدة تشترط تطابقه مع المتصل —
  /// فلا يُنسب أحدٌ شكوى إلى غيره.
  Future<String?> submitFeedback({
    required FeedbackKind kind,
    required String title,
    required String body,
  }) async {
    final me = currentUser;
    if (me == null) return 'لا يوجد مستخدم مسجَّل';
    try {
      await _db.collection('feedback').add(FeedbackItem(
            id: '',
            kind: kind,
            title: title.trim(),
            body: body.trim(),
            submittedByUid: me.id,
            submittedByName: me.name,
            departmentId: me.departmentId,
            createdAt: DateTime.now(),
          ).toMap());
      return null;
    } catch (e) {
      return 'تعذّر إرسال ${kind.label}: $e';
    }
  }

  /// يبتّ في شكوى أو اقتراح. نصّ الشكوى نفسه لا يُمسّ — القاعدة تمنع ذلك.
  Future<String?> resolveFeedback(
    FeedbackItem item, {
    required FeedbackStatus status,
    String? note,
  }) async {
    try {
      await _db.collection('feedback').doc(item.id).update({
        'status': status.name,
        'responseNote': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'handledByName': currentUser?.name,
        'handledAt': Timestamp.fromDate(DateTime.now()),
      });
      await _log('الشكاوى والاقتراحات',
          'بتّ ${currentUser?.name} في ${item.kind.label} "${item.title}" — ${status.label}');
      return null;
    } catch (e) {
      return 'تعذّر حفظ القرار: $e';
    }
  }

  /// الأعمال ضمن نطاق المستخدم الحالي:
  /// - من يرى كل الإدارات: كل الأعمال.
  /// - مدير الإدارة: أعمال إداراته.
  /// - الموظف ومدير المشروع وغيرهما: الأعمال المُسنَدة إليه، إضافة إلى أعمال
  ///   إدارته إن كان يملك صلاحية إدارة الأعمال.
  List<WorkItem> get visibleWorks {
    final user = currentUser;
    if (user == null) return const [];
    if (canViewAllDepartments) return works;
    // **المُسنَد إليه أولاً، مهما كانت إدارته.**
    //
    // وكان مدير الإدارة يرى أعمال إداراته وحدها، فعملٌ أُسنِد إليه شخصياً في
    // إدارة أخرى يختفي عنه — يصله إشعارٌ بعملٍ لا يجده في المنصة. والقاعدة
    // على الخادم كانت تسمح بقراءته أصلاً؛ التصفية في الواجهة وحدها هي التي
    // كانت تُسقطه.
    final mine = works.where((w) => w.assigneeUid == user.id);
    final scoped = (isManager || canManageWorks)
        ? works.where((w) => myDepartmentIds.contains(w.departmentId))
        : const <WorkItem>[];
    return mergeById<WorkItem>((w) => w.id, [mine.toList(), scoped.toList()]);
  }

  /// المشاريع المُسنَدة إلى المستخدم الحالي مديراً أو منفّذاً — **أينما كانت**.
  List<Project> get myProjects {
    final uid = currentUser?.id;
    if (uid == null) return const [];
    final list = projects.where((p) => p.hasMember(uid)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// الأعمال المُسنَدة إلى المستخدم الحالي — أينما كانت إدارتها.
  List<WorkItem> get myWorks {
    final uid = currentUser?.id;
    if (uid == null) return const [];
    final list = works.where((w) => w.assigneeUid == uid).toList()
      ..sort((a, b) {
        // غير المنجَز أولاً، ثم الأقرب موعداً — فما يحتاج عملاً في الأعلى.
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
    return list;
  }

  /// سجل الإنجاز: الأعمال المنجَزة مرتّبة بالأحدث إنجازاً.
  List<WorkItem> get completedWorks {
    final done = visibleWorks.where((w) => w.isDone).toList();
    done.sort((a, b) => (b.completedDate ?? b.dueDate).compareTo(a.completedDate ?? a.dueDate));
    return done;
  }

  /// هل يستطيع المستخدم الحالي تعديل هذا العمل؟ الموظف يحدّث تقدّم عمله
  /// المُسنَد إليه، ومن يملك صلاحية إدارة الأعمال يعدّل أعمال نطاقه.
  bool canEditWork(WorkItem work) {
    final user = currentUser;
    if (user == null) return false;
    if (isAdmin) return true;
    if (work.assigneeUid == user.id) return true;
    if (!canManageWorks) return false;
    if (canViewAllDepartments) return true;
    if (isManager) return myDepartmentIds.contains(work.departmentId);
    return user.departmentId == work.departmentId;
  }

  Future<void> addWork(WorkItem work) async {
    final ref = _db.collection('works').doc();
    await ref.set(work.toMap());
    await _log('الأعمال التشغيلية', 'أضاف ${currentUser?.name} العمل "${work.title}"');
  }

  Future<void> updateWork(WorkItem work) async {
    await _db.collection('works').doc(work.id).update(work.toMap());
  }

  Future<String?> deleteWork(WorkItem work) async {
    try {
      await _db.collection('works').doc(work.id).delete();
      await _log('الأعمال التشغيلية', 'حذف ${currentUser?.name} العمل "${work.title}"');
      return null;
    } catch (e) {
      return 'تعذر حذف العمل: $e';
    }
  }

  // ------------------------- متابعة الأشخاص -------------------------

  /// مؤشرات أداء شخص واحد، محسوبة من الأعمال والمشاريع مباشرة بلا مجموعة
  /// إضافية. يستخدمها جدول المقارنة وملف الشخص معاً فلا يتكرر الحساب.
  ({
    int works,
    int worksDone,
    int worksOverdue,
    double avgWorkProgress,
    int projects,
    int projectsOverdue,
  }) personStats(AppUser user) {
    final myWorks = worksOf(user);
    final myProjects = projectsOf(user);
    return (
      works: myWorks.length,
      worksDone: myWorks.where((w) => w.isDone).length,
      worksOverdue: myWorks.where((w) => w.delayDays > 0).length,
      avgWorkProgress: myWorks.isEmpty
          ? 0
          : myWorks.map((w) => w.progressPercent).reduce((a, b) => a + b) / myWorks.length,
      projects: myProjects.length,
      projectsOverdue: myProjects.where((p) => p.delayDays > 0).length,
    );
  }

  /// أعمال الشخص (المُسنَدة إليه بمعرّفه).
  List<WorkItem> worksOf(AppUser user) => works.where((w) => w.assigneeUid == user.id).toList();

  /// مشاريع الشخص: ما يديره (managerUid) وما هو منفّذ فيه (مطابقة بالاسم،
  /// لأن المشروع يخزّن أسماء المنفذين لا معرّفاتهم).
  List<Project> projectsOf(AppUser user) {
    final name = user.name.trim();
    return projects
        .where((p) => p.managerUid == user.id || p.executorNames.any((e) => e.trim() == name))
        .toList();
  }

  /// الأشخاص الذين يستطيع المستخدم الحالي متابعتهم: الكل لمن يرى كل
  /// الإدارات، وموظفو إداراته لمدير الإدارة.
  List<AppUser> get trackablePeople {
    final approved = users.where((u) => u.status == UserStatus.approved && u.role != UserRole.systemAdmin).toList();
    if (canViewAllDepartments) return approved;
    if (isManager) {
      return approved
          .where((u) => myDepartmentIds.contains(u.departmentId) || u.departmentIds.any(myDepartmentIds.contains))
          .toList();
    }
    return const [];
  }

  bool get canTrackPeople => trackablePeople.isNotEmpty;

  // ------------------------- لوحة مخصّصة لكل مستخدم -------------------------

  /// ما ثبّته مسؤول النظام في لوحة قيادة **المستخدم الحالي** تحديداً
  /// (مجموعة `userFocus/{uid}`)، بخلاف [focusedProjectIds] العامة التي يراها
  /// الجميع.
  List<String> myFocusProjectIds = [];
  List<String> myFocusWorkIds = [];

  List<Project> get myFocusProjects {
    final visible = visibleProjects;
    return myFocusProjectIds.map((id) => visible.where((p) => p.id == id)).expand((e) => e).toList();
  }

  List<WorkItem> get myFocusWorks {
    final visible = visibleWorks;
    return myFocusWorkIds.map((id) => visible.where((w) => w.id == id)).expand((e) => e).toList();
  }

  /// يقرأ تثبيتات مستخدم آخر (لتحرير لوحته). يُحمَّل عند الطلب لا اشتراكاً
  /// دائماً بكل المستندات — قد يكون عدد المستخدمين بالمئات.
  Future<({List<String> projectIds, List<String> workIds})> focusFor(String uid) async {
    final doc = await _db.collection('userFocus').doc(uid).get();
    final data = doc.data() ?? {};
    return (
      projectIds: ((data['projectIds'] as List?) ?? []).map((e) => e.toString()).toList(),
      workIds: ((data['workIds'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }

  Future<void> setUserFocus(String uid, {required List<String> projectIds, required List<String> workIds}) async {
    await _db.collection('userFocus').doc(uid).set({'projectIds': projectIds, 'workIds': workIds});
    final target = users.where((u) => u.id == uid);
    await _log(
      'تخصيص لوحة مستخدم',
      'حدّث ${currentUser?.name} ما يظهر في لوحة قيادة "${target.isEmpty ? uid : target.first.name}"',
    );
  }

  /// يضيف أو يزيل عنصراً واحداً من لوحة مستخدم بعينه — يُستخدم من نموذج
  /// التثبيت المفتوح من صفحة المشروع أو العمل.
  Future<void> toggleFocusForUser(String uid, {String? projectId, String? workId}) async {
    final current = await focusFor(uid);
    final projectIds = List<String>.of(current.projectIds);
    final workIds = List<String>.of(current.workIds);
    if (projectId != null && !projectIds.remove(projectId)) projectIds.add(projectId);
    if (workId != null && !workIds.remove(workId)) workIds.add(workId);
    await setUserFocus(uid, projectIds: projectIds, workIds: workIds);
  }

  // ------------------------- المشاريع تحت التركيز -------------------------

  /// مشاريع اختار مسؤول النظام إبرازها منفردة بجانب الإدارات وأعلى لوحة
  /// القيادة، لتكون أول ما يراه القيادي عند الدخول.
  List<String> focusedProjectIds = [];

  bool isFocused(String projectId) => focusedProjectIds.contains(projectId);

  /// المشاريع المميّزة ضمن نطاق رؤية المستخدم الحالي فقط (تُرشَّح تلقائياً
  /// فلا يرى مستخدم مشروعاً مميّزاً خارج صلاحيته).
  List<Project> get focusedProjects {
    final visible = visibleProjects;
    return focusedProjectIds.map((id) => visible.where((p) => p.id == id)).expand((e) => e).toList();
  }

  Future<void> toggleFocusedProject(Project project) async {
    final updated = List<String>.of(focusedProjectIds);
    final wasFocused = updated.remove(project.id);
    if (!wasFocused) updated.add(project.id);
    await _db.collection('settings').doc('focus').set({'projectIds': updated});
    await _log(
      'المشاريع تحت التركيز',
      wasFocused ? 'أُزيل المشروع "${project.name}" من التركيز' : 'وُضع المشروع "${project.name}" تحت التركيز',
    );
  }

  /// تنبيهات تُحسب حيّة من بيانات المشاريع الفعلية حسب إعدادات [alertRules]
  /// (بدل أن تُكتب يدوياً)، ضمن نطاق رؤية المستخدم الحالي.
  List<ProjectAlertGroup> get liveProjectAlerts {
    final groups = <ProjectAlertGroup>[];
    if (alertRules.delayedEnabled) {
      final delayed = visibleProjects.where((p) => p.delayDays > 0).toList();
      if (delayed.isNotEmpty) {
        groups.add(ProjectAlertGroup(
          title: '${delayed.length} مشروع متأخر عن الخطة',
          style: AnnouncementStyle.danger,
          projects: delayed,
        ));
      }
    }
    if (alertRules.dueSoonEnabled) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dueSoon = visibleProjects.where((p) {
        if (p.effectiveStatus == ProjectStatus.completed) return false;
        final due = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day);
        final diff = due.difference(todayDate).inDays;
        return diff >= 0 && diff <= alertRules.dueSoonDays;
      }).toList();
      if (dueSoon.isNotEmpty) {
        groups.add(ProjectAlertGroup(
          title: '${dueSoon.length} مشروع يستحق خلال ${alertRules.dueSoonDays} أيام',
          style: AnnouncementStyle.warning,
          projects: dueSoon,
        ));
      }
    }
    return groups;
  }

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
    _readyFallbackTimer?.cancel();
    _userDocSub?.cancel();
    _themeSub?.cancel();
    _cancelDataSubs();
    super.dispose();
  }

  /// هل حاولنا مزامنة البطاقة في هذه الجلسة؟ محاولة واحدة تكفي — التكرار
  /// عند كل تحديث للسجل يعني استدعاء دالة سحابية في حلقة.
  bool _claimsSyncTried = false;

  /// هل وصلت صلاحيات الأدوار من الخادم؟ الإعداد المبدئي ليس حقيقةً — وفيه
  /// «موظف» بلا أي صلاحية — فالمقارنة به تُنتج «لا اختلاف» كاذباً.
  bool _rolePermissionsLoaded = false;

  /// صلاحيات الأدوار قراءةً واحدة، لا عبر الاشتراكات.
  Future<RolePermissionsConfig> loadRolePermissions() async {
    try {
      final doc = await _db.collection('settings').doc('rolePermissions').get();
      return RolePermissionsConfig.fromMap(doc.data());
    } catch (_) {
      // تعذّرت القراءة: نُبقي ما لدينا بدل أن نستنتج نقصاً وهمياً.
      return rolePermissions;
    }
  }

  /// يوفّق بين سجل المستخدم وبطاقة دخوله.
  ///
  /// قواعد Firestore تقرأ `request.auth.token` لا مستند المستخدم. فحساب
  /// عُدّل دوره أو إداراته بينما صاحبه مسجَّل دخوله يبقى يحمل بطاقة قديمة،
  /// وحساب لم يُختم قط لا يحمل `approved` إطلاقاً — وفي الحالتين تُرفض كل
  /// قراءاته بصمت. نجرّب أولاً تجديد التوكن (رخيص)، فإن بقي الاختلاف
  /// استدعينا `syncMyClaims` مرة واحدة.
  Future<void> _reconcileClaims(fb_auth.User user) async {
    final me = currentUser;
    if (me == null || me.status != UserStatus.approved) return;

    // صلاحيات الأدوار تُقرأ هنا قراءةً واحدة قبل أي مقارنة.
    //
    // وغياب هذه القراءة كان عطلاً حقيقياً أفرغ شاشة الموظف: هذه الدالة
    // تُستدعى **قبل** `_subscribeAppData()`، وصلاحيات الأدوار لا تصل إلا
    // من اشتراكاتها. فكانت المقارنة تجري على الإعداد المبدئي — وفيه «موظف»
    // بلا أي صلاحية — فتقول «المتوقَّع لا شيء والبطاقة لا شيء، إذن لا
    // اختلاف» وتنصرف. فلا تسري صلاحية مُنحت حديثاً أبداً، والحارس الذي
    // بنيناه للمشكلة نفسها كان يحرس وعيناه مغمضتان.
    if (!_rolePermissionsLoaded) {
      rolePermissions = await loadRolePermissions();
      _rolePermissionsLoaded = true;
    }

    Future<bool> mismatched({required bool refresh}) async {
      try {
        final claims = await currentTokenClaims(forceRefresh: refresh);
        if (claims['approved'] != true) return true;
        if (claims['role'] != me.role.name) return true;
        // الإدارة المفردة تُقارَن بالمفردة، والجمع بالجمع.
        //
        // ومقارنة الجمع بـ `myDepartmentIds` — وهي ترجع إلى المفرد حين تفرغ —
        // كانت عطلاً مزدوجاً لكل من ليس مدير إدارة: بطاقته تحمل
        // `departmentIds: []` دائماً (والخادم لا يملؤها إلا لمدير الإدارة)،
        // فتقول المقارنة «مختلف» أبداً ولا تتّفق مهما أُعيد الختم — فتُستدعى
        // دالة سحابية في كل دخول بلا جدوى، و**تُحجب مقارنة الصلاحيات خلفها**
        // فلا تُفحص أصلاً.
        //
        // والأهم أن المفرد لم يكن يُقارَن قط، وهو الذي تحتكم إليه القواعد:
        // فبطاقةٌ بلا `departmentId` مع سجلٍّ يحمل إدارةً تعني رفض كل قراءات
        // الموظف لمشاريع إدارته — وهو يرى إدارته في سجلّه فلا يفهم السبب.
        if ((claims['departmentId'] as String?) != me.departmentId) return true;
        final tokenDepts = ((claims['departmentIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        if (!tokenDepts.containsAll(me.departmentIds.toSet())) return true;
        // الصلاحيات أيضاً — وغيابها من المقارنة كان عيباً حقيقياً: مسؤول
        // النظام يمنح صلاحية فتُختم على الخادم، بينما يبقى المستخدم حاملاً
        // بطاقته القديمة حتى ينتهي أجل رمزه (قد يبلغ ساعة). فيرى الصلاحية
        // ممنوحة في الشاشة ولا تعمل، ولا شيء يفسّر له السبب.
        if (expectedPermissionKeys.difference(tokenPermissionKeys(claims)).isNotEmpty) return true;
        // والنطاقات كذلك: صلاحية مقيَّدة بنطاق قد تكون بصمتها في البطاقة
        // موجودة والنطاق فيها قديماً (وُسِّع أو ضُيِّق بعد آخر ختم). ومقارنة
        // العلَم وحده تقول «متّفق» بينما الخادم يقيس بنطاقٍ آخر.
        //
        // ومسؤول النظام خارج هذه المقارنة كما هو خارج مقارنة الصلاحيات:
        // `scopeFor` ترجع له «كل الإدارات» وبطاقته بلا نطاقات أصلاً، فمقارنته
        // تُنتج اختلافاً وهمياً دائماً ومزامنة لا تنتهي.
        if (!isAdmin) {
          for (final p in RolePermission.scoped) {
            if (scopeFor(p) != tokenScopeFor(claims, p)) return true;
          }
        }
        return false;
      } catch (_) {
        return false;
      }
    }

    if (!await mismatched(refresh: false)) return;
    if (!await mismatched(refresh: true)) {
      _cancelDataSubs();
      _subscribeAppData();
      return;
    }
    if (_claimsSyncTried) return;
    _claimsSyncTried = true;
    await syncMyClaims();
  }

  /// يُعيد الفحص حين تصل إعدادات الصلاحيات **بعد** بدء الاشتراكات — أي حين
  /// يمنح مسؤول النظام صلاحيةً والمستخدم فاتحٌ صفحته. فتسري بلا خروج ودخول.
  Future<void> _recheckPermissionClaims() async {
    final user = _auth.currentUser;
    if (user == null || _claimsSyncTried) return;
    if (currentUser?.status != UserStatus.approved) return;
    try {
      final claims = await currentTokenClaims();
      if (expectedPermissionKeys.difference(tokenPermissionKeys(claims)).isEmpty) return;
    } catch (_) {
      return;
    }
    await _reconcileClaims(user);
  }

  void _cancelDataSubs() {
    for (final s in _dataSubs) {
      s.cancel();
    }
    _dataSubs.clear();
    // أخطاء الاشتراك السابق لا تصف الاشتراك الجديد، فتُمسح معه — وإلا بقيت
    // لافتة خطأ معلّقة بعد أن صُحّحت صلاحيات الحساب فعلاً.
    dataErrors.clear();
    _projectsByScope = [];
    _projectsByMembership = [];
    _projectsByExecution = [];
    _worksByScope = [];
    _worksByAssignment = [];
    _requestsByScope = [];
    _requestsByMine = [];
    _feedbackAll = [];
    _feedbackMine = [];
    feedback = [];
    departments = [];
    sections = [];
    projects = [];
    tasks = [];
    risks = [];
    blockers = [];
    dailyUpdates = [];
    approvalRequests = [];
    auditLog = [];
    reports = [];
    users = [];
    globalDashboardWidgets = DashboardWidgetConfig.defaults();
    _roleDashboards.clear();
    _myDashboard = null;
    projectsPageWidgets = [];
    announcements = [];
    alertRules = const AlertRulesConfig();
    registrationPolicy = const RegistrationPolicy();
    works = [];
    myFocusProjectIds = [];
    myFocusWorkIds = [];
    focusedProjectIds = [];
    rolePermissions = RolePermissionsConfig.defaults();
    // ولأن القيمة عادت إلى الإعداد المبدئي، تعود معها علامة التحميل — وإلا
    // قارنت المزامنة لاحقاً بإعدادٍ مبدئي وهي تحسبه الحقيقة.
    _rolePermissionsLoaded = false;
    customRoles = [];
    _projectWidgets.clear();
    _projectWidgetsSubscribed.clear();
  }

  /// أقصى انتظار لأول لقطة من مستند المستخدم قبل رسم الواجهة على أي حال.
  ///
  /// بدونه يبقى `ready` كاذباً إلى الأبد إن تعذّر الوصول إلى Firestore (شبكة
  /// تحجب نطاقات Google مثلاً)، فلا تُرمى أخطاء ولا تُرسم شاشة — دوّار صامت
  /// يظنه المستخدم عطلاً تاماً. الاشتراك يبقى قائماً بعد انقضاء المهلة، فإن
  /// وصلت البيانات لاحقاً ظهرت الشاشة الصحيحة تلقائياً.
  static const Duration _firstSnapshotPatience = Duration(seconds: 15);

  Timer? _readyFallbackTimer;

  Future<void> _onAuthChanged(fb_auth.User? user) async {
    await _userDocSub?.cancel();
    _readyFallbackTimer?.cancel();
    _cancelDataSubs();
    if (user == null) {
      currentUser = null;
      _ready = true;
      notifyListeners();
      return;
    }
    _readyFallbackTimer = Timer(_firstSnapshotPatience, () {
      if (_ready) return;
      _ready = true;
      notifyListeners();
    });
    _userDocSub = _db.collection('users').doc(user.uid).snapshots().listen((doc) async {
      _readyFallbackTimer?.cancel();
      final wasApproved = currentUser?.status == UserStatus.approved;
      currentUser = doc.exists ? AppUser.fromDoc(doc) : null;
      if (!wasApproved && currentUser?.status == UserStatus.approved) {
        // تحديث Custom Claims المخزّنة في التوكن بعد اعتماد الحساب لأول مرة
        await user.getIdToken(true);
      }
      // بطاقة الدخول هي ما تحتكم إليه قواعد الخادم، لا هذا السجل. فإن اختلفا
      // رأى المستخدم منصة خالية بلا سبب — وهو ما وقع لمدير إدارة معتمد لم يرَ
      // مشاريعه ولا التعميمات العامة. نصحّح ذلك هنا بلا تدخّل منه.
      await _reconcileClaims(user);
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
      _readyFallbackTimer?.cancel();
      _ready = true;
      notifyListeners();
    });
  }

  /// يدمج تدفّقات متعددة على المجموعة نفسها في قائمة واحدة بلا تكرار.
  ///
  /// قواعد Firestore **ترفض ولا تُصفّي**: المجموعة تُطلب بنطاق يضمن أن كل ما
  /// تعيده مسموح، وإلا رُفض الطلب كله فتظهر الشاشة فارغة كأن لا بيانات. وما
  /// يحتاج شرطين مختلفين (إدارتي **أو** المُسنَد إليّ) لا يُجمع في استعلام
  /// واحد، فيُقرأ بتدفّقين. ولا يجوز أن يكتبا في قائمة واحدة لأن كلاً منهما
  /// يصل بلقطة كاملة فيدوس على الآخر — لذلك لكلٍّ قائمته وتُدمجان هنا.
  @visibleForTesting
  static List<T> mergeById<T>(String Function(T) idOf, List<List<T>> sources) {
    final byId = <String, T>{};
    for (final list in sources) {
      for (final item in list) {
        byId[idOf(item)] = item;
      }
    }
    return byId.values.toList();
  }

  /// تصفية بقائمة إدارات. Firestore يحدّ `whereIn` بثلاثين قيمة، فتُقتطع.
  Query<Map<String, dynamic>> _whereDeptIn(
    CollectionReference<Map<String, dynamic>> col,
    List<String> ids,
  ) =>
      col.where('departmentId', whereIn: ids.length > 30 ? ids.sublist(0, 30) : ids);

  void _subscribeAppData() {
    final myUid = currentUser?.id;
    final officer = isOfficer;
    final manager = isManager;
    final scopedDept = (canViewAllDepartments || officer || manager) ? null : currentUser?.departmentId;

    // أقسام الإدارات: مجموعة صغيرة تُقرأ كاملةً — الفلترة بالإدارة تتم في
    // الذاكرة لأن الشجرة تُعرض كاملةً على أي حال.
    _listen('sections', _db.collection('sections').snapshots(), (snap) {
      sections = snap.docs.map(DepartmentSection.fromDoc).toList();
      notifyListeners();
    });
    _listen('departments', _db.collection('departments').orderBy('name').snapshots(), (snap) {
      departments = snap.docs.map(Department.fromDoc).toList();
      notifyListeners();
    });

    // مدير المشروع (officer) تُقرأ له مستندات مشروعه التابعة عبر managerUid.
    // مدير الإدارة (manager) قد يدير أكثر من إدارة، فيُقيَّد بقائمة departmentIds
    // كاملة (whereIn) بدل مطابقة إدارة واحدة فقط.
    Query<Map<String, dynamic>> scoped(String collection) {
      final col = _db.collection(collection);
      if (officer) return col.where('managerUid', isEqualTo: currentUser?.id);
      if (manager) {
        final ids = myDepartmentIds;
        return ids.isEmpty ? col.where('departmentId', isEqualTo: '__none__') : _whereDeptIn(col, ids);
      }
      return scopedDept == null ? col : col.where('departmentId', isEqualTo: scopedDept);
    }

    // المشاريع وحدها لا تتبع `scoped`: نطاقها **الإدارة** لكل من لا يرى كل
    // الإدارات، مدير المشروع منهم.
    //
    // وتقييد مدير المشروع بمشروعه المُسنَد إليه كان يمنعه من رؤية مشاريع
    // إدارته أصلاً — فلا يجد ما ينضمّ إليه. أما مشاريعه المُسنَدة خارج إدارته
    // فتصله عبر تدفّقَي العضوية أدناه، فلا يضيع منه شيء.
    Query<Map<String, dynamic>> projectsScope() {
      final col = _db.collection('projects');
      if (canViewAllDepartments) return col;
      if (manager) {
        final ids = myDepartmentIds;
        return ids.isEmpty ? col.where('departmentId', isEqualTo: '__none__') : _whereDeptIn(col, ids);
      }
      final dept = currentUser?.departmentId;
      return (dept == null || dept.isEmpty)
          ? col.where('departmentId', isEqualTo: '__none__')
          : col.where('departmentId', isEqualTo: dept);
    }

    // المشاريع تُقرأ بتدفّقين لا بواحد.
    //
    // Firestore لا يجمع شرطين مختلفين في استعلام واحد، وصاحب صلاحية
    // «الانضمام لمشاريع الإدارة» يحتاج الاثنين معاً: المشاريع التي هو عضو
    // فيها (قد تكون خارج إدارته إن نُقل)، ومشاريع إدارته كاملةً. ولو كُتب
    // التدفّقان في نفس القائمة لداس أحدهما الآخر عند كل لقطة، فتظهر
    // المشاريع وتختفي بلا سبب — لذلك لكلٍّ قائمته وتُدمجان في `projects`.
    void publishProjects() {
      projects = mergeById<Project>(
        (p) => p.id,
        [_projectsByScope, _projectsByMembership, _projectsByExecution],
      );
      notifyListeners();
    }

    _listen('projects', projectsScope().snapshots(), (snap) {
      _projectsByScope = snap.docs.map(Project.fromDoc).toList();
      publishProjects();
    });
    if (myUid != null && !canViewAllDepartments) {
      _listen('projects/عضويتي',
          _db.collection('projects').where('managerUids', arrayContains: myUid).snapshots(),
          (snap) {
        _projectsByMembership = snap.docs.map(Project.fromDoc).toList();
        publishProjects();
      });
      _listen('projects/تنفيذي',
          _db.collection('projects').where('executorUids', arrayContains: myUid).snapshots(),
          (snap) {
        _projectsByExecution = snap.docs.map(Project.fromDoc).toList();
        publishProjects();
      });
    }
    _listen('tasks', scoped('tasks').snapshots(), (snap) {
      tasks = snap.docs.map(ProjectTask.fromDoc).toList();
      notifyListeners();
    });
    _listen('risks', scoped('risks').snapshots(), (snap) {
      risks = snap.docs.map(ProjectRisk.fromDoc).toList();
      notifyListeners();
    });
    _listen('blockers', scoped('blockers').snapshots(), (snap) {
      blockers = snap.docs.map(ProjectBlocker.fromDoc).toList();
      notifyListeners();
    });
    _listen('dailyUpdates', scoped('dailyUpdates').snapshots(), (snap) {
      dailyUpdates = snap.docs.map(DailyUpdate.fromDoc).toList();
      notifyListeners();
    });
    // طلبات الاعتماد كانت تُطلب كاملةً بلا نطاق، وقاعدتها تعتمد على محتوى
    // المستند — فيُرفض الطلب كله لكل من ليس مسؤول نظام أو مستخدماً تنفيذياً،
    // فلا يرى الموظف حتى حالة طلباته هو. النطاق هنا يطابق القاعدة حرفياً.
    void publishRequests() {
      approvalRequests = mergeById<ApprovalRequest>((r) => r.id, [_requestsByScope, _requestsByMine])
          .where((r) => canViewAll(r))
          .toList();
      notifyListeners();
    }

    if (isAdmin || isExecutive) {
      _listen('approvalRequests', _db.collection('approvalRequests').snapshots(), (snap) {
        _requestsByScope = snap.docs.map(ApprovalRequest.fromDoc).toList();
        publishRequests();
      });
    } else {
      final deptIds = myDepartmentIds;
      if (deptIds.isNotEmpty) {
        _listen('approvalRequests/إدارتي',
            _whereDeptIn(_db.collection('approvalRequests'), deptIds).snapshots(), (snap) {
          _requestsByScope = snap.docs.map(ApprovalRequest.fromDoc).toList();
          publishRequests();
        });
      }
      if (myUid != null) {
        _listen('approvalRequests/طلباتي',
            _db.collection('approvalRequests').where('requestedByUid', isEqualTo: myUid).snapshots(), (snap) {
          _requestsByMine = snap.docs.map(ApprovalRequest.fromDoc).toList();
          publishRequests();
        });
      }
    }
    _listen('reports', _db.collection('reports').snapshots(), (snap) {
      reports = snap.docs.map(ReportSnapshot.fromDoc).toList()
        ..sort((a, b) => b.generatedDate.compareTo(a.generatedDate));
      notifyListeners();
    });
    _listen('roles', _db.collection('roles').orderBy('name').snapshots(), (snap) {
      customRoles = snap.docs.map(CustomRole.fromDoc).toList();
      notifyListeners();
    });
    // مستند واحد لكل طبقة داخل dashboardConfig: `main` اللوحة العامة،
    // `projectsPage` ودجات صفحة المشاريع، و`role_<الدور>` لوحة كل دور.
    // نستمع للمجموعة كاملةً بدل مستند لكل دور حتى لا يتغيّر عدد الاشتراكات
    // كلما أُضيف دور مخصّص جديد.
    _listen('dashboardConfig', _db.collection('dashboardConfig').snapshots(), (snap) {
      var global = const <DashboardWidgetConfig>[];
      var projectsPage = const <DashboardWidgetConfig>[];
      _roleDashboards.clear();
      for (final doc in snap.docs) {
        final widgets = _parseWidgets(doc.data()['widgets']);
        if (doc.id == 'main') {
          global = widgets;
        } else if (doc.id == 'projectsPage') {
          projectsPage = widgets;
        } else if (doc.id.startsWith('role_')) {
          _roleDashboards[doc.id.substring('role_'.length)] = widgets;
        }
      }
      globalDashboardWidgets = global.isEmpty ? DashboardWidgetConfig.defaults() : global;
      projectsPageWidgets = projectsPage.toList();
      notifyListeners();
    });
    _listen('announcements', _db.collection('announcements').orderBy('createdAt', descending: true).snapshots(), (snap) {
      announcements = snap.docs.map(PlatformAnnouncement.fromDoc).toList();
      notifyListeners();
    });
    _listen('settings/alertRules', _db.collection('settings').doc('alertRules').snapshots(), (doc) {
      alertRules = AlertRulesConfig.fromMap(doc.data());
      notifyListeners();
    });
    _listen('settings/registration', _db.collection('settings').doc('registration').snapshots(), (doc) {
      registrationPolicy = RegistrationPolicy.fromMap(doc.data());
      notifyListeners();
    });
    // الأعمال كانت تُطلب كاملةً بلا نطاق، وقاعدتها تعتمد على محتوى المستند
    // (إدارتي، أو مُسنَد إليّ). فالطلب المفتوح يُرفض لكل من لا يرى كل
    // الإدارات — **بمن فيهم مدراء الإدارات** — فتظهر صفحة الأعمال فارغة.
    void publishWorks() {
      works = mergeById<WorkItem>((w) => w.id, [_worksByScope, _worksByAssignment])
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      notifyListeners();
    }

    if (canViewAllDepartments) {
      _listen('works', _db.collection('works').snapshots(), (snap) {
        _worksByScope = snap.docs.map(WorkItem.fromDoc).toList();
        publishWorks();
      });
    } else {
      // أعمال الإدارة لا تُطلب إلا لمن يعرضها فعلاً (راجع `visibleWorks`):
      // الموظف العادي يرى المُسنَد إليه وحده، فلا معنى لتحميل ما لن يُعرض له.
      final deptIds = myDepartmentIds;
      if ((isManager || canManageWorks) && deptIds.isNotEmpty) {
        _listen('works/إدارتي', _whereDeptIn(_db.collection('works'), deptIds).snapshots(), (snap) {
          _worksByScope = snap.docs.map(WorkItem.fromDoc).toList();
          publishWorks();
        });
      }
      if (myUid != null) {
        _listen('works/المسنَدة إليّ',
            _db.collection('works').where('assigneeUid', isEqualTo: myUid).snapshots(), (snap) {
          _worksByAssignment = snap.docs.map(WorkItem.fromDoc).toList();
          publishWorks();
        });
      }
    }
    // الشكاوى والاقتراحات بنطاقها كذلك: قاعدتها تعتمد على محتوى المستند
    // (صاحبها) وعلى صلاحية المتابعة. فمن يتابعها يقرأ المجموعة كاملةً —
    // وهي صلاحية لا تتعلق بمستند بعينه — ومن لا يتابعها يقرأ ما رفعه هو.
    void publishFeedback() {
      feedback = mergeById<FeedbackItem>((f) => f.id, [_feedbackAll, _feedbackMine])
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }

    if (isAdmin || canManageFeedback) {
      _listen('feedback', _db.collection('feedback').snapshots(), (snap) {
        _feedbackAll = snap.docs.map(FeedbackItem.fromDoc).toList();
        publishFeedback();
      });
    }
    if (myUid != null) {
      _listen('feedback/ما رفعته',
          _db.collection('feedback').where('submittedByUid', isEqualTo: myUid).snapshots(), (snap) {
        _feedbackMine = snap.docs.map(FeedbackItem.fromDoc).toList();
        publishFeedback();
      });
    }

    _listen('settings/rolePermissions', _db.collection('settings').doc('rolePermissions').snapshots(), (doc) {
      rolePermissions = RolePermissionsConfig.fromMap(doc.data());
      _rolePermissionsLoaded = true;
      notifyListeners();
      _recheckPermissionClaims();
    });
    if (myUid != null) {
      _listen('userFocus', _db.collection('userFocus').doc(myUid).snapshots(), (doc) {
        final data = doc.data() ?? {};
        myFocusProjectIds = ((data['projectIds'] as List?) ?? []).map((e) => e.toString()).toList();
        myFocusWorkIds = ((data['workIds'] as List?) ?? []).map((e) => e.toString()).toList();
        notifyListeners();
      });
      _listen('userDashboards', _db.collection('userDashboards').doc(myUid).snapshots(), (doc) {
        final widgets = _parseWidgets(doc.data()?['widgets']);
        _myDashboard = widgets.isEmpty ? null : widgets;
        notifyListeners();
      });
    }
    _listen('settings/focus', _db.collection('settings').doc('focus').snapshots(), (doc) {
      final ids = doc.data()?['projectIds'] as List?;
      focusedProjectIds = ids == null ? [] : ids.map((e) => e.toString()).toList();
      notifyListeners();
    });

    if (canViewAuditLog) {
      _listen('auditLog', _db.collection('auditLog').orderBy('timestamp', descending: true).limit(300).snapshots(), (snap) {
        auditLog = snap.docs.map(AuditLogEntry.fromDoc).toList();
        notifyListeners();
      });
    }
    // قائمة المستخدمين مطلوبة لأي مستخدم معتمد (وليس فقط من يدير المستخدمين):
    // قوائم اختيار "مدير المشروع" و"المنفذون" تحتاج أسماء المستخدمين
    // المسجَّلين، وقواعد Firestore تسمح أصلاً بقراءة المجموعة لأي مستخدم
    // معتمد (allow list: if isApproved()) فلا يوجد كشف صلاحيات إضافي هنا.
    _listen('users', _db.collection('users').orderBy('createdAt', descending: true).snapshots(), (snap) {
      users = snap.docs.map(AppUser.fromDoc).toList();
      notifyListeners();
    });
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
    String? requestedSectionId,
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
        sectionId: requestedSectionId,
        status: UserStatus.pending,
        createdAt: now,
      );
      await _db.collection('users').doc(uid).set(user.toMap());
      // رسالة التأكيد تُرسل فور إنشاء الحساب لا عند فتح شاشة التأكيد: قد
      // يغلق الموظف المتصفح قبلها، فتصله الرسالة على أي حال.
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {
        // فشل الإرسال لا يُبطل التسجيل — للموظف زر إعادة إرسال في شاشة التأكيد.
      }
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
              'requestedSectionId': requestedSectionId,
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

  /// صلاحيات الأدوار الأساسية كما ضبطها مسؤول النظام (settings/rolePermissions).
  RolePermissionsConfig rolePermissions = RolePermissionsConfig.defaults();

  /// هل يملك المستخدم الحالي صلاحية معيّنة؟
  ///
  /// مسؤول النظام يملك كل شيء دائماً. ثم **الاستثناء الفردي** إن وُجد، وهو
  /// ما يكتبه مسؤول النظام على حساب بعينه ليمنحه أو يمنعه بمعزل عن دوره.
  /// وما لم يوجد استثناء يُرجع إلى إعدادات الدور: الدور المخصص من مستنده،
  /// والأدوار الأساسية من خريطة [rolePermissions].
  /// هذه الدالة **لا تشمل** بوابات الاعتماد الثلاث — راجع [canApprove].
  bool hasPermission(RolePermission permission) {
    if (isAdmin) return true;
    final role = currentUser?.role;
    if (role == null) return false;
    // الاستثناء الفردي يعلو على الدور في الاتجاهين معاً: يمنح لمن لا يملكه
    // دوره، ويمنع من يملكه دوره. وهذا هو ما يجعل المنح «لأي مستخدم» ممكناً
    // دون تغيير دوره ولا صلاحيات زملائه.
    final override = currentUser?.permissionOverrides[permission.key];
    if (override != null) return override;
    // الصلاحيتان المقيَّدتان بنطاق تُقرآن من منحة الفرد وحدها: لا يرثهما
    // دور، ولا تُضبطان من شاشة «صلاحيات الأدوار». و«يملكها» هنا تعني أن
    // لها نطاقاً غير فارغ — أما **أين** تسري فيقرّره `scopeFor`.
    if (RolePermission.scoped.contains(permission)) {
      return !(currentUser?.scopeOf(permission) ?? GrantScope.none).isEmpty;
    }
    // رفع الشكوى أو الاقتراح **حق لكل حساب معتمد**، لا صلاحية تُمنح لدور.
    //
    // ولم يكن جعله كذلك بتعديل الإعداد المبدئي كافياً: مستند
    // `settings/rolePermissions` مكتوبٌ فعلاً في المنصة الحيّة، والمخزَّن
    // يُقدَّم على أي إعداد في الشيفرة — فكان التبويب يبقى مخفياً عن الجميع.
    // ومن أراد مسؤول النظام حرمانه يُسحب منه فرداً بالاستثناء أعلاه.
    if (permission == RolePermission.submitFeedback) return true;
    if (role == UserRole.custom) {
      final r = myCustomRole;
      if (r == null) return false;
      switch (permission) {
        case RolePermission.viewAllDepartments:
          return r.viewAllDepartments;
        case RolePermission.manageReports:
          return r.manageReports;
        case RolePermission.manageDashboard:
          return r.manageDashboard;
        case RolePermission.approveGeneralDecisions:
          return r.approveGeneralDecisions;
        case RolePermission.selfAssignProjects:
          return r.selfAssignProjects;
        case RolePermission.manageWorks:
        case RolePermission.deleteRecords:
        case RolePermission.sendNotifications:
        case RolePermission.submitFeedback:
        case RolePermission.manageFeedback:
        // والمقيَّدتان بنطاق لا تُمنحان لدور إطلاقاً — لا أساسي ولا مخصص.
        case RolePermission.manageProjects:
        case RolePermission.approveProjectRequests:
          // صلاحيات لا مقابل لها في مستند الدور المخصص؛ تُمنح لحامله
          // بالاستثناء الفردي أعلاه إن أراد مسؤول النظام.
          return false;
      }
    }
    return rolePermissions.has(role, permission);
  }

  Future<void> saveRolePermissions(RolePermissionsConfig config) async {
    await _db.collection('settings').doc('rolePermissions').set(config.toMap());
    await _log('صلاحيات الأدوار', 'قام ${currentUser?.name} بتحديث صلاحيات الأدوار الأساسية');
  }

  /// يعيد ختم بصمات الصلاحيات (Custom Claims) على كل مستخدمي دور معيّن حتى
  /// يسري التعديل فعلياً على الخادم لا في الواجهة وحدها. يُعيد عدد الحسابات
  /// المُحدَّثة، أو رسالة خطأ.
  Future<({int updated, String? error})> applyRolePermissions(UserRole role) async {
    try {
      final res = await _functions.httpsCallable('refreshRolePermissions').call({'role': role.name});
      final data = Map<String, dynamic>.from(res.data as Map);
      return (updated: (data['updated'] as num?)?.toInt() ?? 0, error: null);
    } on FirebaseFunctionsException catch (e) {
      return (updated: 0, error: e.message ?? 'تعذر تطبيق الصلاحيات');
    }
  }

  /// نطاق صلاحية مقيَّدة بنطاق للمستخدم الحالي.
  ///
  /// مسؤول النظام يشمل كل الإدارات دائماً — صلاحياته عبر `isAdmin()` في
  /// القواعد لا عبر منحة مكتوبة، فلا يُنتظر منه أن يمنح نفسه.
  GrantScope scopeFor(RolePermission permission) {
    if (isAdmin) return GrantScope.all;
    return currentUser?.scopeOf(permission) ?? GrantScope.none;
  }

  /// هل يستطيع المستخدم إنشاء مشروع أو عمل في هذه الإدارة مباشرةً؟
  bool canCreateIn(String? departmentId) {
    if (isAdmin) return true;
    return scopeFor(RolePermission.manageProjects).covers(departmentId);
  }

  /// هل يستطيع البتّ في طلب إضافة مشروع لهذه الإدارة؟
  bool canApproveProjectIn(String? departmentId) {
    if (isAdmin) return true;
    return scopeFor(RolePermission.approveProjectRequests).covers(departmentId);
  }

  /// مفاتيح الصلاحيات التي **يُفترض** أن يحملها المستخدم حسب إعدادات دوره.
  ///
  /// مسؤول النظام لا يمرّ من هنا: صلاحياته كاملة عبر `isAdmin()` في القواعد
  /// لا عبر أعلام في البطاقة، فمقارنته بها تُنتج اختلافاً وهمياً دائماً.
  Set<String> get expectedPermissionKeys {
    if (isAdmin) return const {};
    return {
      for (final p in RolePermission.values)
        if (hasPermission(p)) p.key,
    };
  }

  /// الصلاحيات الممنوحة في إعدادات الدور والغائبة عن بطاقة الدخول.
  ///
  /// هذه هي الحالة التي تُفرغ الشاشة بلا سبب مفهوم: مسؤول النظام يرى
  /// الصلاحية مفعّلة، والمستخدم لا تعمل عنده — لأن الخادم يحتكم إلى البطاقة
  /// وحدها. فتُسمّى له باسمها العربي بدل رسالة رفض عامة.
  Future<List<RolePermission>> pendingPermissions() async {
    try {
      final claims = await currentTokenClaims();
      final missing = expectedPermissionKeys.difference(tokenPermissionKeys(claims));
      return [
        for (final key in missing)
          if (RolePermission.fromKey(key) != null) RolePermission.fromKey(key)!,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// نطاق صلاحية كما هو مختوم في بطاقة الدخول فعلاً.
  @visibleForTesting
  GrantScope tokenScopeFor(Map<String, dynamic> claims, RolePermission permission) {
    final scopes = claims['scopes'];
    if (scopes is! Map) return GrantScope.none;
    return GrantScope.fromClaim(scopes[permission.key]);
  }

  /// مفاتيح الصلاحيات الموجودة فعلاً في بطاقة الدخول.
  Set<String> tokenPermissionKeys(Map<String, dynamic> claims) {
    final perms = claims['perms'];
    if (perms is! Map) return const {};
    return {
      for (final e in perms.entries)
        if (e.value == true) e.key.toString(),
    };
  }

  /// بصمات بطاقة الدخول الحالية (Custom Claims) كما يراها الخادم.
  ///
  /// هي — لا مستند المستخدم — ما تحتكم إليه قواعد Firestore. وقراءتها هنا
  /// تتيح مقارنتها بالمستند وكشف أي اختلاف، وهو سبب رؤية المستخدم منصة
  /// خالية بينما سجلّه يقول إنه معتمد.
  Future<Map<String, dynamic>> currentTokenClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return const {};
    final result = await user.getIdTokenResult(forceRefresh);
    return Map<String, dynamic>.from(result.claims ?? const {});
  }

  /// يزامن بطاقة دخول المستخدم الحالي مع سجلّه، ثم يجدّد التوكن ويعيد
  /// الاشتراك بالبيانات.
  ///
  /// الدالة على الخادم تنسخ ما كتبه مسؤول النظام في السجل ولا تضيف شيئاً —
  /// وسجل المستخدم لا يكتب فيه إلا مسؤول النظام (راجع firestore.rules).
  Future<String?> syncMyClaims() async {
    try {
      await _functions.httpsCallable('syncMyClaims').call();
      await _auth.currentUser?.getIdToken(true);
      _cancelDataSubs();
      _subscribeAppData();
      notifyListeners();
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذّرت مزامنة صلاحيات الحساب';
    } catch (e) {
      return e.toString();
    }
  }

  /// يضبط الاستثناءات الفردية لصلاحيات مستخدم بعينه ويعيد ختم بطاقته فوراً.
  ///
  /// الخريطة الفارغة تعني «يتبع دوره». والدالة الخلفية ترفض المفاتيح المجهولة
  /// بدل إهمالها، فلا تبدو صلاحية ممنوحة وهي لا تعمل.
  /// يمنح مستخدماً بعينه صلاحيةً بنطاق، أو يسحبها بنطاق فارغ.
  ///
  /// الكتابة تمرّ بدالة سحابية لا بمستند المستخدم مباشرةً: القواعد تحتكم
  /// إلى بطاقة الدخول، والدالة وحدها تستطيع إعادة ختمها.
  Future<String?> setScopedGrant(String uid, RolePermission permission, GrantScope scope) async {
    try {
      await _functions.httpsCallable('setScopedGrant').call({
        'uid': uid,
        'key': permission.key,
        'all': scope.allDepartments,
        'departmentIds': scope.departmentIds,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذّر ضبط الصلاحية';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setPermissionOverrides(String uid, Map<String, bool> overrides) async {
    try {
      await _functions.httpsCallable('setUserPermissionOverrides').call({
        'uid': uid,
        'overrides': overrides,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذّر ضبط الصلاحيات الفردية';
    } catch (e) {
      return e.toString();
    }
  }

  /// يعيد ختم بطاقة مستخدم بعينه — لمسؤول النظام، بلا تغيير دوره أو حالته.
  Future<String?> restampUserClaims(String uid) async {
    try {
      await _functions.httpsCallable('adminRestampClaims').call({'uid': uid});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'تعذّرت إعادة ختم الصلاحيات';
    } catch (e) {
      return e.toString();
    }
  }

  bool get canViewAllDepartments => isAdmin || hasPermission(RolePermission.viewAllDepartments);
  bool get canManageUsers => isAdmin;
  // سجل التدقيق، الموافقة على تسجيل الأعضاء/المشاريع/المواعيد النهائية، وإضافة
  // المستخدمين تبقى دائماً حصراً لمسؤول النظام — لا يملك أي دور تجاوزها.
  bool get canViewAuditLog => isAdmin;
  bool get canManageReports => hasPermission(RolePermission.manageReports);
  bool get canManageDashboard => hasPermission(RolePermission.manageDashboard);
  bool get canManageWorks => hasPermission(RolePermission.manageWorks);
  bool get canSendNotifications => hasPermission(RolePermission.sendNotifications);

  /// حسابات المستخدمين المرتبطة بمشروع: مديره المُسنَد إليه، إضافة إلى
  /// المنفذين المطابَقين بالاسم. المشروع يخزّن أسماء المنفذين لا معرّفاتهم،
  /// فالمطابقة بالاسم أفضل المتاح؛ من لا يُطابَق يبقى للاختيار اليدوي.
  List<AppUser> recipientsForProject(Project project) {
    final names = project.executorNames.map((e) => e.trim()).toSet();
    return users
        .where((u) => u.id == project.managerUid || names.contains(u.name.trim()))
        .toList();
  }

  /// حساب الموظف المُسنَد إليه العمل (مطابقة بالمعرّف لا بالاسم).
  List<AppUser> recipientsForWork(WorkItem work) =>
      users.where((u) => u.id == work.assigneeUid).toList();
  bool get canDeleteRecords => hasPermission(RolePermission.deleteRecords);

  /// اعتماد "قرار تنفيذي" عام يجوز للمسؤول أو المستخدم التنفيذي أو دور مخصص
  /// يملك صلاحية "اعتماد القرارات التنفيذية العامة" صراحة.
  /// أما تسجيل عضو / إضافة مشروع / تعديل موعد نهائي فلا يعتمدها إلا مسؤول النظام حصرياً،
  /// ولا يمكن لأي دور مخصص تجاوز هذا القيد مهما كانت صلاحياته.
  /// من يبتّ في هذا الطلب — مرآةٌ لما تفرضه الدالة الخلفية، والحَكَم هي.
  ///
  /// **تسجيل الأعضاء وتعديل المواعيد النهائية** يبقيان لمسؤول النظام وحده.
  /// أما **إضافة المشاريع** فقد قرّر فتحها بمفتاح بيده: `apr` ضمن نطاق.
  /// و**إضافة الأعمال** ليست بوابة: يعتمدها مدير الإدارة صاحبتها.
  bool canApprove(ApprovalRequest r) {
    if (isAdmin) return true;
    switch (r.type) {
      case ApprovalType.decision:
        return hasPermission(RolePermission.approveGeneralDecisions);
      case ApprovalType.projectCreate:
        return canApproveProjectIn(r.departmentId);
      case ApprovalType.workCreate:
        return (isManager && myDepartmentIds.contains(r.departmentId)) || canCreateIn(r.departmentId);
      case ApprovalType.registration:
      case ApprovalType.deadlineChange:
        return false;
    }
  }

  /// إدارة/إدارات مدير الإدارة الحالي (دور departmentManager فقط قد يملك أكثر من إدارة).
  /// إدارات المستخدم الحالي.
  ///
  /// الرجوع إلى `departmentId` المفرد ليس احتياطاً تجميلياً: حقل الإدارات
  /// الجمع أُضيف لاحقاً لمدير الإدارة الذي يدير أكثر من إدارة، وبقيت حسابات
  /// أُنشئت قبله تحمل المفرد وحده. ومدير إدارة بقائمة فارغة يصير استعلامه
  /// `where('departmentId', isEqualTo: '__none__')` — أي **لا شيء إطلاقاً**،
  /// فيرى منصة خالية ولا يفهم لماذا.
  List<String> get myDepartmentIds {
    final many = currentUser?.departmentIds ?? const <String>[];
    if (many.isNotEmpty) return many;
    final one = currentUser?.departmentId;
    return (one == null || one.isEmpty) ? const [] : [one];
  }

  /// من يعدّل المشروع ويكتب تحديثاته اليومية.
  ///
  /// **العضوية لا الحقل المفرد.** `project.managerUid` يُشتقّ من **أول**
  /// اسم في `managerUids`، فمنذ أن صار للمشروع أكثر من مدير كان المدير
  /// الثاني — والمنفّذ المُسنَد — ممنوعَين من كتابة تحديث يومي بلا سبب
  /// ظاهر. والمقارنة هنا صارت بالعضوية كما في قواعد الخادم.
  bool canEditProject(Project project) {
    final uid = currentUser?.id;
    if (uid == null) return false;
    if (isAdmin) return true;
    if (isExecutive) return false;
    if (project.hasMember(uid)) return true;
    if (isOfficer) return false;
    if (isManager) return myDepartmentIds.contains(project.departmentId);
    return currentUser!.departmentId == project.departmentId;
  }

  bool canSubmitDailyUpdate(Project project) => canEditProject(project);

  /// هل يستطيع المستخدم **طلب** إضافة مشروع في هذه الإدارة؟
  ///
  /// الطلب ليس منحاً: كل من ينتمي للإدارة يستطيع أن يطلب، والبتّ محكوم
  /// بـ [canApprove]. وقصرُ الطلب على مدير الإدارة كان يمنع الموظف من
  /// اقتراح مشروع أصلاً — وهو ما طُلب فتحه.
  bool canRequestNewProject(String departmentId) {
    if (currentUser == null) return false;
    if (isAdmin || canCreateIn(departmentId)) return true;
    return myDepartmentIds.contains(departmentId) || currentUser!.departmentId == departmentId;
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

  /// المشاريع التي يراها المستخدم الحالي: **مشاريع إدارته، وما هو عضو فيه**.
  ///
  /// قاعدة واحدة لكل الأدوار، ومطابقة لشرط القراءة على الخادم حرفياً. وكانت
  /// قبلها أربعة فروع متباينة، وفيها عطلان:
  ///
  /// - مدير المشروع كان يُقيَّد بما هو عضو فيه وحده، فلا يرى مشاريع إدارته
  ///   ولا يجد ما ينضمّ إليه.
  /// - وبقية الأدوار كانت رؤيتها لإدارتها معلَّقة على صلاحية «الانضمام
  ///   لمشاريع الإدارة»، وقد صار الاطّلاع حقاً أساسياً لا صلاحية.
  ///
  /// والعضوية تبقى في الشرط لأن المستخدم قد يُسنَد إلى مشروع خارج إدارته.
  List<Project> get visibleProjects {
    if (canViewAllDepartments) return projects;
    final uid = currentUser?.id;
    final myDepts = {...myDepartmentIds, if (currentUser?.departmentId != null) currentUser!.departmentId!};
    return projects.where((p) => myDepts.contains(p.departmentId) || p.hasMember(uid)).toList();
  }

  List<Project> projectsForDepartment(String departmentId) =>
      projects.where((p) => p.departmentId == departmentId).toList();

  // ------------------------- أقسام الإدارات -------------------------

  /// أقسام كل الإدارات (بمستوييها) — راجع [DepartmentSection].
  List<DepartmentSection> sections = [];

  DepartmentSection? sectionById(String? id) {
    if (id == null) return null;
    final match = sections.where((s) => s.id == id);
    return match.isEmpty ? null : match.first;
  }

  /// أقسام إدارة على مستوى واحد: [parentId] فارغ يعطي الأقسام المباشرة تحت
  /// الإدارة، وغير فارغ يعطي الأقسام الفرعية تحت قسم بعينه.
  List<DepartmentSection> sectionsOf(String departmentId, {String? parentId}) {
    final list = sections.where((s) => s.departmentId == departmentId && s.parentId == parentId).toList()
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
    return list;
  }

  /// معرّفات القسم وكل ما تحته — يُستخدم لعدّ مشاريع فرع كامل من الشجرة.
  Set<String> sectionWithDescendants(String sectionId) {
    final result = {sectionId};
    var frontier = {sectionId};
    // العمق محدود بـ maxDepth، والحلقة محروسة بأن كل جولة تضيف معرّفات جديدة
    // فقط، فلا تدور إلى ما لا نهاية لو حوت البيانات مرجعاً دائرياً.
    while (frontier.isNotEmpty) {
      final next = sections
          .where((s) => s.parentId != null && frontier.contains(s.parentId) && !result.contains(s.id))
          .map((s) => s.id)
          .toSet();
      result.addAll(next);
      frontier = next;
    }
    return result;
  }

  /// مشاريع قسم. [includeDescendants] يضم مشاريع الأقسام الفرعية تحته أيضاً،
  /// وهو المطلوب عند عرض عدّاد على القسم الأب.
  List<Project> projectsInSection(String sectionId, {bool includeDescendants = true}) {
    final ids = includeDescendants ? sectionWithDescendants(sectionId) : {sectionId};
    return visibleProjects.where((p) => p.sectionId != null && ids.contains(p.sectionId)).toList();
  }

  /// مشاريع إدارة غير المُسنَدة لأي قسم (تظهر تحت الإدارة مباشرةً). المشروع
  /// المُسنَد لقسم محذوف يُعامَل كأنه بلا قسم فلا يختفي من الشاشة.
  List<Project> projectsWithoutSection(String departmentId) => visibleProjects
      .where((p) => p.departmentId == departmentId && (p.sectionId == null || sectionById(p.sectionId) == null))
      .toList();

  /// مسار القسم مقروءاً: «قسم ← قسم فرعي»، أو نص فارغ إن لم يكن للمشروع قسم.
  String sectionPathLabel(String? sectionId) {
    final parts = <String>[];
    var current = sectionById(sectionId);
    final seen = <String>{};
    while (current != null && seen.add(current.id)) {
      parts.insert(0, current.name);
      current = sectionById(current.parentId);
    }
    return parts.join(' ← ');
  }

  /// هل يستطيع المستخدم إنشاء/تعديل/حذف أقسام هذه الإدارة؟
  /// مسؤول النظام دائماً، ومدير الإدارة لإدارته. تنظيم داخلي لا يمسّ بوابات
  /// الاعتماد الثلاث.
  bool canManageSections(String departmentId) {
    if (currentUser == null) return false;
    if (isAdmin) return true;
    return isManager && myDepartmentIds.contains(departmentId);
  }

  /// هل يمكن إضافة قسم فرعي تحت هذا القسم؟ يمنع تجاوز العمق المسموح.
  bool canAddChildSection(DepartmentSection section) => section.levelIn(sections) < DepartmentSection.maxDepth;

  Future<void> addSection({required String departmentId, String? parentId, required String name}) async {
    final siblings = sectionsOf(departmentId, parentId: parentId);
    final ref = _db.collection('sections').doc();
    await ref.set(DepartmentSection(
      id: ref.id,
      departmentId: departmentId,
      parentId: parentId,
      name: name,
      order: siblings.isEmpty ? 0 : siblings.last.order + 1,
    ).toMap());
    await _log('أقسام الإدارات', 'أضاف ${currentUser?.name} قسم "$name"');
  }

  Future<void> renameSection(DepartmentSection section, String name) async {
    await _db.collection('sections').doc(section.id).update({'name': name});
    await _log('أقسام الإدارات', 'أعاد ${currentUser?.name} تسمية قسم "${section.name}" إلى "$name"');
  }

  /// حذف قسم دون فقد شيء: أقسامه الفرعية ومشاريعه تُرفع مستوىً واحداً إلى
  /// أبيه (أو إلى الإدارة مباشرةً إن لم يكن له أب). لا يُحذف مشروع أبداً
  /// بحذف قسم — التنظيم شيء والبيانات شيء آخر.
  Future<void> deleteSection(DepartmentSection section) async {
    final batch = _db.batch();
    for (final child in sections.where((s) => s.parentId == section.id)) {
      batch.update(_db.collection('sections').doc(child.id), {'parentId': section.parentId});
    }
    for (final p in projects.where((p) => p.sectionId == section.id)) {
      batch.update(_db.collection('projects').doc(p.id), {'sectionId': section.parentId});
    }
    batch.delete(_db.collection('sections').doc(section.id));
    await batch.commit();
    await _log('أقسام الإدارات', 'حذف ${currentUser?.name} قسم "${section.name}" ونُقل محتواه للمستوى الأعلى');
  }

  /// هل يملك المستخدم نقل قسم من إدارة إلى أخرى؟ مسؤول النظام وحده.
  ///
  /// إنشاء الأقسام وترتيبها داخل الإدارة تنظيم داخلي يملكه مدير الإدارة
  /// ([canManageSections])، أما نقل قسم بين إدارتين فيغيّر **من يرى مشاريعه
  /// ومن يعدّلها** — قرار هيكلي لا يصح أن يتخذه من لا يملك الإدارتين معاً.
  bool get canMoveSectionAcrossDepartments => isAdmin;

  /// نقل قسم بكامل فرعه إلى إدارة أخرى: القسم نفسه، وكل أقسامه الفرعية، وكل
  /// مشاريع الفرع تنتقل معه. لا يُحذف شيء ولا يبقى شيء خلفه.
  ///
  /// القسم المنقول يصبح جذراً في الإدارة الجديدة (`parentId: null`) لأن أباه
  /// السابق بقي في الإدارة القديمة، ولو أبقيناه لأشار إلى قسم في إدارة أخرى.
  Future<String?> moveSectionToDepartment(DepartmentSection section, String targetDepartmentId) async {
    if (!canMoveSectionAcrossDepartments) return 'لا تملك صلاحية نقل الأقسام بين الإدارات';
    if (targetDepartmentId == section.departmentId) return null;
    try {
      final ids = sectionWithDescendants(section.id);
      final batch = _db.batch();
      for (final id in ids) {
        final data = <String, dynamic>{'departmentId': targetDepartmentId};
        if (id == section.id) data['parentId'] = null;
        batch.update(_db.collection('sections').doc(id), data);
      }
      for (final p in projects.where((p) => p.sectionId != null && ids.contains(p.sectionId))) {
        batch.update(_db.collection('projects').doc(p.id), {'departmentId': targetDepartmentId});
      }
      await batch.commit();
      final target = departmentById(targetDepartmentId)?.name ?? targetDepartmentId;
      await _log('أقسام الإدارات', 'نقل ${currentUser?.name} قسم "${section.name}" وكل ما تحته إلى إدارة "$target"');
      return null;
    } catch (e) {
      return 'تعذر نقل القسم: $e';
    }
  }

  /// تحويل إدارة كاملة إلى قسم داخل إدارة أخرى.
  ///
  /// الهيكل الفعلي في الوزارة: الإدارة تضم أقساماً. وحين تُستورد الأقسام من
  /// ملفات المتابعة تأتي كإدارات مستقلة، فيحتاج مسؤول النظام إلى ضمّها تحت
  /// إدارتها الأم. هذه الدالة تفعل ذلك في دفعة واحدة:
  /// ينشأ قسم في الإدارة الهدف باسم الإدارة ورئيسها، وتنتقل إليه كل مشاريعها،
  /// وتصير أقسامها القائمة أقساماً فرعية تحته، ثم تُحذف الإدارة الفارغة.
  ///
  /// **لا يُحذف مشروع ولا قسم** — التحويل إعادة ترتيب لا إتلاف. ويُرفض إن
  /// تجاوزت الشجرة الناتجة العمق المسموح، حتى لا تُدفن أقسام في مستوى لا
  /// تعرضه الواجهة.
  Future<String?> convertDepartmentToSection(Department source, String targetDepartmentId) async {
    if (!canMoveSectionAcrossDepartments) return 'لا تملك صلاحية تحويل الإدارات إلى أقسام';
    if (targetDepartmentId == source.id) return 'لا يمكن تحويل الإدارة إلى قسم داخل نفسها';
    if (departmentById(targetDepartmentId) == null) return 'الإدارة المستقبِلة غير موجودة';

    // أقسام الإدارة المصدر ستنزل مستوىً واحداً (تصبح تحت القسم الجديد)، فلو
    // كان فيها قسم فرعي أصلاً لتجاوزنا الحد.
    final ownSections = sections.where((s) => s.departmentId == source.id).toList();
    final deepest = ownSections.fold<int>(0, (m, s) => s.levelIn(sections) > m ? s.levelIn(sections) : m);
    if (deepest + 1 > DepartmentSection.maxDepth) {
      return 'تحتوي هذه الإدارة أقساماً فرعية، وتحويلها سيتجاوز الحد المسموح '
          '(${DepartmentSection.maxDepth} مستويات). انقل أقسامها الفرعية أولاً.';
    }

    try {
      final owned = projectsForDepartment(source.id);
      final ref = _db.collection('sections').doc();
      final siblings = sectionsOf(targetDepartmentId);
      final batch = _db.batch();

      batch.set(
        ref,
        DepartmentSection(
          id: ref.id,
          departmentId: targetDepartmentId,
          name: source.name,
          headName: source.headName,
          order: siblings.isEmpty ? 0 : siblings.last.order + 1,
          sourceDepartmentId: source.id,
        ).toMap(),
      );

      for (final p in owned) {
        batch.update(_db.collection('projects').doc(p.id), {
          'departmentId': targetDepartmentId,
          // المشروع الذي كان داخل قسم من أقسام الإدارة يبقى فيه، وغيره ينضم
          // للقسم الجديد مباشرةً.
          if (p.sectionId == null || sectionById(p.sectionId) == null) 'sectionId': ref.id,
        });
      }

      for (final s in ownSections) {
        batch.update(_db.collection('sections').doc(s.id), {
          'departmentId': targetDepartmentId,
          if (s.parentId == null) 'parentId': ref.id,
        });
      }

      batch.delete(_db.collection('departments').doc(source.id));
      await batch.commit();

      final target = departmentById(targetDepartmentId)?.name ?? targetDepartmentId;
      await _log(
        'أقسام الإدارات',
        'حوّل ${currentUser?.name} إدارة "${source.name}" إلى قسم داخل "$target" مع ${owned.length} مشروعاً',
      );
      return null;
    } catch (e) {
      return 'تعذر تحويل الإدارة: $e';
    }
  }

  /// إسناد مشروع لقسم (أو رفعه للإدارة مباشرةً بتمرير null).
  Future<void> assignProjectSection(Project project, String? sectionId) async {
    await _db.collection('projects').doc(project.id).update({'sectionId': sectionId});
    final where = sectionId == null ? 'الإدارة مباشرةً' : sectionPathLabel(sectionId);
    await _log('أقسام الإدارات', 'نُقل مشروع "${project.name}" إلى $where');
  }

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

  /// يرفع مرفقاً إلى تخزين المنصة ويعيده جاهزاً للحفظ مع التحديث.
  ///
  /// يعيد **رسالة عربية** عند الفشل بدل رمي استثناء: أشيع أسباب الفشل أن
  /// التخزين غير مفعَّل في مشروع Firebase أصلاً، وهو ليس عطلاً في المنصة بل
  /// خطوةٌ لم يخطُها مسؤول النظام بعد — فيجب أن تُقال له كما هي، لا أن تظهر
  /// كخطأ غامض ولا أن تفشل صامتة.
  Future<({Attachment? file, String? error})> uploadAttachment({
    required String projectId,
    required PickedFile picked,
  }) async {
    const maxBytes = 10 * 1024 * 1024;
    if (picked.sizeBytes > maxBytes) {
      return (file: null, error: 'حجم الملف يتجاوز ١٠ ميغابايت. ارفعه على نظام الوزارة وألصق رابطه.');
    }
    try {
      // الاسم يُنقّى قبل أن يصير مساراً: الأسماء العربية تُسقط الامتداد في
      // Chromium عند التنزيل — راجع safe_file_name.dart.
      final clean = safeFileName(picked.name, fallbackBase: 'attachment');
      final path = 'projects/$projectId/dailyUpdates/${DateTime.now().millisecondsSinceEpoch}_$clean';
      final ref = fb_storage.FirebaseStorage.instance.ref(path);
      await ref.putData(
        picked.bytes,
        fb_storage.SettableMetadata(
          contentType: picked.contentType.isEmpty ? 'application/octet-stream' : picked.contentType,
          // الاسم الأصلي يبقى محفوظاً ليُعرض للمستخدم كما كتبه.
          customMetadata: {'originalName': picked.name},
        ),
      );
      final url = await ref.getDownloadURL();
      return (
        file: Attachment(
          name: picked.name,
          url: url,
          kind: AttachmentKind.upload,
          contentType: picked.contentType,
          sizeBytes: picked.sizeBytes,
          storagePath: path,
        ),
        error: null,
      );
    } on fb_storage.FirebaseException catch (e) {
      if (e.code == 'unknown' || e.code == 'object-not-found' || e.code == 'unauthorized') {
        return (
          file: null,
          error: 'تعذّر الرفع — قد لا يكون التخزين (Storage) مفعّلاً في المشروع بعد. '
              'يمكنك إرفاق رابط الملف بدلاً من رفعه، أو اطلب من مسؤول النظام تفعيل التخزين.',
        );
      }
      return (file: null, error: e.message ?? 'تعذّر رفع الملف');
    } catch (e) {
      return (file: null, error: 'تعذّر رفع الملف: $e');
    }
  }

  Future<void> addDailyUpdate({
    required Project project,
    required String achievements,
    required List<String> completedTasks,
    required List<String> newRisks,
    required List<String> blockersText,
    required List<String> decisionsRequired,
    required double progressPercent,
    String notes = '',
    List<Attachment> attachments = const [],
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
          notes: notes,
          attachments: attachments,
        ).toMap(),
        'managerUid': project.managerUid,
        'managerUids': project.managerUids,
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
          'managerUids': project.managerUids,
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
          'managerUids': project.managerUids,
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
    final project = projectById(task.projectId);
    await _db.collection('tasks').doc(task.id).set({
      ...task.toMap(),
      'managerUid': project?.managerUid,
      'managerUids': project?.managerUids ?? const <String>[],
    });
    await _log('إضافة مهمة', 'تمت إضافة مهمة جديدة "${task.title}"');
  }

  // ------------------------- طلبات الموافقة -------------------------

  /// طلب إضافة **عمل** — يعتمده مدير الإدارة صاحبته، لا مسؤول النظام.
  ///
  /// والعمل ليس من بوابات الاعتماد الثلاث، فلا قيد عليه: أقرب من يعرف
  /// أولويات الإدارة هو من يبتّ فيه.
  Future<void> submitWorkRequest({
    required String departmentId,
    required String title,
    required String description,
    required DateTime dueDate,
    required PriorityLevel priority,
    String? assigneeUid,
    String? assigneeName,
  }) async {
    final now = DateTime.now();
    await _db.collection('approvalRequests').add(ApprovalRequest(
          id: '',
          type: ApprovalType.workCreate,
          status: DecisionStatus.pending,
          title: 'طلب إضافة عمل جديد: $title',
          description: description,
          priority: priority,
          delayImpactDays: 0,
          departmentId: departmentId,
          requestedByUid: currentUser?.id ?? '',
          requestedByName: currentUser?.name ?? '',
          requestedDate: now,
          payload: {
            'title': title,
            'description': description,
            'dueDate': dueDate.toIso8601String(),
            'priority': priority.name,
            'assigneeUid': assigneeUid,
            'assigneeName': assigneeName,
          },
        ).toMap());
    await _log('طلب إضافة عمل', 'قدّم ${currentUser?.name} طلب إضافة عمل "$title"');
  }

  /// هل يستطيع المستخدم **طلب** إضافة عمل في هذه الإدارة؟
  bool canRequestNewWork(String? departmentId) {
    if (currentUser == null || departmentId == null) return false;
    if (isAdmin || canCreateIn(departmentId) || canManageWorks) return true;
    return myDepartmentIds.contains(departmentId) || currentUser!.departmentId == departmentId;
  }

  Future<void> submitProjectRequest({
    required String departmentId,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime dueDate,
    required PriorityLevel priority,
    List<String> executorNames = const [],
    String? sectionId,
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
            // القسم يُحمل مع الطلب لا يُترك للاعتماد: بدونه يخرج المشروع
            // المُعتمَد بلا قسم فيضطر مدير الإدارة لإسناده يدوياً بعد كل موافقة.
            'sectionId': sectionId,
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
    String? sectionId,
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
      managerUids: managerUid == null || managerUid.isEmpty ? const [] : [managerUid],
      sectionId: sectionId,
    ).toMap());
    await _log('إضافة مشروع', 'أضاف ${currentUser?.name} مشروعاً جديداً "$name" مباشرة');
  }

  // ------------------------- عضوية المشروع -------------------------

  /// يكتب قائمتَي عضوية المشروع معاً، ومعهما الحقل المفرد الموروث متسقاً.
  ///
  /// الكتابة في موضع واحد مقصودة: قاعدة الأمان تشترط أن يكون `managerUid`
  /// عضواً في `managerUids`، فأي مسار كتابة يغفل عن ذلك يُرفض على الخادم —
  /// أو أسوأ، يمرّ ويترك المستند متناقضاً.
  Future<void> _writeMembership(Project project, List<String> managers, List<String> executors) async {
    await _db.collection('projects').doc(project.id).update({
      'managerUids': managers,
      'executorUids': executors,
      'managerUid': managers.isEmpty ? null : managers.first,
    });
  }

  /// انضمام المستخدم الحالي إلى مشروع، أو تغيير صفته فيه.
  ///
  /// يعمل على **معرّف المستخدم نفسه فقط** — وهو ما تفرضه قاعدة الأمان أيضاً،
  /// فلا يستطيع أحد إضافة غيره ولا إزاحة زميله عن مشروعه.
  Future<String?> joinProject(Project project, {required bool asManager}) async {
    final uid = currentUser?.id;
    if (uid == null) return 'لا يوجد مستخدم مسجَّل';
    if (!canSelfAssign(project)) return 'لا تملك صلاحية الانضمام لمشاريع هذه الإدارة';
    final managers = project.managerUids.toList()..remove(uid);
    final executors = project.executorUids.toList()..remove(uid);
    if (asManager) {
      managers.add(uid);
    } else {
      executors.add(uid);
    }
    try {
      await _writeMembership(project, managers, executors);
      await _log('انضمام لمشروع',
          'سجّل ${currentUser?.name} نفسه ${asManager ? 'مديراً' : 'منفّذاً'} في مشروع "${project.name}"');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// انسحاب المستخدم الحالي من مشروع.
  Future<String?> leaveProject(Project project) async {
    final uid = currentUser?.id;
    if (uid == null) return 'لا يوجد مستخدم مسجَّل';
    try {
      await _writeMembership(
        project,
        project.managerUids.where((x) => x != uid).toList(),
        project.executorUids.where((x) => x != uid).toList(),
      );
      await _log('انسحاب من مشروع', 'سحب ${currentUser?.name} نفسه من مشروع "${project.name}"');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// نقل عضو بين صفتَي مدير ومنفّذ، أو إزالته — لمسؤول النظام ومدير الإدارة.
  ///
  /// `role` يقبل `manager` أو `executor` أو null للإزالة.
  Future<String?> setProjectMemberRole(Project project, String uid, String? role) async {
    if (!canManageProjectTeam(project)) return 'لا تملك صلاحية تعديل فريق هذا المشروع';
    final managers = project.managerUids.where((x) => x != uid).toList();
    final executors = project.executorUids.where((x) => x != uid).toList();
    if (role == 'manager') managers.add(uid);
    if (role == 'executor') executors.add(uid);
    try {
      await _writeMembership(project, managers, executors);
      final name = users.where((u) => u.id == uid).map((u) => u.name).firstOrNull ?? uid;
      await _log('تعديل فريق المشروع',
          'عُدِّلت صفة "$name" في مشروع "${project.name}" إلى ${role == 'manager' ? 'مدير' : role == 'executor' ? 'منفّذ' : 'مُزال'}');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// هل يستطيع المستخدم الحالي تسجيل نفسه على هذا المشروع؟
  ///
  /// الصلاحية قابلة للسحب من شاشة «صلاحيات الأدوار»، ومقيَّدة بإدارته: لا
  /// معنى لأن ينضم موظف لمشروع إدارة لا يعمل فيها.
  bool canSelfAssign(Project project) {
    if (!hasPermission(RolePermission.selfAssignProjects)) return false;
    return myDepartmentIds.contains(project.departmentId) ||
        currentUser?.departmentId == project.departmentId;
  }

  /// هل يستطيع المستخدم الحالي تعديل فريق المشروع كاملاً (لا نفسه فقط)؟
  bool canManageProjectTeam(Project project) {
    if (isAdmin) return true;
    return isManager && myDepartmentIds.contains(project.departmentId);
  }

  /// تعيين/تغيير "مدير المشروع" (مسؤول النظام فقط) — يُبقى للتوافق مع
  /// المسارات التي تُسنِد مديراً واحداً، ويكتب القائمة متسقةً.
  Future<void> setProjectManager(Project project, String? managerUid) async {
    await _writeMembership(
      project,
      managerUid == null || managerUid.isEmpty ? const [] : [managerUid],
      project.executorUids,
    );
    await _log('تعيين مدير مشروع', 'تم تعيين مدير المشروع لمشروع "${project.name}"');
  }

  /// المشاريع التي يخالف حقلها المخزَّن ما يقوله تاريخ الاستحقاق.
  ///
  /// تُعرض لمسؤول النظام قبل المطابقة: تغيير عشرات المستندات دفعةً واحدة
  /// دون أن يرى ماذا سيتغيّر ليس قراراً، بل مقامرة.
  List<Project> get projectsWithStaleStatus =>
      visibleProjects.where((p) => p.statusOutOfSync).toList();

  /// يكتب الحالة الفعلية في المستندات التي تخالفها.
  ///
  /// العرض يستعمل `effectiveStatus` دائماً، فالمنصة متسقة بدونها. لكن الحقل
  /// المخزَّن يخرج مع التقارير المُصدَّرة ويقرؤه أي نظام آخر، فمطابقته تمنع
  /// أن يقرأ الخارج حالةً غير التي يراها المستخدم على الشاشة.
  Future<int> reconcileProjectStatuses() async {
    final stale = projectsWithStaleStatus;
    if (stale.isEmpty) return 0;
    final batch = _db.batch();
    for (final p in stale) {
      batch.update(_db.collection('projects').doc(p.id), {'status': p.effectiveStatus.name});
    }
    await batch.commit();
    await _log('مطابقة حالات المشاريع',
        'طابق ${currentUser?.name} حالة ${stale.length} مشروعاً مع تواريخ استحقاقها');
    return stale.length;
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

  /// يحذف إدارة ولو كانت تحتوي مشاريع.
  ///
  /// [cascade] يحدد مصير مشاريعها:
  /// - `false`: تبقى المشاريع وتصبح "بدون إدارة" (`departmentId: ''`) — التطبيق
  ///   يعرضها بهذه التسمية في كل المواضع، ويمكن إعادة توزيعها لاحقاً.
  /// - `true`: تُحذف المشاريع وكل تابعيها (مهام/مخاطر/عوائق/تحديثات) نهائياً.
  ///
  /// يُعيد رسالة خطأ عند الفشل أو null عند النجاح.
  Future<String?> deleteDepartment(Department dept, {required bool cascade}) async {
    final owned = projectsForDepartment(dept.id);
    try {
      if (cascade) {
        for (final p in owned) {
          await _deleteProjectDocs(p);
        }
      } else {
        // نقل المشاريع إلى "بدون إدارة" على دفعات (حد Firestore ٥٠٠ عملية للدفعة).
        for (var i = 0; i < owned.length; i += 400) {
          final batch = _db.batch();
          for (final p in owned.skip(i).take(400)) {
            // إزالة القسم أيضاً: أقسام الإدارة تُحذف معها بعد قليل، فلو بقي
            // sectionId مشيراً لقسم محذوف لظهر المشروع بمسار قسم لا وجود له.
            batch.update(_db.collection('projects').doc(p.id), {'departmentId': '', 'sectionId': null});
          }
          await batch.commit();
        }
      }
      // أقسام الإدارة تذهب معها في الحالتين — فهي تنظيم داخلي لها لا معنى له
      // بعد حذفها.
      final deptSections = sections.where((s) => s.departmentId == dept.id).toList();
      for (var i = 0; i < deptSections.length; i += 400) {
        final batch = _db.batch();
        for (final sec in deptSections.skip(i).take(400)) {
          batch.delete(_db.collection('sections').doc(sec.id));
        }
        await batch.commit();
      }
      await _db.collection('departments').doc(dept.id).delete();
      await _log(
        'إدارة الإدارات',
        cascade
            ? 'تم حذف الإدارة "${dept.name}" مع ${owned.length} مشروعاً وكل تابعيها'
            : 'تم حذف الإدارة "${dept.name}" ونُقل ${owned.length} مشروعاً إلى "بدون إدارة"',
      );
      return null;
    } catch (e) {
      return 'تعذر حذف الإدارة: $e';
    }
  }

  // ------------------------- حذف المشاريع -------------------------

  /// يحذف مشروعاً وكل المستندات المرتبطة به. يُعيد رسالة خطأ أو null عند النجاح.
  Future<String?> deleteProject(Project project) async {
    try {
      await _deleteProjectDocs(project);
      await _log('إدارة المشاريع', 'تم حذف المشروع "${project.name}" وكل تابعيه');
      return null;
    } catch (e) {
      return 'تعذر حذف المشروع: $e';
    }
  }

  /// يحذف مستند المشروع وكل ما يتبعه من مهام ومخاطر وعوائق وتحديثات يومية
  /// وودجات خاصة به — لئلا تبقى مستندات يتيمة تظهر في المؤشرات والتقارير.
  Future<void> _deleteProjectDocs(Project project) async {
    const related = ['tasks', 'risks', 'blockers', 'dailyUpdates'];
    for (final collection in related) {
      final snap = await _db.collection(collection).where('projectId', isEqualTo: project.id).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final doc in snap.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _db.collection('projectWidgets').doc(project.id).delete();
    await _db.collection('projects').doc(project.id).delete();
  }

  /// عدد المستندات التابعة لمشروع، لعرضه في نافذة تأكيد الحذف حتى يعرف
  /// المستخدم حجم ما سيفقده قبل أن يؤكد.
  ({int tasks, int risks, int blockers}) projectDependents(String projectId) => (
        tasks: tasks.where((t) => t.projectId == projectId).length,
        risks: risks.where((r) => r.projectId == projectId).length,
        blockers: blockers.where((b) => b.projectId == projectId).length,
      );

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

  /// استيراد ملف «مراقبة تنفيذ المشروعات ٢٠٢٦»: خمسة أقسام كإدارات مستقلة
  /// برؤسائها، و٧١ مشروعاً بأوصافها وجهاتها المستفيدة وفرق عملها وملاحظاتها.
  /// معرّفات ثابتة (merge) فتكرار الاستيراد آمن ولا يُنشئ سجلات مكرّرة، ولا
  /// يمسّ بوابات الاعتماد الثلاث.
  Future<void> importMinistryProjects2026() async {
    // إدارة صار لها قسم محوَّل عنها لا تُعاد إنشاؤها، وتُكتب مشاريعها داخل
    // ذلك القسم. بدون هذا كان كل استيراد يُلغي إعادة الهيكلة التي قام بها
    // مسؤول النظام ويُعيد الإدارات المحذوفة من العدم.
    final converted = <String, DepartmentSection>{
      for (final s in sections)
        if (s.sourceDepartmentId != null) s.sourceDepartmentId!: s,
    };

    final batch = _db.batch();
    for (final d in MinistryProjects2026.departments()) {
      if (converted.containsKey(d.id)) continue;
      batch.set(_db.collection('departments').doc(d.id), d.toMap(), SetOptions(merge: true));
    }
    for (final p in MinistryProjects2026.projects()) {
      final target = converted[p.departmentId];
      final mapped = target == null
          ? p
          : p.copyWith(departmentId: target.departmentId, sectionId: target.id);
      batch.set(_db.collection('projects').doc(mapped.id), mapped.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
    await _log('استيراد بيانات', 'قام ${currentUser?.name} باستيراد ملف مراقبة تنفيذ المشروعات ٢٠٢٦');
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
      'widgets': DashboardWidgetConfig.dedupe(widgets).map((w) => w.toMap()).toList(),
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
