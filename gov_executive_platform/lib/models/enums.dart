import 'package:flutter/material.dart';

/// أدوار المستخدمين في المنصة
enum UserRole {
  systemAdmin, // مسؤول نظام - كامل الصلاحيات
  executiveViewer, // مستخدم تنفيذي - عرض فقط لكل الإدارات
  departmentManager, // مدير إدارة - تعديل مشاريع إدارته فقط
  projectOfficer, // مدير مشروع - يرى مشروعه المُسنَد إليه فقط
  employee, // موظف - ينفّذ الأعمال التشغيلية المُسنَدة إليه ضمن إدارته
  custom; // دور مخصص مُعرَّف من مسؤول النظام (راجع CustomRole)

  String get label {
    switch (this) {
      case UserRole.systemAdmin:
        return 'مسؤول نظام';
      case UserRole.executiveViewer:
        return 'مستخدم تنفيذي';
      case UserRole.departmentManager:
        return 'مدير إدارة';
      case UserRole.projectOfficer:
        return 'مدير مشروع';
      case UserRole.employee:
        return 'موظف';
      case UserRole.custom:
        return 'دور مخصص';
    }
  }

  /// الأدوار التي يمكن لمسؤول النظام ضبط صلاحياتها من شاشة "صلاحيات الأدوار".
  /// [systemAdmin] مستثنى عمداً (كامل الصلاحيات دائماً)، و[custom] له شاشته
  /// الخاصة في "إدارة الأدوار".
  static const List<UserRole> configurable = [
    UserRole.executiveViewer,
    UserRole.departmentManager,
    UserRole.projectOfficer,
    UserRole.employee,
  ];

  static UserRole fromName(String name) =>
      UserRole.values.firstWhere((e) => e.name == name, orElse: () => UserRole.projectOfficer);
}

/// حالة اعتماد حساب المستخدم
enum UserStatus {
  pending, // بانتظار موافقة مسؤول النظام
  approved, // مفعّل
  rejected, // مرفوض
  suspended; // موقوف

  String get label {
    switch (this) {
      case UserStatus.pending:
        return 'بانتظار الموافقة';
      case UserStatus.approved:
        return 'مفعّل';
      case UserStatus.rejected:
        return 'مرفوض';
      case UserStatus.suspended:
        return 'موقوف';
    }
  }

  static UserStatus fromName(String name) =>
      UserStatus.values.firstWhere((e) => e.name == name, orElse: () => UserStatus.pending);
}

enum ProjectStatus {
  onTrack, // على المسار
  atRisk, // مهدد بالخطر
  delayed, // متأخر
  completed; // مكتمل

  String get label {
    switch (this) {
      case ProjectStatus.onTrack:
        return 'على المسار';
      case ProjectStatus.atRisk:
        return 'مهدد بالخطر';
      case ProjectStatus.delayed:
        return 'متأخر';
      case ProjectStatus.completed:
        return 'مكتمل';
    }
  }

  static ProjectStatus fromName(String name) =>
      ProjectStatus.values.firstWhere((e) => e.name == name, orElse: () => ProjectStatus.onTrack);
}

enum PriorityLevel {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case PriorityLevel.low:
        return 'منخفضة';
      case PriorityLevel.medium:
        return 'متوسطة';
      case PriorityLevel.high:
        return 'عالية';
      case PriorityLevel.critical:
        return 'حرجة';
    }
  }

  static PriorityLevel fromName(String name) => PriorityLevel.values
      .firstWhere((e) => e.name == name, orElse: () => PriorityLevel.medium);
}

enum TaskStatus {
  todo, // قائمة الانتظار
  inProgress, // قيد التنفيذ
  review, // قيد المراجعة
  done, // منجزة
  blocked; // معلقة

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'قائمة الانتظار';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.review:
        return 'قيد المراجعة';
      case TaskStatus.done:
        return 'منجزة';
      case TaskStatus.blocked:
        return 'معلقة';
    }
  }

  static TaskStatus fromName(String name) =>
      TaskStatus.values.firstWhere((e) => e.name == name, orElse: () => TaskStatus.todo);
}

