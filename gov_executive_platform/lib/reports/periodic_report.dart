// التقرير الدوري — الحساب كلُّه، بلا Firestore وبلا شاشة.
//
// ــــ لماذا وحدةٌ نقيّة ــــ
//
// التقرير أربعون مقياساً يُقرأ عليها أداءُ موظفين وإداراتٍ في وزارة. ورقمٌ
// خاطئٌ فيه ليس عطلاً في شاشة: هو حكمٌ على إنسان. فالحساب هنا — بلا شبكةٍ
// ولا `BuildContext` — ليُقاس كلُّ مقياسٍ وحده، وتُقلب كلُّ عدّةٍ بطفرةٍ
// فيُعرف أن اختباراً يمسكها.
//
// وهو نمطٌ قائم في المنصة: `splitDeleted` و`diffMaps` و`workUpdateOutcome`
// و`convert_record.ts` — كلُّها أُخرجت من مواضع لا يبلغها اختبار.
//
// ــــ والنشاط يُقاس بما فُعل لا بمرّات الدخول ــــ
//
// كما نصصتَ. فالمصادر هي الأثر المكتوب: التحديثات اليومية، وتحديثات
// الأعمال، والمرفقات المرفوعة داخلها، والمخاطر والعوائق المسجّلة،
// والمهامّ المُضافة والمنجَزة.
//
// ــــ والمرفقاتُ والعوائق تُنسب عبر أبيها ــــ
//
// `Attachment` لا تحمل رافعاً، لكنها تعيش داخل تحديثٍ يحمل كاتبَه وتاريخه.
// وكذلك المخاطر والعوائق: تُكتب من التحديث اليومي (`addDailyUpdate`)، فلا
// تحمل مسجِّلاً في مستندها. فتُنسب إلى كاتب التحديث الذي وُلدت منه — وهو
// **هو** من سجّلها فعلاً.
import '../models/app_user.dart';
import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/risk.dart';
import '../models/work_item.dart';
import '../models/work_update.dart';

/// مدى التقرير: من بدايةِ يومٍ إلى نهايةِ يوم.
///
/// والحدّان **شاملان**: تقريرُ أسبوعٍ يبدأ السبت وينتهي الجمعة يجب أن يضمّ
/// ما كُتب يوم الجمعة. ولذلك تُقارن الأيام لا اللحظات — فتحديثٌ كُتب الجمعة
/// الساعة الحادية عشرة مساءً داخلَ الأسبوع لا خارجه.
class ReportRange {
  final DateTime start;
  final DateTime end;
  final ReportPeriod period;

  const ReportRange({required this.start, required this.end, required this.period});

  /// أسبوعٌ ينتهي بـ[anchor] — سبعةُ أيامٍ شاملةً طرفيها.
  factory ReportRange.weekEnding(DateTime anchor) {
    final e = DateTime(anchor.year, anchor.month, anchor.day);
    return ReportRange(
      start: e.subtract(const Duration(days: 6)),
      end: e,
      period: ReportPeriod.weekly,
    );
  }

