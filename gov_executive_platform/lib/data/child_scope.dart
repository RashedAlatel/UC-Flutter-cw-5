/// نطاقُ قراءة المستندات التابعة للمشروع — مهامَّ وتحديثاتٍ ومخاطرَ وعوائق.
///
/// ــــ العطل الذي أوجد هذه الوحدة، ثم العطل الذي بقي بعدها ــــ
///
/// كان القرار سطراً داخل دالّة الاشتراك يُصفّي لصاحب دور **«مدير مشروع»**
/// بالحقل المفرد الموروث `managerUid`. فأُخرج إلى هنا وصُحّح إلى القائمة.
///
/// ثم تبيّن أن التصحيح **لا يمسّ أحداً**: دور «مدير مشروع» موروثٌ لا يُمنح
/// لأحد — `GRANTABLE_ROLES` في الخادم ثلاثةٌ ليس هو منها — منذ أن فُصلت
/// قيادةُ المشروع عن الدور الأساسي. فمديرو المشاريع أدوارُهم «موظف» أو
/// «مدير إدارة»، ويُصفّى لهم **بالإدارة وحدها**.
///
/// ومستندُ المشروع نفسه يُقرأ بثلاثة تدفّقات: الإدارة، وعضويتي مديراً،
/// وعضويتي منفّذاً. أما توابعه فبالإدارة وحدها. فمن كان عضواً في مشروعٍ
/// خارج إدارته — أو لم تُختم إدارتُه في بطاقة دخوله بعد — لا يصله تحديثٌ
/// واحد على مشروعه. والقاعدةُ على الخادم تعرف العضوية (`isProjectMember`)
/// بينما الاستعلام لا يسأل عنها.
///
/// فصارت **العضوية بُعداً للقراءة** كما هي في المشاريع، ولم يُستبدل نطاق
/// الإدارة بل أُضيف إليه.
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
/// وما يحتاج شروطاً يُقرأ بتدفّقاتٍ ثم تُدمَج بلا تكرار (`mergeById`).
/// وقائمةٌ فارغة تعني «المجموعة كاملةً بلا تصفية» — ولا تُرجَع إلا لمن يرى
/// كل الإدارات فعلاً.
///
/// ــ [viewsAll] معاملٌ صريح، ولا يُستنتج من غياب الإدارة ــ
///
/// كان «بلا إدارة» و«يرى كل الإدارات» يؤدّيان إلى الشيء نفسه: تصفيةٌ فارغة
/// أي المجموعة كاملة. فمن لم تُختم إدارتُه في بطاقته بعدُ كان يطلب المجموعة
/// كلَّها فتُردّ عليه بالكامل — فيرى منصةً خالية بلا سبب ظاهر، وهو **حالٌ
/// يقع فعلاً** لأن ختم البطاقة لا يتزامن مع تعديل السجل.
List<ChildFilter> childScopeFilters({
  required bool manager,
  bool viewsAll = false,
  String? uid,
  List<String> departmentIds = const [],
  String? scopedDept,
}) {
  if (viewsAll) return const [];

  final me = (uid ?? '').trim();
  final streams = <ChildFilter>[];

  // ــ العضوية أوّلاً: هي الصلة الحقيقية بالمشروع ــ
  //
  // والقاعدة تقبل الثلاثة أصلاً: `isProjectMember` تقرأ القائمتين على
  // المستند، و`canAccessProjectDoc` تقرأ المفرد الموروث.
  if (me.isNotEmpty) {
    streams.add(ChildFilter.arrayContains('managerUids', me));
    streams.add(ChildFilter.arrayContains('executorUids', me));
    // المفرد الموروث للمستندات التي كُتبت قبل أن تُنسخ القائمة عليها.
    streams.add(ChildFilter.equals('managerUid', me));
  }

  // ــ ثم نطاق الإدارة، مُضافاً لا بديلاً ــ
  if (manager) {
    if (departmentIds.isNotEmpty) {
      // Firestore يحدّ `whereIn` بثلاثين قيمة، فتُقتطع.
      streams.add(ChildFilter.whereIn(
        'departmentId',
        departmentIds.length > 30 ? departmentIds.sublist(0, 30) : departmentIds,
      ));
    }
  } else if (scopedDept != null && scopedDept.isNotEmpty) {
    streams.add(ChildFilter.equals('departmentId', scopedDept));
  }

  // لا عضويةَ ولا إدارة: لا يُقرأ شيء — ولا تُفتح المجموعة كاملةً.
  if (streams.isEmpty) {
    return const [ChildFilter.equals('departmentId', noDepartmentSentinel)];
  }
  return streams;
}
