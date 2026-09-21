/// حالةُ موظّفٍ في يوم — **سجلٌّ يُقال كما هو، لا طلبٌ يُعتمَد**.
///
/// ــــ القرارُ الذي بُنيت عليه ــــ
///
/// اختار مسؤولُ النظام أن تُسجَّل الحالةُ **كما يقولها صاحبُها**: لا تنتظر
/// موافقةً، ولا تقف في طابور. فمن استأذن كتبه ومضى. والتصحيحُ بعد ذلك
/// **لمسؤوله وحدَه**، وبأثرٍ يحمل اسمَه وما كان قبله.
///
/// ولو كانت طلباً يُعتمَد لَصارت الشاشةُ طابوراً آخر على مكتب المدير، وهو
/// ما لم يُطلب.
///
/// ــــ وصورةُ اليوم ــــ
///
/// اليومُ **حالةٌ واحدةٌ تشغله** — حضورٌ أو إجازةٌ أو تدريب. ويجوز أن يُضاف
/// إليه **خروجٌ بوقته** حين يخرج الموظّفُ من الوزارة: «مهمّة رسميّة من ٩
/// إلى ١١». وهذا ما وصفه مسؤولُ النظام بعينه.
///
/// فحالةُ اليوم معرّفُها محسوبٌ `{uid}_{yyyy-mm-dd}` — فلا تتعدّد. والخروجُ
/// معرّفُه تلقائيّ: من خرج مرّتين في يومٍ يقول ذلك.
library;

import 'attachment.dart';
import 'safe_read.dart';

/// أهذا سجلُّ يومٍ كامل، أم خروجٌ بوقته داخله؟
enum StatusKind {
  /// الحالةُ التي تشغل اليوم.
  day,

  /// خروجٌ من الوزارة بوقتٍ محدّد، على يوم حضور.
  outing;

  static StatusKind fromName(String? name) =>
      name == StatusKind.outing.name ? StatusKind.outing : StatusKind.day;
}

class DailyStatus {
  final String id;
  final String uid;

  /// اسمُ صاحبه **منسوخاً وقتَ الكتابة**.
  ///
  /// ولا يُقرأ من سجلّ المستخدم عند العرض: من غادر الوزارة يُحذف سجلُّه،
  /// فيصير تقريرُ الشهر الماضي صفوفاً بلا أسماء.
  final String userName;

  /// الإدارةُ والقسمُ **وقتَ الكتابة** كذلك — فمن نُقل بعد شهرٍ يبقى سجلُّ
  /// ذلك اليوم منسوباً إلى إدارته يومَها، ولا يتبدّل تاريخُ الوزارة بنقل
  /// موظّف.
  final String? departmentId;
  final String? sectionId;

  /// مفتاحُ اليوم `yyyy-mm-dd` — **بتوقيت الكويت**.
  final String dayKey;
  final DateTime? day;

  final StatusKind kind;

  /// النوعُ ومسمّاه ونغمتُه، منسوخةً كذلك: مسؤولُ النظام يحرّر القائمة،
  /// وتحريرُ اسمٍ اليومَ لا يجوز أن يغيّر ما قيل الشهرَ الماضي.
  final String typeId;
  final String typeName;
  final String toneKey;

  /// دقائقُ الخروج والعودة منذ منتصف الليل — **للخروج وحدَه**.
  final int? fromMinutes;
  final int? toMinutes;

  /// مكانُ المهمّة — «وزارة المالية».
  final String place;
  final String note;
  final Attachment? attachment;

  final DateTime? createdAt;
  final String createdByName;

  /// أثرُ التصحيح — فارغٌ لسجلٍّ لم يُمسّ.
  final DateTime? correctedAt;
  final String correctedByName;
  final String correctionNote;

  const DailyStatus({
    required this.id,
    required this.uid,
    required this.userName,
    required this.dayKey,
    required this.typeId,
    required this.typeName,
    this.departmentId,
    this.sectionId,
    this.day,
    this.kind = StatusKind.day,
    this.toneKey = 'neutral',
    this.fromMinutes,
    this.toMinutes,
    this.place = '',
    this.note = '',
    this.attachment,
    this.createdAt,
    this.createdByName = '',
    this.correctedAt,
    this.correctedByName = '',
    this.correctionNote = '',
  });

  /// هل مسّه مسؤولٌ بعد حفظه؟ — تُعرض به علامةٌ في الصفّ.
  bool get wasCorrected => correctedByName.isNotEmpty;

  /// «٠٩:٠٠ — ١١:٣٠» أو نصٌّ فارغٌ لحالة يوم.
  String get timeLabel {
    if (fromMinutes == null || toMinutes == null) return '';
    return '${_clock(fromMinutes!)} — ${_clock(toMinutes!)}';
  }

  static String _clock(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// يقرأ بقرّاء `safe_read.dart` — فمستندٌ واحدٌ معطوبٌ لا يُفرغ الشهرَ.
  ///
  /// ــ ويرمي ولا يُرجع `null` ــ
  ///
  /// لأنّ `_parseDocs` تلتقط لكلّ مستندٍ على حدة **وتسمّيه** في لافتة تعذُّر
  /// القراءة. و`null` كانت ستُسقطه صامتاً: يختفي يومٌ من تقويم موظّفٍ ولا
  /// شيء يقول لماذا. وهو الدرسُ المدفوعُ ثمنُه يومَ اختفت مشاريعُ الوزارة.
  static DailyStatus fromMap(String id, Map<String, dynamic> map) {
    final uid = readText(map['uid']);
    final dayKey = readText(map['dayKey']);
    if (uid.isEmpty || dayKey.isEmpty) {
      throw FormatException('سجلُّ حالةٍ بلا صاحبٍ أو بلا يوم', id);
    }
    final from = readNum(map['fromMinutes']);
    final to = readNum(map['toMinutes']);
    return DailyStatus(
      id: id,
      uid: uid,
      userName: readText(map['userName']),
      departmentId: readText(map['departmentId']).isEmpty ? null : readText(map['departmentId']),
      sectionId: readText(map['sectionId']).isEmpty ? null : readText(map['sectionId']),
      dayKey: dayKey,
      day: readDate(map['day']),
      kind: StatusKind.fromName(readText(map['kind'])),
      typeId: readText(map['typeId']),
      typeName: readText(map['typeName']),
      toneKey: readText(map['toneKey']),
      fromMinutes: from?.toInt(),
      toMinutes: to?.toInt(),
      place: readText(map['place']),
      note: readText(map['note']),
      attachment: map['attachment'] is Map
          ? Attachment.fromMap(Map<String, dynamic>.from(map['attachment'] as Map))
          : null,
      createdAt: readDate(map['createdAt']),
      createdByName: readText(map['createdByName']),
      correctedAt: readDate(map['correctedAt']),
      correctedByName: readText(map['correctedByName']),
      correctionNote: readText(map['correctionNote']),
    );
  }
}
