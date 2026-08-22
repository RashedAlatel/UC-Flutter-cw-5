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

  testWidgets('لوحة القيادة لا تترك فراغاً في ذيلها', (tester) async {
    // سطح طويل عمداً: يُلغي التمرير فيقع كل شيء في إحداثيات واحدة، فيُقاس
    // ذيل المحتوى مباشرةً بلا حساب إزاحة تمرير.
    const size = Size(390, 4200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // تخطيط المستخدم كما ظهر في حوار «تخصيص اللوحة» في تسجيله: رسمان
    // وقائمتان وتفاصيل الترتيب — لا التخطيط الافتراضي.
    final store = _store()
      ..setDashboardWidgetsForTest(const [
        DashboardWidgetConfig(id: 'k1', type: DashboardWidgetType.kpiAvgProgress),
        DashboardWidgetConfig(id: 'k2', type: DashboardWidgetType.kpiProjectCount),
        DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.deptBarChart),
        DashboardWidgetConfig(id: 'w2', type: DashboardWidgetType.statusPieChart),
        DashboardWidgetConfig(id: 'w3', type: DashboardWidgetType.pendingApprovalsList),
        DashboardWidgetConfig(id: 'w4', type: DashboardWidgetType.recentUpdatesList),
        DashboardWidgetConfig(id: 'w5', type: DashboardWidgetType.departmentRankingList),
        DashboardWidgetConfig(id: 'w6', type: DashboardWidgetType.projectsTable, width: DashboardWidgetWidth.full),
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
