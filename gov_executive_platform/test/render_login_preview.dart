// أداة معاينة (وليست اختباراً تعاقدياً): تُصيّر شاشة تسجيل الدخول بخط
// Tajawal الحقيقي وأصول الشعار والزخرفة، وتحفظ الناتج كصورة PNG لمراجعة
// التصميم بصرياً قبل النشر. تُشغَّل يدوياً عبر:
//   flutter test test/render_login_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/screens/login_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _shotKey = ValueKey('login-preview');

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

void main() {
  testWidgets('render login screen preview', (WidgetTester tester) async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ]);
    // بدون تحميل خط الأيقونات تظهر كل الأيقونات كمربعات في المعاينة.
    await _loadFont('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);

    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 760));

    await tester.pumpWidget(MaterialApp(
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
        child: RepaintBoundary(key: _shotKey, child: LoginScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // فك تحميل الصور: AssetImage غير متزامن ولا يكتمل داخل pumpAndSettle
    // وحده، فتظهر المعاينة بلا شعار ولا زخرفة رغم سلامتهما فعلياً.
    await tester.runAsync(() async {
      for (final p in ['assets/images/logo.png', 'assets/images/frame_border.png']) {
        await precacheImage(AssetImage(p), tester.element(find.byKey(_shotKey)));
      }
    });
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/login_preview.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${out.absolute.path}');
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
