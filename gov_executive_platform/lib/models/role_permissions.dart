import 'enums.dart';

/// صلاحية واحدة يفوّضها مسؤول النظام.
///
/// **الحدّ الثابت وما تغيّر منه، بصراحة:**
///
/// بقيت بوابات الاعتماد الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي)
/// محصورة بمسؤول النظام وحده طوال بناء المنصة. ثم قرّر مسؤول النظام صراحةً
/// فتح **إضافة المشاريع** وحدها عبر مفتاح بيده: `manageProjects` للإنشاء
/// المباشر و`approveProjectRequests` للاعتماد — كلتاهما **مغلقة افتراضياً،
/// تُمنح لفرد بعينه لا لدور، مقيَّدة بنطاق إدارات، وقابلة للسحب**، ومفروضة
/// في قواعد Firestore وفي Cloud Functions معاً لا في الواجهة.
///
/// أما **تسجيل الأعضاء** و**تعديل المواعيد النهائية** فتبقيان حصراً لمسؤول
/// النظام، ولا مفتاح لهما في هذه القائمة ولن يكون.
enum RolePermission {
  viewAllDepartments('vad', 'عرض كل الإدارات', 'الاطلاع على مشاريع كل الإدارات لا إدارته فقط'),
  manageReports('mr', 'إدارة التقارير', 'توليد التقارير وتحرير التعليقات التنفيذية عليها'),
  manageDashboard('md', 'تخصيص لوحة القيادة', 'إضافة وحذف وترتيب ودجات لوحة القيادة'),
  approveGeneralDecisions('agd', 'اعتماد القرارات العامة', 'اعتماد أو رفض القرارات التنفيذية العامة'),
  manageWorks('mw', 'إدارة الأعمال', 'إضافة وتعديل الأعمال التشغيلية وإسنادها للموظفين'),
  deleteRecords('del', 'حذف السجلات', 'حذف المشاريع والأعمال نهائياً'),
  sendNotifications('ntf', 'إرسال الإشعارات', 'مراسلة المستخدمين بالبريد وواتساب ضمن نطاقه'),
  selfAssignProjects('sap', 'الانضمام لمشاريع الإدارة',
      'الاطلاع على كل مشاريع إدارته وتسجيل نفسه على أي منها منفّذاً أو مديراً'),
  manageProjects('mpr', 'إنشاء المشاريع والأعمال',
      'إنشاء مشروع أو عمل مباشرةً بلا طلب، وإسناد مستخدمين إليه — ضمن نطاق محدَّد'),
  approveProjectRequests('apr', 'اعتماد طلبات إضافة المشاريع',
      'البتّ في طلبات إضافة المشاريع — ضمن نطاق محدَّد'),
  submitFeedback('sfb', 'رفع الشكاوى والاقتراحات',
      'رفع شكوى أو اقتراح إلى مسؤول النظام ومتابعة ما رفعه هو'),
  manageFeedback('mfb', 'متابعة الشكاوى والاقتراحات',
      'الاطلاع على كل ما يرده الموظفون من شكاوى واقتراحات والبتّ فيها');

  /// مفتاح مختصر — يُخزَّن في Custom Claims التي لها حدّ حجم صارم.
  final String key;
  final String label;
  final String description;

  const RolePermission(this.key, this.label, this.description);

  /// حقوق أساسية لكل حساب معتمد: لا تُمنح لدور ولا تظهر في شبكة
  /// «صلاحيات الأدوار»، ولا تُسحب إلا من فرد بعينه عبر استثناءات المستخدم.
  static const Set<RolePermission> baseline = {RolePermission.submitFeedback};

  /// ما يضبطه مسؤول النظام لكل دور — أي ما ليس حقاً أساسياً ولا مقيَّداً
  /// بنطاق. والمقيَّدة بنطاق خارج الشبكة عمداً: مفتاحٌ بلا نطاق يوهم بمنحٍ
  /// شامل، وهو أخطر ما يمكن أن يقع في صلاحية تفتح بوابة.
  static List<RolePermission> get roleAssignable => RolePermission.values
      .where((p) => !baseline.contains(p) && !scoped.contains(p))
      .toList();

  /// صلاحيتان **لا تُمنحان لدور** ولا تظهران في شبكة «صلاحيات الأدوار»:
  /// تُمنحان لفرد بعينه ومعهما **نطاق** الإدارات التي تسري فيه.
  ///
  /// و`apr` منهما تفتح بوابةً كانت محصورة بمسؤول النظام وحده (اعتماد إضافة
  /// المشاريع) — بقرار صريح منه. ولذلك هي مغلقة افتراضياً، ولا يمنحها إلا
  /// هو، ولفردٍ لا لدور، وقابلة للسحب. أما **تسجيل الأعضاء** و**تعديل
  /// المواعيد النهائية** فتبقيان محصورتين به وحده ولا مفتاح لهما هنا.
  static const Set<RolePermission> scoped = {
    RolePermission.manageProjects,
    RolePermission.approveProjectRequests,
  };

  static RolePermission? fromKey(String key) {
    for (final p in RolePermission.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// نطاق الإدارات الذي تسري فيه صلاحية ممنوحة لفرد.
///
/// «كل الإدارات» ليس قائمةً بكل المعرّفات: الإدارات تُضاف وتُحذف، وقائمةٌ
/// مجمَّدة وقت المنح كانت ستتخلّف عن الواقع صامتةً. فهو علَمٌ صريح.
class GrantScope {
  /// يسري على كل الإدارات، الموجودة منها والتي ستُضاف.
  final bool allDepartments;

  /// إدارات بعينها — تُهمَل حين تكون [allDepartments].
  final List<String> departmentIds;

  const GrantScope({this.allDepartments = false, this.departmentIds = const []});

  static const GrantScope none = GrantScope();
  static const GrantScope all = GrantScope(allDepartments: true);

  /// نطاق فارغ = لا منح. وهذا هو الفرق بين «ممنوحة بلا نطاق» و«ممنوحة»:
  /// الأولى **لا تسري على شيء**، ولا تُفهم أبداً على أنها الكل.
  bool get isEmpty => !allDepartments && departmentIds.isEmpty;

  bool covers(String? departmentId) {
    if (departmentId == null || departmentId.isEmpty) return false;
    return allDepartments || departmentIds.contains(departmentId);
  }

  /// الصورة المكتوبة في بطاقة الدخول: `'*'` أو قائمة معرّفات.
  Object toClaim() => allDepartments ? '*' : departmentIds;

  Map<String, dynamic> toMap() => allDepartments
      ? {'all': true}
      : {'all': false, 'departmentIds': departmentIds};

  factory GrantScope.fromMap(Object? raw) {
    if (raw is! Map) return none;
    if (raw['all'] == true) return all;
    final ids = raw['departmentIds'];
    return GrantScope(
      departmentIds: ids is List ? ids.map((e) => e.toString()).toList() : const [],
    );
  }

  /// يقرأ ما في البطاقة (`'*'` أو قائمة) — تُستعمل لمقارنة البطاقة بالسجل.
  factory GrantScope.fromClaim(Object? raw) {
    if (raw == '*') return all;
    if (raw is List) return GrantScope(departmentIds: raw.map((e) => e.toString()).toList());
    return none;
  }

  @override
  bool operator ==(Object other) =>
      other is GrantScope &&
      other.allDepartments == allDepartments &&
      other.departmentIds.toSet().length == departmentIds.toSet().length &&
      other.departmentIds.toSet().containsAll(departmentIds);

  @override
  int get hashCode => Object.hash(allDepartments, departmentIds.toSet().length);
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
