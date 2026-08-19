// أداة معاينة (وليست اختباراً تعاقدياً): تُصيّر لوحة القيادة ببيانات بحجم
// بيانات الوزارة الحقيقية (٦٥ مشروعاً) وودجت مخصص، بمقاس الهاتف ومقاس سطح
// المكتب، وتحفظ الناتج PNG لمراجعة التخطيط بصرياً.
//
// سبب وجودها: عيب "الصفحة فارغة عند النزول للأسفل" و"الودجت المخصص لا يظهر"
// تكرّر أربع مرات وفشلت محاولات إصلاحه اعتماداً على قراءة الكود وحده. المعاينة
// المُصيَّرة هي ما يكشف العيب فعلاً.
//
// تُشغَّل يدوياً:  flutter test test/render_dashboard_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/dashboard_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/theme/department_icons.dart';

const _shotKey = ValueKey('dashboard-preview');

/// متجر مملوء يدوياً ببيانات تجريبية — ممكن الآن لأن حقول Firebase داخل
/// AppStore صارت late (تُقيَّم عند أول استخدام فعلي فقط).
AppStore _seededStore() {
  final store = AppStore()
    ..currentUser = AppUser(
      id: 'admin-1',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '+96555555555',
      role: UserRole.systemAdmin,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

  store.departments = List.generate(
    4,
    (i) => Department(
      id: 'dept_$i',
      name: ['إدارة تطوير النظم', 'إدارة التشغيل', 'إدارة الدعم الفني', 'إدارة الإحصاء والبحوث'][i],
      headName: 'مسؤول الإدارة $i',
      colorValue: 0xFF0E4D3C,
      iconKey: DepartmentIcons.defaultKey,
    ),
  );

  // ٦٥ مشروعاً — نفس حجم بيانات الوزارة المستوردة فعلياً.
  store.projects = List.generate(
    65,
    (i) => Project(
      id: 'p$i',
      departmentId: 'dept_${i % 4}',
      name: 'مشروع تطوير الخدمة الإلكترونية رقم ${i + 1}',
      description: 'وصف مختصر',
      startDate: DateTime(2026, 1, 10),
      dueDate: DateTime(2026, 9, 30),
      status: ProjectStatus.values[i % ProjectStatus.values.length],
      priority: PriorityLevel.values[i % PriorityLevel.values.length],
      progressPercent: (i * 7) % 100,
      executorNames: const ['فهد المطيري', 'نورة العنزي'],
    ),
  );

  // التخطيط الافتراضي + ودجت مخصص مضاف في الآخر (كما يفعل التطبيق اليوم).
  store.globalDashboardWidgets = [
    ...DashboardWidgetConfig.defaults(),
    const DashboardWidgetConfig(
      id: 'custom-1',
      type: DashboardWidgetType.custom,
      custom: CustomWidgetSpec(
        title: 'ودجت مخصص — توزيع المشاريع حسب الإدارة',
        source: CustomWidgetSource.projects,
        display: CustomWidgetDisplay.bar,
        groupBy: 'department',
      ),
    ),
  ];

  return store;
}

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

Future<void> _shoot(WidgetTester tester, Size size, String name) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(size);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: _seededStore(),
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
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: RepaintBoundary(key: _shotKey, child: DashboardScreen()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // نقيس الارتفاع الكلي للمحتوى القابل للتمرير — هو الرقم الذي يكشف "الجدار".
  final scrollable = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final total = position.maxScrollExtent + size.height;
  // ignore: avoid_print
  print('[$name] viewport=${size.height.toStringAsFixed(0)} '
      'totalHeight=${total.toStringAsFixed(0)}px '
      'screens=${(total / size.height).toStringAsFixed(1)}');

  // نصوّر عدة مواضع أثناء النزول، لا أعلى الصفحة فقط — العيب الذي يشتكي منه
  // المستخدم يظهر في منتصف الصفحة وآخرها لا في أولها.
  final stops = <double>[0, position.maxScrollExtent * 0.35, position.maxScrollExtent * 0.7, position.maxScrollExtent];
  for (var i = 0; i < stops.length; i++) {
    position.jumpTo(stops[i]);
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/${name}_$i.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${out.absolute.path}  (scrollOffset=${stops[i].toStringAsFixed(0)})');
    expect(bytes.lengthInBytes, greaterThan(1000));
  }
}

void main() {
  setUpAll(() async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('dashboard at phone size', (tester) async {
    await _shoot(tester, const Size(390, 844), 'dash_phone');
  });

  testWidgets('dashboard at desktop size', (tester) async {
    await _shoot(tester, const Size(1280, 900), 'dash_desktop');
  });
}
