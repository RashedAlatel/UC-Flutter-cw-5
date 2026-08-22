// الفراغ في ذيل لوحة القيادة.
//
// في تسجيل من هاتف مسؤول النظام: اللوحة تعرض الشريط ثم المؤشرات ثم رسم
// توزيع الحالة وقائمة القرارات سليمين، ثم يمتدّ فراغٌ بأكثر من شاشة كاملة
// إلى نهاية التمرير — فراغٌ **بلا بطاقة**: لا خلفية بيضاء ولا عنوان.
//
// وهذا ما لا يكشفه أي اختبار قائم: كلها تقيس أن النص لا يخرج عن الشاشة، ولا
// يقيس أحدها أن الصفحة تنتهي حيث ينتهي محتواها.
//
// فالقياس هنا: ارتفاع المحتوى كله ناقص أدنى نقطة رُسم فيها شيء فعلاً.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/dashboard_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _dept = 'd-tech';

AppUser _manager() => AppUser(
      id: 'mgr',
      name: 'مدير الإدارة',
      email: 'mgr@moj.gov.kw',
      phone: '',
      role: UserRole.departmentManager,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

/// بشكل بيانات المستخدم كما في التسجيل: ثلاثون مشروعاً، أغلبها متأخر،
/// وتاريخ بدءٍ في المستقبل كما تفعل بيانات الوزارة المستوردة.
Project _project(int i) => Project(
      id: 'p$i',
      departmentId: _dept,
      name: 'مشروع رقم $i',
      description: 'وصف',
      startDate: DateTime(2026, 12, 1),
      dueDate: i % 3 == 0 ? DateTime(2099, 1, 1) : DateTime(2026, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: (i * 7) % 100,
      managerUids: const ['mgr'],
    );

AppStore _store() => AppStore()
  ..currentUser = _manager()
  ..users = [_manager()]
  ..departments = [
    Department(id: _dept, name: 'الإدارة العامة لتقنية المعلومات', headName: 'رئيس', colorValue: 0xFF1B5E4A, iconKey: 'settings'),
  ]
  ..projects = [for (var i = 0; i < 30; i++) _project(i)];

/// متجرٌ بحجم الوزارة: مسؤول نظام، ومئتا موظف، وأربعون إدارة، وثلاثمئة
/// مشروع — لا ثلاثون مشروعاً في إدارة واحدة.
///
/// ــــ ولماذا هذا الحجم بالذات؟ ــــ
///
/// لأن ثلاث جولات من الإصلاح أخفقت وأنا أقيس لوحةً ببيانات اخترعتُها: ثلاثون
/// مشروعاً ومستخدمان. فكان الحارس يقول «الذيل ٧٤ بكسل» صادقاً فيما قاس،
/// كاذباً عمّا يراه المستخدم — إذ لوحته تعمل على بيانات وزارة.
///
/// وفيه إدارتان **بلا مشاريع** عمداً: القسمة على صفر تعطي `NaN`، ورسمٌ
/// بقيمة `NaN` قد لا يرسم شيئاً ويشغل ارتفاعه كاملاً — بطاقةٌ بيضاء تماماً.
AppStore _ministryStore() {
  final admin = AppUser(
    id: 'admin',
    name: 'مسؤول النظام',
    email: 'admin@moj.gov.kw',
    phone: '',
    role: UserRole.systemAdmin,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  );
  final departments = [
    for (var d = 0; d < 40; d++)
      Department(
        id: 'd$d',
        name: 'الإدارة العامة رقم $d للتخطيط والمتابعة',
        headName: 'رئيس الإدارة $d',
        colorValue: 0xFF1B5E4A,
        iconKey: 'settings',
      ),
  ];
  final users = [
    admin,
    for (var u = 0; u < 200; u++)
      AppUser(
        id: 'u$u',
        name: 'عبدالرحمن بن عبدالعزيز المطيري $u',
        email: 'u$u@moj.gov.kw',
        phone: '',
        role: UserRole.employee,
        departmentId: 'd${u % 40}',
        departmentIds: ['d${u % 40}'],
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      ),
  ];
  return AppStore()
    ..currentUser = admin
    ..users = users
    ..departments = departments
    // ــ التحديثات اليومية ليست تفصيلاً في هذا المتجر ــ
    //
    // متجر الاختبار كان **بلا تحديثات**، فبطاقة «أحدث التحديثات» تعرض «لا
    // توجد تحديثات بعد» ولا تبني صفوفها أصلاً. وفي تلك الصفوف كان
    // `Row(stretch)` بلا `IntrinsicHeight`، فارتفاع البطاقة **`Infinity`**
    // على شاشة المستخدم. أي أن العطل كان يختبئ خلف بيانات ناقصة عندي، لا
    // خلف منطقٍ معقّد.
    ..dailyUpdates = [
      for (var i = 0; i < 12; i++)
        DailyUpdate(
          id: 'du$i',
          projectId: 'p$i',
          departmentId: 'd${i % 38}',
          authorUid: 'u$i',
          authorName: 'عبدالرحمن بن عبدالعزيز المطيري $i',
          date: DateTime(2026, 8, 20 - (i % 15)),
          achievements: 'أُنجزت مرحلة التحليل ورُفعت الوثائق إلى لجنة المراجعة.',
          completedTasks: const [],
          newRisks: const [],
          blockers: const [],
          decisionsRequired: const [],
          progressPercent: 40,
        ),
    ]
    ..projects = [
      for (var i = 0; i < 300; i++)
        Project(
          id: 'p$i',
          // إدارتان بلا مشاريع: `% 38` يترك d38 وd39 فارغتين.
          departmentId: 'd${i % 38}',
          name: 'مشروع رقم $i لتطوير الخدمات',
          description: 'وصف',
          startDate: DateTime(2026, 12, 1),
          dueDate: i % 3 == 0 ? DateTime(2099, 1, 1) : DateTime(2026, 1, 1),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: (i * 7) % 100,
          managerUids: ['u${i % 200}'],
          executorUids: ['u${(i + 1) % 200}'],
        ),
    ];
}

/// هل يرسم هذا العنصر شيئاً مرئياً بذاته؟
bool _paints(Widget w) {
  if (w is Text) return (w.data ?? '').trim().isNotEmpty;
  if (w is Icon) return true;
  if (w is RichText) return true;
  return false;
}

/// هل هذا العنصر داخل منطقة تُمرَّر أفقياً؟ (جدول المشاريع يخرج عن عرض
/// الصفحة بحقّ، فقياس ذيله يخلط القياس.)
bool _inHorizontalScroll(Element element) {
  var scrolls = false;
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Scrollable &&
        (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
      scrolls = true;
      return false;
    }
    return true;
  });
  return scrolls;
}

