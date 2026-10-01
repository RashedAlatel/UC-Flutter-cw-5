/// خطّةُ الأسبوع لموظّف — **ثلاثُ أولويّاتٍ لا قائمةُ مهامّ**.
///
/// ــــ ولماذا ثلاثٌ بحدّ ــــ
///
/// خطّةٌ بعشرة بنودٍ ليست خطّة: هي قائمةُ أعمالٍ أخرى بجوار المهامّ. والحدُّ
/// **هو الأداة**: يُجبر المديرَ على أن يقرّر ما الذي يهمّ فعلاً هذا الأسبوع،
/// وهو القرارُ الذي يُؤجَّل عادةً.
///
/// ــــ وهي غيرُ المهامّ ــــ
///
/// المهمّةُ التزامٌ بموعدٍ داخل مشروع. والأولويّةُ الأسبوعيّة **نيّةٌ
/// معلَنة**: «هذا ما سأقضي فيه أسبوعي». وقد تكون مهمّةً قائمة، وقد تكون
/// عملاً لا سجلَّ له بعد.
///
/// ــــ والتاريخُ يُحفظ ــــ
///
/// خطّةُ كلّ أسبوعٍ مستندٌ بمفتاحه، فلا تُكتب فوق سابقتها. ومن أراد أن يعرف
/// ما وعد به فريقُه قبل شهرٍ وما أُنجز منه يجده.
library;

import 'safe_read.dart';

/// بندٌ واحدٌ في خطّة الأسبوع.
class PlanItem {
  final String title;

  /// المشروعُ المتّصل — أو فارغٌ لعملٍ خارج المشاريع.
  final String projectId;
  final String projectName;

  /// **النتيجةُ المتوقَّعة** — وهي ما يُقاس عليه في آخر الأسبوع.
  ///
  /// وبلا هذا الحقل تصير الخطّةُ عناوينَ لا تُراجَع: «متابعة المشروع» بندٌ
  /// يمكن أن يُقال في كلّ أسبوعٍ إلى الأبد.
  final String expectedOutcome;

  /// `planned` · `inProgress` · `done` · `carriedOver`
  final String status;

  const PlanItem({
    required this.title,
    this.projectId = '',
    this.projectName = '',
    this.expectedOutcome = '',
    this.status = 'planned',
  });

  bool get isDone => status == 'done';

  /// **مُرحَّلٌ من أسبوعٍ مضى** — وهو أهمُّ ما في المراجعة.
  ///
  /// بندٌ يُرحَّل ثلاثةَ أسابيعَ متتاليةً ليس بنداً متعثّراً، بل قرارٌ لم
  /// يُتَّخذ: إمّا أن يُنجَز أو يُسقَط.
  bool get isCarriedOver => status == 'carriedOver';

  Map<String, dynamic> toMap() => {
        'title': title,
        'projectId': projectId,
        'projectName': projectName,
        'expectedOutcome': expectedOutcome,
        'status': status,
      };

  static PlanItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final title = readText(map['title']);
    if (title.isEmpty) return null;
    return PlanItem(
      title: title,
      projectId: readText(map['projectId']),
      projectName: readText(map['projectName']),
      expectedOutcome: readText(map['expectedOutcome']),
      status: readText(map['status']).isEmpty ? 'planned' : readText(map['status']),
    );
  }

  PlanItem copyWith({String? title, String? expectedOutcome, String? status,
          String? projectId, String? projectName}) =>
      PlanItem(
        title: title ?? this.title,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        expectedOutcome: expectedOutcome ?? this.expectedOutcome,
        status: status ?? this.status,
      );
}

class WeeklyPlan {
  /// معرّفٌ محسوب: `{uid}_{weekKey}` — فخطّةُ الأسبوع واحدةٌ لا تتعدّد.
  final String id;
  final String uid;
  final String userName;
  final String departmentId;

  /// مفتاحُ الأسبوع — تاريخُ أحدِه `yyyy-mm-dd`.
  final String weekKey;

  final List<PlanItem> items;

  final DateTime? updatedAt;
  final String updatedByName;

  const WeeklyPlan({
    required this.id,
    required this.uid,
    required this.weekKey,
    this.userName = '',
    this.departmentId = '',
    this.items = const [],
    this.updatedAt,
    this.updatedByName = '',
  });

  /// **الحدُّ ثلاثة** — وهو الأداةُ لا القيد.
  static const int maxItems = 3;

  int get doneCount => items.where((i) => i.isDone).length;

  /// أحدُ الأسبوع الذي يقع فيه هذا اليوم — **والأسبوعُ يبدأ الأحد**.
  ///
  /// وهو أسبوعُ العمل في الوزارة، لا أسبوعُ التقويم الغربيّ الذي يبدأ
  /// الإثنين. راجع `WorkWeek`.
  static DateTime weekStart(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    // `DateTime.sunday` يساوي ٧ في ترقيم Dart، فالأحدُ يعود صفراً بالباقي.
    return d.subtract(Duration(days: d.weekday % 7));
  }

  static String weekKeyOf(DateTime day) {
    final s = weekStart(day);
    return '${s.year.toString().padLeft(4, '0')}-'
        '${s.month.toString().padLeft(2, '0')}-'
        '${s.day.toString().padLeft(2, '0')}';
  }

  static String docId(String uid, String weekKey) => '${uid}_$weekKey';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'departmentId': departmentId,
        'weekKey': weekKey,
        'items': items.map((i) => i.toMap()).toList(),
      };

  static WeeklyPlan fromMap(String id, Map<String, dynamic> map) {
    final uid = readText(map['uid']);
    final weekKey = readText(map['weekKey']);
    if (uid.isEmpty || weekKey.isEmpty) {
      throw FormatException('خطّةُ أسبوعٍ بلا صاحبٍ أو بلا أسبوع', id);
    }
    final raw = map['items'];
    return WeeklyPlan(
      id: id,
      uid: uid,
      userName: readText(map['userName']),
      departmentId: readText(map['departmentId']),
      weekKey: weekKey,
      items: raw is List
          ? raw.map(PlanItem.fromMap).whereType<PlanItem>().take(maxItems).toList()
          : const [],
      updatedAt: readDate(map['updatedAt']),
      updatedByName: readText(map['updatedByName']),
    );
  }
}
