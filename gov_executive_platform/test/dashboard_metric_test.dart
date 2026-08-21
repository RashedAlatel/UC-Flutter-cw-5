import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/dashboard_metric.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/widgets/charts.dart';

/// مشروع بأقل ما يلزم — التاريخ هو ما يقرّر الحالة الفعلية، فيُضبط صراحةً.
Project _project(
  String id, {
  String dept = 'd1',
  double progress = 0,
  ProjectStatus status = ProjectStatus.onTrack,
  PriorityLevel priority = PriorityLevel.medium,
  DateTime? due,
  List<String> managerUids = const [],
  List<String> executorUids = const [],
  List<String> executorNames = const [],
}) =>
    Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      // موعدٌ بعيد افتراضاً: أي تاريخ ماضٍ يجعل `effectiveStatus` متأخراً مهما
      // قال الحقل المخزَّن، فيُفسد أي اختبار لا يقصد التأخير.
      dueDate: due ?? DateTime(2099, 1, 1),
      status: status,
      priority: priority,
      progressPercent: progress,
      managerUids: managerUids,
      executorUids: executorUids,
      executorNames: executorNames,
    );

AppUser _user(String id, String name) => AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: UserRole.employee,
      departmentId: 'd1',
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('حساب المقياس', () {
    test('متوسط نسبة الإنجاز', () {
      final list = [_project('a', progress: 20), _project('b', progress: 80)];
      expect(AppStore.metricValue(DashboardMetric.avgProgress, list), 50);
    });

    test('نسبة المتأخرة تُحسب من الحالة الفعلية لا من الحقل المخزَّن', () {
      final list = [
        // مخزَّن «على المسار» لكن موعده مضى ⇒ متأخر فعلياً.
        _project('a', due: DateTime(2020, 1, 1)),
        // مخزَّن «متأخر» وموعده لم يحن ⇒ ليس متأخراً.
        _project('b', status: ProjectStatus.delayed),
        _project('c'),
        _project('d'),
      ];
      expect(AppStore.metricValue(DashboardMetric.delayedRate, list), 25);
    });

    test('المكتمل يبقى مكتملاً ولو مضى موعده', () {
      final list = [
        _project('a', status: ProjectStatus.completed, due: DateTime(2020, 1, 1)),
        _project('b'),
      ];
      expect(AppStore.metricValue(DashboardMetric.completedRate, list), 50);
      expect(AppStore.metricValue(DashboardMetric.delayedRate, list), 0);
    });

    test('عدد المشاريع عددٌ لا نسبة', () {
      expect(AppStore.metricValue(DashboardMetric.projectCount, [_project('a'), _project('b'), _project('c')]), 3);
    });

    test('القائمة الفارغة تعطي صفراً بلا قسمة على صفر', () {
      for (final m in DashboardMetric.values) {
        expect(AppStore.metricValue(m, const []), 0, reason: m.name);
      }
    });

    test('الوحدة تميّز العدد عن النسبة', () {
      expect(DashboardMetric.projectCount.unit, DashboardMetricUnit.count);
      for (final m in DashboardMetric.values.where((m) => m != DashboardMetric.projectCount)) {
        expect(m.unit, DashboardMetricUnit.percent, reason: m.name);
      }
    });

    test('نسبة التأخير وحدها يسوء ارتفاعها', () {
      expect(DashboardMetric.delayedRate.higherIsBetter, isFalse);
      expect(DashboardMetric.avgProgress.higherIsBetter, isTrue);
      expect(DashboardMetric.completedRate.higherIsBetter, isTrue);
      expect(DashboardMetric.projectCount.higherIsBetter, isTrue);
    });
  });

  group('مشاريع الشخص تُحسب بالعضوية', () {
    AppStore store() {
      final s = AppStore();
      s.users = [_user('u1', 'فهد المطيري'), _user('u2', 'نورة العنزي')];
      s.projects = [
        // فهد **ثاني** المديرين — والحقل المفرد `managerUid` يعطي الأول وحده،
        // فكان هذا المشروع يسقط من حسابه.
        _project('p-comgr', managerUids: const ['someone-else', 'u1']),
        // نورة منفّذة **بحسابها** لا باسمها — و`executorUids` لم يكن يُقرأ أصلاً.
        _project('p-execuid', executorUids: const ['u2']),
        // اسمٌ نصي مستورد من ملفات الوزارة بلا حساب — يجب أن يبقى محسوباً.
        _project('p-name', executorNames: const ['فهد المطيري']),
        _project('p-none'),
      ];
      return s;
    }

    test('المدير الثاني في القائمة يُحسب', () {
      final s = store();
      expect(s.projectsOf(s.users[0]).map((p) => p.id), contains('p-comgr'));
    });

    test('المنفّذ المسجَّل بحسابه يُحسب', () {
      final s = store();
      expect(s.projectsOf(s.users[1]).map((p) => p.id), ['p-execuid']);
    });

    test('الاسم النصي المستورد يبقى محسوباً', () {
      final s = store();
      expect(s.projectsOf(s.users[0]).map((p) => p.id), contains('p-name'));
    });

    test('من لا صلة له بالمشروع لا يُحسب عليه', () {
      final s = store();
      expect(s.projectsOf(s.users[0]).map((p) => p.id), isNot(contains('p-none')));
      expect(s.projectsOf(s.users[1]).map((p) => p.id), isNot(contains('p-none')));
    });

    test('اسمٌ فارغ لا يبتلع كل المشاريع', () {
      final s = store();
      s.users = [_user('u3', '   ')];
      expect(s.projectsOf(s.users.first), isEmpty);
    });
  });

  group('المقياس يُحفظ مع الودجت', () {
    test('الذهاب والإياب يحفظ المقياس', () {
      const w = DashboardWidgetConfig(
        id: 'x',
        type: DashboardWidgetType.deptBarChart,
        metric: DashboardMetric.delayedRate,
      );
      expect(DashboardWidgetConfig.fromMap(w.toMap()).metric, DashboardMetric.delayedRate);
    });

    test('تخطيطٌ محفوظ بلا مفتاح المقياس يُقرأ بسلوك اليوم نفسه', () {
      // هذا هو ضمان الاستمرارية: كل لوحة في Firestore الآن بلا هذا المفتاح.
      final legacy = DashboardWidgetConfig.fromMap({'id': 'a', 'type': 'deptBarChart', 'width': 'half'});
      expect(legacy.metric, DashboardMetric.avgProgress);
    });

    test('النوع بلا مقياس لا يكتب المفتاح أصلاً', () {
      const w = DashboardWidgetConfig(id: 'x', type: DashboardWidgetType.projectsTable);
      expect(w.toMap().containsKey('metric'), isFalse);
    });

    test('نسختان بمقياسين مختلفين تبقيان، وبمقياس واحد تنطويان', () {
      final kept = DashboardWidgetConfig.dedupe(const [
        DashboardWidgetConfig(id: '1', type: DashboardWidgetType.deptBarChart, metric: DashboardMetric.avgProgress),
        DashboardWidgetConfig(id: '2', type: DashboardWidgetType.deptBarChart, metric: DashboardMetric.delayedRate),
      ]);
      expect(kept.map((w) => w.id), ['1', '2']);

      final folded = DashboardWidgetConfig.dedupe(const [
        DashboardWidgetConfig(id: '1', type: DashboardWidgetType.deptBarChart, metric: DashboardMetric.delayedRate),
        DashboardWidgetConfig(id: '2', type: DashboardWidgetType.deptBarChart, metric: DashboardMetric.delayedRate),
      ]);
      expect(folded.map((w) => w.id), ['1']);
    });

    test('النوع بلا مقياس يبقى واحداً مهما تكرر', () {
      final folded = DashboardWidgetConfig.dedupe(const [
        DashboardWidgetConfig(id: '1', type: DashboardWidgetType.projectsTable),
        DashboardWidgetConfig(id: '2', type: DashboardWidgetType.projectsTable),
      ]);
      expect(folded.map((w) => w.id), ['1']);
    });
  });

  group('ترحيل صفّ المؤشرات', () {
    const stored = [DashboardWidgetConfig(id: 'a', type: DashboardWidgetType.projectsTable)];

    test('لوحة قديمة بلا علامة تكتسب المؤشرات فلا يفقدها المستخدم', () {
      final out = DashboardWidgetConfig.withKpiRow(stored, migrated: false);
      expect(out.where((w) => w.type.isKpi), isNotEmpty);
      expect(out.last.type, DashboardWidgetType.projectsTable, reason: 'ما حفظه المستخدم يبقى بعدها');
    });

    test('ومع العلامة لا تُضاف — فحذفُك المتعمَّد يبقى', () {
      expect(DashboardWidgetConfig.withKpiRow(stored, migrated: true), stored);
    });

    test('لوحة فيها مؤشر واحد لا تُحشى ثانيةً', () {
      const withOne = [DashboardWidgetConfig(id: 'k', type: DashboardWidgetType.kpiAvgProgress)];
      expect(DashboardWidgetConfig.withKpiRow(withOne, migrated: false), withOne);
    });

    test('الطبقة الفارغة تبقى فارغة لتُتخطّى لا لتبدو مضبوطة', () {
      // لو حُشيت بالمؤشرات لصارت لوحة الدور «مضبوطة» فحجبت اللوحة العامة.
      expect(DashboardWidgetConfig.withKpiRow(const [], migrated: false), isEmpty);
    });
  });

  group('العمود يفهم وحدته', () {
    Future<void> pump(WidgetTester tester, DashboardMetricUnit unit, List<double> values) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              height: 300,
              child: RankedBarChart(
                unit: unit,
                bars: [
                  for (var i = 0; i < values.length; i++)
                    (label: 'صف $i', color: Colors.green, value: values[i]),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('العدد يُطبع بلا ٪ ويُقاس على أكبر قيمة', (tester) async {
      await pump(tester, DashboardMetricUnit.count, [12, 6]);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('12٪'), findsNothing);

      final bars = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).toList();
      expect(bars.first.widthFactor, 1.0, reason: 'الأكبر يملأ السطر');
      expect(bars[1].widthFactor, closeTo(0.5, 0.001), reason: 'النصف نصفُ العمود');
    });

    testWidgets('النسبة تُطبع بـ٪ وتُقاس على مائة', (tester) async {
      await pump(tester, DashboardMetricUnit.percent, [50]);
      expect(find.text('50٪'), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox).first);
      expect(bar.widthFactor, closeTo(0.5, 0.001));
    });

    testWidgets('رسمٌ كله أصفار لا ينهار بقسمة على صفر', (tester) async {
      await pump(tester, DashboardMetricUnit.count, [0, 0]);
      expect(tester.takeException(), isNull);
      final bar = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox).first);
      expect(bar.widthFactor, 0.0);
    });

    testWidgets('لون الإدارة يصل العمود عبر الغلاف', (tester) async {
      final dept = Department(id: 'd1', name: 'الدعم الفني', headName: '', colorValue: 0xFF123456, iconKey: 'build');
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              height: 200,
              child: DepartmentBarChart(ranking: [MapEntry(dept, 40)], unit: DashboardMetricUnit.percent),
            ),
          ),
        ),
      ));
      expect(find.text('الدعم الفني'), findsOneWidget);
      expect(find.text('40٪'), findsOneWidget);
    });
  });
}
