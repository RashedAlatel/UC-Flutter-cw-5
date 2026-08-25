import 'package:cloud_firestore/cloud_firestore.dart';

import 'change_type.dart';

/// سطرٌ في سجل التدقيق: من فعل، وماذا، وعلى أيّ شيء، ومتى — وما تغيّر.
///
/// ــــ الحقول السبعة الجديدة كلُّها اختيارية بقصد ــــ
///
/// في السجل آلافُ السطور مكتوبةٌ قبل هذا التوسيع، وفيها خمسةٌ وخمسون
/// موضعاً في الشيفرة يكتب سطراً بحقلين نصّيين. فلو صارت الحقول مطلوبةً
/// لَانكسر القديم ولَوجب تعديل كل موضعٍ دفعةً واحدة.
///
/// فالسطر القديم يُقرأ كما هو ويُعرض تحت «أخرى»، والجديد يحمل ما يستحقّه.
class AuditLogEntry {
  final String id;
  final String userName;
  final String action;
  final String details;

  /// وقتُ السطر — **يُقرأ ولا يُكتب**.
  ///
  /// قاعدةُ `auditLog` تشترط `request.resource.data.timestamp ==
  /// request.time`، أي وقتَ **الخادم**. فلا سبيل إلى كتابة قيمةٍ من هنا
  /// تُطابقه: ساعةُ الجهاز لا تساوي ساعةَ الخادم ولو ضُبطت إلى
  /// الميلي‑ثانية. ولذلك تكتب [toMap] ختمَ الخادم لا هذا الحقل.
  ///
  /// وهذا الحقل هو ما تقرؤه [AuditLogEntry.fromDoc] من المستند بعد كتابته،
  /// وما تعرضه الشاشة. ومن أعاده يوماً إلى `Timestamp.fromDate` أعاد العطل:
  /// رُدّ **كلُّ** سطرٍ يكتبه المتصفّح — لا سطرٌ بعينه — فوقعت الأفعال بلا
  /// أثر. ويحرسه `tool/test/approval_gates_test.sh`.
  final DateTime timestamp;

  /// نوع التغيير — وبه تقع التصفية في الشاشة.
  final ChangeType type;

  /// معرّف الفاعل — لا اسمُه وحده.
  ///
  /// الأسماء تتكرّر في وزارةٍ فيها مئتا موظف، وتتغيّر حين يُصحَّح اسم. فمن
  /// أراد «كلُّ ما فعله هذا الشخص» لا يجد إلا مطابقةَ نصٍّ لا يُوثق بها.
  /// وهو كذلك ما تشترط القاعدةُ مطابقتَه لهوية الكاتب، فلا يُكتب سطرٌ
  /// باسم غيره.
  final String? actorUid;

  /// ما وقع عليه التغيير: نوعُه ومعرّفه واسمُه وقتَ وقوعه.
  ///
  /// والاسم منسوخٌ عمداً: السجل يُقرأ بعد سنة وقد حُذف الهدف، فيبقى
  /// السطر مفهوماً بلا استعلامٍ عن شيءٍ لم يعد موجوداً.
  final String? targetType;
  final String? targetId;
  final String? targetName;

  /// الحقول المتغيّرة وحدها — راجع `diffMaps`.
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  const AuditLogEntry({
    required this.id,
    required this.userName,
    required this.action,
    required this.details,
    required this.timestamp,
    this.type = ChangeType.other,
    this.actorUid,
    this.targetType,
    this.targetId,
    this.targetName,
    this.before,
    this.after,
  });

  /// هل يحمل هذا السطر فرقاً يُعرض؟
  bool get hasDiff => (before?.isNotEmpty ?? false) || (after?.isNotEmpty ?? false);

  Map<String, dynamic> toMap() => {
        'userName': userName,
        'action': action,
        'details': details,
        // ختمُ الخادم لا ساعةُ الجهاز — راجع [timestamp] أعلاه.
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.key,
        if (actorUid != null) 'actorUid': actorUid,
        if (targetType != null) 'targetType': targetType,
        if (targetId != null) 'targetId': targetId,
        if (targetName != null) 'targetName': targetName,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      };

  factory AuditLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      userName: json['userName'] as String? ?? '',
      action: json['action'] as String? ?? '',
      details: json['details'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: ChangeType.fromKey(json['type'] as String?),
      actorUid: json['actorUid'] as String?,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      targetName: json['targetName'] as String?,
      before: _mapOf(json['before']),
      after: _mapOf(json['after']),
    );
  }

  static Map<String, dynamic>? _mapOf(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : null;
}
