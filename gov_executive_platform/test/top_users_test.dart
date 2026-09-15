// «الأشخاص حسب المشاريع» — الرسم الجديد، والباب الآخر لنفس السؤال.
//
// السؤال («من عليه أكثر المشاريع؟») يُطرح من موضعين: بطاقة جاهزة على اللوحة،
// ومنشئ الودجت الحرّ بالتجميع «حسب المنفّذ». وكان الثاني يجمّع حسب النص
// المدموج لأسماء المنفّذين كلهم، فمشروعٌ لثلاثة يصنع خانةً واحدة اسمها
// «أحمد، هاجر، طارق». فلو تُرك كذلك لتناقض البابان: البطاقة تقول إن على أحمد
// ثلاثة مشاريع، والودجت الحرّ يقول إن «أحمد وهاجر» عليهما مشروع واحد.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/dashboard_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/custom_widget_view.dart';

const _dept = 'd1';

AppUser _user(String id, String name, {UserRole role = UserRole.employee}) => AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(
  String id, {
  List<String> executorUids = const [],
  List<String> executorNames = const [],
  List<String> managerUids = const [],
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.high,
      progressPercent: 50,
      executorUids: executorUids,
      executorNames: executorNames,
      managerUids: managerUids,
    );

AppStore _store({List<Project>? projects, List<AppUser>? users}) => AppStore()
  ..currentUser = _user('admin', 'مسؤول النظام', role: UserRole.systemAdmin)
  ..departments = [
    Department(id: _dept, name: 'الدعم الفني', headName: 'رئيس', colorValue: 0xFF1B5E4A, iconKey: 'build'),
  ]
  ..users = users ??
      [
        _user('admin', 'مسؤول النظام', role: UserRole.systemAdmin),
        _user('u1', 'أحمد المليجي'),
        _user('u2', 'هاجر حامد'),
      ]
  ..projects = projects ?? const [];

/// هل هذا النص داخل منطقة تُمرَّر أفقياً؟
///
/// جدول المشاريع يُمرَّر أفقياً عمداً، فأعمدته الأبعد تقع **خارج** حدود
/// الشاشة وهذا هو المطلوب لا عطل. ولولا هذا الاستثناء لأبلغ الحارس عن عشرات
/// النصوص السليمة، فيُهمَل بلاغه كله — والحارس الذي يصيح دائماً لا يُسمع.
bool _inHorizontalScroll(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is Scrollable &&
        (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// كل نصّ مرسوم يقع داخل عرض الشاشة — الفحص الهندسي نفسه المستعمل في
/// `card_overflow_test.dart`، لأن `Wrap` لا يُبلّغ عن تجاوز أبنائه بأي استثناء.
void _expectAllTextInside(WidgetTester tester, Size size) {
  final offenders = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! Text) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize || !object.attached) continue;
    if (_inHorizontalScroll(element)) continue;
    final a = object.localToGlobal(Offset.zero).dx;
    final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
    final left = a < b ? a : b;
    final right = a < b ? b : a;
    if (left < -0.5 || right > size.width + 0.5) {
      offenders.add('«${widget.data}» من ${left.toStringAsFixed(0)} إلى ${right.toStringAsFixed(0)}');
    }
  }
  expect(offenders, isEmpty, reason: 'نصوص خرجت عن حدود الشاشة:\n${offenders.join('\n')}');
}

