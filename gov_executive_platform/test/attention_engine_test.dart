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
import 'package:gov_exec_platform/models/contract.dart';
import 'package:gov_exec_platform/models/it_asset.dart';
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
  List<Contract> contracts = const [],
  List<ITAsset> assets = const [],
  AttentionThresholds thresholds = const AttentionThresholds(),
}) =>
    AttentionEngine.build(
      projects: projects,
      tasks: tasks,
      works: works,
      contracts: contracts,
      assets: assets,
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
  _registryTests();
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

// ــــ سجلُّ الأصول: ولا يُعدّ خبرٌ مرّتين ــــ
Contract _contract({
  String id = 'c1',
  String title = 'عقدُ دعم',
  int endsInDays = 20,
  int notice = 60,
  String projectId = '',
}) =>
    Contract(
      id: id,
      title: title,
      kind: ContractKind.support,
      vendorName: 'مورّد',
      endDate: _now.add(Duration(days: endsInDays)),
      renewalNoticeDays: notice,
      relatedProjectId: projectId,
      createdByUid: 'u1',
      createdAt: DateTime(2026, 1, 1),
    );

ITAsset _asset({
  String id = 'a1',
  num? used,
  int threshold = 85,
  String criticality = '',
  AssetStatus status = AssetStatus.live,
}) =>
    ITAsset(
      id: id,
      kind: AssetKind.server,
      name: 'خادم',
      status: status,
      criticality: criticality,
      capacityUsedPercent: used,
      capacityThreshold: threshold,
      createdByUid: 'u1',
      createdAt: DateTime(2026, 1, 1),
    );

void _registryTests() {
  group('العقودُ المستقلّة', () {
    test('عقدٌ يوشك على الانتهاء يُنبَّه عليه', () {
      final items = _of(_build(contracts: [_contract()]), AttentionKind.contractExpiring);
      expect(items, hasLength(1));
      expect(items.first.recordId, 'c1');
    });

    test('وبعيدُ الانتهاء لا يُنبَّه عليه', () {
      expect(
        _of(_build(contracts: [_contract(endsInDays: 200)]), AttentionKind.contractExpiring),
        isEmpty,
      );
    });

    // ــ ومهلةُ التنبيه من العقد نفسِه ــ
    //
    // ترخيصٌ يُجدَّد في أسبوعٍ غيرُ عقدِ دعمٍ تستغرق مناقصتُه ثلاثة أشهر.
    test('والمهلةُ تُقرأ من العقد لا من رقمٍ واحدٍ للجميع', () {
      expect(_of(_build(contracts: [_contract(endsInDays: 40, notice: 10)]),
          AttentionKind.contractExpiring), isEmpty);
      expect(_of(_build(contracts: [_contract(endsInDays: 40, notice: 90)]),
          AttentionKind.contractExpiring), hasLength(1));
    });

    test('والمنتهي فعلاً خرج من النطاق', () {
      expect(_of(_build(contracts: [_contract(endsInDays: -5)]),
          AttentionKind.contractExpiring), isEmpty);
    });

    // ــــ وهذا أهمُّ ما يُقاس في هذه الدفعة ــــ
    //
    // `Project` يحمل عقدَه أصلاً ويُنبَّه عليه منه. فعقدٌ في السجلّ يحمل
    // `relatedProjectId` هو **الوثيقةُ نفسُها** مسجَّلةً للتصفّح. ولو
    // نُبِّه عليه لظهر العقدُ الواحد مرّتين — والرقمُ الذي يُعدّ مرّتين لا
    // يُصدَّق مرّة.
    test('وعقدُ مشروعٍ لا يُعدّ مرّتين', () {
      final items = _of(
        _build(
          projects: [_project(contractEnd: _now.add(const Duration(days: 20)))],
          contracts: [_contract(projectId: 'p1')],
        ),
        AttentionKind.contractExpiring,
      );
      expect(items, hasLength(1), reason: 'بندٌ واحدٌ لا اثنان');
      expect(items.first.recordId, 'p1', reason: 'ومن المشروع لا من السجلّ');
    });

    // والضابط: العقدُ نفسُه بلا ربطٍ بمشروعٍ يُنبَّه عليه.
    test('والضابط: عقدٌ بلا مشروعٍ يُنبَّه عليه', () {
      expect(
        _of(_build(contracts: [_contract(projectId: '')]), AttentionKind.contractExpiring),
        hasLength(1),
      );
    });
  });

  group('سعةُ الأصول', () {
    test('أصلٌ تجاوز حدَّه يُنبَّه عليه', () {
      final items = _of(_build(assets: [_asset(used: 91)]), AttentionKind.assetOverCapacity);
      expect(items, hasLength(1));
    });

    test('وما دون الحدّ لا يُنبَّه عليه', () {
      expect(_of(_build(assets: [_asset(used: 40)]), AttentionKind.assetOverCapacity), isEmpty);
    });

    // ــ وغيرُ المقيس ليس متجاوزاً ــ
    //
    // `null` تعني «لم تُقَس» لا صفراً. ولو قُرئت صفراً لَمرّت، ولو قُرئت
    // تجاوزاً لامتلأت الشاشةُ حمرةً بأصولٍ لم يُنظر إليها أصلاً — فيُهمَل
    // اللونُ ويضيع معه ما تجاوز حقّاً.
    test('وسعةٌ غيرُ مقيسةٍ لا تُنبِّه', () {
      expect(_of(_build(assets: [_asset(used: null)]), AttentionKind.assetOverCapacity), isEmpty);
    });

    test('والخارجُ من الخدمة لا يُنبَّه على سعته', () {
      expect(
        _of(_build(assets: [_asset(used: 99, status: AssetStatus.retired)]),
            AttentionKind.assetOverCapacity),
        isEmpty,
      );
    });

    // ــ والحَرِجيّةُ من تصنيف الأصل لا من النسبة ــ
    test('وأصلٌ من الطبقة الأولى حرجٌ، وغيرُه يحتاج انتباهاً', () {
      expect(
        _of(_build(assets: [_asset(used: 90, criticality: 'tier1')]),
            AttentionKind.assetOverCapacity).first.severity,
        AttentionSeverity.critical,
      );
      expect(
        _of(_build(assets: [_asset(used: 90, criticality: 'tier3')]),
            AttentionKind.assetOverCapacity).first.severity,
        AttentionSeverity.needsAttention,
      );
    });

    test('والحدُّ يُقرأ من الأصل', () {
      expect(_of(_build(assets: [_asset(used: 70, threshold: 60)]),
          AttentionKind.assetOverCapacity), hasLength(1));
      expect(_of(_build(assets: [_asset(used: 70, threshold: 95)]),
          AttentionKind.assetOverCapacity), isEmpty);
    });
  });
}
