/// أدوار المستخدمين في المنصة
enum UserRole {
  systemAdmin, // مسؤول نظام - كامل الصلاحيات
  executiveViewer, // مستخدم تنفيذي - عرض فقط لكل الإدارات
  departmentManager, // مدير إدارة - تعديل مشاريع إدارته فقط
  projectOfficer; // ضابط مشروع - تحديث المهام اليومية

  String get label {
    switch (this) {
      case UserRole.systemAdmin:
        return 'مسؤول نظام';
      case UserRole.executiveViewer:
        return 'مستخدم تنفيذي';
      case UserRole.departmentManager:
        return 'مدير إدارة';
      case UserRole.projectOfficer:
        return 'ضابط مشروع';
    }
  }

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
  deadlineChange, // تعديل موعد نهائي لمشروع
  decision; // قرار تنفيذي عام مطلوب من القيادة

  String get label {
    switch (this) {
      case ApprovalType.registration:
        return 'تسجيل عضو جديد';
      case ApprovalType.projectCreate:
        return 'إضافة مشروع جديد';
      case ApprovalType.deadlineChange:
        return 'تعديل موعد نهائي';
      case ApprovalType.decision:
        return 'قرار تنفيذي';
    }
  }

  static ApprovalType fromName(String name) =>
      ApprovalType.values.firstWhere((e) => e.name == name, orElse: () => ApprovalType.decision);
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
