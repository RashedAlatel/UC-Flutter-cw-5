import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/audit_log_entry.dart';
import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/decision_request.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/report.dart';
import '../models/risk.dart';
import 'seed_data.dart';

/// طبقة إدارة الحالة المركزية للمنصة (بيانات + منطق أعمال + صلاحيات).
/// تُخزَّن البيانات محلياً عبر SharedPreferences، ويمكن استبدالها لاحقاً
/// بخدمة API حقيقية دون التأثير على واجهات المستخدم.
class AppStore extends ChangeNotifier {
  static const _prefsKey = 'gov_platform_state_v1';
  static const _uuid = Uuid();

  AppUser? currentUser;

  List<AppUser> users = [];
  List<Department> departments = [];
  List<Project> projects = [];
  List<ProjectTask> tasks = [];
  List<ProjectRisk> risks = [];
  List<ProjectBlocker> blockers = [];
  List<DecisionRequest> decisions = [];
  List<DailyUpdate> dailyUpdates = [];
  List<AuditLogEntry> auditLog = [];
  List<ReportSnapshot> reports = [];

  bool _ready = false;
  bool get ready => _ready;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
        _ready = true;
        notifyListeners();
        return;
      } catch (_) {
        // في حال تلف البيانات المخزنة، أعد التهيئة من البيانات الافتراضية
      }
    }
    _seed();
    _ready = true;
    notifyListeners();
  }

  void _seed() {
    departments = SeedData.departments();
    users = SeedData.users();
    projects = SeedData.projects();
    tasks = SeedData.tasks();
    risks = SeedData.risks();
    blockers = SeedData.blockers();
    decisions = SeedData.decisions();
    dailyUpdates = SeedData.dailyUpdates();
    auditLog = [
      AuditLogEntry(
        id: _uuid.v4(),
        userName: 'النظام',
        action: 'تهيئة المنصة',
        details: 'تم تحميل البيانات الأولية للمنصة التنفيذية الحكومية.',
        timestamp: DateTime.now(),
      ),
    ];
  }

  // ------------------------- المصادقة -------------------------

  bool login(String username, String password) {
    final match = users.where(
      (u) => u.username.toLowerCase() == username.trim().toLowerCase() && u.password == password && u.active,
    );
    if (match.isEmpty) return false;
    currentUser = match.first;
    _log('تسجيل دخول', 'قام ${currentUser!.name} بتسجيل الدخول');
    notifyListeners();
    return true;
  }

  void logout() {
    if (currentUser != null) {
      _log('تسجيل خروج', 'قام ${currentUser!.name} بتسجيل الخروج');
    }
    currentUser = null;
    notifyListeners();
  }

  // ------------------------- الصلاحيات -------------------------

  bool get isAdmin => currentUser?.role == UserRole.systemAdmin;
  bool get isExecutive => currentUser?.role == UserRole.executiveViewer;
  bool get isManager => currentUser?.role == UserRole.departmentManager;
  bool get isOfficer => currentUser?.role == UserRole.projectOfficer;

  bool get canViewAllDepartments => isAdmin || isExecutive;
  bool get canManageUsers => isAdmin;
  bool get canViewAuditLog => isAdmin;
  bool get canResolveDecisions => isAdmin || isExecutive;

  bool canEditProject(Project project) {
    if (currentUser == null) return false;
    if (isAdmin) return true;
    if (isExecutive) return false;
    return currentUser!.departmentId == project.departmentId;
  }

  bool canSubmitDailyUpdate(Project project) => canEditProject(project);

  bool canViewDepartment(String departmentId) {
    if (currentUser == null) return false;
    if (canViewAllDepartments) return true;
    return currentUser!.departmentId == departmentId;
  }

  List<Department> get visibleDepartments {
    if (canViewAllDepartments) return departments;
    return departments.where((d) => d.id == currentUser?.departmentId).toList();
  }

  List<Project> get visibleProjects {
    if (canViewAllDepartments) return projects;
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

  List<DecisionRequest> decisionsForProject(String projectId) =>
      decisions.where((d) => d.projectId == projectId).toList();

  List<DailyUpdate> updatesForProject(String projectId) =>
      dailyUpdates.where((u) => u.projectId == projectId).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// نسبة إنجاز الإدارة = متوسط نسب إنجاز مشاريعها
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

  /// ترتيب الإدارات حسب الأداء (الأعلى إنجازاً أولاً)
  List<MapEntry<Department, double>> get departmentRanking {
    final list = departments.map((d) => MapEntry(d, departmentProgress(d.id))).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // KPIs المركزية
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
  int get pendingDecisionsCount => decisions.where((d) => d.status == DecisionStatus.pending).length;

  List<DecisionRequest> get pendingDecisionsSorted {
    final list = decisions.where((d) => d.status == DecisionStatus.pending).toList();
    list.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return b.delayImpactDays.compareTo(a.delayImpactDays);
    });
    return list;
  }

  // ------------------------- عمليات الكتابة -------------------------

  void addDailyUpdate({
    required Project project,
    required String achievements,
    required List<String> completedTasks,
    required List<String> newRisks,
    required List<String> blockersText,
    required List<String> decisionsRequired,
    required double progressPercent,
  }) {
    final update = DailyUpdate(
      id: _uuid.v4(),
      projectId: project.id,
      departmentId: project.departmentId,
      authorName: currentUser?.name ?? 'غير معروف',
      date: DateTime.now(),
      achievements: achievements,
      completedTasks: completedTasks,
      newRisks: newRisks,
      blockers: blockersText,
      decisionsRequired: decisionsRequired,
      progressPercent: progressPercent,
    );
    dailyUpdates.insert(0, update);

    final idx = projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      final old = projects[idx];
      final delta = progressPercent - old.progressPercent;
      ProjectStatus newStatus = old.status;
      if (progressPercent >= 100) {
        newStatus = ProjectStatus.completed;
      } else if (old.delayDays > 5) {
        newStatus = ProjectStatus.delayed;
      } else if (newRisks.isNotEmpty || blockersText.isNotEmpty) {
        newStatus = ProjectStatus.atRisk;
      } else if (delta > 0) {
        newStatus = ProjectStatus.onTrack;
      }
      projects[idx] = old.copyWith(progressPercent: progressPercent, status: newStatus);
    }

    for (final r in newRisks) {
      risks.add(ProjectRisk(
        id: _uuid.v4(),
        projectId: project.id,
        description: r,
        level: RiskLevel.medium,
        status: ItemStatus.open,
        dateRaised: DateTime.now(),
      ));
    }
    for (final b in blockersText) {
      blockers.add(ProjectBlocker(
        id: _uuid.v4(),
        projectId: project.id,
        description: b,
        status: ItemStatus.open,
        dateRaised: DateTime.now(),
      ));
    }
    for (final d in decisionsRequired) {
      decisions.add(DecisionRequest(
        id: _uuid.v4(),
        projectId: project.id,
        departmentId: project.departmentId,
        title: d,
        description: 'قرار مطلوب ضمن التحديث اليومي بتاريخ ${_fmtDate(DateTime.now())} بواسطة ${currentUser?.name ?? ''}',
        priority: PriorityLevel.medium,
        delayImpactDays: 5,
        status: DecisionStatus.pending,
        requestedBy: currentUser?.name ?? '',
        requestedDate: DateTime.now(),
      ));
    }

    _log('تحديث يومي', 'أضاف ${currentUser?.name} تحديثاً يومياً لمشروع "${project.name}"');
    _persist();
    notifyListeners();
  }

  void updateTaskStatus(ProjectTask task, TaskStatus status) {
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;
    tasks[idx] = task.copyWith(
      status: status,
      lastUpdated: DateTime.now(),
      progressPercent: status == TaskStatus.done ? 100 : task.progressPercent,
    );
    _log('تحديث مهمة', 'تم تغيير حالة المهمة "${task.title}" إلى ${status.label}');
    _persist();
    notifyListeners();
  }

  void updateTaskProgress(ProjectTask task, double progress) {
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;
    tasks[idx] = task.copyWith(progressPercent: progress, lastUpdated: DateTime.now());
    _log('تحديث تقدم مهمة', 'تم تحديث نسبة إنجاز المهمة "${task.title}" إلى ${progress.toStringAsFixed(0)}٪');
    _persist();
    notifyListeners();
  }

  void addTask(ProjectTask task) {
    tasks.add(task);
    _log('إضافة مهمة', 'تمت إضافة مهمة جديدة "${task.title}"');
    _persist();
    notifyListeners();
  }

  void resolveDecision(DecisionRequest decision, DecisionStatus status, {String? note}) {
    final idx = decisions.indexWhere((d) => d.id == decision.id);
    if (idx == -1) return;
    decisions[idx] = decision.copyWith(status: status, resolutionNote: note);
    _log('قرار تنفيذي', 'تم ${status == DecisionStatus.approved ? "الموافقة على" : "رفض"} طلب "${decision.title}"');
    _persist();
    notifyListeners();
  }

  void addUser(AppUser user) {
    users.add(user);
    _log('إدارة المستخدمين', 'تمت إضافة مستخدم جديد "${user.name}" بدور ${user.role.label}');
    _persist();
    notifyListeners();
  }

  void updateUser(AppUser user) {
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx == -1) return;
    users[idx] = user;
    _log('إدارة المستخدمين', 'تم تعديل بيانات المستخدم "${user.name}"');
    _persist();
    notifyListeners();
  }

  void toggleUserActive(AppUser user) {
    updateUser(user.copyWith(active: !user.active));
  }

  ReportSnapshot generateReport(ReportPeriod period) {
    final ranking = departmentRanking.map((e) => MapEntry(e.key.name, double.parse(e.value.toStringAsFixed(1)))).toList();
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
      'مع وجود $pendingDecisionsCount طلب قرار بانتظار اعتماد القيادة التنفيذية.',
    );

    final report = ReportSnapshot(
      id: _uuid.v4(),
      period: period,
      generatedDate: DateTime.now(),
      executiveSummary: summary.toString().trim(),
      avgProgress: overallProgress,
      avgDelayDays: overallAvgDelay,
      totalRisks: openRisksCount,
      totalBlockers: openBlockersCount,
      pendingDecisions: pendingDecisionsCount,
      departmentRanking: ranking,
    );
    reports.insert(0, report);
    _log('تقرير', 'تم توليد تقرير ${period.label} بتاريخ ${_fmtDate(report.generatedDate)}');
    _persist();
    notifyListeners();
    return report;
  }

  void updateReportComment(ReportSnapshot report, String comment) {
    report.manualComment = comment;
    _log('تقرير', 'تم إضافة/تعديل تعليق يدوي على تقرير ${report.period.label}');
    _persist();
    notifyListeners();
  }

  void _log(String action, String details) {
    auditLog.insert(
      0,
      AuditLogEntry(
        id: _uuid.v4(),
        userName: currentUser?.name ?? 'النظام',
        action: action,
        details: details,
        timestamp: DateTime.now(),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  // ------------------------- التخزين المحلي -------------------------

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'departments': departments.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'risks': risks.map((e) => e.toJson()).toList(),
        'blockers': blockers.map((e) => e.toJson()).toList(),
        'decisions': decisions.map((e) => e.toJson()).toList(),
        'dailyUpdates': dailyUpdates.map((e) => e.toJson()).toList(),
        'auditLog': auditLog.map((e) => e.toJson()).toList(),
        'reports': reports.map((e) => e.toJson()).toList(),
      };

  void _loadFromJson(Map<String, dynamic> json) {
    users = (json['users'] as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
    departments =
        (json['departments'] as List).map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
    projects = (json['projects'] as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    tasks = (json['tasks'] as List).map((e) => ProjectTask.fromJson(e as Map<String, dynamic>)).toList();
    risks = (json['risks'] as List).map((e) => ProjectRisk.fromJson(e as Map<String, dynamic>)).toList();
    blockers = (json['blockers'] as List).map((e) => ProjectBlocker.fromJson(e as Map<String, dynamic>)).toList();
    decisions =
        (json['decisions'] as List).map((e) => DecisionRequest.fromJson(e as Map<String, dynamic>)).toList();
    dailyUpdates =
        (json['dailyUpdates'] as List).map((e) => DailyUpdate.fromJson(e as Map<String, dynamic>)).toList();
    auditLog = (json['auditLog'] as List).map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    reports = (json['reports'] as List).map((e) => ReportSnapshot.fromJson(e as Map<String, dynamic>)).toList();
    if (users.isEmpty || departments.isEmpty) {
      _seed();
    }
  }

  /// إعادة ضبط المنصة إلى بياناتها الافتراضية (لأغراض العرض التجريبي)
  Future<void> resetToSeed() async {
    currentUser = null;
    _seed();
    reports = [];
    await _persist();
    notifyListeners();
  }
}