Future<void> _pumpDashboard(WidgetTester tester, AppStore store, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

void main() {
  group('الودجت الحرّ يجمّع حسب شخص لا حسب نصّ مدموج', () {
    const spec = CustomWidgetSpec(
      title: 'من عليه أكثر المشاريع',
      source: CustomWidgetSource.projects,
      groupBy: 'executor',
      display: CustomWidgetDisplay.bar,
    );

    test('مشروعٌ لثلاثة يُحسب على كلٍّ منهم لا على تركيبتهم', () {
      final store = _store(projects: [
        _project('p1', executorNames: const ['أحمد المليجي', 'هاجر حامد', 'طارق السالم']),
        _project('p2', executorNames: const ['أحمد المليجي']),
      ]);
      final counts = CustomWidgetEngine.compute(store, spec);
      expect(counts['أحمد المليجي'], 2);
      expect(counts['هاجر حامد'], 1);
      expect(counts['طارق السالم'], 1);
      expect(counts.containsKey('أحمد المليجي، هاجر حامد، طارق السالم'), isFalse,
          reason: 'التركيبة المدموجة كانت هي الخانة، وهي أصل العطل');
    });

    test('المنفّذ المسجَّل بحسابه يُنسب باسمه لا بمعرّفه', () {
      final store = _store(projects: [_project('p1', executorUids: const ['u1'])]);
      expect(CustomWidgetEngine.compute(store, spec)['أحمد المليجي'], 1);
    });

    test('من ورد بحسابه وباسمه معاً لا يُحسب مرتين', () {
      final store = _store(projects: [
        _project('p1', executorUids: const ['u1'], executorNames: const ['أحمد المليجي']),
      ]);
      expect(CustomWidgetEngine.compute(store, spec)['أحمد المليجي'], 1);
    });

    test('مشروع بلا منفّذين يبقى في خانة «غير محدد»', () {
      final store = _store(projects: [_project('p1')]);
      expect(CustomWidgetEngine.compute(store, spec)['غير محدد'], 1);
    });

    test('التجميع بحقل آخر لم يتغيّر سلوكه', () {
      final store = _store(projects: [_project('p1'), _project('p2')]);
      const byPriority = CustomWidgetSpec(
        title: 'حسب الأولوية',
        source: CustomWidgetSource.projects,
        groupBy: 'priority',
        display: CustomWidgetDisplay.bar,
      );
      expect(CustomWidgetEngine.compute(store, byPriority), {'عالية': 2});
    });
  });

  group('بطاقة الأشخاص على اللوحة', () {
    testWidgets('تظهر بأسماء الأشخاص وأعداد مشاريعهم', (tester) async {
      final store = _store(projects: [
        _project('p1', managerUids: const ['u1']),
        _project('p2', executorUids: const ['u1']),
        _project('p3', executorUids: const ['u2']),
      ]);
      await _pumpDashboard(tester, store, const Size(1400, 2400));

      expect(find.text('الأشخاص حسب: عدد المشاريع'), findsOneWidget);
      expect(find.text('أحمد المليجي'), findsOneWidget);
      expect(find.text('هاجر حامد'), findsOneWidget);
      // أحمد مديرٌ في واحد ومنفّذٌ في آخر ⇒ اثنان، لا واحد.
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('من لا مشروع له لا يُزاحم الأسماء', (tester) async {
      final store = _store(projects: [_project('p1', executorUids: const ['u1'])]);
      await _pumpDashboard(tester, store, const Size(1400, 2400));
      expect(find.text('أحمد المليجي'), findsOneWidget);
      expect(find.text('هاجر حامد'), findsNothing);
    });

    testWidgets('من لا يملك متابعة أشخاص يرى سبباً لا رسماً خالياً', (tester) async {
      final store = _store(projects: [_project('p1', executorUids: const ['u1'])])
        ..currentUser = _user('u1', 'أحمد المليجي');
      await _pumpDashboard(tester, store, const Size(1400, 2400));
      expect(find.text('لا تملك صلاحية متابعة أشخاص'), findsOneWidget);
    });

    testWidgets('وبمقاس هاتف لا يخرج نصّ عن الشاشة', (tester) async {
      const size = Size(375, 667);
      final store = _store(
        projects: [_project('p1', executorUids: const ['u1'])],
        users: [
          _user('admin', 'مسؤول النظام', role: UserRole.systemAdmin),
          _user('u1', 'عبدالرحمن بن عبدالعزيز المطيري الشمري العتيبي'),
        ],
      );
      await _pumpDashboard(tester, store, size);
      expect(tester.takeException(), isNull);
      _expectAllTextInside(tester, size);
    });
  });

  group('صفّ المؤشرات صار ودجات على اللوحة', () {
    testWidgets('المؤشرات السبعة تظهر ومنها الجديدان', (tester) async {
      final store = _store(projects: [
        _project('p1', executorUids: const ['u1']),
        _project('p2', executorUids: const ['u2']),
      ]);
      await _pumpDashboard(tester, store, const Size(1400, 2400));

      expect(find.text('إجمالي عدد المشاريع'), findsOneWidget);
      expect(find.text('المشاريع عالية الأولوية'), findsOneWidget);
      expect(find.text('نسبة الإنجاز العام'), findsOneWidget);
      expect(find.text('متوسط التأخير عن الخطة'), findsOneWidget);
      expect(find.text('المخاطر القائمة'), findsOneWidget);
      expect(find.text('العوائق النشطة'), findsOneWidget);
      expect(find.text('طلبات بانتظار القيادة'), findsOneWidget);
    });
  });
}
