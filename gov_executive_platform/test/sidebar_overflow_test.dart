import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// يعيد إنتاج بنية الشريط الجانبي بالضبط (نفس الأبعاد والحشوات والخط الفعلي
/// Tajawal) للتحقق من عدم وجود تجاوز أفقي (RenderFlex overflow) عند أطول
/// تسميات التنقل الفعلية، بمعزل عن Firebase الذي لا يمكن تهيئته في اختبار.
void main() {
  const labels = [
    'لوحة القيادة',
    'الإدارات',
    'مركز القرارات',
    'المشاريع',
    'التقارير',
    'سجل التدقيق',
    'المستخدمون',
    'إدارة الأدوار',
    'إعدادات المظهر',
  ];

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: Container(
                  width: 240,
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
                        child: Row(children: [
                          Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('المنصة التنفيذية',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.3)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          children: labels
                              .map((label) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      child: Row(children: [
                                        const Icon(Icons.dashboard_rounded, size: 19),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        ),
                                      ]),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('no overflow at 1440x900 (typical laptop)', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 1024x900 (near the 980 breakpoint)', (tester) async {
    await pumpAt(tester, const Size(1024, 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 2880x1800 (retina logical-equivalent wide)', (tester) async {
    await pumpAt(tester, const Size(2880, 1800));
    expect(tester.takeException(), isNull);
  });
}