  /// شهرُ [anchor] كاملاً — من أوّله إلى آخره.
  ///
  /// وآخرُه يُحسب باليوم صفر من الشهر التالي، فلا يُكتب ثلاثونَ لشهرٍ فيه
  /// واحدٌ وثلاثون ولا لشباط.
  factory ReportRange.monthOf(DateTime anchor) => ReportRange(
        start: DateTime(anchor.year, anchor.month, 1),
        end: DateTime(anchor.year, anchor.month + 1, 0),
        period: ReportPeriod.monthly,
      );

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime moment) {
    final d = DateTime(moment.year, moment.month, moment.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// هل وقع هذا الحدث **قبل** الفترة؟ يُستعمل لقراءة الحال عند بدايتها.
  bool isBefore(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day).isBefore(start);
}

/// مستوى النشاط — **أداةُ متابعةٍ لا حكمٌ على موظف**.
///
/// كما نصصتَ: تُعرف بها الإدارةُ أين يوجد نشاطٌ وأين تلزم متابعة، ولا
/// يُحكم بها وحدها على أحد. ولذلك يُعرض معها **سببُها** دائماً: كم تحديثاً
/// وكم مهمةً وكم مرفقاً — فالرقم يُراجَع لا يُصدَّق.
enum ActivityLevel {
  none('لا يوجد نشاط'),
  low('نشاط منخفض'),
  medium('نشاط متوسط'),
  high('نشاط مرتفع');

  final String label;
  const ActivityLevel(this.label);
}

/// النصُّ الذي طلبتَ أن يُكتب مع المؤشّر — **في موضعٍ واحد**.
///
/// يُعرض على الشاشة، ويُكتب في ورقة Excel، ويُطبع في صفحة PDF. ولو كُتب
/// ثلاث مرّات لَخرج الملفُّ المُرسَل يوماً بلا تحفّظه بينما الشاشة تحمله —
/// والملفُّ هو ما يُقرأ خارج المنصة.
const String kActivityDisclaimer =
    'مؤشّر النشاط أداةُ متابعةٍ للإدارة، ولا يُستخدم منفرداً للحكم على أداء '
    'الموظف. وهو محسوبٌ من الأنشطة المسجَّلة في المنصة — لا من عدد مرّات '
    'الدخول — وقد يكون للموظف عملٌ لا يمرّ بها.';

/// حدودُ التصنيف — مكشوفةٌ لا مدفونة، فمن يراجع التقرير يعرف بمَ صُنّف.
///
/// وهي لكل **أسبوع**: الشهر يُقاس بأربعة أضعافها، فلا يُصنَّف شهرٌ كامل
/// «منخفضاً» لأن معيارَه معيارُ أسبوع.
const int kActivityLowAtLeast = 1;
const int kActivityMediumAtLeast = 4;
const int kActivityHighAtLeast = 10;

/// هل المهمة متأخرة **عند [asOf]**؟
///
/// ــــ لماذا لا تُقاس بلحظة فتح الشاشة ــــ
///
/// `Project.delayDays` يقيس التأخّر بـ`DateTime.now()`، وهو الصواب في بطاقةٍ
/// تُعرض الآن. أما تقريرُ شهرٍ مضى فيجب أن يقول ما كان صحيحاً **في نهايته**:
/// مهمةٌ استُحقّت بعد انتهاء الفترة ليست متأخرةً في تقريرها ولو تأخّرت اليوم.
/// ولولا ذلك لتغيّر رقمُ التقرير نفسِه كلما أُعيد فتحه.
///
/// والمنجَزة ليست متأخرةً هنا: تأخّرُها عن موعدها يُقاس بـ
/// [ProjectTask.finishedOnTime] لا بهذه.
bool isTaskLateAt(ProjectTask task, DateTime asOf) {
  if (task.isDone) return false;
  final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  final at = DateTime(asOf.year, asOf.month, asOf.day);
  return at.isAfter(due);
}

/// المدّةُ المبدئية التي يصير بعدها المشروع «غير نشط» — ويغيّرها مسؤول
/// النظام من إعدادات القسم. اخترتَ سبعةً: أسبوعٌ كاملٌ بلا تحديث، فلا
/// تُعلَّم عطلةُ نهاية الأسبوع جموداً.
const int kDefaultInactiveAfterDays = 7;

/// كم يوماً قبل الاستحقاق يُقال «قريبٌ من موعده».
const int kDueSoonDays = 7;

/// هل المشروع متأخّر **عند [asOf]**؟
///
/// ــــ ولماذا لا يُسأل `effectiveStatus` مباشرةً ــــ
///
/// لأنها تقيس بـ`DateTime.now()`، وهو الصواب في بطاقةٍ تُعرض الآن. أما
/// التقرير فيجيب عن سؤالٍ آخر: **ما الذي كان صحيحاً في نهاية الفترة**.
/// ولولا ذلك لتغيّر رقمُ تقريرِ شهرٍ مضى كلّما أُعيد فتحه — فيُطبع الملفّ
/// مرّتين برقمين، ولا يُعرف أيُّهما الصحيح.
///
/// والقاعدةُ **هي قاعدةُ `effectiveStatus` حرفاً**، بساعة التقرير لا بساعة
/// الشاشة: المكتملُ ليس متأخراً مهما مضى، ومن تجاوز موعده ولم يكتمل متأخّر.
bool isProjectLateAt(Project project, DateTime asOf) =>
    project.status != ProjectStatus.completed && _pastDue(project.dueDate, asOf);

/// ونظيرُها للعمل — و`TaskStatus.done` هو اكتمالُه.
bool isWorkLateAt(WorkItem work, DateTime asOf) =>
    !work.isDone && _pastDue(work.dueDate, asOf);

bool _pastDue(DateTime due, DateTime asOf) {
  final d = DateTime(due.year, due.month, due.day);
  final at = DateTime(asOf.year, asOf.month, asOf.day);
  return at.isAfter(d);
}

/// حالةُ المشروع أو العمل في التقرير — الأربعُ التي طلبتها.
///
/// وهي **غيرُ** `ProjectStatus` المخزَّنة عمداً: تلك تصف الخطة (على المسار ·
/// مهدد · متأخر · مكتمل)، وهذه تصف **ما يلزم فعله الآن** — وهو سؤالُ
/// القيادة حين تقرأ تقريراً.
enum ReportItemStatus {
  /// متأخّرٌ ومعه ما يمنع تقدّمه — عائقٌ قائم أو جمودٌ منذ المدّة المحدَّدة.
  needsIntervention('يحتاج تدخل'),

  /// تجاوز موعده ولم يكتمل.
  late_('متأخر'),

  /// لم يتأخّر، لكنه جامدٌ منذ المدّة أو عليه عائقٌ قائم.
  needsFollowUp('يحتاج متابعة'),

  /// ما عدا ذلك — والمكتملُ منها دائماً.
  normal('طبيعي');

  final String label;
  const ReportItemStatus(this.label);
}

/// تصنيفٌ نقيٌّ يُقاس وحده — راجع `test/periodic_report_test.dart`.
///
/// والترتيبُ نازلٌ في الخطورة، فأشدُّ الشروط يُفحص أوّلاً: مشروعٌ متأخّرٌ
/// وعليه عائق **يحتاج تدخّلاً**، لا «متأخراً» فحسب.
///
/// و[stalledDays] هو عددُ الأيام بلا تحديث — و`null` حين لا تحديث إطلاقاً،
/// وذلك **جمودٌ لا براءة**: مشروعٌ لم يُحدَّث قطّ ليس أفضل حالاً من مشروعٍ
/// تُرك شهراً.
ReportItemStatus reportItemStatus({
  required bool isCompleted,
  required bool isLate,
  required bool hasOpenBlocker,
  required int? stalledDays,
  required int inactiveAfterDays,
}) {
  // المكتملُ لا يُطالَب بتحديث: مشروعٌ أُنجز في الربيع لا يُقال عنه في
  // الخريف إنه «يحتاج متابعة» لأنه ساكن.
  if (isCompleted) return ReportItemStatus.normal;

  final stalled = stalledDays == null || stalledDays >= inactiveAfterDays;
  final blocked = hasOpenBlocker;

  if (isLate && (blocked || stalled)) return ReportItemStatus.needsIntervention;
  if (isLate) return ReportItemStatus.late_;
  if (blocked || stalled) return ReportItemStatus.needsFollowUp;
  return ReportItemStatus.normal;
}

ActivityLevel activityLevelFor(int activities, ReportPeriod period) {
  final factor = period == ReportPeriod.monthly ? 4 : 1;
  if (activities < kActivityLowAtLeast) return ActivityLevel.none;
  if (activities < kActivityMediumAtLeast * factor) return ActivityLevel.low;
  if (activities < kActivityHighAtLeast * factor) return ActivityLevel.medium;
  return ActivityLevel.high;
}

/// أداءُ شخصٍ واحد خلال الفترة.
class PersonPerformance {
  final String uid;
  final String name;
  final String? departmentId;
  final UserRole role;

  /// المهامُّ المنجَزة خلال الفترة — و`null` **ليس صفراً**: راجع
  /// [tasksWithoutCompletionDate].
  final int tasksCompleted;

  /// المهامُّ التي أضافها خلال الفترة.
  final int tasksAdded;

  final int dailyUpdates;
  final int workUpdates;
  final int attachmentsUploaded;
  final int risksRaised;
  final int blockersRaised;

  /// المُسنَدة إليه والمتأخّرة **عند نهاية الفترة** — راجع [isTaskLateAt]:
  /// تقريرُ شهرٍ مضى يقول ما كان صحيحاً في آخره، لا ما صار صحيحاً اليوم.
  final int lateTasksAssigned;

  final int finishedOnTime;
  final int finishedLate;

  /// مهامٌّ منجَزةٌ لا يُعرف متى أُنجزت — أقدمُ من الحقل.
  ///
  /// تُعرض «غير مسجّل» ولا تُضاف إلى [finishedOnTime] ولا [finishedLate]،
  /// فلا يُقرأ نقصُ البيان تأخّراً.
  final int tasksWithoutCompletionDate;

  final List<String> projectNames;
  final List<String> workTitles;

  /// آخرُ أثرٍ له في المنصة — و`null` حين لا أثر إطلاقاً.
  final DateTime? lastActivity;

  final ActivityLevel activity;

  const PersonPerformance({
    required this.uid,
    required this.name,
    required this.departmentId,
    required this.role,
    required this.tasksCompleted,
    required this.tasksAdded,
    required this.dailyUpdates,
    required this.workUpdates,
    required this.attachmentsUploaded,
    required this.risksRaised,
    required this.blockersRaised,
    required this.lateTasksAssigned,
    required this.finishedOnTime,
    required this.finishedLate,
    required this.tasksWithoutCompletionDate,
    required this.projectNames,
    required this.workTitles,
    required this.lastActivity,
    required this.activity,
  });

  /// مجموعُ ما فُعل — وهو ما يُصنَّف به النشاط.
  int get totalActivities =>
      tasksCompleted + tasksAdded + dailyUpdates + workUpdates +
      attachmentsUploaded + risksRaised + blockersRaised;

  bool get hasNoActivity => totalActivities == 0;
}

/// أداءُ إدارةٍ واحدة خلال الفترة.
class DepartmentPerformance {
  final String departmentId;
  final String name;
  final int projectCount;
  final int workCount;
  final int tasksCompleted;
  final int tasksAdded;
  final int lateTasks;
  final int lateProjects;

  /// مشاريعُ بلا تحديثٍ حديث — «حديث» يعني داخل الفترة.
  final int projectsWithoutRecentUpdate;

  /// ما يحتاج تدخّلاً: متأخرٌ **أو** عليه عائقٌ قائم.
  final int projectsNeedingIntervention;

  final double avgProgress;
  final int activePeople;
  final int idlePeople;

  /// متوسطُ التحديثات لكل مشروع — و`0` لإدارةٍ بلا مشاريع، لا قسمةٌ على صفر.
  final double avgUpdatesPerProject;

  final List<String> topAchievements;
  final List<String> topBlockers;
  final ActivityLevel activity;

  const DepartmentPerformance({
    required this.departmentId,
    required this.name,
    required this.projectCount,
    required this.workCount,
    required this.tasksCompleted,
    required this.tasksAdded,
    required this.lateTasks,
    required this.lateProjects,
    required this.projectsWithoutRecentUpdate,
    required this.projectsNeedingIntervention,
    required this.avgProgress,
    required this.activePeople,
    required this.idlePeople,
    required this.avgUpdatesPerProject,
    required this.topAchievements,
    required this.topBlockers,
    required this.activity,
  });
}

/// أداءُ مشروعٍ أو عملٍ واحد خلال الفترة — البنودُ التي عدّدتَها.
///
/// ــــ ولماذا الأعداد `int?` لا `int` ــــ
///
/// لأن **العملَ لا يحمل مهامّ ولا عوائق ولا مخاطر** — تلك معلّقةٌ بالمشروع
/// في هذه المنصة. فلو كُتبت أصفاراً لَقرأ المدير «صفر مهام منجَزة» على عملٍ
/// أُنجز كلُّه، وهو كذبٌ لا نقصُ بيان. فـ`null` تعني **«لا ينطبق»** وتُعرض
/// «—»، على المبدأ نفسه الذي حكم «غير مسجّل» في المهام.
class ItemPerformance {
  final String id;
  final String name;

  /// عملٌ أم مشروع — يُعرض في عمودٍ مستقل، فالجدول واحدٌ والقارئ يميّز.
  final bool isWork;

  final String departmentName;

  /// مكتملٌ أم لا — يُحمَل صراحةً لأن قائمة «غير النشط» تستثنيه، والاستنتاجُ
  /// من [status] استنتاجٌ هشّ: «طبيعي» تعني المكتملَ وغيرَ المكتملِ السليم.
  final bool isCompleted;

  /// مديرُ المشروع — فارغٌ للعمل، فالعمل يُسنَد ولا يُدار.
  final String managerNames;
  final String executorNames;

  final double progressNow;

  /// نسبةُ الإنجاز في **بداية** الفترة — من آخر تحديثٍ قبلها.
  ///
  /// و`null` تعني **«لا أساس للمقارنة»**: مشروعٌ بلا تحديثٍ سابق لا يُقال
  /// إنه بدأ من الصفر، وإلا ظهر مشروعٌ عمرُه سنةٌ وكأنه أنجز كلَّ شيء في
  /// أسبوع.
  final double? progressAtStart;

  /// مقدارُ التقدّم — و`null` حين لا أساس له.
  double? get progressMade =>
      progressAtStart == null ? null : progressNow - progressAtStart!;

  final int? tasksCompleted;
  final int? tasksAdded;
  final int? tasksLate;
  final int? openTasks;

  /// آخرُ تحديثٍ أُدخل — في أي وقت، لا داخل الفترة وحدها: السؤال «متى آخر
  /// مرّة تحرّك» لا معنى له محصوراً بالفترة التي نسأل عنها.
  final DateTime? lastUpdate;

  /// الأيامُ منذ آخر تحديث، محسوبةً إلى **نهاية الفترة** — و`null` حين لا
  /// تحديث إطلاقاً.
  final int? daysSinceLastUpdate;

  final DateTime dueDate;

  /// الأيامُ المتبقية إلى الاستحقاق عند نهاية الفترة — سالبةٌ لمن تجاوزه.
  final int remainingDays;

  /// العوائقُ **القائمة** لا كلُّ ما سُجّل: عائقٌ حُلّ لا يُحسب.
  final int? openBlockers;

  /// «المتطلبات» — وهي في هذه المنصة **القرارات المطلوبة من القيادة**
  /// المسجَّلة في تحديثات الفترة (`DailyUpdate.decisionsRequired`). ولا يوجد
  /// نموذجٌ باسم «متطلّب»، فلا يُدَّعى ما ليس موجوداً.
  final int? requirementsRaised;

  final int filesAdded;
  final ReportItemStatus status;
  final ActivityLevel activity;

  /// مجموعُ ما وقع عليه في الفترة — وهو ما صُنّف به [activity].
  final int totalActivities;

  const ItemPerformance({
    required this.id,
    required this.name,
    required this.isWork,
    required this.departmentName,
    required this.isCompleted,
    required this.managerNames,
    required this.executorNames,
    required this.progressNow,
    required this.progressAtStart,
    required this.tasksCompleted,
    required this.tasksAdded,
    required this.tasksLate,
    required this.openTasks,
    required this.lastUpdate,
    required this.daysSinceLastUpdate,
    required this.dueDate,
    required this.remainingDays,
    required this.openBlockers,
    required this.requirementsRaised,
    required this.filesAdded,
    required this.status,
    required this.activity,
    required this.totalActivities,
  });
}

/// مشروعٌ أو عملٌ لم يتحرّك — القائمةُ التي طلبتها بمدّةٍ قابلةٍ للضبط.
class InactiveItem {
  final String id;
  final String name;
  final bool isWork;

  /// المسؤولُ عنه: مديرُ المشروع، أو المُسنَد إليه العمل.
  final String ownerNames;

  final DateTime? lastUpdate;

  /// أيامٌ بلا نشاط — و`null` حين لا تحديث إطلاقاً، وتُعرض «لا تحديث منذ
  /// الإنشاء» لا رقماً مختلقاً.
  final int? daysWithoutActivity;

  final int? openTasks;
  final DateTime dueDate;
  final int remainingDays;

  /// هل هو قريبٌ من موعده — داخل [kDueSoonDays] أو متجاوزٌ له؟ وهذا ما
  /// يفرّق الجمودَ المحتمَل من الجمود الخطر.
  bool get dueSoon => remainingDays <= kDueSoonDays;

  const InactiveItem({
    required this.id,
    required this.name,
    required this.isWork,
    required this.ownerNames,
    required this.lastUpdate,
    required this.daysWithoutActivity,
    required this.openTasks,
    required this.dueDate,
    required this.remainingDays,
  });
}

/// سطرٌ في ورقة «المهام المتأخرة».
class LateTaskLine {
  final String title;
  final String projectName;
  final String departmentName;
  final String assigneeName;
  final DateTime dueDate;
  final int delayDays;

  const LateTaskLine({
    required this.title,
    required this.projectName,
    required this.departmentName,
    required this.assigneeName,
    required this.dueDate,
    required this.delayDays,
  });
}

/// الملخّص التنفيذي — أعلى التقرير.
class ExecutiveDigest {
  final int totalProjects;
  final int lateProjects;
  final int projectsNeedingIntervention;
  final int projectsNotUpdated;
  final int tasksCompleted;
  final int lateTasks;
  final List<String> topDepartments;
  final List<String> departmentsNeedingFollowUp;
  final List<String> mostActivePeople;
  final List<String> idlePeople;
  final List<String> topAchievements;
  final List<String> topBlockers;

  const ExecutiveDigest({
    required this.totalProjects,
    required this.lateProjects,
    required this.projectsNeedingIntervention,
    required this.projectsNotUpdated,
    required this.tasksCompleted,
    required this.lateTasks,
    required this.topDepartments,
    required this.departmentsNeedingFollowUp,
    required this.mostActivePeople,
    required this.idlePeople,
    required this.topAchievements,
    required this.topBlockers,
  });
}

/// التقرير كاملاً.
class PeriodicReport {
  final ReportRange range;
  final ExecutiveDigest digest;
  final List<PersonPerformance> people;
  final List<DepartmentPerformance> departments;
  final List<ItemPerformance> items;
  final List<InactiveItem> inactive;
  final List<LateTaskLine> lateTasks;

  /// المدّةُ التي بُنيت بها قائمةُ [inactive] — تُعرض مع القائمة لا تُخفى:
  /// «١٢ مشروعاً غير نشط» بلا معيارها رقمٌ لا يُراجَع.
  final int inactiveAfterDays;

  const PeriodicReport({
    required this.range,
    required this.digest,
    required this.people,
    required this.departments,
    required this.items,
    required this.inactive,
    required this.lateTasks,
    required this.inactiveAfterDays,
  });
}

/// الفلاتر التسعة — التاسعُ هو الفترة نفسُها ([ReportRange])، وهذه الثمانية.
///
/// ــــ ولماذا تُصفّى المدخلاتُ لا الجداول ــــ
///
/// لأنك طلبت **«تصفية التقرير»** لا تصفية جدول. فلو صُفّي جدولُ المشاريع
/// وحده لَبقي الملخّصُ التنفيذي يقول «٤٠ مشروعاً» بينما الجدول تحته يعرض
/// ثلاثة — وهو تناقضٌ في ورقةٍ واحدة يُفقد التقريرَ ثقته كلَّها.
///
/// فتُطبَّق [applyFilters] على المدخلات **قبل** الحساب، فيتبعها الملخّص
/// وأداءُ الأشخاص والإدارات والمشاريع جميعاً.
class ReportFilters {
  final String? departmentId;
  final String? projectId;
  final String? managerUid;
  final String? executorUid;
  final ProjectStatus? projectStatus;
  final TaskStatus? taskStatus;

  /// المتأخرةُ وحدها — بمقياس نهاية الفترة، كبقيّة التقرير.
  final bool lateOnly;

  /// ما لم يُحدَّث داخل الفترة وحده.
  final bool notUpdatedOnly;

  const ReportFilters({
    this.departmentId,
    this.projectId,
    this.managerUid,
    this.executorUid,
    this.projectStatus,
    this.taskStatus,
    this.lateOnly = false,
    this.notUpdatedOnly = false,
  });

  static const none = ReportFilters();

  bool get isEmpty =>
      departmentId == null &&
      projectId == null &&
      managerUid == null &&
      executorUid == null &&
      projectStatus == null &&
      taskStatus == null &&
      !lateOnly &&
      !notUpdatedOnly;

  ReportFilters copyWith({
    String? departmentId,
    String? projectId,
    String? managerUid,
    String? executorUid,
    ProjectStatus? projectStatus,
    TaskStatus? taskStatus,
    bool? lateOnly,
    bool? notUpdatedOnly,
    bool clearDepartment = false,
    bool clearProject = false,
    bool clearManager = false,
    bool clearExecutor = false,
    bool clearProjectStatus = false,
    bool clearTaskStatus = false,
  }) =>
      ReportFilters(
        departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
        projectId: clearProject ? null : (projectId ?? this.projectId),
        managerUid: clearManager ? null : (managerUid ?? this.managerUid),
        executorUid: clearExecutor ? null : (executorUid ?? this.executorUid),
        projectStatus:
            clearProjectStatus ? null : (projectStatus ?? this.projectStatus),
        taskStatus: clearTaskStatus ? null : (taskStatus ?? this.taskStatus),
        lateOnly: lateOnly ?? this.lateOnly,
        notUpdatedOnly: notUpdatedOnly ?? this.notUpdatedOnly,
      );
}

/// يُصفّي المدخلات، ويُسقط معها كلَّ ما يتعلّق بما خرج.
///
/// والإسقاطُ المتسلسل مقصود: مشروعٌ خرج بالفلتر تخرج معه مهامُّه وتحديثاته
/// وعوائقه — وإلا لَبقيت مهامُّه تُحسب على أشخاصٍ في جدولٍ صُفّي عنه
/// مشروعُهم، فيقرأ المدير أرقاماً لا يجد لها مصدراً.
ReportInput applyFilters(ReportInput input, ReportFilters f, ReportRange range) {
  if (f.isEmpty) return input;

  final updatedInRange =
      input.dailyUpdates.where((u) => range.contains(u.date)).map((u) => u.projectId).toSet();
  final workUpdatedInRange =
      input.workUpdates.where((u) => range.contains(u.date)).map((u) => u.workId).toSet();

  bool keepProject(Project p) {
    if (f.departmentId != null && p.departmentId != f.departmentId) return false;
    if (f.projectId != null && p.id != f.projectId) return false;
    if (f.managerUid != null && !p.managerUids.contains(f.managerUid)) return false;
    if (f.executorUid != null && !p.executorUids.contains(f.executorUid)) return false;
    if (f.projectStatus != null && p.effectiveStatus != f.projectStatus) return false;
    if (f.lateOnly && !isProjectLateAt(p, range.end)) return false;
    if (f.notUpdatedOnly && updatedInRange.contains(p.id)) return false;
    return true;
  }

  bool keepWork(WorkItem w) {
    if (f.departmentId != null && w.departmentId != f.departmentId) return false;
    // فلترُ المشروع يُخرج الأعمال كلَّها: العمل ليس في مشروع، فطلبُ مشروعٍ
    // بعينه طلبٌ لا يشمله.
    if (f.projectId != null) return false;
    // ولا مديرَ للعمل — فتصفيةٌ بمدير مشروعٍ لا تُبقي عملاً.
    if (f.managerUid != null) return false;
    if (f.executorUid != null && w.assigneeUid != f.executorUid) return false;
    if (f.lateOnly && !isWorkLateAt(w, range.end)) return false;
    if (f.notUpdatedOnly && workUpdatedInRange.contains(w.id)) return false;
    return true;
  }

  final projects = input.projects.where(keepProject).toList();
  final works = input.works.where(keepWork).toList();
  final projectIds = projects.map((p) => p.id).toSet();
  final workIds = works.map((w) => w.id).toSet();

  final tasks = input.tasks
      .where((t) =>
          projectIds.contains(t.projectId) &&
          (f.taskStatus == null || t.status == f.taskStatus))
      .toList();
  final dailyUpdates =
      input.dailyUpdates.where((u) => projectIds.contains(u.projectId)).toList();
  final workUpdates = input.workUpdates.where((u) => workIds.contains(u.workId)).toList();

  // ــــ والأشخاصُ يُصفَّون كما تُصفّى بقيّةُ المدخلات ــــ
  //
  // ولم يكونوا يُصفَّون: كانت الدالّة تُضيّق سبعَ قوائم وتترك `users`، فيبقى
  // موظفو الوزارة كلُّهم في جدول الأشخاص وأكثرُهم بأصفار — لأن مشاريعهم
  // صُفّيت عنهم وبقيت أسماؤهم. وهو ما بلّغ عنه مسؤول النظام: «اخترتُ إدارةً
  // محدّدة ويظهر موظفو الإدارات كلِّها».
  //
  // ــ والقاعدةُ: من بقي له أثرٌ في التقرير يظهر ــ
  //
  // عضوٌ في مشروعٍ باقٍ، أو مُسنَدةٌ إليه مهمّةٌ أو عملٌ باقٍ، أو كتب تحديثاً
  // باقياً. وأرقامُ هؤلاء محسوبةٌ في جداول المشاريع والأعمال، فإخفاؤهم يجعل
  // الجدولين لا يتطابقان — ويسأل القارئ عن رقمٍ لا يجد له صاحباً.
  //
  // فمنفّذٌ من إدارةٍ أخرى يعمل في مشروع هذه الإدارة **يظهر**.
  //
  // ــ ويُضاف الانتماءُ حين تُختار إدارة ــ
  //
  // ليظهر الخاملُ فيها بأصفاره: كشفُ من لم يعمل هو أصلُ الغرض من الجدول،
  // ولو اقتُصر على «من له أثر» لَاختفى المقصّر — وهو أوّلُ من يُراد.
  final memberUids = <String>{
    for (final p in projects) ...p.managerUids,
    for (final p in projects) ...p.executorUids,
    for (final t in tasks) t.assigneeUid,
    for (final w in works) w.assigneeUid,
    for (final u in dailyUpdates) u.authorUid,
    for (final u in workUpdates) u.authorUid,
  }..removeWhere((uid) => uid.isEmpty);

  final users = input.users
      .where((u) => memberUids.contains(u.id) || u.belongsToDepartment(f.departmentId))
      .toList();

  return input.copyWith(
    projects: projects,
    works: works,
    tasks: tasks,
    dailyUpdates: dailyUpdates,
    workUpdates: workUpdates,
    users: users,
    risks: input.risks.where((r) => projectIds.contains(r.projectId)).toList(),
    blockers: input.blockers.where((b) => projectIds.contains(b.projectId)).toList(),
    departments: f.departmentId == null
        ? input.departments
        : input.departments.where((d) => d.id == f.departmentId).toList(),
  );
}

/// مدخلاتُ الحساب — قوائمُ المتجر كما هي.
///
/// ولا تُصفّى بالنطاق هنا: صاحبُ التقرير لا يحمل إلا ما تسمح له القواعد
/// بقراءته أصلاً، فمديرُ الإدارة يُحسب تقريرُه على إدارته بلا شرطٍ يُكتب
/// هنا ويُنسى هناك.
class ReportInput {
  final List<Project> projects;
  final List<WorkItem> works;
  final List<ProjectTask> tasks;
  final List<DailyUpdate> dailyUpdates;
  final List<WorkUpdate> workUpdates;
  final List<AppUser> users;
  final List<Department> departments;

  /// المخاطرُ والعوائق المسجّلة — تُقرأ منها **القائمة** وحدها، لا كلُّ ما
  /// سُجّل يوماً: عائقٌ حُلّ لا يُحسب على مشروعه.
  final List<ProjectRisk> risks;
  final List<ProjectBlocker> blockers;

  /// كم يوماً بلا تحديثٍ يصير بعدها المشروع «غير نشط» — إعدادٌ يضبطه مسؤول
  /// النظام، ومبدئيُّه [kDefaultInactiveAfterDays].
  ///
  /// ويُمرَّر عبر المدخلات لا يُقرأ من متجرٍ داخل الحساب: الوحدةُ نقيّة،
  /// ولأن اختباراً يُمرّر ثلاثةً ثم أربعةَ عشرَ على المدخلات نفسها يُثبت
  /// أن الإعداد **يُقرأ فعلاً** لا يُحفظ ويُهمَل.
  final int inactiveAfterDays;

  const ReportInput({
    required this.projects,
    required this.works,
    required this.tasks,
    required this.dailyUpdates,
    required this.workUpdates,
    required this.users,
    required this.departments,
    this.risks = const [],
    this.blockers = const [],
    this.inactiveAfterDays = kDefaultInactiveAfterDays,
  });

  /// نسخةٌ بقوائم مُصفّاة — يستعملها [applyFilters] ولا يُعاد بناء المُنشئ
  /// في كل موضع، فحقلٌ جديدٌ يُنسى نسخُه لا يمرّ صامتاً.
  ReportInput copyWith({
    List<Project>? projects,
    List<WorkItem>? works,
    List<ProjectTask>? tasks,
    List<DailyUpdate>? dailyUpdates,
    List<WorkUpdate>? workUpdates,
    List<AppUser>? users,
    List<Department>? departments,
    List<ProjectRisk>? risks,
    List<ProjectBlocker>? blockers,
    int? inactiveAfterDays,
  }) =>
      ReportInput(
        projects: projects ?? this.projects,
        works: works ?? this.works,
        tasks: tasks ?? this.tasks,
        dailyUpdates: dailyUpdates ?? this.dailyUpdates,
        workUpdates: workUpdates ?? this.workUpdates,
        users: users ?? this.users,
        departments: departments ?? this.departments,
        risks: risks ?? this.risks,
        blockers: blockers ?? this.blockers,
        inactiveAfterDays: inactiveAfterDays ?? this.inactiveAfterDays,
      );
}

/// أكثرُ ما يُعرض من قوائم النصّ: سطرٌ طويلٌ لا يُقرأ في تقرير.
const int kTopListSize = 5;

PeriodicReport buildPeriodicReport(
  ReportInput raw,
  ReportRange range, {
  ReportFilters filters = ReportFilters.none,
}) {
  final input = applyFilters(raw, filters, range);
  final people = _buildPeople(input, range);
  final departments = _buildDepartments(input, range, people);
  final items = _buildItems(input, range);
  return PeriodicReport(
    range: range,
    digest: _buildDigest(input, range, people, departments),
    people: people,
    departments: departments,
    items: items,
    inactive: _buildInactive(items, input),
    lateTasks: _buildLateTasks(input, range),
    inactiveAfterDays: input.inactiveAfterDays,
  );
}

// ───────────────────────────── الأشخاص ─────────────────────────────

List<PersonPerformance> _buildPeople(ReportInput input, ReportRange range) {
  // المعتمَدون وحدهم: من ينتظر الاعتماد أو أُوقف حسابُه ليس مقصّراً في
  // العمل — وإدراجُه «بلا نشاط» يُحصي عليه غيابَ صلاحيةٍ لا غيابَ عمل.
  final active = input.users.where((u) => u.status == UserStatus.approved).toList();
  final projectById = {for (final p in input.projects) p.id: p};
  final workById = {for (final w in input.works) w.id: w};

  final result = <PersonPerformance>[];
  for (final user in active) {
    final uid = user.id;

    final myUpdates = input.dailyUpdates
        .where((u) => u.authorUid == uid && range.contains(u.date))
        .toList();
    final myWorkUpdates = input.workUpdates
        .where((u) => u.authorUid == uid && range.contains(u.date))
        .toList();

    // المرفقات والمخاطر والعوائق تُنسب عبر التحديث الذي وُلدت منه.
    var attachments = 0;
    var risks = 0;
    var blockers = 0;
    for (final u in myUpdates) {
      attachments += u.attachments.length;
      risks += u.newRisks.length;
      blockers += u.blockers.length;
    }
    for (final u in myWorkUpdates) {
      attachments += u.attachments.length;
    }

    final addedInRange = input.tasks
        .where((t) => t.createdByUid == uid && t.createdAt != null && range.contains(t.createdAt!))
        .length;

    final mine = input.tasks.where((t) => t.assigneeUid == uid).toList();
    final completedInRange = mine
        .where((t) => t.isDone && t.completedAt != null && range.contains(t.completedAt!))
        .toList();
    var onTime = 0;
    var late = 0;
    for (final t in completedInRange) {
      if (t.finishedOnTime == true) {
        onTime++;
      } else {
        late++;
      }
    }
    // منجَزةٌ بلا تاريخ: تُعدّ ولا تُصنَّف — «غير مسجّل» لا «متأخرة».
    final undated = mine.where((t) => t.isDone && t.completedAt == null).length;

    final lateAssigned = mine.where((t) => isTaskLateAt(t, range.end)).length;

    // ما شارك فيه: عضويةً في مشروع، أو إسناداً لعمل، أو كتابةً لتحديث عليه.
    final projectIds = <String>{
      for (final p in input.projects)
        if (p.hasMember(uid)) p.id,
      for (final u in myUpdates) u.projectId,
    };
    final workIds = <String>{
      for (final w in input.works)
        if (w.assigneeUid == uid) w.id,
      for (final u in myWorkUpdates) u.workId,
    };

    // آخرُ أثر: أحدثُ ما فعله، أيّاً كان نوعه — وخارجَ الفترة كذلك، فسؤالُ
    // «متى آخر مرّة تحرّك؟» لا معنى له محصوراً بالفترة التي نسأل عنها.
    DateTime? last;
    void note(DateTime? d) {
      if (d == null) return;
      if (last == null || d.isAfter(last!)) last = d;
    }
    for (final u in input.dailyUpdates.where((u) => u.authorUid == uid)) {
      note(u.date);
    }
    for (final u in input.workUpdates.where((u) => u.authorUid == uid)) {
      note(u.date);
    }
    for (final t in input.tasks.where((t) => t.assigneeUid == uid || t.createdByUid == uid)) {
      note(t.completedAt);
      note(t.createdAt);
    }

    final person = PersonPerformance(
      uid: uid,
      name: user.name,
      departmentId: user.departmentId,
      role: user.role,
      tasksCompleted: completedInRange.length,
      tasksAdded: addedInRange,
      dailyUpdates: myUpdates.length,
      workUpdates: myWorkUpdates.length,
      attachmentsUploaded: attachments,
      risksRaised: risks,
      blockersRaised: blockers,
      lateTasksAssigned: lateAssigned,
      finishedOnTime: onTime,
      finishedLate: late,
      tasksWithoutCompletionDate: undated,
      projectNames: projectIds
          .map((id) => projectById[id]?.name)
          .whereType<String>()
          .toList()
        ..sort(),
      workTitles: workIds.map((id) => workById[id]?.title).whereType<String>().toList()..sort(),
      lastActivity: last,
      activity: ActivityLevel.none,
    );
    result.add(_withActivity(person, range.period));
  }

  // الأنشطُ أوّلاً، ومن لا نشاط له في الآخر — فالتقرير يُقرأ من أعلاه.
  result.sort((a, b) {
    final byActivity = b.totalActivities.compareTo(a.totalActivities);
    return byActivity != 0 ? byActivity : a.name.compareTo(b.name);
  });
  return result;
}

PersonPerformance _withActivity(PersonPerformance p, ReportPeriod period) => PersonPerformance(
      uid: p.uid,
      name: p.name,
      departmentId: p.departmentId,
      role: p.role,
      tasksCompleted: p.tasksCompleted,
      tasksAdded: p.tasksAdded,
      dailyUpdates: p.dailyUpdates,
      workUpdates: p.workUpdates,
      attachmentsUploaded: p.attachmentsUploaded,
      risksRaised: p.risksRaised,
      blockersRaised: p.blockersRaised,
      lateTasksAssigned: p.lateTasksAssigned,
      finishedOnTime: p.finishedOnTime,
      finishedLate: p.finishedLate,
      tasksWithoutCompletionDate: p.tasksWithoutCompletionDate,
      projectNames: p.projectNames,
      workTitles: p.workTitles,
      lastActivity: p.lastActivity,
      activity: activityLevelFor(p.totalActivities, period),
    );

// ───────────────────────────── الإدارات ─────────────────────────────

List<DepartmentPerformance> _buildDepartments(
  ReportInput input,
  ReportRange range,
  List<PersonPerformance> people,
) {
  final result = <DepartmentPerformance>[];
  for (final dept in input.departments) {
    final projects = input.projects.where((p) => p.departmentId == dept.id).toList();
    final works = input.works.where((w) => w.departmentId == dept.id).toList();
    final projectIds = projects.map((p) => p.id).toSet();
    final tasks = input.tasks.where((t) => projectIds.contains(t.projectId)).toList();
    final updates = input.dailyUpdates
        .where((u) => projectIds.contains(u.projectId) && range.contains(u.date))
        .toList();

    final updatedIds = updates.map((u) => u.projectId).toSet();
    final blockedIds = updates.where((u) => u.blockers.isNotEmpty).map((u) => u.projectId).toSet();

    final lateProjects = projects.where((p) => isProjectLateAt(p, range.end)).toList();
    // ما يحتاج تدخّلاً: متأخّرٌ أو عليه عائقٌ سُجّل في الفترة. والمجموعة
    // لا الجمع — فمشروعٌ متأخرٌ وعليه عائق واحدٌ لا اثنان.
    final needing = <String>{
      for (final p in lateProjects) p.id,
      ...blockedIds,
    };

    final deptPeople = people.where((p) => p.departmentId == dept.id).toList();

    result.add(DepartmentPerformance(
      departmentId: dept.id,
      name: dept.name,
      projectCount: projects.length,
      workCount: works.length,
      tasksCompleted: tasks
          .where((t) => t.isDone && t.completedAt != null && range.contains(t.completedAt!))
          .length,
      tasksAdded: tasks
          .where((t) => t.createdAt != null && range.contains(t.createdAt!))
          .length,
      lateTasks: tasks.where((t) => isTaskLateAt(t, range.end)).length,
      lateProjects: lateProjects.length,
      projectsWithoutRecentUpdate:
          projects.where((p) => !updatedIds.contains(p.id)).length,
      projectsNeedingIntervention: needing.length,
      avgProgress: projects.isEmpty
          ? 0
          : projects.map((p) => p.progressPercent).reduce((a, b) => a + b) / projects.length,
      activePeople: deptPeople.where((p) => !p.hasNoActivity).length,
      idlePeople: deptPeople.where((p) => p.hasNoActivity).length,
      avgUpdatesPerProject:
          projects.isEmpty ? 0 : updates.length / projects.length,
      topAchievements: _topLines(updates.map((u) => u.achievements)),
      topBlockers: _topLines(updates.expand((u) => u.blockers)),
      activity: activityLevelFor(updates.length, range.period),
    ));
  }
  result.sort((a, b) => b.avgProgress.compareTo(a.avgProgress));
  return result;
}

/// أبرزُ سطورٍ من نصٍّ حرّ — بلا فراغٍ ولا تكرار، ومحدودةُ العدد.
List<String> _topLines(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final line in raw) {
    final text = line.trim().split('\n').first.trim();
    if (text.isEmpty || !seen.add(text)) continue;
    out.add(text);
    if (out.length >= kTopListSize) break;
  }
  return out;
}

