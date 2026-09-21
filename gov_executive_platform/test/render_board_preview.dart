// معاينة سريعة لشبكة ودجات اللوحة: العروض الثلاثة، ووضع الترتيب.
//
// مستقلة عن `render_dashboard_preview.dart` عمداً. تلك تُصيّر اللوحة كاملةً
// بـ ٦٥ مشروعاً وتُصوّر أربعة مواضع أثناء التمرير، وتستعمل `pumpAndSettle`
// الذي لا يستقرّ أبداً مع أي حركة دائمة على الصفحة — فتتجاوز مهلتها. وهذه
// تسأل سؤالاً واحداً محدوداً: **هل تُرصّ البطاقات بعروضها الصحيحة؟**
// فتستعمل `pump` بمدة ثابتة وتنتهي في ثوانٍ.
//
// تُشغَّل يدوياً:  flutter test test/render_board_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/dashboard_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

final _key = GlobalKey();

/// تحميل الخط بمهلة.
///
/// `rootBundle.load` في بيئة الاختبار قد **لا يعود أبداً** حين لا تكون
/// الأصول مبنيّة، و`FontLoader.load` ينتظره بلا حدّ — فتُعلَّق المعاينة كلها
/// حتى تنتهي مهلة الاختبار بلا صورة ولا رسالة. والمعاينة أداة نظر: خطٌّ
/// افتراضي أفضل من لا صورة.
Future<void> _loadFont(String family, List<String> paths) async {
  try {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(rootBundle.load(p).timeout(const Duration(seconds: 5)));
    }
    await loader.load().timeout(const Duration(seconds: 10));
  } catch (_) {
    // ignore: avoid_print
    print('⚠ تعذّر تحميل الخط $family — تُصيَّر المعاينة بالخط الافتراضي.');
  }
}

/// بطاقة وهمية بارتفاع معلوم: الغرض قياس **الرصّ** لا محتوى الودجت.
Widget _stub(DashboardWidgetConfig c) => Card(
      child: Container(
        height: 120,
        alignment: Alignment.center,
        child: Text('${c.type.label}\n(${c.width.label})',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );

const _layout = [
  DashboardWidgetConfig(
      id: '1', type: DashboardWidgetType.topProjectsList, width: DashboardWidgetWidth.third),
  DashboardWidgetConfig(
      id: '2', type: DashboardWidgetType.statusPieChart, width: DashboardWidgetWidth.third),
  DashboardWidgetConfig(
      id: '3', type: DashboardWidgetType.deptBarChart, width: DashboardWidgetWidth.third),
  DashboardWidgetConfig(
      id: '4', type: DashboardWidgetType.projectsTable, width: DashboardWidgetWidth.full),
  DashboardWidgetConfig(
      id: '5', type: DashboardWidgetType.pendingApprovalsList, width: DashboardWidgetWidth.half),
  DashboardWidgetConfig(
      id: '6', type: DashboardWidgetType.recentUpdatesList, width: DashboardWidgetWidth.half),
];

Future<void> _shoot(WidgetTester tester, Size size, bool arranging, String name) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RepaintBoundary(
          key: _key,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: DashboardWidgetBoardPreview(
              widgets: _layout,
              arranging: arranging,
              builder: _stub,
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File('build/$name.png')..parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('WROTE ${out.absolute.path}');
  expect(bytes.lengthInBytes, greaterThan(1000));
}

void main() {
  setUpAll(() async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('board at desktop width', (tester) async {
    await _shoot(tester, const Size(1280, 900), false, 'board_desktop');
  });

  testWidgets('board in arrange mode', (tester) async {
    await _shoot(tester, const Size(1280, 900), true, 'board_arranging');
  });

  testWidgets('board at phone width', (tester) async {
    await _shoot(tester, const Size(390, 844), false, 'board_phone');
  });
}
