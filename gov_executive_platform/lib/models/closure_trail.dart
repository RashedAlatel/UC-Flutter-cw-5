import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

/// سجلّ إغلاق بندٍ من بنود العمل — عملاً كان أو مهمةَ مشروع.
///
/// ــــ لماذا صنفٌ واحد يُخزَّن تحت مفتاح `closure`؟ ــــ
///
/// لأن الكيانين يحتاجان الحقول نفسها بالضبط (من يعتمد، من أعلن الإتمام ومتى،
/// من اعتمد ومتى، وكم مرةً أُعيد). ونسخُها في نموذجين يعني نسخَ `toMap`
/// و`fromMap` والشريط الزمني والاختبارات مرتين — وأول تعديلٍ يُنسى في أحدهما
/// يجعل مهمةَ المشروع تكذب على قارئها بينما العمل صادق.
///
/// **والغياب ليس خطأً**: مستندٌ بلا `closure` يُقرأ بسجلٍّ فارغ، فكل أعمال
/// الوزارة المكتوبة قبل اليوم تعمل بعد النشر كما هي حرفاً — بلا اعتماد
/// مفروض عليها ولا شاشة تتعطّل.
class ClosureTrail {
  /// من يعتمد الإغلاق. **فارغٌ يعني إغلاقاً مباشراً** كما كانت المنصة.
  final String approverUid;
  final String approverName;

  /// من أعلن الإتمام ومتى.
  final String claimedByUid;
  final String claimedByName;
  final DateTime? claimedAt;

  /// من اعتمد الإغلاق ومتى — و[approvedAt] هو تاريخ الإغلاق الفعلي.
  final String approvedByUid;
  final String approvedByName;
  final DateTime? approvedAt;

  /// كم مرةً أُعيد البند إلى التنفيذ بعد إعلان إتمامه.
  ///
  /// عددٌ لا علَم: بندٌ رُدَّ ثلاث مرات ليس كبندٍ رُدَّ مرة، والفرق بينهما
  /// هو ما تبحث عنه القيادة حين تسأل «أين يضيع الوقت؟».
  final int reworkCount;
  final String reworkReason;
  final String reworkByName;
  final DateTime? reworkAt;

  /// ردُّ المُسنَد إليه البندَ **لعدم الاختصاص** — من ردَّه ولماذا ومتى.
  ///
  /// ــــ ولماذا يُحفظ ولا يُمحى الإسناد وكفى؟ ــــ
  ///
  /// لأن البند يعود إلى مدير الإدارة بلا مُسنَدٍ إليه، فلو لم يُحفظ السبب
  /// لَوجده «غير مُسنَد» بلا أن يعرف أنه عُرض على أحدٍ وردَّه — فيُسنده إليه
  /// من جديد. والسببُ هو ما يمنع الدورة أن تُعاد.
  ///
  /// ويُمحى عند الإسناد التالي: بندٌ يحمل «ردَّه فلان» وهو مُسنَدٌ لغيره
  /// ويعمل عليه يكذب على قارئه.
  final String declinedByUid;
  final String declinedByName;
  final String declinedReason;
  final DateTime? declinedAt;

  const ClosureTrail({
    this.approverUid = '',
    this.approverName = '',
    this.claimedByUid = '',
    this.claimedByName = '',
    this.claimedAt,
    this.approvedByUid = '',
    this.approvedByName = '',
    this.approvedAt,
    this.reworkCount = 0,
    this.reworkReason = '',
    this.reworkByName = '',
    this.reworkAt,
    this.declinedByUid = '',
    this.declinedByName = '',
    this.declinedReason = '',
    this.declinedAt,
  });

  static const ClosureTrail none = ClosureTrail();

  /// هل يمرّ هذا البند بمرحلة اعتماد أصلاً؟
  bool get requiresApproval => approverUid.isNotEmpty;

  /// هل يستطيع [uid] اعتماد الإغلاق أو ردَّه؟
  ///
  /// ومسؤول النظام يُفحص عند المستدعي لا هنا: هذا الصنف يصف **المستند** ولا
  /// يعرف أدوار المنصة.
  bool isApprover(String? uid) => uid != null && uid.isNotEmpty && uid == approverUid;

  /// هل رُدَّ هذا البند لعدم الاختصاص وينتظر إسناداً جديداً؟
  bool get isDeclined => declinedAt != null;

