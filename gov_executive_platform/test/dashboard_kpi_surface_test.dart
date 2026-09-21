// أيُّ سطحٍ يعرض المؤشّرات فعلاً — وماذا يقع عند ضغطها.
//
// ــــ لماذا هذا الاختبار موجود ــــ
//
// كان في `dashboard_screen.dart` تعليقٌ يقول: «يقرأ من `_kpiData` موضعان:
// بطاقةٌ على اللوحة، ومؤشّرٌ في الشريط». **وكان كاذباً**. فقد قسمت `build`
// الودجاتِ قسمين — ما كان مؤشّراً إلى الشريط القيادي وما عداه إلى لوحة
// التحليل — ولم تُصيَّر ذراعُ البطاقة بعد ذلك أبداً.
//
// ولولا أنّي قِستُ قبل الكتابة لَوضعتُ بطاقةَ المؤشّر الجديدة بتدرّجها في
// سطرٍ لا يُنفَّذ، ولَقلتُ «تمّ» والمستخدمُ لا يرى شيئاً.
//
// فالمقياسُ هنا ليس «هل الشيفرةُ صحيحة» بل **«أين تُرى»**. ووصفٌ في تعليقٍ
// يشيخ صامتاً؛ واختبارٌ يقيس الوصفَ نفسَه يشكو يوم يشيخ.
//
// ــــ وما يُقاس أيضاً ــــ
//
// أنّ كلَّ مؤشّرٍ خلفه قائمةٌ **يُضغط فيفتحها**، وأنّ المؤشّرَين اللذَين لا
// قائمةَ لهما **لا يُظهران إشارةَ الضغط أصلاً**. فبطاقةٌ تبدو قابلةً للضغط
// ولا تستجيب عطلٌ في عين مستعملها، لا نقصٌ في ميزة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/blocker.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/risk.dart';
import 'package:gov_exec_platform/screens/dashboard_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/kpi_card.dart';
import 'package:gov_exec_platform/widgets/stat_card.dart';

const _dept = 'd-tech';

