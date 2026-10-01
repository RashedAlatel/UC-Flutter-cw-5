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
import 'package:firebase_core/firebase_core.dart';
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
        {bool isLate = false,
        PriorityLevel priority = PriorityLevel.medium,
        ProjectStatus? status,
        DateTime? due}) =>
    Project(
      id: 'p$i',
      departmentId: _dept,
      name: 'مشروع رقم $i',
      description: 'وصف',
      startDate: DateTime(2020, 1, 1),
      dueDate: due ?? (isLate ? DateTime(2020, 6, 1) : DateTime(2099, 1, 1)),
      // و[status] يُمرَّر حيث يُراد أن **يخالف** ما يقوله التاريخ.
      status: status ?? (isLate ? ProjectStatus.delayed : ProjectStatus.onTrack),
      priority: priority,
      progressPercent: (i * 9) % 100,
    );

/// كلُّ المؤشّرات التسعة على اللوحة دفعةً واحدة.
List<DashboardWidgetConfig> _allKpis() => [
      for (final (i, t) in DashboardWidgetType.values.where((t) => t.isKpi).indexed)
        DashboardWidgetConfig(id: 'k$i', type: t),
    ];

/// و[projects] تُمرَّر حيث يحتاج اختبارٌ بذرةً تفرّق بين حالتين.
///
/// والافتراضُ هو الأربعةُ كما كانت، فلا يتأثّر اختبارٌ قائمٌ يعدّ صيدَه.
AppStore _store({List<DashboardWidgetConfig>? layout, List<Project>? projects}) {
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
    ..projects = projects ??
        [
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

Future<AppStore> _pump(WidgetTester tester,
    {List<DashboardWidgetConfig>? layout, List<Project>? projects}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = _store(layout: layout, projects: projects);
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

  // ــــ بطاقةُ «المشاريع غير المكتملة» ــــ
  //
  // طُلبت لتُضغط فتُفتح قائمتُها ويُدخَل على تفصيل أيّ مشروعٍ منها. فالمقياسُ
  // السلسلةُ كاملةً: الرقمُ ← الورقةُ ← الشاشة.
  group('المشاريعُ غير المكتملة', () {
    List<DashboardWidgetConfig> only() => [
          const DashboardWidgetConfig(id: 'k', type: DashboardWidgetType.kpiIncomplete),
        ];

    // ــــ بذرةٌ تفرّق بين الصحيح والخطأ ــــ
    //
    // البذرةُ العامّةُ في هذا الملفّ **لا تفرّق**: لا مكتملَ فيها، ومتأخّرُها
    // الوحيد مخزَّنٌ «متأخّر» أيضاً. فطفرتان نجتا عليها — «عُدَّ كلَّ شيء»
    // و«رتّب بالحقل المخزَّن» — لأنّ جوابَهما عليها هو الجوابُ الصحيح.
    //
    // فهذه بذرةٌ فيها:
    //   • **مكتملٌ** — فيفترق «عُدَّ غيرَ المكتمل» عن «عُدَّ الكلّ».
    //   • **ومتأخّرٌ بالتاريخ مخزَّنٌ «على المسار»** — فيفترق الترتيبُ
    //     بـ`effectiveStatus` عن الترتيب بالحقل المخزَّن. وهو أحقُّ ما في
    //     القائمة بالنظر، ولو رُتِّب بالمخزَّن لغرق بين ما على المسار.
    //   • **ومهدَّدٌ مخزَّناً وموعدُه بعيد** — ولولاه لَما افترق الترتيبان
    //     أصلاً: المتأخّرُ بالتاريخ أقربُ موعداً كذلك، فالفاصلُ الثاني
    //     (الموعد) يُقدّمه حتّى لو رُتِّب بالحقل المخزَّن. فطفرةُ الترتيب
    //     نجت مرّتين قبل إضافته — والفِخاخُ لا تُكشف ببذرةٍ تُصدِّق كلَّ
    //     جواب.
    List<Project> mixed() => [
          _project(1, status: ProjectStatus.completed),
          _project(2, isLate: true, status: ProjectStatus.onTrack),
          _project(3),
          _project(5, status: ProjectStatus.atRisk),
        ];

    testWidgets('الرقمُ يعدّ ما لم يبلغ نهايتَه ويُسقط المكتمل', (tester) async {
      await _pump(tester, layout: only(), projects: mixed());
      // ثلاثةٌ من أربعة: الأوّلُ مكتملٌ فخرج.
      expect(find.text('3'), findsOneWidget,
          reason: 'ولو عُدَّ الكلُّ لظهرت ٤ — وهو ما يجب أن يُعضّ');
    });

    testWidgets('والبطاقةُ تُعرض ورقمُها على اللوحة', (tester) async {
      await _pump(tester, layout: only());
      expect(find.text('المشاريع غير المكتملة'), findsOneWidget);
    });

    // ــ والضغطُ يفتح القائمة ــ
    testWidgets('وتُضغط فتُفتح قائمتُها', (tester) async {
      await _pump(tester, layout: only());
      await tester.tap(find.text('المشاريع غير المكتملة'));
      await tester.pumpAndSettle();
      // عنوانُ الورقة هو العنوانُ نفسُه، فيصير اثنين: البطاقةُ والورقة.
      expect(find.text('المشاريع غير المكتملة'), findsNWidgets(2));
      expect(find.text('مشروع رقم 1'), findsOneWidget);
    });

    // ــ ومن القائمة يُدخَل على تفصيل المشروع ــ
    //
    // وهذا نصُّ ما طُلب: «واجعلني ادخل عليها وارى تفاصيلها».
    //
    // ــــ وحدُّ هذا الاختبار يُقال ــــ
    //
    // المقيسُ **أنّ الشاشةَ تُفتح**، لا أنّها تُرسَم. و`ProjectDetailScreen`
    // تقرأ من Firebase حين تُبنى، فترمي بلا تهيئةٍ حيّة — فيُلتقَط ذلك
    // صراحةً ويُقال، ولا يُدّعى أنّ التفاصيلَ قُرئت.
    //
    // ولا يُضعِف ذلك ما يُقاس: الطلبُ كان «اجعلني أدخل عليها»، والدخولُ هو
    // دفعُ الشاشة. ورسمُها مقيسٌ في اختباراتها هي.
    testWidgets('ويُدخَل من القائمة على تفاصيل مشروع', (tester) async {
      await _pump(tester, layout: only());
      await tester.tap(find.text('المشاريع غير المكتملة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مشروع رقم 1'));
      await tester.pump();

      // ــ والدليلُ على الدخول هو العطلُ نفسُه ــ
      //
      // لا شيءَ في هذا المسار يمسّ Firebase إلا `ProjectDetailScreen` حين
      // تُبنى. فـ`FirebaseException` **تُثبت أنّها بُنيت** — أي أنّ الشاشةَ
      // دُفعت فعلاً. ولا يصحّ البحثُ عنها في الشجرة: البناءُ أخفق فأُزيلت.
      expect(tester.takeException(), isA<FirebaseException>(),
          reason: 'الضغطُ في القائمة يدفع شاشةَ تفاصيل المشروع، فتُحاول القراءة');

    });

    // ــ والترتيبُ بالأسوأ أوّلاً، و**هنا تفترق `effectiveStatus`** ــ
    //
    // ولا تفترقان في **العدّ**: كلتاهما لا تقول «مكتمل» إلا إذا كان الحقلُ
    // المخزَّن مكتملاً. وقد ظننتُ غيرَ ذلك فقِستُ قبل أن أكتب، فظهر أنّ
    // اختباراً على العدّ يقيس ما لا يفترق — وهو أسوأُ من لا اختبار.
    //
    // وتفترقان في **الطبقة**: مشروعٌ مخزَّنٌ «على المسار» وقد فات موعدُه
    // يقرؤه `effectiveStatus` متأخّراً، فيجب أن يتصدّر القائمة. ولو رُتِّب
    // بالحقل المخزَّن لَغرق بين ما على المسار، وهو أحقُّ ما فيها بالنظر.
    testWidgets('والمتأخّرُ بالتاريخ يتصدّر ولو كان مخزَّناً «على المسار»',
        (tester) async {
      await _pump(tester, layout: only(), projects: mixed());
      await tester.tap(find.text('المشاريع غير المكتملة'));
      await tester.pumpAndSettle();
      final names = tester
          .widgetList<Text>(find.textContaining('مشروع رقم'))
          .map((t) => t.data ?? '')
          .toList();
      expect(names.first, 'مشروع رقم 2',
          reason: 'فات موعدُه وحقلُه المخزَّن «على المسار». ولو رُتِّب '
              'بالمخزَّن لَتصدّر «رقم 5» المهدَّدُ — وموعدُه سنة ٢٠٩٩');

      // ــ والمكتملُ ليس في القائمة أصلاً ــ
      //
      // فبطاقةٌ تعدّ ثلاثةً وتفتح أربعةً تقول شيئين — وهو العطلُ الذي
      // يُخشى حين يُحسب الرقمُ في موضعٍ وتُبنى القائمةُ في آخر.
      expect(names, isNot(contains('مشروع رقم 1')),
          reason: 'المكتملُ خرج من العدّ، فيجب أن يخرج من القائمة معه');
      expect(names, hasLength(3));
    });

    // ــ والأقربُ موعداً أوّلاً داخل الطبقة نفسِها ــ
    //
    // ولا تكشفه بذرةُ `mixed()`: طبقاتُها الثلاث مختلفةٌ فلا يقع فيها
    // تعادلٌ أصلاً، فطفرةُ «أُلغِ الفاصلَ الثاني» نجت عليها. فبذرةٌ من
    // طبقةٍ واحدةٍ وموعدَين — وهي الحالةُ الغالبةُ في حافظةٍ حقيقيّة: أكثرُ
    // المشاريع «على المسار»، والذي يُسأل عنه أقربُها موعداً.
    testWidgets('والأقربُ موعداً أوّلاً داخل الطبقة الواحدة', (tester) async {
      await _pump(tester, layout: only(), projects: [
        _project(7, due: DateTime(2099, 12, 1)),
        _project(8, due: DateTime(2027, 1, 1)),
      ]);
      await tester.tap(find.text('المشاريع غير المكتملة'));
      await tester.pumpAndSettle();
      final names = tester
          .widgetList<Text>(find.textContaining('مشروع رقم'))
          .map((t) => t.data ?? '')
          .toList();
      expect(names.first, 'مشروع رقم 8',
          reason: 'كلاهما على المسار، وموعدُ الثامن أقرب');
    });
  });
}
