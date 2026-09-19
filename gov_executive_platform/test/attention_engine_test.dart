// ما يحتاج تدخّلاً — **موضعٌ واحدٌ يقرّر**.
//
// ــــ لماذا يُقاس ــــ
//
// القاعدةُ المطلوبة «الإدارةُ بالاستثناء»: اللوحةُ لا تعرض كلَّ شيء، بل ما
// يحتاج قراراً. ودقّةُ هذا الحكم هي كلُّ قيمة اللوحة — لوحةٌ تقول «ثلاثةُ
// مشاريعَ متأخرة» وتقريرٌ صباحيٌّ يقول «أربعة» يُفقدان معاً ثقةَ قارئهما.
//
// ــــ وما يُقاس هنا ــــ
//
// (١) أنّ كلَّ بابٍ يُفتح على سببه لا على وصفٍ عامّ.
// (٢) وأنّ **المكتملَ لا يُنبَّه عليه** — تأخُّرُه خبرٌ لا نداء.
// (٣) وأنّ **العتبات تُقرأ ولا تُدفن**: مسؤولُ النظام يضبطها.
// (٤) وأنّ **الأشدَّ أوّلاً** — من يفتح اللوحةَ لدقيقةٍ يقرأ أعلاها.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_task.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/reports/attention.dart';

final _now = DateTime(2026, 9, 20);

Project _project({
  String id = 'p1',
  String name = 'مشروع',
  int dueInDays = 30,
  double progress = 50,
  ProjectStatus status = ProjectStatus.onTrack,
  String nextAction = 'الخطوة التالية',
  DateTime? contractEnd,
}) =>
    Project(
      id: id,
      departmentId: 'd1',
      name: name,
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: _now.add(Duration(days: dueInDays)),
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: progress,
      nextAction: nextAction,
      contractEndDate: contractEnd,
    );

List<AttentionItem> _build({
  List<Project> projects = const [],
  List<ProjectTask> tasks = const [],
  List<WorkItem> works = const [],
  Map<String, DateTime>? updates,
  int decisions = 0,
  AttentionThresholds thresholds = const AttentionThresholds(),
}) =>
    AttentionEngine.build(
      projects: projects,
      tasks: tasks,
      works: works,
      // والافتراضُ «حُدِّث اليوم» إلا أن يُقال غيرُه، فلا يطغى بابُ الإهمال
      // على ما يُقاس في كلّ اختبار.
      lastUpdateByProject: updates ?? {for (final p in projects) p.id: _now},
      pendingDecisions: decisions,
      now: _now,
      thresholds: thresholds,
    );

Iterable<AttentionItem> _of(List<AttentionItem> items, AttentionKind kind) =>
    items.where((i) => i.kind == kind);

