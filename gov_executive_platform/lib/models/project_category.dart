import 'dart:ui' show Color;

/// تصنيف يضعه مسؤول النظام ويَسِم به المشاريع.
///
/// ليس قسماً ولا إدارة: القسم موقعٌ في الهيكل التنظيمي، والتصنيف **عرضي**
/// يقطع الهيكل — «مبادرة رؤية ٢٠٣٥» قد تشمل مشاريع من ثلاث إدارات. ولذلك
/// يحمل المشروع أكثر من تصنيف، بخلاف القسم الواحد.
///
/// والقائمة تُحفظ في `settings/projectCategories`، وقاعدة `settings/{id}`
/// تقصر الكتابة على مسؤول النظام أصلاً — فلا يخترع كلُّ مستخدم تصنيفاته
/// فتصير التصفية بلا معنى.
class ProjectCategory {
  final String id;
  final String name;
  final int colorValue;

  const ProjectCategory({required this.id, required this.name, required this.colorValue});

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'colorValue': colorValue};

  /// يعيد null لمدخل ناقص بدل تصنيف بلا اسم أو بلا معرّف: تصنيفٌ اسمه فارغ
  /// يظهر في القوائم كخيار لا يُقرأ ولا يُختار، وحذفه أصدق من عرضه.
  static ProjectCategory? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as String?)?.trim() ?? '';
    final name = (raw['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) return null;
    return ProjectCategory(
      id: id,
      name: name,
      colorValue: (raw['colorValue'] as num?)?.toInt() ?? 0xFF1B5E4A,
    );
  }

  ProjectCategory copyWith({String? name, int? colorValue}) => ProjectCategory(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );
}