/// اسم البطاقة = أول نصّ فيها، وهو عنوانها.
String _cardTitle(Element card) {
  var title = '؟';
  var found = false;
  void visit(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is Text && (w.data ?? '').trim().isNotEmpty) {
      title = w.data!;
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  card.visitChildren(visit);
  return title;
}

void main() {
  // ــ تشخيص: كل نوع ودجة على حدة، بارتفاعه وآخر ما رُسم داخله ــ
  for (final type in DashboardWidgetType.values.where((t) => !t.isKpi)) {
    testWidgets('ودجة ${type.name} لا تشغل ارتفاعاً بلا رسم', (tester) async {
      const size = Size(390, 4200);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _store()
        ..setDashboardWidgetsForTest([DashboardWidgetConfig(id: 'only', type: type)]);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: DashboardScreen()),
          ),
        ),
      ));
      await tester.pump();

      final scroller = find.byType(SingleChildScrollView).first;
      final content = tester.renderObject<RenderBox>(
        find.descendant(of: scroller, matching: find.byType(Column)).first,
      );
      final top = content.localToGlobal(Offset.zero).dy;
      final bottom = content.localToGlobal(Offset(0, content.size.height)).dy;

      var painted = top;
      for (final element in tester.allElements) {
        final object = element.renderObject;
        if (object is! RenderBox || !object.hasSize || !object.attached) continue;
        if (!_paints(element.widget) || _inHorizontalScroll(element)) continue;
        final b = object.localToGlobal(Offset(0, object.size.height)).dy;
        if (b > painted) painted = b;
      }
      // ١٦٠ لا ٨٠: بطاقات الرسوم ذات ارتفاع ثابت (٢٦٠) والرسم لا يملؤه
      // كلَّه، فيبقى فراغٌ داخل البطاقة مقصود. والحارس هنا ضد الفراغ **بعد**
      // آخر بطاقة لا داخلها.
      expect(bottom - painted, lessThan(160),
          reason: 'ودجة ${type.name} تشغل ارتفاعاً بلا رسم: ذيل ${bottom - painted} بكسل');
    });
  }

  testWidgets('الودجت المخصص ذو الخانتين لا يحجز ارتفاع عشرٍ', (tester) async {
    // الحارس المباشر على ما سمّاه القياس: `SizedBox(height: 220)` مهما كان
    // ما فيه. ومدير إدارة يجمّع مشاريعه حسب الحالة يحصل على خانتين، فكان
    // يبقى داخل بطاقته نحو مئتي بكسل فراغاً — وهي آخر ودجة في لوحته.
    const size = Size(390, 2000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _store()
      ..setDashboardWidgetsForTest([
        DashboardWidgetConfig(
          id: 'c1',
          type: DashboardWidgetType.custom,
          custom: const CustomWidgetSpec(
            title: 'المشاريع المهمة',
            source: CustomWidgetSource.projects,
            groupBy: 'status',
            display: CustomWidgetDisplay.bar,
          ),
        ),
      ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DashboardScreen()),
        ),
      ),
    ));
    await tester.pump();

    final scroller = find.byType(SingleChildScrollView).first;
    final content = tester.renderObject<RenderBox>(
      find.descendant(of: scroller, matching: find.byType(Column)).first,
    );
    final top = content.localToGlobal(Offset.zero).dy;
    final bottom = content.localToGlobal(Offset(0, content.size.height)).dy;
    var painted = top;
    for (final element in tester.allElements) {
      final object = element.renderObject;
      if (object is! RenderBox || !object.hasSize || !object.attached) continue;
      if (!_paints(element.widget) || _inHorizontalScroll(element)) continue;
      final b = object.localToGlobal(Offset(0, object.size.height)).dy;
      if (b > painted) painted = b;
    }
    expect(bottom - painted, lessThan(100),
        reason: 'ودجت مخصص بخانتين يترك ${bottom - painted} بكسل فراغاً');
  });

  testWidgets('لوحة القيادة لا تترك فراغاً في ذيلها', (tester) async {
    // سطح طويل عمداً: يُلغي التمرير فيقع كل شيء في إحداثيات واحدة، فيُقاس
    // ذيل المحتوى مباشرةً بلا حساب إزاحة تمرير.
    const size = Size(390, 4200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // تخطيط المستخدم **حرفياً** كما قرأتُه من حوار «تخصيص اللوحة» في
    // تسجيله — لا تخطيطاً مشابهاً ولا الافتراضي. والفرق ليس تفصيلاً: محاولتي
    // السابقة قاست ٧٤ بكسلاً ولم تُعِد إنتاج شكواه، لأن فيها ما ليس عنده
    // وليس فيها ما عنده: **ودجت مخصص**، و**جدول بعرض نصف**.
    final store = _store()
      ..setDashboardWidgetsForTest([
        ...DashboardWidgetConfig.kpiDefaults(),
        const DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.pendingApprovalsList),
        const DashboardWidgetConfig(id: 'w2', type: DashboardWidgetType.deptBarChart),
        const DashboardWidgetConfig(id: 'w3', type: DashboardWidgetType.recentUpdatesList),
        const DashboardWidgetConfig(id: 'w4', type: DashboardWidgetType.departmentRankingList),
        const DashboardWidgetConfig(id: 'w5', type: DashboardWidgetType.statusPieChart),
        const DashboardWidgetConfig(id: 'w6', type: DashboardWidgetType.projectsTable),
        const DashboardWidgetConfig(id: 'w7', type: DashboardWidgetType.topProjectsList),
        DashboardWidgetConfig(
          id: 'w8',
          type: DashboardWidgetType.custom,
          custom: const CustomWidgetSpec(
            title: 'المشاريع المهمة',
            source: CustomWidgetSource.projects,
            groupBy: 'status',
            display: CustomWidgetDisplay.bar,
          ),
        ),
      ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DashboardScreen()),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // ارتفاع المحتوى = ارتفاع **ابن** الـScrollView لا الـScrollView نفسه:
    // هذا الأخير يملأ الشاشة دائماً، فقياسه يقيس الشاشة لا الصفحة.
    final scroller = find.byType(SingleChildScrollView).first;
    final content = tester.renderObject<RenderBox>(
      find.descendant(of: scroller, matching: find.byType(Column)).first,
    );
    final viewportTop = content.localToGlobal(Offset.zero).dy;
    final contentBottom = content.localToGlobal(Offset(0, content.size.height)).dy;

    var paintedBottom = viewportTop;
    String lastPainted = '—';
    for (final element in tester.allElements) {
      final object = element.renderObject;
      if (object is! RenderBox || !object.hasSize || !object.attached) continue;
      if (!_paints(element.widget) || _inHorizontalScroll(element)) continue;
      final bottom = object.localToGlobal(Offset(0, object.size.height)).dy;
      if (bottom > paintedBottom) {
        paintedBottom = bottom;
        final w = element.widget;
        lastPainted = w is Text ? '«${w.data}»' : w.runtimeType.toString();
      }
    }

    final tail = contentBottom - paintedBottom;
    // ignore: avoid_print
    print('ارتفاع المحتوى: ${contentBottom - viewportTop} · آخر ما رُسم: '
        '${paintedBottom - viewportTop} ($lastPainted) · الذيل الفارغ: $tail');

    expect(tail, lessThan(80),
        reason: 'ذيلٌ فارغ قدره $tail بكسل بعد آخر محتوى مرسوم');
  });

  testWidgets('اللوحة ببيانات بحجم الوزارة لا تترك فراغاً', (tester) async {
    const size = Size(390, 8000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _ministryStore()
      ..setDashboardWidgetsForTest([
        ...DashboardWidgetConfig.kpiDefaults(),
        const DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.pendingApprovalsList),
        const DashboardWidgetConfig(id: 'w2', type: DashboardWidgetType.deptBarChart),
        const DashboardWidgetConfig(id: 'w3', type: DashboardWidgetType.recentUpdatesList),
        const DashboardWidgetConfig(id: 'w4', type: DashboardWidgetType.departmentRankingList),
        const DashboardWidgetConfig(id: 'w5', type: DashboardWidgetType.statusPieChart),
        const DashboardWidgetConfig(id: 'w6', type: DashboardWidgetType.projectsTable),
        const DashboardWidgetConfig(id: 'w7', type: DashboardWidgetType.topProjectsList),
        const DashboardWidgetConfig(id: 'w8', type: DashboardWidgetType.topUsersChart),
        DashboardWidgetConfig(
          id: 'w9',
          type: DashboardWidgetType.custom,
          custom: const CustomWidgetSpec(
            title: 'المشاريع المهمة',
            source: CustomWidgetSource.projects,
            groupBy: 'status',
            display: CustomWidgetDisplay.bar,
          ),
        ),
      ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DashboardScreen()),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final scroller = find.byType(SingleChildScrollView).first;
    final content = tester.renderObject<RenderBox>(
      find.descendant(of: scroller, matching: find.byType(Column)).first,
    );
    final top = content.localToGlobal(Offset.zero).dy;
    final bottom = content.localToGlobal(Offset(0, content.size.height)).dy;
    var painted = top;
    String lastPainted = '—';
    for (final element in tester.allElements) {
      final object = element.renderObject;
      if (object is! RenderBox || !object.hasSize || !object.attached) continue;
      if (!_paints(element.widget) || _inHorizontalScroll(element)) continue;
      final b = object.localToGlobal(Offset(0, object.size.height)).dy;
      if (b > painted) {
        painted = b;
        final w = element.widget;
        lastPainted = w is Text ? '«${w.data}»' : w.runtimeType.toString();
      }
    }
    // ignore: avoid_print
    print('DIAG وزارة :: ارتفاع ${bottom - top} · آخر رسم ${painted - top} '
        '($lastPainted) · ذيل ${bottom - painted}');
    expect(bottom - painted, lessThan(80),
        reason: 'ذيلٌ فارغ قدره ${bottom - painted} بكسل ببيانات بحجم الوزارة');
  });

  testWidgets('لا بطاقة في اللوحة أطول من شاشتين ببيانات الوزارة', (tester) async {
    // ــ لماذا سقفٌ على ارتفاع **البطاقة** لا على ذيل الصفحة؟ ــ
    //
    // لأن ذيل الصفحة كان ٧٤ بكسل في كل قياس — سليماً — بينما كانت بطاقة
    // «ترتيب الإدارات» وحدها **٦٢٥٧ بكسل**: تعرض كل إدارة بلا سقف، وبوزارة
    // فيها أربعون إدارة صارت ثماني شاشات هاتف لبطاقة واحدة، في صفحة طولها
    // عشرة آلاف بكسل. فالحارس الذي ينظر إلى الذيل وحده يمرّ على هذا صامتاً.
    //
    // وهذا هو الفارق الذي أعمى ثلاث جولات من الإصلاح: القياس كان بثلاثين
    // مشروعاً وإدارة واحدة، والمستخدم على بيانات وزارة.
    const size = Size(390, 40000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _ministryStore()
      ..setDashboardWidgetsForTest([
        ...DashboardWidgetConfig.kpiDefaults(),
        const DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.pendingApprovalsList),
        const DashboardWidgetConfig(id: 'w2', type: DashboardWidgetType.deptBarChart),
        const DashboardWidgetConfig(id: 'w3', type: DashboardWidgetType.recentUpdatesList),
        const DashboardWidgetConfig(id: 'w4', type: DashboardWidgetType.departmentRankingList),
        const DashboardWidgetConfig(id: 'w5', type: DashboardWidgetType.statusPieChart),
        const DashboardWidgetConfig(id: 'w6', type: DashboardWidgetType.projectsTable),
        const DashboardWidgetConfig(id: 'w7', type: DashboardWidgetType.topProjectsList),
        const DashboardWidgetConfig(id: 'w8', type: DashboardWidgetType.topUsersChart),
      ]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DashboardScreen()),
        ),
      ),
    ));
    await tester.pump();

    final tall = <String>[];
    final infinite = <String>[];
    for (final cardElement in find.byType(Card).evaluate()) {
      final box = cardElement.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      // **المحدودية أولاً**: `Infinity` ليس «طويلاً» بل مكسوراً، والمقارنة
      // `> 900` تصدق عليه فيُبلَّغ عنه كأنه بطاقة طويلة. وهو ليس كذلك: بطاقةٌ
      // بارتفاع لا نهائي تبتلع الصفحة كلها وتظهر بيضاء إلى آخر التمرير.
      if (!box.size.height.isFinite) {
        infinite.add(_cardTitle(cardElement));
        continue;
      }
      if (box.size.height <= 900) continue;
      tall.add('«${_cardTitle(cardElement)}» بارتفاع ${box.size.height.toStringAsFixed(0)}');
    }

    expect(infinite, isEmpty,
        reason: 'بطاقات بارتفاع لا نهائي — تبتلع الصفحة وتظهر بيضاء:\n${infinite.join('\n')}');
    expect(tall, isEmpty,
        reason: 'بطاقات أطول من شاشتين على الهاتف:\n${tall.join('\n')}');
  });

  testWidgets('لوحة بلا ودجات تقول ذلك ولا تترك صفحة بيضاء', (tester) async {
    // يكفي أن يحذف المستخدم ودجاته من «تخصيص اللوحة» ليقع في هذا الحال —
    // وكان يرى عنواناً ثم فراغاً إلى آخر التمرير بلا كلمة تفسير.
    const size = Size(390, 1400);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _store()
      ..setDashboardWidgetsForTest(
        DashboardWidgetConfig.defaults().where((w) => w.type.isKpi).toList(),
      );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DashboardScreen()),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('لوحتك بلا رسوم ولا قوائم'), findsOneWidget);
    expect(find.text('أضف ودجة'), findsOneWidget);
  });
}
