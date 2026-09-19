/// حملُ الموظّف — **موزونٌ لا معدود**.
///
/// ــــ لماذا لا يكفي العدّ ــــ
///
/// «عليه سبعُ مهامّ» لا تقول شيئاً: سبعُ مهامّ منخفضة الأولويّة مواعيدُها
/// بعد شهرين أخفُّ من مهمّتين حرجتين تستحقّان غداً. ومديرٌ يوازن بالعدد
/// يُحمّل المثقَلَ ويترك الفارغ.
///
/// فالوزنُ يقرأ أربعةً: **الأولويّة**، و**قربَ الموعد**، و**التأخُّر**،
/// و**عددَ المشاريع الجارية**. وكلٌّ منها يُضاعف لا يُجمع وحدَه.
///
/// ــــ والأوزانُ مكتوبةٌ هنا لا مدفونة ــــ
///
/// تُقرأ من [WorkloadWeights]، فمن أراد وزناً آخرَ للحرِج غيّره في موضعٍ
/// واحد. وهي اليومَ ثابتةٌ في الشيفرة — ووضعُها في إعدادات النظام خطوةٌ
/// تالية، لا يمنعها شيءٌ في هذا التصميم.
library;

import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/work_item.dart';

/// أوزانُ الحمل — ومنها يُحسب الرقم.
class WorkloadWeights {
  /// وزنُ البندِ بأولويّته.
  final double critical;
  final double high;
  final double medium;
  final double low;

  /// ما يُضاف للبند المتأخّر — **والتأخُّرُ يُثقل مرّتين**: عملٌ لم يُنجَز
  /// في وقته يبقى، ويُضاف إليه ضغطُ من ينتظره.
  final double overdueBonus;

  /// ما يُضاف للبند المستحقّ خلال [dueSoonDays].
  final double dueSoonBonus;
  final int dueSoonDays;

  /// وزنُ المشروع الجاري — أثقلُ من مهمّة: فيه اجتماعاتُه ومتابعتُه.
  final double activeProject;

  const WorkloadWeights({
    this.critical = 5,
    this.high = 3,
    this.medium = 2,
    this.low = 1,
    this.overdueBonus = 3,
    this.dueSoonBonus = 1.5,
    this.dueSoonDays = 3,
    this.activeProject = 4,
  });

  double ofPriority(PriorityLevel p) => switch (p) {
        PriorityLevel.critical => critical,
        PriorityLevel.high => high,
        PriorityLevel.medium => medium,
        PriorityLevel.low => low,
      };
}

/// تصنيفُ الحمل — وهو ما يُقرأ بنظرة.
enum LoadBand {
  /// أقلُّ ممّا يحتمل — يُسنَد إليه.
  underloaded('حملٌ خفيف'),
  normal('حملٌ معتدل'),
  high('حملٌ مرتفع'),

  /// فوق طاقته — **ولا يُسنَد إليه شيءٌ قبل أن يُخفَّف عنه**.
  overloaded('حملٌ زائد');

  final String label;
  const LoadBand(this.label);
}

/// حملُ موظّفٍ واحدٍ بتفصيله.
class Workload {
  final String uid;
  final String name;
  final String departmentId;

  final int activeProjects;
  final int activeTasks;
  final int activeWorks;
  final int criticalItems;
  final int overdueItems;
  final int dueSoonItems;

  /// الرقمُ الموزون.
  final double score;
  final LoadBand band;

  const Workload({
    required this.uid,
    required this.name,
    required this.score,
    required this.band,
    this.departmentId = '',
    this.activeProjects = 0,
    this.activeTasks = 0,
    this.activeWorks = 0,
    this.criticalItems = 0,
    this.overdueItems = 0,
    this.dueSoonItems = 0,
  });

  /// أليس عليه شيءٌ جارٍ؟ — وهو غيرُ «خفيف الحمل».
  ///
  /// والفرقُ يُقال: من لا عملَ عليه أصلاً حالٌ تحتاج قراراً، ومن عليه القليلُ
  /// يحتمل المزيد.
  bool get isIdle => activeProjects == 0 && activeTasks == 0 && activeWorks == 0;
}