enum RiskLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'منخفض';
      case RiskLevel.medium:
        return 'متوسط';
      case RiskLevel.high:
        return 'مرتفع';
    }
  }

  static RiskLevel fromName(String name) =>
      RiskLevel.values.firstWhere((e) => e.name == name, orElse: () => RiskLevel.medium);
}

enum ItemStatus {
  open, // قائم
  resolved; // تم الحل

  String get label => this == ItemStatus.open ? 'قائم' : 'تم الحل';

  static ItemStatus fromName(String name) =>
      ItemStatus.values.firstWhere((e) => e.name == name, orElse: () => ItemStatus.open);
}

enum DecisionStatus {
  pending, // بانتظار القرار
  approved, // تمت الموافقة
  rejected; // مرفوض

  String get label {
    switch (this) {
      case DecisionStatus.pending:
        return 'بانتظار القرار';
      case DecisionStatus.approved:
        return 'تمت الموافقة';
      case DecisionStatus.rejected:
        return 'مرفوض';
    }
  }

  static DecisionStatus fromName(String name) => DecisionStatus.values
      .firstWhere((e) => e.name == name, orElse: () => DecisionStatus.pending);
}

enum ReportPeriod {
  weekly,
  monthly;

  String get label => this == ReportPeriod.weekly ? 'أسبوعي' : 'شهري';

  static ReportPeriod fromName(String name) =>
      ReportPeriod.values.firstWhere((e) => e.name == name, orElse: () => ReportPeriod.weekly);
}

/// أنواع طلبات الموافقة التي تمر عبر مركز القرارات التنفيذية
enum ApprovalType {
  registration, // تسجيل عضو جديد
  projectCreate, // إضافة مشروع جديد
  workCreate, // إضافة عمل تشغيلي جديد
  deadlineChange, // تعديل موعد نهائي لمشروع
  // إرسال بريد/إشعار باسم المنصة. بوابة اعتماد كسابقتيها: كل بريد يخرج
  // للمستخدمين يمرّ بمسؤول النظام، ولا يفتحه مفتاح مفوَّض.
  notifySend,
  decision; // قرار تنفيذي عام مطلوب من القيادة

  String get label {
    switch (this) {
      case ApprovalType.registration:
        return 'تسجيل عضو جديد';
      case ApprovalType.projectCreate:
        return 'إضافة مشروع جديد';
      case ApprovalType.workCreate:
        return 'إضافة عمل جديد';
      case ApprovalType.deadlineChange:
        return 'تعديل موعد نهائي';
      case ApprovalType.notifySend:
        return 'إرسال بريد';
      case ApprovalType.decision:
        return 'قرار تنفيذي';
    }
  }

  static ApprovalType fromName(String name) =>
      ApprovalType.values.firstWhere((e) => e.name == name, orElse: () => ApprovalType.decision);
}

/// أنواع الودجات القابلة للإضافة إلى لوحة القيادة الرئيسية
enum DashboardWidgetType {
  // بطاقات المؤشرات — كانت مثبَّتة في شيفرة الصفحة خارج اللوحة، فلا تُسحب
  // ولا تُحذف ولا يُختار أيّها يظهر. صارت ودجات كبقيتها، فنالت السحب والعرض
  // والحذف بلا شيفرة جديدة.
  kpiAvgProgress,
  kpiAvgDelay,
  kpiProjectCount,
  kpiHighPriority,
  kpiOpenRisks,
  kpiOpenBlockers,
  kpiPendingApprovals,
  // الرسوم والقوائم
  deptBarChart,
  topUsersChart,
  statusPieChart,
  pendingApprovalsList,
  departmentRankingList,
  recentUpdatesList,
  topProjectsList,
  projectsTable,
  custom;

