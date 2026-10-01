import 'package:cloud_firestore/cloud_firestore.dart';

import 'attachment.dart';
import 'safe_read.dart';

class DailyUpdate {
  final String id;
  final String projectId;
  final String departmentId;
  final String authorUid;
  final String authorName;
  final DateTime date;
  final String achievements; // الإنجازات
  final List<String> completedTasks; // المهام المنجزة
  final List<String> newRisks; // المخاطر الجديدة
  final List<String> blockers; // العوائق
  final List<String> decisionsRequired; // القرارات المطلوبة من القيادة
  final double progressPercent; // نسبة التقدم عند التحديث

  // ــــــــــــــ ما يجيب عن أسئلة الاجتماع ــــــــــــــ
  //
  // ــ ونسبةُ الإنجاز وحدَها لا تجيب ــ
  //
  // «٦٠٪» لا تقول **ما الذي يجري الآن**، ولا **ما الخطوةُ التالية**، ولا
  // **متى تقع**. وهي الأسئلةُ الثلاثة التي يُفتح تقريرُ المشروع لأجلها.
  //
  // وثلاثةٌ من المطلوب كانت قائمةً أصلاً: `achievements` هي «ما أُنجز»،
  // و`blockers` هي العوائق، و`newRisks` المخاطر، و`decisionsRequired`
  // القرارات. فلم يبقَ إلا هذه الأربعة — **إضافةٌ محضة**، وكلُّ تحديثٍ
  // مكتوبٍ قبل اليوم يُقرأ بلا ترحيل.

  /// ما يجري الآن — بين ما أُنجز وما لم يبدأ.
  final String inProgress;

  /// الخطوةُ التالية وموعدُها.
  final String nextAction;
  final DateTime? nextActionDate;

  /// ما يُحتاج من خارج الفريق — «نحتاج حساباً على الخادم من التشغيل».
  ///
  /// وهو غيرُ العائق: العائقُ ما **أوقف** العمل، وهذا ما **سيوقفه** إن لم
  /// يصل. وجمعُهما كان يجعل الطلبَ يُقرأ شكوى.
  final String supportRequired;

  /// ملاحظات حرة يكتبها صاحب التحديث — ما لا يقع تحت الإنجازات ولا العوائق.
  final String notes;

  /// مرفقات اليوم: ملفات مرفوعة أو روابط إلى ملفات على أنظمة الوزارة.
  final List<Attachment> attachments;

  const DailyUpdate({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.authorUid,
    required this.authorName,
    required this.date,
    required this.achievements,
    required this.completedTasks,
    required this.newRisks,
    required this.blockers,
    required this.decisionsRequired,
    required this.progressPercent,
    this.inProgress = '',
    this.nextAction = '',
    this.nextActionDate,
    this.supportRequired = '',
    this.notes = '',
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'authorUid': authorUid,
        'authorName': authorName,
        'date': Timestamp.fromDate(date),
        'achievements': achievements,
        'completedTasks': completedTasks,
        'newRisks': newRisks,
        'blockers': blockers,
        'decisionsRequired': decisionsRequired,
        'progressPercent': progressPercent,
        'inProgress': inProgress,
        'nextAction': nextAction,
        'nextActionDate': nextActionDate == null ? null : Timestamp.fromDate(nextActionDate!),
        'supportRequired': supportRequired,
        'notes': notes,
        'attachments': [for (final a in attachments) a.toMap()],
      };

  factory DailyUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return DailyUpdate(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      achievements: json['achievements'] as String? ?? '',
      completedTasks: List<String>.from(json['completedTasks'] as List? ?? const []),
      newRisks: List<String>.from(json['newRisks'] as List? ?? const []),
      blockers: List<String>.from(json['blockers'] as List? ?? const []),
      decisionsRequired: List<String>.from(json['decisionsRequired'] as List? ?? const []),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      // التحديثات المكتوبة قبل هذه الحقول تُقرأ بلا كسر — والغائبُ فارغٌ
      // لا مخترَع.
      inProgress: json['inProgress'] as String? ?? '',
      nextAction: json['nextAction'] as String? ?? '',
      nextActionDate: readDate(json['nextActionDate']),
      supportRequired: json['supportRequired'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      attachments: Attachment.listFrom(json['attachments']),
    );
  }
}
