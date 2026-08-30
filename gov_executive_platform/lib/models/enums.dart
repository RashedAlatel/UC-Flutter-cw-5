import 'package:flutter/material.dart';

/// أدوار المستخدمين في المنصة
enum UserRole {
  systemAdmin, // مسؤول نظام - كامل الصلاحيات
  executiveViewer, // مستخدم تنفيذي - عرض فقط لكل الإدارات
  departmentManager, // مدير إدارة - تعديل مشاريع إدارته فقط
  // ــــ دورٌ موروث لا يُمنح بعد اليوم ــــ
  //
  // كان «مدير مشروع» دوراً أساسياً يُختار عند التسجيل، فيسري على صاحبه في
  // كل مشاريع المنصة لمجرّد أنه قاد مشروعاً واحداً. وصار قيادةُ المشروع
  // **مسؤوليةً داخل مشروع بعينه** تُقرأ من `managerUids` عليه — راجع
  // `isMyProject` في firestore.rules و`canEditProject` في المتجر.
  //
  // ويبقى العنصر في التعداد لأن حساباتٍ حيّة في الوزارة تحمله، وحذفُه يجعل
  // سجلّاتها تُقرأ بدورٍ آخر فجأةً. ولا يظهر في أي قائمة اختيار — راجع
  // [assignableAtSignup] و[adminAssignable].
  projectOfficer, // (موروث) مدير مشروع
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

  /// الأدوار التي يختارها الموظف عند التسجيل، ويمنحها مسؤول النظام عند
  /// إنشاء حساب أو تعديله.
  ///
  /// و«مدير مشروع» ليس منها بقرار صريح: هو مسؤوليةٌ داخل مشروع بعينه تُطلب
  /// وتُعتمد (راجع [ApprovalType.projectManagerAppointment])، لا موقعٌ في
  /// الهيكل التنظيمي. ومنحُه دوراً أساسياً كان يُعطي صاحبه صفة مدير مشروع
  /// في **كل** مشاريع المنصة لمجرّد أنه قاد واحداً.
  static const List<UserRole> assignable = [
    UserRole.executiveViewer,
    UserRole.departmentManager,
    UserRole.employee,
  ];

  /// هل هذا الدور موروثٌ لا يُمنح بعد اليوم؟ يُعرض لصاحبه ولا يُختار لغيره.
  bool get isLegacy => this == UserRole.projectOfficer;

  /// والافتراض عند قراءة دورٍ غير معروف **أدنى الأدوار** لا أعلاها: مستندٌ
  /// تالفٌ أو حقلٌ ناقص يجب أن يُنقص الوصول لا أن يزيده.
  static UserRole fromName(String name) =>
      UserRole.values.firstWhere((e) => e.name == name, orElse: () => UserRole.employee);
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
  // ــــ بانتظار اعتماد الطالب ــــ
  //
  // كانت ضغطةٌ واحدة تُغلق العمل: يكتبها **الطرف المنفِّذ نفسه**، فيُقفل
  // المطلوب بلا أن يعلم من طلبه. وهما إدارياً حالتان لا واحدة: «أفادت
  // الإدارة بالإتمام» إفادةُ طرف، و«اعتمده الطالب وأغلقه» قرار.
  //
  // وموضعها بين «قيد المراجعة» و«منجزة» في التعداد لا يمسّ ما هو مخزَّن:
  // الحالة تُكتب في Firestore بالاسم لا بالرقم.
  awaitingApproval, // بانتظار اعتماد مدير المشروع
  done, // منجزة
  blocked; // معلقة

