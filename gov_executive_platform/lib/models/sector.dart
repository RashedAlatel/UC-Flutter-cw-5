/// قطاعٌ يضمّ إداراتٍ — **تجميعٌ للقراءة لا للصلاحية**.
///
/// ــــ ولماذا حقلٌ موازٍ لا طبقةٌ في الهرم ــــ
///
/// `departmentId` هو **مفتاحُ النطاق في كلّ قاعدةٍ وكلّ بطاقةِ دخول** في
/// هذه المنصة: من يقرأ مشروعاً، ومن يعدّل عملاً، ومن يرى حالةَ موظّف — كلُّه
/// يُحسم به. وإدخالُ طبقةٍ فوقه كان يعني إعادةَ كتابة التخويل كلِّه، وأخطرُ
/// ما يقع في منصّةٍ حيّةٍ أن يتبدّل من يرى ماذا بتعديلٍ في الهيكل.
///
/// فالقطاعُ **حقلٌ اختياريٌّ على الإدارة**: يجمعها في اللوحة التنفيذية
/// والتقارير، ولا يدخل قاعدةَ أمانٍ واحدة. وإدارةٌ بلا قطاعٍ تبقى تعمل كما
/// كانت حرفاً بحرف — وهو شرطُ ألّا يُكسر شيءٌ قائم.
///
/// ــــ وما يمكّنه ــــ
///
/// قطاعُ تقنية المعلومات بإداراته الثلاث — نظم المعلومات، والدعم الفنّي،
/// والتشغيل — يصير كياناً واحداً تُقرأ مؤشّراتُه معاً. ويبقى لكلّ إدارةٍ
/// نطاقُها ومديرُها كما هما.
library;

import 'safe_read.dart';

class Sector {
  final String id;
  final String name;

  /// وصفٌ قصيرٌ يظهر تحت الاسم في اللوحة.
  final String description;

  /// مديرُ القطاع — يُعرض، **ولا يمنح صلاحيةً بذاته**.
  ///
  /// ومن أراد أن يرى مديرُ القطاع إداراتِه الثلاث فالطريقُ القائم: تُسنَد
  /// إليه الإداراتُ الثلاث في حسابه، أو يُمنح «عرض كل الإدارات». فالقطاعُ
  /// لا يفتح باباً لم يفتحه مسؤولُ النظام صراحةً.
  final String headUid;
  final String headName;

  final int order;

  const Sector({
    required this.id,
    required this.name,
    this.description = '',
    this.headUid = '',
    this.headName = '',
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'headUid': headUid,
        'headName': headName,
        'order': order,
      };

  static Sector? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = readText(map['id']);
    final name = readText(map['name']);
    if (id.isEmpty || name.isEmpty) return null;
    return Sector(
      id: id,
      name: name,
      description: readText(map['description']),
      headUid: readText(map['headUid']),
      headName: readText(map['headName']),
      order: (readNum(map['order']) ?? 0).toInt(),
    );
  }

  Sector copyWith({String? name, String? description, String? headUid, String? headName, int? order}) =>
      Sector(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        headUid: headUid ?? this.headUid,
        headName: headName ?? this.headName,
        order: order ?? this.order,
      );

  /// قطاعُ تقنية المعلومات بإداراته الثلاث — **بذرةٌ تُحرَّر لا حدٌّ**.
  ///
  /// وتُعرض حين لا يكون المستندُ مكتوباً بعد، فلا تفتح الوزارةُ الشاشةَ على
  /// قائمةٍ خالية. ويبقى لمسؤول النظام أن يضيف قطاعاتٍ أخرى ويعيد التسمية.
  static List<Sector> seed() => const [
        Sector(
          id: 'it',
          name: 'قطاع تقنية المعلومات',
          description: 'نظم المعلومات · الدعم الفنّي · التشغيل',
          order: 0,
        ),
      ];
}