void main() {
  group('المشروعُ المتأخّر', () {
    test('يظهر بعدد أيامه لا بوصفٍ عامّ', () {
      final items = _of(_build(projects: [_project(dueInDays: -12)]), AttentionKind.projectOverdue);
      expect(items.length, 1);
      // والعددُ لا الوصف: «متأخّر» لا تقول لمديرٍ يوازن أيَّها يبدأ به.
      expect(items.first.reason, contains('12'));
      expect(items.first.days, 12);
    });

    test('وتأخُّرٌ قصيرٌ يحتاج انتباهاً لا حرجاً', () {
      final items = _of(_build(projects: [_project(dueInDays: -3)]), AttentionKind.projectOverdue);
      expect(items.first.severity, AttentionSeverity.needsAttention);
    });

    test('وتأخُّرٌ يتجاوز العتبةَ حرج', () {
      final items = _of(_build(projects: [_project(dueInDays: -20)]), AttentionKind.projectOverdue);
      expect(items.first.severity, AttentionSeverity.critical);
    });

    // ــ والعتبةُ تُقرأ ولا تُدفن ــ
    test('والعتبةُ يضبطها مسؤولُ النظام', () {
      final items = _of(
        _build(
          projects: [_project(dueInDays: -5)],
          thresholds: const AttentionThresholds(criticalDelayDays: 3),
        ),
        AttentionKind.projectOverdue,
      );
      expect(items.first.severity, AttentionSeverity.critical);
    });

    // ــ والمكتملُ لا يُنبَّه عليه ــ
    test('ومشروعٌ مكتملٌ لا يظهر ولو فات موعدُه', () {
      final done = _project(dueInDays: -40, progress: 100, status: ProjectStatus.completed);
      expect(_build(projects: [done]), isEmpty);
    });
  });

  group('والمشروعُ المهمَل', () {
    test('بلا تحديثٍ منذ العتبة يظهر', () {
      final items = _of(
        _build(projects: [_project()], updates: {'p1': _now.subtract(const Duration(days: 9))}),
        AttentionKind.projectStale,
      );
      expect(items.length, 1);
      expect(items.first.reason, contains('9'));
    });

    test('وحُدِّث أمسِ فلا يظهر', () {
      final items = _of(
        _build(projects: [_project()], updates: {'p1': _now.subtract(const Duration(days: 1))}),
        AttentionKind.projectStale,
      );
      expect(items, isEmpty);
    });

    // ــ و«لم يُحدَّث قطّ» غيرُ «انقطعت متابعتُه» ــ
    test('ومشروعٌ بلا تحديثٍ قطّ يُقال ذلك فيه نصّاً', () {
      final items = _of(_build(projects: [_project()], updates: {}), AttentionKind.projectStale);
      expect(items.first.reason, contains('قطّ'));
    });
  });

  group('وبلا خطوةٍ تالية', () {
    test('مشروعٌ جارٍ بلا خطوةٍ تالية يظهر', () {
      final items = _of(
        _build(projects: [_project(nextAction: '  ')]),
        AttentionKind.projectNoNextAction,
      );
      expect(items.length, 1);
    });

    test('ومشروعٌ لم يبدأ لا يظهر — لا شيء ينتظر بعد', () {
      final items = _of(
        _build(projects: [_project(nextAction: '', progress: 0)]),
        AttentionKind.projectNoNextAction,
      );
      expect(items, isEmpty);
    });
  });

  group('والعقدُ الموشك', () {
    test('ينتهي بعد شهرين فيحتاج انتباهاً', () {
      final items = _of(
        _build(projects: [_project(contractEnd: _now.add(const Duration(days: 60)))]),
        AttentionKind.contractExpiring,
      );
      expect(items.length, 1);
      expect(items.first.severity, AttentionSeverity.needsAttention);
    });

    test('وينتهي بعد عشرين يوماً فهو حرج', () {
      final items = _of(
        _build(projects: [_project(contractEnd: _now.add(const Duration(days: 20)))]),
        AttentionKind.contractExpiring,
      );
      expect(items.first.severity, AttentionSeverity.critical);
    });

    test('وعقدٌ بعيدٌ لا يُزعج', () {
      final items = _of(
        _build(projects: [_project(contractEnd: _now.add(const Duration(days: 200)))]),
        AttentionKind.contractExpiring,
      );
      expect(items, isEmpty);
    });

    // وعقدٌ انتهى فعلاً ليس «يوشك»: هو حالٌ أخرى تُعالَج بابَها.
    test('وعقدٌ انتهى لا يظهر في هذا الباب', () {
      final items = _of(
        _build(projects: [_project(contractEnd: _now.subtract(const Duration(days: 5)))]),
        AttentionKind.contractExpiring,
      );
      expect(items, isEmpty);
    });
  });

  group('والقرارُ المعلَّق', () {
    test('يظهر حرجاً بعدده', () {
      final items = _of(_build(decisions: 4), AttentionKind.decisionPending);
      expect(items.length, 1);
      expect(items.first.severity, AttentionSeverity.critical);
      expect(items.first.reason, contains('4'));
    });

    test('وبلا قراراتٍ لا يظهر', () {
      expect(_of(_build(decisions: 0), AttentionKind.decisionPending), isEmpty);
    });
  });

  group('والترتيبُ: الأشدُّ أوّلاً ثمّ الأطول', () {
    // ــ وهذه الحالةُ كُتبت لأنّ طفرةً نجت ــ
    //
    // كان الاختبارُ الأوّل يضع مشروعاً متأخّراً ثلاثين يوماً (حرجاً) وآخرَ
    // يومين (يحتاج انتباهاً) — **والأشدُّ فيه هو الأطولُ أيضاً**. فنُزع
    // ترتيبُ الشدّة ومرّ الاختبارُ صامتاً: ترتيبُ الأيام وحدَه يعطي الجواب
    // نفسَه.
    //
    // فالحدُّ يُقاس بحالةٍ **يتعارض فيها الميزانان**: بندٌ حرجٌ عددُه صغير،
    // وبندٌ يحتاج انتباهاً عددُه كبير.
    test('الحرجُ يسبق ولو كان عددُه أصغر', () {
      final items = _build(
        projects: [_project(id: 'p1', name: 'مهمَلٌ منذ أربعين يوماً')],
        updates: {'p1': _now.subtract(const Duration(days: 40))},
        decisions: 1,
      );
      expect(items.first.kind, AttentionKind.decisionPending,
          reason: 'قرارٌ واحدٌ حرجٌ يسبق إهمالاً عمرُه أربعون يوماً');
      expect(items.first.severity, AttentionSeverity.critical);
    });

    test('وبين حرجَين يسبق الأطول', () {
      final items = _build(projects: [
        _project(id: 'p1', name: 'قصيرُ التأخير', dueInDays: -15),
        _project(id: 'p2', name: 'طويلُ التأخير', dueInDays: -30),
      ]).where((i) => i.kind == AttentionKind.projectOverdue).toList();
      expect(items.first.title, 'طويلُ التأخير');
      expect(items.first.severity, AttentionSeverity.critical);
    });

    test('وبين متساويَي الشدّة يسبق الأطولُ تأخُّراً', () {
      final items = _build(projects: [
        _project(id: 'p1', name: 'أقلّ', dueInDays: -2),
        _project(id: 'p2', name: 'أكثر', dueInDays: -5),
      ]).where((i) => i.kind == AttentionKind.projectOverdue).toList();
      expect(items.first.title, 'أكثر');
    });
  });

  group('والعدُّ بالأبواب', () {
    test('يجمع كلَّ بابٍ على حدة', () {
      final counts = AttentionEngine.countByKind(_build(
        projects: [_project(dueInDays: -3), _project(id: 'p2', dueInDays: -4)],
        decisions: 1,
      ));
      expect(counts[AttentionKind.projectOverdue], 2);
      expect(counts[AttentionKind.decisionPending], 1);
    });

    test('وبابٌ خالٍ لا يُذكر بصفر', () {
      final counts = AttentionEngine.countByKind(_build(projects: [_project()]));
      expect(counts[AttentionKind.projectOverdue], isNull);
    });
  });
}
