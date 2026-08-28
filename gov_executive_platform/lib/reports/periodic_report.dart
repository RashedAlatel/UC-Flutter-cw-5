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
import '../models/daily_update.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
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

  const PeriodicReport({
    required this.range,
    required this.digest,
    required this.people,
    required this.departments,
  });
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

  const ReportInput({
    required this.projects,
    required this.works,
    required this.tasks,
    required this.dailyUpdates,
    required this.workUpdates,
    required this.users,
    required this.departments,
  });
}

/// أكثرُ ما يُعرض من قوائم النصّ: سطرٌ طويلٌ لا يُقرأ في تقرير.
const int kTopListSize = 5;

PeriodicReport buildPeriodicReport(ReportInput input, ReportRange range) {
  final people = _buildPeople(input, range);
  final departments = _buildDepartments(input, range, people);
  return PeriodicReport(
    range: range,
    digest: _buildDigest(input, range, people, departments),
    people: people,
    departments: departments,
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

    final lateProjects =
        projects.where((p) => p.effectiveStatus == ProjectStatus.delayed).toList();
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
    lateProjects:
        input.projects.where((p) => p.effectiveStatus == ProjectStatus.delayed).length,
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