  String get label {
    switch (this) {
      case DashboardWidgetType.kpiAvgProgress:
        return 'مؤشر: نسبة الإنجاز العام';
      case DashboardWidgetType.kpiAvgDelay:
        return 'مؤشر: متوسط التأخير عن الخطة';
      case DashboardWidgetType.kpiProjectCount:
        return 'مؤشر: إجمالي عدد المشاريع';
      case DashboardWidgetType.kpiHighPriority:
        return 'مؤشر: المشاريع عالية الأولوية';
      case DashboardWidgetType.kpiOpenRisks:
        return 'مؤشر: المخاطر القائمة';
      case DashboardWidgetType.kpiOpenBlockers:
        return 'مؤشر: العوائق النشطة';
      case DashboardWidgetType.kpiPendingApprovals:
        return 'مؤشر: طلبات بانتظار القيادة';
      case DashboardWidgetType.deptBarChart:
        return 'رسم بياني: ترتيب الإدارات (أعمدة)';
      case DashboardWidgetType.topUsersChart:
        return 'رسم بياني: الأشخاص حسب المشاريع';
      case DashboardWidgetType.statusPieChart:
        return 'رسم بياني: توزيع حالة المشاريع (دائري)';
      case DashboardWidgetType.pendingApprovalsList:
        return 'قائمة: قرارات مطلوبة من القيادة';
      case DashboardWidgetType.departmentRankingList:
        return 'قائمة: تفاصيل ترتيب الإدارات';
      case DashboardWidgetType.recentUpdatesList:
        return 'قائمة: أحدث التحديثات اليومية';
      case DashboardWidgetType.topProjectsList:
        return 'قائمة: أعلى المشاريع تقدماً';
      case DashboardWidgetType.projectsTable:
        return 'جدول: تفاصيل المشاريع';
      case DashboardWidgetType.custom:
        return 'ودجت مخصص (أنشئه بنفسك)';
    }
  }

  IconData get icon {
    switch (this) {
      case DashboardWidgetType.kpiAvgProgress:
        return Icons.trending_up_rounded;
      case DashboardWidgetType.kpiAvgDelay:
        return Icons.schedule_rounded;
      case DashboardWidgetType.kpiProjectCount:
        return Icons.folder_copy_rounded;
      case DashboardWidgetType.kpiHighPriority:
        return Icons.priority_high_rounded;
      case DashboardWidgetType.kpiOpenRisks:
        return Icons.warning_amber_rounded;
      case DashboardWidgetType.kpiOpenBlockers:
        return Icons.block_rounded;
      case DashboardWidgetType.kpiPendingApprovals:
        return Icons.gavel_rounded;
      case DashboardWidgetType.deptBarChart:
        return Icons.bar_chart_rounded;
      case DashboardWidgetType.topUsersChart:
        return Icons.groups_rounded;
      case DashboardWidgetType.statusPieChart:
        return Icons.pie_chart_rounded;
      case DashboardWidgetType.pendingApprovalsList:
        return Icons.gavel_rounded;
      case DashboardWidgetType.departmentRankingList:
        return Icons.leaderboard_rounded;
      case DashboardWidgetType.recentUpdatesList:
        return Icons.history_edu_rounded;
      case DashboardWidgetType.topProjectsList:
        return Icons.military_tech_rounded;
      case DashboardWidgetType.projectsTable:
        return Icons.table_chart_rounded;
      case DashboardWidgetType.custom:
        return Icons.auto_awesome_mosaic_rounded;
    }
  }

  /// هل يحمل هذا النوع مقياساً يختاره المستخدم (`DashboardMetric`)؟
  ///
  /// الأنواع الحاملة للمقياس هي وحدها التي يُسمح بتكرارها على اللوحة —
  /// نسخةٌ لكل مقياس — وتظهر لها قائمة «المقياس» في وضع الترتيب وفي نافذة
  /// التخصيص.
  bool get hasMetric =>
      this == DashboardWidgetType.deptBarChart ||
      this == DashboardWidgetType.departmentRankingList ||
      this == DashboardWidgetType.topUsersChart;

  /// بطاقات المؤشرات: رقم واحد في بطاقة صغيرة، تُصيَّر بـ`KpiCard`.
  bool get isKpi => name.startsWith('kpi');

  static DashboardWidgetType fromName(String name) => DashboardWidgetType.values
      .firstWhere((e) => e.name == name, orElse: () => DashboardWidgetType.deptBarChart);
}

/// قنوات إرسال الإشعارات للمستخدمين
enum NotifyChannel {
  email,
  whatsapp,
  both;

  String get label {
    switch (this) {
      case NotifyChannel.email:
        return 'البريد الإلكتروني';
      case NotifyChannel.whatsapp:
        return 'واتساب';
      case NotifyChannel.both:
        return 'البريد وواتساب معاً';
    }
  }
}