AppUser _admin() => AppUser(
      id: 'adm',
      name: 'مسؤول النظام',
      email: 'adm@moj.gov.kw',
      phone: '',
      role: UserRole.systemAdmin,
      // التخصيص بصلاحية، والاختبار يضبط التخطيط بيده — فبلا `md` تُهمل
      // الطبقةُ الشخصية ويُقاس التخطيط الافتراضي بدل تخطيط الاختبار.
      permissionOverrides: const {'md': true},
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

/// و**موعدُ الاستحقاق في المستقبل البعيد افتراضاً**.
///
/// لأنّ `effectiveStatus` تُشتقّ من التاريخ لا من الحقل المخزَّن: أوّلُ
/// صياغةٍ أعطت الأربعةَ موعداً في ٢٠٢٦، فصارت كلُّها متأخرةً بمجرّد مرور
/// اليوم — واختبارٌ يصدُق شهراً ويكذب بعده أسوأُ من لا اختبار.
Project _project(int i,
        {bool isLate = false, PriorityLevel priority = PriorityLevel.medium}) =>
    Project(
      id: 'p$i',
      departmentId: _dept,
      name: 'مشروع رقم $i',
      description: 'وصف',
      startDate: DateTime(2020, 1, 1),
      dueDate: isLate ? DateTime(2020, 6, 1) : DateTime(2099, 1, 1),
      status: isLate ? ProjectStatus.delayed : ProjectStatus.onTrack,
      priority: priority,
      progressPercent: (i * 9) % 100,
    );

/// كلُّ المؤشّرات التسعة على اللوحة دفعةً واحدة.
List<DashboardWidgetConfig> _allKpis() => [
      for (final (i, t) in DashboardWidgetType.values.where((t) => t.isKpi).indexed)
        DashboardWidgetConfig(id: 'k$i', type: t),
    ];

AppStore _store({List<DashboardWidgetConfig>? layout}) {
  final store = AppStore()
    ..currentUser = _admin()
    ..users = [_admin()]
    ..departments = [
      Department(
          id: _dept,
          name: 'الإدارة العامة لتقنية المعلومات',
          headName: 'رئيس',
          colorValue: 0xFF1B5E4A,
          iconKey: 'settings'),
    ]
    ..projects = [
      // متأخرٌ واحد، وحرجٌ واحد، والباقي في المسار — فلكلّ قائمةٍ صيدٌ
      // معلومُ العدد، ويُقاس العددُ لا مجرّد أنّ شيئاً انفتح.
      _project(1, isLate: true),
      _project(2, priority: PriorityLevel.critical),
      _project(3),
      _project(4),
    ]
    ..risks = [
      ProjectRisk(
        id: 'r1',
        projectId: 'p3',
        departmentId: _dept,
        description: 'خطرٌ قائم',
        level: RiskLevel.high,
        status: ItemStatus.open,
        dateRaised: DateTime(2026, 1, 1),
      ),
    ]
    ..blockers = [
      ProjectBlocker(
        id: 'b1',
        projectId: 'p4',
        departmentId: _dept,
        description: 'عائقٌ نشط',
        status: ItemStatus.open,
        dateRaised: DateTime(2026, 1, 1),
      ),
    ];
  store.setDashboardWidgetsForTest(layout ?? _allKpis());
  return store;
}

Future<AppStore> _pump(WidgetTester tester, {List<DashboardWidgetConfig>? layout}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = _store(layout: layout);
  // ــ والمزوِّد **فوق** `MaterialApp` لا تحته ــ
  //
  // لأنّ ضغط «طلبات بانتظار القيادة» يدفع مساراً جديداً، والمسارُ المدفوع
  // أخٌ للصفحة لا ابنٌ لها. فمزوِّدٌ داخل `home` لا تبلغه الشاشةُ المفتوحة
  // فتسقط بـ`ProviderNotFoundException`. وهذا تركيبُ `main.dart` نفسُه.
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.theme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: DashboardScreen()),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return store;
}