/// يحسب أحمالَ فريقٍ — **من المرئيّ لا من الكلّ**.
class WorkloadEngine {
  /// حدودُ التصنيف — والنصفُ الأعلى مفتوح.
  static const double normalFrom = 6;
  static const double highFrom = 14;
  static const double overloadedFrom = 24;

  static LoadBand bandOf(double score) {
    if (score >= overloadedFrom) return LoadBand.overloaded;
    if (score >= highFrom) return LoadBand.high;
    if (score >= normalFrom) return LoadBand.normal;
    return LoadBand.underloaded;
  }

  /// يحسب حملَ كلّ موظّفٍ في [people].
  ///
  /// و[projects] و[tasks] و[works] مصفّاةٌ بالنطاق قبل الدخول: هذه الوحدةُ
  /// لا تعرف من يقرأ ولا تفحص صلاحية — كما في `attention.dart`.
  static List<Workload> build({
    required List<({String uid, String name, String departmentId})> people,
    required List<Project> projects,
    required List<ProjectTask> tasks,
    required List<WorkItem> works,
    DateTime? now,
    WorkloadWeights weights = const WorkloadWeights(),
  }) {
    final today = now ?? DateTime.now();
    final out = <Workload>[];

    for (final person in people) {
      var score = 0.0;
      var criticalItems = 0;
      var overdueItems = 0;
      var dueSoonItems = 0;

      final myProjects = projects
          .where((p) => p.hasMember(person.uid) && p.effectiveStatus != ProjectStatus.completed)
          .toList();
      score += myProjects.length * weights.activeProject;

      final myTasks = tasks.where((t) => t.assigneeUid == person.uid && !t.isDone).toList();
      for (final t in myTasks) {
        score += weights.ofPriority(t.priority);
        if (t.priority == PriorityLevel.critical) criticalItems++;
        final late = _lateDays(t.dueDate, today);
        if (late > 0) {
          score += weights.overdueBonus;
          overdueItems++;
        } else if (_daysUntil(t.dueDate, today) <= weights.dueSoonDays) {
          score += weights.dueSoonBonus;
          dueSoonItems++;
        }
      }

      final myWorks = works.where((w) => w.assigneeUid == person.uid && !w.isDone).toList();
      for (final w in myWorks) {
        score += weights.ofPriority(w.priority);
        if (w.priority == PriorityLevel.critical) criticalItems++;
        final late = _lateDays(w.dueDate, today);
        if (late > 0) {
          score += weights.overdueBonus;
          overdueItems++;
        } else if (_daysUntil(w.dueDate, today) <= weights.dueSoonDays) {
          score += weights.dueSoonBonus;
          dueSoonItems++;
        }
      }

      out.add(Workload(
        uid: person.uid,
        name: person.name,
        departmentId: person.departmentId,
        activeProjects: myProjects.length,
        activeTasks: myTasks.length,
        activeWorks: myWorks.length,
        criticalItems: criticalItems,
        overdueItems: overdueItems,
        dueSoonItems: dueSoonItems,
        score: score,
        band: bandOf(score),
      ));
    }

    // الأثقلُ أوّلاً: من يفتح الشاشةَ يسأل «من فوق طاقته؟» قبل «من فارغ؟».
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// عددُ الموظّفين في كلّ تصنيف — لبطاقات اللوحة.
  static Map<LoadBand, int> countByBand(List<Workload> loads) {
    final counts = {for (final b in LoadBand.values) b: 0};
    for (final l in loads) {
      counts[l.band] = (counts[l.band] ?? 0) + 1;
    }
    return counts;
  }
}

int _lateDays(DateTime due, DateTime now) {
  final d = DateTime(due.year, due.month, due.day);
  final t = DateTime(now.year, now.month, now.day);
  return t.isAfter(d) ? t.difference(d).inDays : 0;
}

int _daysUntil(DateTime due, DateTime now) {
  final d = DateTime(due.year, due.month, due.day);
  final t = DateTime(now.year, now.month, now.day);
  return d.difference(t).inDays;
}
