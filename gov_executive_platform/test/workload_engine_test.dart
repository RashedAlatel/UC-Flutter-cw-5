// حملُ الموظّف — **موزونٌ لا معدود**.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) أنّ **العدّ وحدَه يُضلّل**: موظّفٌ عليه سبعُ مهامّ خفيفةٍ بعيدةِ
//     الموعد أخفُّ من آخرَ عليه مهمّتان حرجتان متأخّرتان. ومديرٌ يوازن
//     بالعدد يُحمّل المثقَلَ ويترك الفارغ.
// (٢) وأنّ **المنجَزَ لا يُثقل**: عملٌ أُغلق لا يبقى في ميزان صاحبه.
// (٣) وأنّ «لا عملَ عليه» غيرُ «حملُه خفيف» — الأولى حالٌ تحتاج قراراً.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_task.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/reports/workload.dart';

final _now = DateTime(2026, 9, 20);

ProjectTask _task({
  String id = 't1',
  String uid = 'u1',
  PriorityLevel priority = PriorityLevel.medium,
  int dueInDays = 30,
  TaskStatus status = TaskStatus.inProgress,
}) =>
    ProjectTask(
      id: id,
      projectId: 'p1',
      departmentId: 'd1',
      title: 'مهمّة',
      assigneeUid: uid,
      assigneeName: 'موظّف',
      status: status,
      progressPercent: 20,
      lastUpdated: _now,
      dueDate: _now.add(Duration(days: dueInDays)),
      priority: priority,
    );

WorkItem _work({
  String id = 'w1',
  String uid = 'u1',
  PriorityLevel priority = PriorityLevel.medium,
  int dueInDays = 30,
  TaskStatus status = TaskStatus.inProgress,
}) =>
    WorkItem(
      id: id,
      title: 'عمل',
      description: '',
      departmentId: 'd1',
      assigneeUid: uid,
      assigneeName: 'موظّف',
      status: status,
      priority: priority,
      progressPercent: 10,
      dueDate: _now.add(Duration(days: dueInDays)),
      createdByUid: 'admin',
      createdAt: _now,
    );

Project _project({
  String id = 'p1',
  String uid = 'u1',
  double progress = 30,
  ProjectStatus status = ProjectStatus.onTrack,
}) =>
    Project(
      id: id,
      departmentId: 'd1',
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: _now.add(const Duration(days: 60)),
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: progress,
      executorUids: [uid],
    );

const _person = (uid: 'u1', name: 'موظّف', departmentId: 'd1');

Workload _load({
  List<Project> projects = const [],
  List<ProjectTask> tasks = const [],
  List<WorkItem> works = const [],
}) =>
    WorkloadEngine.build(
      people: const [_person],
      projects: projects,
      tasks: tasks,
      works: works,
      now: _now,
    ).single;

