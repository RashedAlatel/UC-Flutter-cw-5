import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// يعيد إنتاج بنية AppShell للشاشات الضيقة (هاتف) بالضبط — Scaffold مع
/// extendBodyBehindAppBar + SafeArea + Padding + ClipRRect + Container —
/// للتحقق مما إذا كان محتوى الصفحة يظهر فعلياً بحجم مرئي على شاشة هاتف، أم
/// يختفي بسبب تعارض extendBodyBehindAppBar مع SafeArea.
void main() {
  testWidgets('narrow shell body content is visible at phone size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('لوحة القيادة'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          drawer: const Drawer(child: SizedBox()),
          body: Container(
            decoration: BoxDecoration(gradient: AppColors.pageGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: AppColors.background,
                    child: const SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('لوحة القيادة المركزية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('مؤشرات فورية على أداء الخطة الاستراتيجية ومشاريع الوزارة'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final titleFinder = find.text('لوحة القيادة المركزية');
    expect(titleFinder, findsOneWidget);
    final rect = tester.getRect(titleFinder);
    // ignore: avoid_print
    print('title rect: $rect, screen: 390x844');

    // يجب أن يكون العنوان مرئياً فعلياً داخل حدود الشاشة، لا بحجم صفري ولا خارجها.
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844));
  });
}
