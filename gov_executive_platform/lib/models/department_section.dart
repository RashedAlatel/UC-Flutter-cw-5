import 'package:cloud_firestore/cloud_firestore.dart';

/// قسم داخل إدارة، يمكن أن يحوي أقساماً فرعية بدوره.
///
/// الشجرة: **الإدارة ← قسم ← قسم فرعي**. [parentId] فارغ يعني قسماً مباشراً
/// تحت الإدارة، وغير فارغ يعني قسماً فرعياً تحت قسم آخر. التمثيل بـ
/// [parentId] (لا بحقل "مستوى" ثابت) يجعل التعميق لاحقاً تغييراً في قيمة
/// [maxDepth] وحدها لا إعادة تصميم.
///
/// المشروع يُسنَد إلى قسم عبر `Project.sectionId`، وقد يبقى بلا قسم فيظهر
/// مباشرةً تحت الإدارة — فلا يفرض هذا التنظيم نفسه على الإدارات التي لا
/// تحتاجه.
class DepartmentSection {
  final String id;

  /// الإدارة الجذر — محفوظة في كل قسم (حتى الفرعي) ليمكن جلب شجرة إدارة
  /// كاملة باستعلام واحد وفلترة صلاحيات القراءة بالإدارة مباشرةً.
  final String departmentId;

  /// القسم الأب، أو null لقسم مباشر تحت الإدارة.
  final String? parentId;

  final String name;

  /// ترتيب العرض بين الإخوة.
  final int order;

  const DepartmentSection({
    required this.id,
    required this.departmentId,
    required this.name,
    this.parentId,
    this.order = 0,
  });

  /// أقصى عمق مسموح تحت الإدارة: قسم ثم قسم فرعي.
  static const int maxDepth = 2;

  /// مستوى القسم: ١ لقسم مباشر تحت الإدارة، ٢ لقسم فرعي.
  int levelIn(List<DepartmentSection> all) {
    var level = 1;
    var current = parentId;
    final seen = <String>{id};
    while (current != null) {
      // حارس ضد حلقة في البيانات (قسم صار أباً لنفسه بخطأ ما): بدونه يدور
      // هذا الحساب إلى ما لا نهاية ويُجمّد الواجهة.
      if (!seen.add(current)) break;
      final parent = all.where((s) => s.id == current);
      if (parent.isEmpty) break;
      level++;
      current = parent.first.parentId;
    }
    return level;
  }

  DepartmentSection copyWith({String? name, String? parentId, int? order}) => DepartmentSection(
        id: id,
        departmentId: departmentId,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
        'departmentId': departmentId,
        'parentId': parentId,
        'name': name,
        'order': order,
      };

  factory DepartmentSection.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    final parent = json['parentId'] as String?;
    return DepartmentSection(
      id: doc.id,
      departmentId: json['departmentId'] as String? ?? '',
      parentId: (parent == null || parent.isEmpty) ? null : parent,
      name: json['name'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
