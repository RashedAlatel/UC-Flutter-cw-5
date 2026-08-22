import 'package:cloud_firestore/cloud_firestore.dart';

import 'attachment.dart';

/// تحديث يومي على **عمل** تشغيلي.
///
/// ــــ ولماذا نوعٌ ومجموعةٌ مستقلّان عن `DailyUpdate`؟ ــــ
///
/// لأن قاعدة `dailyUpdates` على الخادم تشترط أن يقابل المستندَ **مشروعٌ
/// حقيقي** (`matchesRealProject`)، وهي شرطٌ أمني لا تجميل: به يُمنع من
/// يكتب تحديثاً أن ينسبه إلى مشروعٍ ليس عضواً فيه. وتوسيعُها لتقبل مستنداً
/// بلا مشروع يفتح ثغرةً في أكثر مسارات المنصة حساسية.
///
/// والعمل ليس مشروعاً: إدارته وإسنادُه وحدهما يقرّران من يراه ومن يكتب فيه.
/// فله مجموعته وقاعدته، على نسق `works` حرفاً بحرف.
///
/// و[assigneeUid] و[departmentId] منسوخان من العمل عمداً: قواعد Firestore
/// **ترفض ولا تُصفّي**، فالاستعلام يجب أن يحمل نطاقه بنفسه — ولا يُستعلم عن
/// حقلٍ في مستندٍ آخر. وهو العطل الذي أخفى أعمال الموظف من قبل.
class WorkUpdate {
  final String id;
  final String workId;
  final String departmentId;

  /// المُسنَد إليه العمل وقت كتابة التحديث — نطاقُ القراءة للموظف.
  final String assigneeUid;

  final String authorUid;
  final String authorName;
  final DateTime date;

  /// ما أُنجز في هذا اليوم.
  final String summary;

  /// ما لا يقع تحت الإنجاز: عائق، أو ملاحظة، أو طلب.
  final String notes;

  /// نسبة إنجاز العمل عند التحديث.
  final double progressPercent;

  final List<Attachment> attachments;

  const WorkUpdate({
    required this.id,
    required this.workId,
    required this.departmentId,
    required this.assigneeUid,
    required this.authorUid,
    required this.authorName,
    required this.date,
    required this.summary,
    required this.progressPercent,
    this.notes = '',
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() => {
        'workId': workId,
        'departmentId': departmentId,
        'assigneeUid': assigneeUid,
        'authorUid': authorUid,
        'authorName': authorName,
        'date': Timestamp.fromDate(date),
        'summary': summary,
        'notes': notes,
        'progressPercent': progressPercent,
        'attachments': [for (final a in attachments) a.toMap()],
      };

  factory WorkUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return WorkUpdate(
      id: doc.id,
      workId: json['workId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      assigneeUid: json['assigneeUid'] as String? ?? '',
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'غير معروف',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: json['summary'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      attachments: ((json['attachments'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Attachment.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}
