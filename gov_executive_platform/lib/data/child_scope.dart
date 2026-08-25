/// نطاقُ قراءة المستندات التابعة للمشروع — مهامَّ وتحديثاتٍ ومخاطرَ وعوائق.
///
/// ــــ لماذا وحدةٌ قائمة بذاتها؟ ــــ
///
/// لأن هذا النطاق كان يُبنى داخل `_subscribeAppData` سطراً واحداً لا يُقرأ
/// ولا يُختبَر، وكان **خاطئاً**: يُصفّي لمدير المشروع بالحقل المفرد الموروث
/// `managerUid` — أي أوّلِ المديرين وحده. فمن كان المديرَ الثاني فصاعداً لا
/// يصله تحديثٌ واحد على مشروعه، ولو كان هو كاتبَه بيده.
///
/// وهو نظيرُ العطل الذي عولج في دمج الحسابات بالضبط: حقلٌ مفردٌ موروث
/// يُقرأ في موضعٍ تُقرأ فيه القائمة. فأُخرج القرار إلى هنا ليصير **قيمةً
/// تُقاس** لا سطراً في دالّةٍ لا تعمل إلا بـFirestore حيّ.
library;

import 'package:flutter/foundation.dart';

/// عاملُ المقارنة في تصفية Firestore.
enum ChildFilterOp {
  /// `where(field, isEqualTo: value)` — القيمة نصٌّ واحد.
  equals,

  /// `where(field, arrayContains: value)` — الحقل قائمة، والقيمة نصٌّ واحد.
  arrayContains,

  /// `where(field, whereIn: value)` — القيمة قائمةُ نصوص.
  whereIn,
}

/// وصفُ **تدفّقٍ واحد**: حقلٌ وعاملٌ وقيمة.
@immutable
class ChildFilter {
  final String field;
  final ChildFilterOp op;

  /// نصٌّ لـ[ChildFilterOp.equals] و[ChildFilterOp.arrayContains]، وقائمةُ
  /// نصوص لـ[ChildFilterOp.whereIn].
  final Object value;

  const ChildFilter(this.field, this.op, this.value);

  const ChildFilter.equals(this.field, String this.value) : op = ChildFilterOp.equals;
  const ChildFilter.arrayContains(this.field, String this.value)
      : op = ChildFilterOp.arrayContains;
  const ChildFilter.whereIn(this.field, List<String> this.value) : op = ChildFilterOp.whereIn;

  @override
  bool operator ==(Object other) =>
      other is ChildFilter &&
      other.field == field &&
      other.op == op &&
      _sameValue(other.value, value);

  static bool _sameValue(Object a, Object b) {
    if (a is List && b is List) return listEquals(a, b);
    return a == b;
  }

  @override
  int get hashCode => Object.hash(field, op, value is List ? Object.hashAll(value as List) : value);

  @override
  String toString() => 'ChildFilter($field ${op.name} $value)';
}

/// معرِّفُ إدارةٍ لا وجود له — يُطلب به لا شيء عن قصد.
///
/// وهو أسلم من إسقاط التصفية: مجموعةٌ بلا تصفية تُطلب كاملةً، فتردّها
/// القواعد كلَّها (القواعد **ترفض ولا تُصفّي**) فتظهر الشاشة فارغة بلافتة
/// حمراء بدل أن تظهر فارغة لأنه لا شيء فيها فعلاً.
const String noDepartmentSentinel = '__none__';

/// التدفّقات التي تُقرأ بها مجموعةٌ تابعة للمشروع لهذا المستخدم.
///
/// **قائمةٌ لا تصفيةٌ واحدة**: Firestore لا يجمع شرطين مختلفين في استعلام،
/// وما يحتاج شرطين يُقرأ بتدفّقين ثم يُدمَجان بلا تكرار (`mergeById`).
/// وقائمةٌ فارغة تعني «المجموعة كاملةً بلا تصفية».
///
/// ولمدير المشروع تدفّقان:
///
///   • `managerUids` بـ`arrayContains` — وهو **الصحيح**: كلُّ مديري المشروع
///     منسوخون على المستند التابع يوم أُنشئ.
///   • `managerUid` المفرد بـ`isEqualTo` — وهو **للمستندات القديمة وحدها**:
///     ما كُتب قبل أن تُنسخ القائمة لا يحمل إلا المفرد، فإسقاطُ هذا التدفّق
///     يُخفي تاريخ المشروع كلَّه عن أوّل مديريه. فهو تدفّقٌ للتوافق لا غير،
///     ولا يُبنى عليه شيء جديد.
List<ChildFilter> childScopeFilters({
  required bool officer,
  required bool manager,
  String? uid,
  List<String> departmentIds = const [],
  String? scopedDept,
}) {
  if (officer) {
    // بلا معرِّف حساب لا يُقرأ شيء — ولا تُفتح المجموعة كاملةً.
    if (uid == null || uid.isEmpty) {
      return const [ChildFilter.equals('departmentId', noDepartmentSentinel)];
    }
    return [
      ChildFilter.arrayContains('managerUids', uid),
      ChildFilter.equals('managerUid', uid),
    ];
  }

  if (manager) {
    if (departmentIds.isEmpty) {
      return const [ChildFilter.equals('departmentId', noDepartmentSentinel)];
    }
    // Firestore يحدّ `whereIn` بثلاثين قيمة، فتُقتطع.
    return [
      ChildFilter.whereIn(
        'departmentId',
        departmentIds.length > 30 ? departmentIds.sublist(0, 30) : departmentIds,
      ),
    ];
  }

  if (scopedDept == null) return const [];
  return [ChildFilter.equals('departmentId', scopedDept)];
}
