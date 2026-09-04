// الشريط القيادي أعلى لوحة القيادة.
//
// وفيه حارسان لا يكشفهما النظر إلى الشاشة مرةً واحدة:
//
// ١) الشريط **يعرض ما اخترتَه** لا قائمةً ثابتة. وهذا قرار المستخدم الصريح:
//    بطاقات المؤشرات صارت ودجات تُحذف وتُرتَّب، والشريط لباسٌ لها لا بديل عنها.
//    فلو عاد أحدٌ يوماً فكتب فيه خمسة أرقام ثابتة، سقط اختبار الحذف هنا.
//
// ٢) لون النص يُشتقّ من إضاءة لون الهوية الفعلية. و«إعدادات المظهر» تقبل
//    إدخالاً حرّاً بالـhex، فلونٌ فاتح مع نصٍّ أبيض ثابت يجعل أول ما يُرى في
//    المنصة غير مقروء — وهي حالة لا يمرّ بها أحد إلا بعد أن تقع.
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
import 'package:gov_exec_platform/widgets/command_band.dart';
import 'package:gov_exec_platform/widgets/ornament_border.dart';

const _dept = 'd1';

AppUser _admin() => AppUser(
      id: 'admin',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '',
      role: UserRole.systemAdmin,
      departmentId: _dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(String id, {PriorityLevel priority = PriorityLevel.high, double progress = 50}) => Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: priority,
      progressPercent: progress,
    );

AppStore _store() => AppStore()
  ..currentUser = _admin()
  ..users = [_admin()]
  ..departments = [
    Department(id: _dept, name: 'الدعم الفني', headName: 'رئيس', colorValue: 0xFF1B5E4A, iconKey: 'build'),
  ]
  ..projects = [_project('p1'), _project('p2')];

Future<void> _pump(WidgetTester tester, AppStore store, {Size size = const Size(1400, 2400)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(AppColors.resetBrand);
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
}

/// لون نصٍّ بعينه كما رُسم فعلاً.
Color _colorOf(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text).first);
  return widget.style!.color!;
}

void main() {
  group('الشريط يعرض مؤشرات اللوحة لا قائمة ثابتة', () {
    testWidgets('المؤشرات الافتراضية تظهر داخل الشريط', (tester) async {
      await _pump(tester, _store());

      expect(find.byType(CommandBand), findsOneWidget);
      // العناوين موجودة، وكلٌّ منها **داخل** الشريط لا أسفله.
      for (final title in const [
        'نسبة الإنجاز العام',
        'إجمالي عدد المشاريع',
        'المشاريع عالية الأولوية',
        'طلبات بانتظار القيادة',
      ]) {
        expect(
          find.descendant(of: find.byType(CommandBand), matching: find.text(title)),
          findsOneWidget,
          reason: title,
        );
      }
    });

    testWidgets('حذف مؤشر من اللوحة يُخرجه من الشريط', (tester) async {
      final store = _store();
      // لوحةٌ بلا «إجمالي عدد المشاريع» — كما لو حذفه المستخدم.
      final kept = DashboardWidgetConfig.defaults()
          .where((w) => w.type != DashboardWidgetType.kpiProjectCount)
          .toList();
      store.setDashboardWidgetsForTest(kept);

      await _pump(tester, store);

      expect(find.text('إجمالي عدد المشاريع'), findsNothing,
          reason: 'الشريط يعرض ما على اللوحة، فلو كان قائمةً ثابتة لبقي المؤشر ظاهراً');
      expect(find.text('نسبة الإنجاز العام'), findsOneWidget, reason: 'وبقيةُ المؤشرات باقية');
    });

    testWidgets('الزخرفة الرسمية موصولة بالشريط', (tester) async {
      await _pump(tester, _store());
      // التصيير في الاختبار لا يرسم صور الأصول، فالمؤكَّد هنا هو **الوصل**:
      // الشريط يستعمل `OrnamentBorder` نفسها المستعملة في شاشة الدخول وتصدير
      // PDF، لا نسخةً منها ولا صورةً أخرى.
      expect(
        find.descendant(of: find.byType(CommandBand), matching: find.byType(OrnamentBorder)),
        findsOneWidget,
      );
    });

    testWidgets('لوحة بلا مؤشرات إطلاقاً تعرض الشريط بلا صفّ أرقام', (tester) async {
      final store = _store();
      store.setDashboardWidgetsForTest(
        DashboardWidgetConfig.defaults().where((w) => !w.type.isKpi).toList(),
      );
      await _pump(tester, store);

      expect(find.byType(CommandBand), findsOneWidget);
      expect(find.text('نسبة الإنجاز العام'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'لا ينهار الشريط بقائمة فارغة');
    });
  });

  group('لون النص يتبع إضاءة الهوية', () {
    testWidgets('الهوية الداكنة الافتراضية تعطي نصاً أبيض', (tester) async {
      await _pump(tester, _store());
      expect(_colorOf(tester, 'لوحة القيادة المركزية'), Colors.white);
    });

    testWidgets('هويةٌ فاتحة تقلب النص إلى حبر داكن', (tester) async {
      // لونٌ فاتح يُدخَل بالـhex من «إعدادات المظهر». مع نصٍّ أبيض ثابت يصير
      // عنوان الصفحة غير مقروء إطلاقاً.
      AppColors.applyBrand(primary: const Color(0xFFEFEFEF), accent: AppColors.defaultAccent);
      await _pump(tester, _store());
      expect(_colorOf(tester, 'لوحة القيادة المركزية'), AppColors.textPrimary);
    });
  });

  group('توزيع أعمدة الشريط', () {
    test('يضيق بضيق الشاشة', () {
      expect(CommandBand.columnsFor(1400), 5);
      expect(CommandBand.columnsFor(900), 3);
      expect(CommandBand.columnsFor(390), 2);
    });
  });

  group('بمقاس هاتف', () {
    testWidgets('لا يخرج نصٌّ عن حدود الشاشة', (tester) async {
      const size = Size(390, 1600);
      await _pump(tester, _store(), size: size);
      expect(tester.takeException(), isNull);

      final offenders = <String>[];
      for (final element in tester.allElements) {
        final widget = element.widget;
        if (widget is! Text) continue;
        final object = element.renderObject;
        if (object is! RenderBox || !object.hasSize || !object.attached) continue;
        // المناطق التي تُمرَّر أفقياً عمداً (جدول المشاريع) تقع خارج الشاشة
        // بحقّ، فتُستثنى — وإلا صاح الحارس دائماً فلم يُسمع.
        var scrolls = false;
        element.visitAncestorElements((a) {
          final w = a.widget;
          if (w is Scrollable && (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
            scrolls = true;
            return false;
          }
          return true;
        });
        if (scrolls) continue;

        final a = object.localToGlobal(Offset.zero).dx;
        final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
        final left = a < b ? a : b;
        final right = a < b ? b : a;
        if (left < -0.5 || right > size.width + 0.5) {
          offenders.add('«${widget.data}» من ${left.toStringAsFixed(0)} إلى ${right.toStringAsFixed(0)}');
        }
      }
      expect(offenders, isEmpty, reason: 'نصوص خرجت عن الشاشة:\n${offenders.join('\n')}');
    });
  });
}