void main() {
  group('العدُّ وحدَه يُضلّل', () {
    // ــ وهذا هو الحدُّ الذي بُنيت الوحدةُ لأجله ــ
    test('سبعُ مهامّ خفيفةٍ أخفُّ من مهمّتين حرجتين متأخّرتين', () {
      final many = _load(tasks: [
        for (var i = 0; i < 7; i++)
          _task(id: 't$i', priority: PriorityLevel.low, dueInDays: 60),
      ]);
      final heavy = _load(tasks: [
        for (var i = 0; i < 2; i++)
          _task(id: 'c$i', priority: PriorityLevel.critical, dueInDays: -5),
      ]);
      expect(many.activeTasks, 7);
      expect(heavy.activeTasks, 2);
      expect(heavy.score, greaterThan(many.score),
          reason: 'الاثنتان الحرجتان المتأخّرتان أثقلُ من السبع الخفيفة');
    });

    test('والحرِجُ أثقلُ من المنخفض', () {
      final low = _load(tasks: [_task(priority: PriorityLevel.low)]);
      final critical = _load(tasks: [_task(priority: PriorityLevel.critical)]);
      expect(critical.score, greaterThan(low.score));
    });

    test('والمتأخّرُ أثقلُ من الذي في وقته', () {
      final onTime = _load(tasks: [_task(dueInDays: 30)]);
      final late = _load(tasks: [_task(dueInDays: -1)]);
      expect(late.score, greaterThan(onTime.score));
      expect(late.overdueItems, 1);
      expect(onTime.overdueItems, 0);
    });

    test('والمستحقُّ قريباً أثقلُ من البعيد', () {
      final soon = _load(tasks: [_task(dueInDays: 2)]);
      final far = _load(tasks: [_task(dueInDays: 40)]);
      expect(soon.score, greaterThan(far.score));
      expect(soon.dueSoonItems, 1);
    });

    test('والمشروعُ الجاري أثقلُ من مهمّة', () {
      final withProject = _load(projects: [_project()]);
      final withTask = _load(tasks: [_task()]);
      expect(withProject.score, greaterThan(withTask.score));
    });
  });

  group('والمنجَزُ لا يُثقل', () {
    test('مهمّةٌ أُغلقت تخرج من الميزان', () {
      final done = _load(tasks: [_task(status: TaskStatus.done)]);
      expect(done.activeTasks, 0);
      expect(done.score, 0);
    });

    test('وعملٌ أُغلق كذلك', () {
      expect(_load(works: [_work(status: TaskStatus.done)]).activeWorks, 0);
    });

    // ــ و«اكتمل» حالةٌ مخزَّنةٌ لا نسبةٌ بلغت مئة ــ
    //
    // قِيس ذلك: مشروعٌ بنسبة مئةٍ وحالتُه «في المسار» يبقى في الميزان —
    // و`effectiveStatus` في هذه المنصة تقرأ الحالةَ المخزَّنة والتاريخ، لا
    // النسبة. فالاختبارُ يقول ما تقوله المنصّة لا ما ظننتُه.
    test('ومشروعٌ اكتمل لا يبقى على صاحبه', () {
      final complete = _load(
        projects: [_project(progress: 100, status: ProjectStatus.completed)],
      );
      expect(complete.activeProjects, 0);
    });

    test('ونسبةُ مئةٍ بلا إغلاقٍ تبقى حملاً — والإغلاقُ قرارٌ يُتّخذ', () {
      final notClosed = _load(projects: [_project(progress: 100)]);
      expect(notClosed.activeProjects, 1);
    });
  });

  group('والتصنيفُ يُقرأ بنظرة', () {
    test('بلا شيءٍ فهو خفيف', () {
      expect(_load().band, LoadBand.underloaded);
    });

    test('ومهمّتان حرجتان متأخّرتان ومشروعان يبلغ الزائد', () {
      final heavy = _load(
        projects: [_project(id: 'p1'), _project(id: 'p2')],
        tasks: [
          _task(id: 'a', priority: PriorityLevel.critical, dueInDays: -3),
          _task(id: 'b', priority: PriorityLevel.critical, dueInDays: -3),
        ],
      );
      expect(heavy.band, LoadBand.overloaded);
      expect(heavy.criticalItems, 2);
    });

    test('والحدودُ متدرّجةٌ لا متداخلة', () {
      expect(WorkloadEngine.bandOf(0), LoadBand.underloaded);
      expect(WorkloadEngine.bandOf(WorkloadEngine.normalFrom), LoadBand.normal);
      expect(WorkloadEngine.bandOf(WorkloadEngine.highFrom), LoadBand.high);
      expect(WorkloadEngine.bandOf(WorkloadEngine.overloadedFrom), LoadBand.overloaded);
    });
  });

  group('و«لا عملَ عليه» غيرُ «حملُه خفيف»', () {
    // فالأولى حالٌ تحتاج قراراً: موظّفٌ لا يُسنَد إليه شيء.
    test('من لا عملَ عليه يُقال ذلك فيه', () {
      expect(_load().isIdle, isTrue);
    });

    test('ومن عليه القليلُ ليس فارغاً', () {
      final light = _load(tasks: [_task(priority: PriorityLevel.low, dueInDays: 90)]);
      expect(light.band, LoadBand.underloaded);
      expect(light.isIdle, isFalse, reason: 'عليه عملٌ وإن خفّ');
    });
  });

  group('والترتيبُ والعدّ', () {
    test('الأثقلُ أوّلاً', () {
      final loads = WorkloadEngine.build(
        people: const [
          (uid: 'light', name: 'خفيف', departmentId: 'd1'),
          (uid: 'heavy', name: 'ثقيل', departmentId: 'd1'),
        ],
        projects: const [],
        tasks: [
          _task(id: 'a', uid: 'light', priority: PriorityLevel.low, dueInDays: 90),
          for (var i = 0; i < 5; i++)
            _task(id: 'h$i', uid: 'heavy', priority: PriorityLevel.critical, dueInDays: -2),
        ],
        works: const [],
        now: _now,
      );
      expect(loads.first.name, 'ثقيل');
    });

    test('والعدُّ بالتصنيف يذكر كلَّ تصنيفٍ ولو بصفر', () {
      // وبصفرٍ صريح: بطاقةٌ تختفي حين لا أحدَ فيها تُقرأ عطلاً لا خبراً.
      final counts = WorkloadEngine.countByBand([_load()]);
      expect(counts.keys.length, LoadBand.values.length);
      expect(counts[LoadBand.underloaded], 1);
      expect(counts[LoadBand.overloaded], 0);
    });
  });
}