// ───────────────────────── الملخّص التنفيذي ─────────────────────────

ExecutiveDigest _buildDigest(
  ReportInput input,
  ReportRange range,
  List<PersonPerformance> people,
  List<DepartmentPerformance> departments,
) {
  final updatedIds = input.dailyUpdates
      .where((u) => range.contains(u.date))
      .map((u) => u.projectId)
      .toSet();
  final withActivity = people.where((p) => !p.hasNoActivity).toList();
  final idle = people.where((p) => p.hasNoActivity).toList();

  // الإداراتُ التي تحتاج متابعة: بها مشاريعُ تحتاج تدخّلاً — لا الأقلُّ
  // إنجازاً. فإدارةٌ مشاريعُها صغيرةٌ ومتأخّرة أولى بالمتابعة من إدارةٍ
  // نسبتُها أدنى ومشاريعُها تسير.
  final needFollowUp = departments
      .where((d) => d.projectsNeedingIntervention > 0 || d.idlePeople > 0)
      .toList()
    ..sort((a, b) => b.projectsNeedingIntervention.compareTo(a.projectsNeedingIntervention));

  return ExecutiveDigest(
    totalProjects: input.projects.length,
    lateProjects: input.projects.where((p) => isProjectLateAt(p, range.end)).length,
    projectsNeedingIntervention:
        departments.fold(0, (sum, d) => sum + d.projectsNeedingIntervention),
    projectsNotUpdated: input.projects.where((p) => !updatedIds.contains(p.id)).length,
    tasksCompleted: departments.fold(0, (sum, d) => sum + d.tasksCompleted),
    lateTasks: departments.fold(0, (sum, d) => sum + d.lateTasks),
    topDepartments:
        departments.where((d) => d.projectCount > 0).take(kTopListSize).map((d) => d.name).toList(),
    departmentsNeedingFollowUp:
        needFollowUp.take(kTopListSize).map((d) => d.name).toList(),
    mostActivePeople: withActivity.take(kTopListSize).map((p) => p.name).toList(),
    idlePeople: idle.map((p) => p.name).toList(),
    topAchievements: _topLines(
      input.dailyUpdates.where((u) => range.contains(u.date)).map((u) => u.achievements),
    ),
    topBlockers: _topLines(
      input.dailyUpdates.where((u) => range.contains(u.date)).expand((u) => u.blockers),
    ),
  );
}