  /// هل هذه الحالة إغلاقٌ فعلي؟ «بانتظار الاعتماد» ليست منها — وهذا هو
  /// الفرق الذي طُلب أن تراه لوحة المدير التنفيذي.
  bool get isClosed => this == TaskStatus.done;

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'قائمة الانتظار';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.review:
        return 'قيد المراجعة';
      case TaskStatus.awaitingApproval:
        return 'بانتظار الاعتماد';
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
  rejected, // مرفوض
  // ــــ معادٌ للتعديل — وهو **غيرُ الرفض** ــــ
  //
  // الرفضُ يُنهي الطلب: البياناتُ تبقى كما هي ولا شيء بعده. وهذه تُعيده إلى
  // مقدّمه حيّاً ليصحّحه ويُعيد إرساله — وهي ما طلبتَ صراحةً في مسار مدير
  // المشروع: «إعادة الطلب لمدير المشروع للتعديل».
  //
  // ولولا التفريق لَاضطُرّ المعتمِد إلى الرفض ليقول «انقص سطراً»، فيقرأ
  // مقدّمُ الطلب رفضاً حيث أُريد تصحيح.
  returnedForRevision;

  String get label {
    switch (this) {
      case DecisionStatus.pending:
        return 'بانتظار القرار';
      case DecisionStatus.approved:
        return 'تمت الموافقة';
      case DecisionStatus.rejected:
        return 'مرفوض';
      case DecisionStatus.returnedForRevision:
        return 'معاد للتعديل';
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
  // تغيير مدير مشروع قائم. يطلبه مدير الإدارة أو المستخدم التنفيذي في
  // نطاقه، ويعتمده مسؤول النظام وحده — فلا ينتقل مشروعٌ من يدٍ إلى يد بقرار
  // طرفٍ واحد، ويبقى الأثر في سجل التدقيق.
  managerChange,
  // ــــ تعيين موظف مديراً لمشروع بعينه ــــ
  //
  // «مدير المشروع» لم يعد دوراً أساسياً يُمنح عند التسجيل فيسري على كل
  // مشاريع المنصة، بل **مسؤولية مؤقتة داخل مشروع واحد**. والموظف يطلبها
  // لنفسه، ويعتمدها **مدير إدارة المشروع** أو مسؤول النظام.
  //
  // وقبل هذا كان صاحب صلاحية «الانضمام لمشاريع الإدارة» يسجّل نفسه مديراً
  // بلا اعتماد أحد — وهو الباب الذي أُغلق.
  projectManagerAppointment,
  // ــــ تعديل البيانات الأساسية للمشروع ــــ
  //
  // مسارٌ **بمرحلتين** بخلاف كل ما سبقه: مديرُ المشروع يطلب، فيوافق مديرُ
  // الإدارة، ثم يعتمد مسؤولُ النظام ويُطبَّق. ومديرُ الإدارة إن طلب بدأ عند
  // مسؤول النظام مباشرةً — فلا يعتمد أحدٌ طلبَ نفسه.
  //
  // والمرحلةُ على مستند الطلب (`stage`)، ومن يبتّ فيها يقرّره
  // `functions/src/approval_stage.ts` — لا الدورُ وحده.
  projectEdit,
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
      case ApprovalType.managerChange:
        return 'تغيير مدير المشروع';
      case ApprovalType.projectManagerAppointment:
        return 'تعيين مدير مشروع';
      case ApprovalType.projectEdit:
        return 'تعديل بيانات مشروع';
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
  // ــــ الفرق بين «أفادت الإدارة» و«اعتمد الطالب وأغلق» ــــ
  //
  // مؤشران لا واحد، لأنهما حالتان مختلفتان إدارياً: الأول عملٌ قالت الإدارة
  // المنفّذة إنه تمّ ولم يراجعه أحد بعد، والثاني عملٌ راجعه طالبه وأغلقه.
  // وجمعُهما في رقم واحد يُخفي عن القيادة كم عملاً واقفٌ على مكتبٍ لا على
  // تنفيذ.
  kpiClaimedDone,
  kpiClosedApproved,
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
      case DashboardWidgetType.kpiClaimedDone:
        return 'مؤشر: أفادت الإدارات بإتمامه (بانتظار الاعتماد)';
      case DashboardWidgetType.kpiClosedApproved:
        return 'مؤشر: مُعتمَد ومغلَق';
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
      case DashboardWidgetType.kpiClaimedDone:
        return Icons.how_to_reg_outlined;
      case DashboardWidgetType.kpiClosedApproved:
        return Icons.task_alt_rounded;
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
