import 'enums.dart';

/// صلاحية واحدة قابلة للتفويض من مسؤول النظام إلى الأدوار الأساسية.
///
/// **حدّ ثابت:** بوابات الاعتماد الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد
/// نهائي) ليست ضمن هذه القائمة عمداً ولن تُضاف إليها — تبقى حصراً لمسؤول
/// النظام في قواعد Firestore وفي Cloud Functions معاً.
enum RolePermission {
  viewAllDepartments('vad', 'عرض كل الإدارات', 'الاطلاع على مشاريع كل الإدارات لا إدارته فقط'),
  manageReports('mr', 'إدارة التقارير', 'توليد التقارير وتحرير التعليقات التنفيذية عليها'),
  manageDashboard('md', 'تخصيص لوحة القيادة', 'إضافة وحذف وترتيب ودجات لوحة القيادة'),
  approveGeneralDecisions('agd', 'اعتماد القرارات العامة', 'اعتماد أو رفض القرارات التنفيذية العامة'),
  manageWorks('mw', 'إدارة الأعمال', 'إضافة وتعديل الأعمال التشغيلية وإسنادها للموظفين'),
  deleteRecords('del', 'حذف السجلات', 'حذف المشاريع والأعمال نهائياً'),
  sendNotifications('ntf', 'إرسال الإشعارات', 'مراسلة المستخدمين بالبريد وواتساب ضمن نطاقه'),
  selfAssignProjects('sap', 'الانضمام لمشاريع الإدارة',
      'الاطلاع على كل مشاريع إدارته وتسجيل نفسه على أي منها منفّذاً أو مديراً');

  /// مفتاح مختصر — يُخزَّن في Custom Claims التي لها حدّ حجم صارم.
  final String key;
  final String label;
  final String description;

  const RolePermission(this.key, this.label, this.description);

  static RolePermission? fromKey(String key) {
    for (final p in RolePermission.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// خريطة صلاحيات كل دور أساسي، مخزَّنة في `settings/rolePermissions`.
///
/// مسؤول النظام غير مُمثَّل هنا إطلاقاً: صلاحياته كاملة دائماً وغير قابلة
/// للتعديل، والقواعد تمنحها له عبر `isAdmin()` لا عبر هذه الخريطة.
class RolePermissionsConfig {
  /// اسم الدور (`UserRole.name`) ← مجموعة مفاتيح الصلاحيات الممنوحة له.
  final Map<String, Set<String>> byRole;

  const RolePermissionsConfig(this.byRole);

  /// الإعداد المبدئي المعقول قبل أن يخصّصه مسؤول النظام — يطابق سلوك المنصة
  /// قبل إضافة هذه الشاشة، حتى لا يتغيّر شيء على المستخدمين الحاليين فجأة.
  factory RolePermissionsConfig.defaults() => const RolePermissionsConfig({
        'executiveViewer': {'vad', 'mr', 'agd'},
        'departmentManager': {'mw'},
        'projectOfficer': <String>{},
        'employee': <String>{},
      });

  bool has(UserRole role, RolePermission permission) =>
      byRole[role.name]?.contains(permission.key) ?? false;

  RolePermissionsConfig toggled(UserRole role, RolePermission permission, bool value) {
    final next = {for (final e in byRole.entries) e.key: Set<String>.of(e.value)};
    final set = next.putIfAbsent(role.name, () => <String>{});
    if (value) {
      set.add(permission.key);
    } else {
      set.remove(permission.key);
    }
    return RolePermissionsConfig(next);
  }

  Map<String, dynamic> toMap() => {
        for (final e in byRole.entries) e.key: e.value.toList()..sort(),
      };

  factory RolePermissionsConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return RolePermissionsConfig.defaults();
    final parsed = <String, Set<String>>{};
    for (final role in UserRole.configurable) {
      final raw = map[role.name];
      parsed[role.name] = raw is List ? raw.map((e) => e.toString()).toSet() : <String>{};
    }
    return RolePermissionsConfig(parsed);
  }
}