  ClosureTrail copyWith({
    String? approverUid,
    String? approverName,
    String? claimedByUid,
    String? claimedByName,
    DateTime? claimedAt,
    String? approvedByUid,
    String? approvedByName,
    DateTime? approvedAt,
    int? reworkCount,
    String? reworkReason,
    String? reworkByName,
    DateTime? reworkAt,
    String? declinedByUid,
    String? declinedByName,
    String? declinedReason,
    DateTime? declinedAt,
    bool clearApproval = false,
    bool clearDecline = false,
  }) =>
      ClosureTrail(
        approverUid: approverUid ?? this.approverUid,
        approverName: approverName ?? this.approverName,
        claimedByUid: claimedByUid ?? this.claimedByUid,
        claimedByName: claimedByName ?? this.claimedByName,
        claimedAt: claimedAt ?? this.claimedAt,
        // الردّ إلى التنفيذ يمسح الاعتماد: بندٌ يحمل «اعتمده فلان» وهو قيد
        // التنفيذ من جديد يكذب على قارئه.
        approvedByUid: clearApproval ? '' : (approvedByUid ?? this.approvedByUid),
        approvedByName: clearApproval ? '' : (approvedByName ?? this.approvedByName),
        approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
        reworkCount: reworkCount ?? this.reworkCount,
        reworkReason: reworkReason ?? this.reworkReason,
        reworkByName: reworkByName ?? this.reworkByName,
        reworkAt: reworkAt ?? this.reworkAt,
        // الإسناد الجديد يمسح الردّ: راجع [declinedReason].
        declinedByUid: clearDecline ? '' : (declinedByUid ?? this.declinedByUid),
        declinedByName: clearDecline ? '' : (declinedByName ?? this.declinedByName),
        declinedReason: clearDecline ? '' : (declinedReason ?? this.declinedReason),
        declinedAt: clearDecline ? null : (declinedAt ?? this.declinedAt),
      );

  /// خريطة تُكتب تحت مفتاح `closure`.
  ///
  /// والسجل الفارغ يُكتب خريطةً فارغة لا مفاتيحَ فارغة: مستندٌ يحمل عشرة
  /// حقول خاوية يُوهم قارئ قاعدة البيانات بدورةٍ لم تقع.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (approverUid.isNotEmpty) {
      map['approverUid'] = approverUid;
      map['approverName'] = approverName;
    }
    if (claimedAt != null) {
      map['claimedByUid'] = claimedByUid;
      map['claimedByName'] = claimedByName;
      map['claimedAt'] = Timestamp.fromDate(claimedAt!);
    }
    if (approvedAt != null) {
      map['approvedByUid'] = approvedByUid;
      map['approvedByName'] = approvedByName;
      map['approvedAt'] = Timestamp.fromDate(approvedAt!);
    }
    if (reworkCount > 0) {
      map['reworkCount'] = reworkCount;
      map['reworkReason'] = reworkReason;
      map['reworkByName'] = reworkByName;
      if (reworkAt != null) map['reworkAt'] = Timestamp.fromDate(reworkAt!);
    }
    if (declinedAt != null) {
      map['declinedByUid'] = declinedByUid;
      map['declinedByName'] = declinedByName;
      map['declinedReason'] = declinedReason;
      map['declinedAt'] = Timestamp.fromDate(declinedAt!);
    }
    return map;
  }

  factory ClosureTrail.fromMap(Object? raw) {
    if (raw is! Map) return none;
    DateTime? at(String key) => (raw[key] as Timestamp?)?.toDate();
    String str(String key) => raw[key] as String? ?? '';
    return ClosureTrail(
      approverUid: str('approverUid'),
      approverName: str('approverName'),
      claimedByUid: str('claimedByUid'),
      claimedByName: str('claimedByName'),
      claimedAt: at('claimedAt'),
      approvedByUid: str('approvedByUid'),
      approvedByName: str('approvedByName'),
      approvedAt: at('approvedAt'),
      reworkCount: (raw['reworkCount'] as num?)?.toInt() ?? 0,
      reworkReason: str('reworkReason'),
      reworkByName: str('reworkByName'),
      reworkAt: at('reworkAt'),
      declinedByUid: str('declinedByUid'),
      declinedByName: str('declinedByName'),
      declinedReason: str('declinedReason'),
      declinedAt: at('declinedAt'),
    );
  }
}

/// من يعتمد إغلاق بندٍ يُنشَأ الآن — أو `null` إن كان إغلاقه مباشراً.
///
/// ــــ القاعدة، وحدودها ــــ
///
/// الاعتماد يُفرض حين **يختلف الطالب عن الإدارة المنفّذة**: تلك هي الحالة
/// التي وصفها مسؤول النظام، وفيها وحدها يكون «الطالب» و«المنفّذ» شخصين
/// مختلفين فعلاً.
///
/// ولا يُفرض على العمل الداخلي: مدير الإدارة يُنشئ لموظفيه أعمالاً كل يوم،
/// وفرضُ مرحلةٍ ثانية عليها يعني أن يعتمد هو ما أعلنه هو — خطوةٌ لا تضيف
/// حوكمةً وتُثقل عشرات البنود يومياً.
///
/// و[creator] بلا إدارة (مسؤول النظام والمستخدم التنفيذي) يُعدّ **من خارج
/// الإدارة المنفّذة**: هو أبعد ما يكون عن تنفيذها، وطلبُه يُعتمد منه.
String? defaultApproverUid({
  required AppUser? creator,
  required String executingDepartmentId,
}) {
  if (creator == null) return null;
  if (executingDepartmentId.isEmpty) return null;
  final own = creator.departmentId ?? '';
  final managed = creator.departmentIds;
  final inside = own == executingDepartmentId || managed.contains(executingDepartmentId);
  return inside ? null : creator.id;
}