// ───────────────────── المشاريع والأعمال ─────────────────────

/// أسماءُ حساباتٍ بأعيانها — والمجهولُ يُترك خارجاً لا يُكتب معرّفاً خاماً.
String _namesOf(Iterable<String> uids, Map<String, AppUser> byId) {
  final names = [
    for (final id in uids)
      if (byId[id] != null) byId[id]!.name,
  ];
  return names.join('، ');
}

/// أيامٌ بين تاريخين، بدقّة اليوم لا الساعة.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime(to.year, to.month, to.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;

List<ItemPerformance> _buildItems(ReportInput input, ReportRange range) {
  final userById = {for (final u in input.users) u.id: u};
  final deptById = {for (final d in input.departments) d.id: d};
  final result = <ItemPerformance>[];

  for (final p in input.projects) {
    final updates = input.dailyUpdates.where((u) => u.projectId == p.id).toList();
    final inRange = updates.where((u) => range.contains(u.date)).toList();
    final tasks = input.tasks.where((t) => t.projectId == p.id).toList();

    // الحالُ عند بداية الفترة: آخرُ تحديثٍ قبلها. وبلا تحديثٍ سابق لا أساس
    // للمقارنة — فلا يُفترض صفر.
    final before = updates.where((u) => range.isBefore(u.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final lastUpdate = updates.isEmpty
        ? null
        : updates.map((u) => u.date).reduce((a, b) => a.isAfter(b) ? a : b);

    final openBlockers = input.blockers
        .where((b) => b.projectId == p.id && b.status == ItemStatus.open)
        .length;
    final files = inRange.fold<int>(0, (n, u) => n + u.attachments.length);
    final requirements =
        inRange.fold<int>(0, (n, u) => n + u.decisionsRequired.length);
    final completed = tasks
        .where((t) => t.isDone && t.completedAt != null && range.contains(t.completedAt!))
        .length;
    final added =
        tasks.where((t) => t.createdAt != null && range.contains(t.createdAt!)).length;
    final stalled = lastUpdate == null ? null : _daysBetween(lastUpdate, range.end);

    final activities = inRange.length + completed + added + files + openBlockers;

    result.add(ItemPerformance(
      id: p.id,
      name: p.name,
      isWork: false,
      departmentName: deptById[p.departmentId]?.name ?? '',
      isCompleted: p.status == ProjectStatus.completed,
      managerNames: _namesOf(p.managerUids, userById),
      // أسماءُ المنفذين المكتوبة نصّاً تُضمّ إلى أصحاب الحسابات: مشاريعُ
      // الوزارة المستوردة تحمل الأسماء نصّاً بلا حسابات.
      executorNames: {
        ..._namesOf(p.executorUids, userById).split('، ').where((e) => e.isNotEmpty),
        ...p.executorNames.map((e) => e.trim()).where((e) => e.isNotEmpty),
      }.join('، '),
      progressNow: p.progressPercent,
      progressAtStart: before.isEmpty ? null : before.last.progressPercent,
      tasksCompleted: completed,
      tasksAdded: added,
      tasksLate: tasks.where((t) => isTaskLateAt(t, range.end)).length,
      openTasks: tasks.where((t) => !t.isDone).length,
      lastUpdate: lastUpdate,
      daysSinceLastUpdate: stalled,
      dueDate: p.dueDate,
      remainingDays: _daysBetween(range.end, p.dueDate),
      openBlockers: openBlockers,
      requirementsRaised: requirements,
      filesAdded: files,
      status: reportItemStatus(
        isCompleted: p.status == ProjectStatus.completed,
        isLate: isProjectLateAt(p, range.end),
        hasOpenBlocker: openBlockers > 0,
        stalledDays: stalled,
        inactiveAfterDays: input.inactiveAfterDays,
      ),
      activity: activityLevelFor(activities, range.period),
      totalActivities: activities,
    ));
  }

  for (final w in input.works) {
    final updates = input.workUpdates.where((u) => u.workId == w.id).toList();
    final inRange = updates.where((u) => range.contains(u.date)).toList();
    final before = updates.where((u) => range.isBefore(u.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final lastUpdate = updates.isEmpty
        ? null
        : updates.map((u) => u.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final files = inRange.fold<int>(0, (n, u) => n + u.attachments.length);
    final stalled = lastUpdate == null ? null : _daysBetween(lastUpdate, range.end);
    final activities = inRange.length + files;

    result.add(ItemPerformance(
      id: w.id,
      name: w.title,
      isWork: true,
      departmentName: deptById[w.departmentId]?.name ?? '',
      isCompleted: w.isDone,
      // العملُ يُسنَد ولا يُدار: لا مدير له، ولا يُكتب اسمُ المُسنَد إليه
      // في خانة المدير فيُقرأ مسؤولاً عمّا ليس مسؤولاً عنه.
      managerNames: '',
      executorNames: w.assigneeName,
      progressNow: w.progressPercent,
      progressAtStart: before.isEmpty ? null : before.last.progressPercent,
      // المهامُّ والعوائق والمتطلبات معلّقةٌ بالمشروع في هذه المنصة، فلا
      // تنطبق على العمل — و`null` تُعرض «—» لا صفراً.
      tasksCompleted: null,
      tasksAdded: null,
      tasksLate: null,
      openTasks: null,
      lastUpdate: lastUpdate,
      daysSinceLastUpdate: stalled,
      dueDate: w.dueDate,
      remainingDays: _daysBetween(range.end, w.dueDate),
      openBlockers: null,
      requirementsRaised: null,
      filesAdded: files,
      status: reportItemStatus(
        isCompleted: w.isDone,
        isLate: isWorkLateAt(w, range.end),
        hasOpenBlocker: false,
        stalledDays: stalled,
        inactiveAfterDays: input.inactiveAfterDays,
      ),
      activity: activityLevelFor(activities, range.period),
      totalActivities: activities,
    ));
  }

  // الأشدُّ حاجةً أوّلاً، ثم الأطولُ جموداً — فالتقرير يُقرأ من أعلاه.
  result.sort((a, b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return byStatus;
    final aStalled = a.daysSinceLastUpdate ?? 1 << 30;
    final bStalled = b.daysSinceLastUpdate ?? 1 << 30;
    final byStalled = bStalled.compareTo(aStalled);
    return byStalled != 0 ? byStalled : a.name.compareTo(b.name);
  });
  return result;
}

// ───────────────────── ما لم يتحرّك ─────────────────────

/// القائمةُ تُبنى من [items] لا من المدخلات ثانيةً: حسابُ «آخر تحديث» مرّةً
/// واحدة يمنع أن يفترق رقمُ الجدولين في ورقةٍ واحدة.
///
/// **والمكتملُ يخرج منها**: مشروعٌ أُنجز لا يُنتظر منه تحديث، وإدراجُه في
/// «غير النشط» يُطيل القائمة بما لا يحتاج متابعةً — فتُهمَل كلُّها.
List<InactiveItem> _buildInactive(List<ItemPerformance> items, ReportInput input) {
  final result = <InactiveItem>[];
  for (final it in items) {
    // المكتملُ يخرج: أُنجز فلا يُنتظر منه تحديث.
    if (it.isCompleted) continue;
    final days = it.daysSinceLastUpdate;
    // ومن لا تحديث له إطلاقاً يدخل: غيابُ التحديث منذ الإنشاء أطولُ جموداً
    // لا براءةٌ منه.
    if (days != null && days < input.inactiveAfterDays) continue;

    result.add(InactiveItem(
      id: it.id,
      name: it.name,
      isWork: it.isWork,
      ownerNames: it.managerNames.isNotEmpty ? it.managerNames : it.executorNames,
      lastUpdate: it.lastUpdate,
      daysWithoutActivity: days,
      openTasks: it.openTasks,
      dueDate: it.dueDate,
      remainingDays: it.remainingDays,
    ));
  }
  // الأطولُ جموداً أوّلاً، ومن لا تحديث له قبله — فهو أقدمُ الجمود لا أحدثه.
  result.sort((a, b) {
    final aDays = a.daysWithoutActivity ?? 1 << 30;
    final bDays = b.daysWithoutActivity ?? 1 << 30;
    final byDays = bDays.compareTo(aDays);
    return byDays != 0 ? byDays : a.name.compareTo(b.name);
  });
  return result;
}

// ───────────────────── المهام المتأخرة ─────────────────────

List<LateTaskLine> _buildLateTasks(ReportInput input, ReportRange range) {
  final projectById = {for (final p in input.projects) p.id: p};
  final deptById = {for (final d in input.departments) d.id: d};
  final lines = [
    for (final t in input.tasks)
      if (isTaskLateAt(t, range.end))
        LateTaskLine(
          title: t.title,
          projectName: projectById[t.projectId]?.name ?? '',
          departmentName: deptById[t.departmentId]?.name ?? '',
          // بلا اسمٍ يُقال «غير مُسنَدة» صراحةً: خانةٌ فارغة تُقرأ عطلاً
          // في العرض، وهذه حالةٌ حقيقية لا نقصُ بيان.
          assigneeName: t.assigneeName.trim().isEmpty ? 'غير مُسنَدة' : t.assigneeName,
          dueDate: t.dueDate,
          delayDays: _daysBetween(t.dueDate, range.end),
        ),
  ];
  lines.sort((a, b) => b.delayDays.compareTo(a.delayDays));
  return lines;
}
