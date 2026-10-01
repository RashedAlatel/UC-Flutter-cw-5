import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// يتحقق هندسياً (بمقارنة المستطيلات الفعلية على الشاشة) من عدم تراكب نص
/// القيمة المختارة في DropdownButtonFormField مع تسمية الحقل العائمة، بنفس
/// الإعداد المستخدم في شاشة "المشاريع" (isDense + عرض 220).
void main() {
  testWidgets('dropdown selected value does not overlap its floating label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: null,
                decoration: const InputDecoration(labelText: 'تصفية حسب الإدارة', isDense: true),
                items: const [
                  DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final labelFinder = find.text('تصفية حسب الإدارة');
    final valueFinder = find.text('كل الإدارات');
    expect(labelFinder, findsOneWidget);
    expect(valueFinder, findsOneWidget);

    final labelRect = tester.getRect(labelFinder);
    final valueRect = tester.getRect(valueFinder);
    // ignore: avoid_print
    print('label rect: $labelRect / value rect: $valueRect');

    final overlaps = labelRect.overlaps(valueRect);
    expect(overlaps, isFalse, reason: 'label $labelRect overlaps value $valueRect');
  });

  testWidgets('dashboard filter-bar department dropdown (tighter contentPadding) does not overlap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 190,
              child: DropdownButtonFormField<String?>(
                initialValue: null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الإدارة',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                  DropdownMenuItem(value: 'x', child: Text('إدارة التشغيل')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final labelRect = tester.getRect(find.text('الإدارة'));
    final valueRect = tester.getRect(find.text('كل الإدارات'));
    // ignore: avoid_print
    print('label rect: $labelRect / value rect: $valueRect');

    expect(labelRect.overlaps(valueRect), isFalse, reason: 'label $labelRect overlaps value $valueRect');
  });
}