void main() {
  group('سطحُ المؤشّرات', () {
    testWidgets('المؤشّراتُ تُصيَّر في الشريط القيادي لا بطاقاتٍ على اللوحة', (tester) async {
      await _pump(tester);
      final kpiCount = _allKpis().length;

      expect(find.byType(KpiMetric), findsNWidgets(kpiCount),
          reason: 'الشريطُ القياديّ هو سطحُ المؤشّرات — فإن نقص عددُها فيه '
              'فقد انتقلت إلى مكانٍ آخر ولم يُحدَّث ما يصفها');
      expect(find.byType(StatCard), findsNothing,
          reason: 'لوحةُ التحليل لا تُصيَّر فيها مؤشّرات: `build` تقسم '
              'الودجات فلا يبلغها إلا ما ليس مؤشّراً. فإن ظهرت هنا بطاقةٌ '
              'فقد تغيّرت القسمة — ويُعاد النظر في التعليق الذي يصفها');
    });

    // ــ ولا تُصيَّر لوحةُ التحليل بلا شيء ــ
    //
    // لو كانت اللوحةُ لا تعرض شيئاً أصلاً لمرّ الشرطُ الأوّل صادقاً وهو لا
    // يقيس شيئاً. فيُقاس أنّ ما ليس مؤشّراً **يبلغها فعلاً**.
    testWidgets('وما ليس مؤشّراً يبلغ لوحةَ التحليل', (tester) async {
      await _pump(tester, layout: [
        ..._allKpis(),
        const DashboardWidgetConfig(id: 'x', type: DashboardWidgetType.projectsTable),
      ]);
      expect(find.text('تفاصيل المشاريع (4)'), findsOneWidget);
    });
  });

  group('والمؤشّرُ يُضغط فيفتح أصحابَه', () {
    /// يضغط المؤشّرَ المسمّى ويعيد نصَّ عنوان النافذة المفتوحة.
    Future<void> tapMetric(WidgetTester tester, String title) async {
      final metric = find.ancestor(
        of: find.text(title),
        matching: find.byType(KpiMetric),
      );
      expect(metric, findsOneWidget, reason: 'لم يُعثر على مؤشّر «$title»');
      await tester.tap(metric);
      await tester.pumpAndSettle();
    }

    testWidgets('المخاطرُ القائمة تفتح مشاريعَها هي لا كلَّ المشاريع', (tester) async {
      await _pump(tester);
      await tapMetric(tester, 'المخاطر القائمة');
      expect(find.text('مشاريع فيها مخاطر قائمة'), findsOneWidget);
      // مشروعٌ واحدٌ فيه خطرٌ قائم — والعددُ معروضٌ في رأس النافذة.
      expect(find.text('مشروع رقم 3'), findsOneWidget);
      expect(find.text('مشروع رقم 4'), findsNothing);
    });

    testWidgets('والعوائقُ النشطة تفتح مشاريعَها', (tester) async {
      await _pump(tester);
      await tapMetric(tester, 'العوائق النشطة');
      expect(find.text('مشاريع فيها عوائق نشطة'), findsOneWidget);
      expect(find.text('مشروع رقم 4'), findsOneWidget);
      expect(find.text('مشروع رقم 3'), findsNothing);
    });

    testWidgets('ومتوسّطُ التأخير يفتح المتأخرة وحدها', (tester) async {
      await _pump(tester);
      await tapMetric(tester, 'متوسط التأخير عن الخطة');
      expect(find.text('المشاريع المتأخرة'), findsOneWidget);
      expect(find.text('مشروع رقم 1'), findsOneWidget);
      expect(find.text('مشروع رقم 3'), findsNothing);
    });

    testWidgets('وعاليةُ الأولوية تفتح الحرجةَ والعالية', (tester) async {
      await _pump(tester);
      await tapMetric(tester, 'المشاريع عالية الأولوية');
      expect(find.text('المشاريع عالية الأولوية'), findsWidgets);
      expect(find.text('مشروع رقم 2'), findsOneWidget);
      expect(find.text('مشروع رقم 1'), findsNothing);
    });

    testWidgets('وطلباتُ القيادة تفتح مركزَ القرار لا قائمةَ مشاريع', (tester) async {
      await _pump(tester);
      await tapMetric(tester, 'طلبات بانتظار القيادة');
      expect(find.text('مركز القرارات التنفيذية'), findsWidgets);
    });

    // ــ وهذا هو الشرطُ الذي يمنع الوعدَ الكاذب ــ
    testWidgets('وما لا قائمةَ له لا يُظهر إشارةَ الضغط', (tester) async {
      await _pump(tester);
      for (final title in ['أفادت الإدارات بإتمامه', 'مُعتمَد ومغلَق']) {
        final metric = find.ancestor(
          of: find.text(title),
          matching: find.byType(KpiMetric),
        );
        expect(metric, findsOneWidget);
        expect(
          find.descendant(of: metric, matching: find.byType(InkWell)),
          findsNothing,
          reason: '«$title» يعدّ أعمالاً لا مشاريع، فلا قائمةَ تُفتح له — '
              'ومؤشّرٌ يبدو قابلاً للضغط ولا يستجيب عطلٌ في عين مستعمله',
        );
      }
    });

    // ولا يمرّ الشرطُ السابق لأنّ **لا مؤشّرَ** فيه إشارةُ ضغطٍ أصلاً.
    testWidgets('بينما ما له قائمةٌ يُظهرها', (tester) async {
      await _pump(tester);
      final metric = find.ancestor(
        of: find.text('المخاطر القائمة'),
        matching: find.byType(KpiMetric),
      );
      expect(find.descendant(of: metric, matching: find.byType(InkWell)), findsOneWidget);
    });
  });
}
