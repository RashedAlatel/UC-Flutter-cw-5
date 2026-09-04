// صفّ الودجة في حوار «تخصيص لوحة القيادة».
//
// في تسجيل من هاتف: اسم الودجة يُكتب **حرفاً في كل سطر** — «قائـ / مة: /
// تفا / صيـ / ل / ترتيـ / ب / الإدا / رات» — فيصير الصفّ بارتفاع أربعمئة
// بكسل وشبه مقروء.
//
// والسبب أنّ `ListTile` يعطي `trailing` عرضاً غير محدود ثم يترك للعنوان ما
// بقي، وكان `trailing` يحمل أربعة عناصر منها زرٌّ نصُّه «نصف العرض» كاملاً.
//
// وهذا القياس **هندسي لا نصّي**: `Row` و`Wrap` لا يُبلّغان عن تجاوز، ولا
// يفشل أي اختبار حين يُهرَس النص إلى حروف — كلٌّ من `find.text` يجده. فلا
// يكشفه إلا قياس عرض المربع المرسوم فيه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/customize_dashboard_dialog.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// عرض هاتف — وهو ما في التسجيل.
const double _phoneWidth = 390;

AppStore _store() => AppStore()
  ..currentUser = AppUser(
    id: 'u-1',
    name: 'مدير الإدارة',
    email: 'mgr@moj.gov.kw',
    phone: '',
    role: UserRole.departmentManager,
    // التخصيص صار بصلاحية: بلا `md` تُهمَل الطبقة الشخصية بحقّ، فلا يُقاس
    // شيء. والاختبار هنا عن هندسة الصفّ لا عن الصلاحية.
    permissionOverrides: const {'md': true},
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  )
  // تخطيط المستخدم كما ظهر في حواره: ودجة تحمل مقياساً وعرضاً معاً (أطول
  // الأسماء)، ومؤشر (لا مقياس له ولا عرض)، وودجت مخصص.
  ..setDashboardWidgetsForTest([
    const DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.departmentRankingList),
    const DashboardWidgetConfig(id: 'w2', type: DashboardWidgetType.projectsTable, width: DashboardWidgetWidth.full),
    const DashboardWidgetConfig(id: 'k1', type: DashboardWidgetType.kpiAvgProgress, width: DashboardWidgetWidth.third),
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

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(_phoneWidth, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: _store(),
      child: MaterialApp(
        theme: AppTheme.theme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: CustomizeDashboardDialog()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// زرّ قائمة الصفّ الذي يحمل هذا العنوان.
Finder _menuOf(String title) => find.descendant(
      of: find.widgetWithText(ListTile, title),
      matching: find.byIcon(Icons.more_vert_rounded),
    );

void main() {
  testWidgets('اسم الودجة يُعطى عرضاً يتّسع لكلمات لا لحروف', (tester) async {
    await _pump(tester);

    // أطول الأسماء وأشدّها عرضةً للهرس: يحمل مقياساً وعرضاً معاً.
    const label = 'قائمة: تفاصيل ترتيب الإدارات';
    final title = find.text(label);
    expect(title, findsOneWidget);

    final box = tester.renderObject<RenderBox>(title);
    final tile = tester.renderObject<RenderBox>(
      find.ancestor(of: title, matching: find.byType(ListTile)).first,
    );
    // ignore: avoid_print
    print('DIAG عرض الصفّ ${tile.size.width} · عرض العنوان ${box.size.width} · ارتفاع الصفّ ${tile.size.height}');
    expect(box.size.width, greaterThan(140),
        reason: 'عرض اسم الودجة ${box.size.width} بكسل — لا يتّسع لكلمة، فيلتفّ حرفاً حرفاً');

    // والارتفاع نتيجةُ العرض. لكن **القياس المعتمد هو العرض وحده**: خطّ
    // الاختبار يرسم كل حرف مربعاً بعرض القياس، فعدد الأسطر عنده ليس عدد
    // الأسطر في المتصفح. أما العرض فهندسةٌ محضة لا يبدّلها خط.
    expect(tile.size.height, lessThan(140),
        reason: 'ارتفاع صفّ الودجة ${tile.size.height} بكسل — نصٌّ ملتفّ لا صفّ');
  });

  testWidgets('العرض والمقياس يبقيان مقروءين بلا فتح القائمة', (tester) async {
    await _pump(tester);
    // جُمعت الأزرار في قائمة، فلا يجوز أن تضيع المعلومة معها.
    expect(find.textContaining('المقياس: متوسط نسبة الإنجاز'), findsWidgets);
    expect(find.textContaining('العرض: العرض كاملاً'), findsWidgets);
  });

  testWidgets('القائمة تحوي المقياس والعرض والحذف، والمقبض يبقى ظاهراً', (tester) async {
    await _pump(tester);

    // مقبض السحب ليس إجراءً يُنقر بل يدٌ تُمسك: إخفاؤه يُلغي إعادة الترتيب.
    expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);

    await tester.tap(_menuOf('قائمة: تفاصيل ترتيب الإدارات'));
    await tester.pumpAndSettle();
    expect(find.text('المقياس'), findsOneWidget);
    expect(find.text('عرض البطاقة'), findsOneWidget);
    expect(find.text('حذف الودجة'), findsOneWidget);
  });

  testWidgets('المؤشر لا يُعرض له عرضٌ لا أثر له', (tester) async {
    await _pump(tester);
    // المؤشرات تُعرض في الشريط القيادي الذي يوزّع أعمدته بنفسه، فـ«ثلث/نصف»
    // خيارٌ يَعِد بما لا يقع.
    // القائمة تُبنى بالتمرير لا كلّها دفعةً واحدة، فصفّ المؤشر لا يوجد في
    // الشجرة قبل الوصول إليه. و`ensureVisible` تحتاج عنصراً موجوداً أصلاً.
    await tester.scrollUntilVisible(
      find.text('مؤشر: نسبة الإنجاز العام'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final menu = _menuOf('مؤشر: نسبة الإنجاز العام');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('عرض البطاقة'), findsNothing);
    expect(find.text('المقياس'), findsNothing);
    expect(find.text('حذف الودجة'), findsOneWidget);
  });

  testWidgets('الحذف من القائمة يحذف الصفّ نفسه', (tester) async {
    await _pump(tester);
    expect(find.text('جدول: تفاصيل المشاريع'), findsOneWidget);

    // يُتحقَّق أن الفهرس المحذوف هو فهرس الصفّ لا غيره.
    final menu = _menuOf('جدول: تفاصيل المشاريع');
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الودجة'));
    await tester.pumpAndSettle();

    expect(find.text('جدول: تفاصيل المشاريع'), findsNothing);
    expect(find.text('قائمة: تفاصيل ترتيب الإدارات'), findsOneWidget);
  });

  testWidgets('اختيار المقياس من القائمة يغيّره على الصفّ', (tester) async {
    await _pump(tester);
    expect(find.textContaining('المقياس: متوسط نسبة الإنجاز'), findsOneWidget);

    await tester.tap(_menuOf('قائمة: تفاصيل ترتيب الإدارات'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<Object>, 'عدد المشاريع'));
    await tester.pumpAndSettle();

    expect(find.textContaining('المقياس: عدد المشاريع'), findsOneWidget);
  });
}
