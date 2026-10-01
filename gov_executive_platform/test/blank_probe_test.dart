// أداة «قياس الفراغ» داخل المنصة.
//
// بُنيت لأن ثلاث جولات من الإصلاح أخفقت: كنت أقيس لوحةً ببيانات اخترعتُها
// (ثلاثون مشروعاً وإدارة واحدة) بينما لوحة المستخدم على بيانات وزارة. وبيانات
// المستخدم لا سبيل إليها من هنا، فنُقل المقياس إليه.
//
// وهذا الاختبار يحرس الأداة نفسها: أداةُ تشخيص تُطمئن ولا تقيس أسوأ من لا
// أداة — يفتحها المستخدم فيراها تقول «لا فراغ» وهي لم تنظر، فيُغلق باب
// التشخيص الوحيد الباقي.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/widgets/blank_probe.dart';

/// صفحةٌ مصطنعة: بطاقة قصيرة ممتلئة، وبطاقة طويلة فارغة أسفلها.
class _Page extends StatelessWidget {
  final double tallCardHeight;
  const _Page({super.key, required this.tallCardHeight});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Card(
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Padding(padding: EdgeInsets.all(8), child: Text('بطاقة ممتلئة')),
            ),
          ),
          Card(
            child: SizedBox(
              height: tallCardHeight,
              width: double.infinity,
              child: const Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(padding: EdgeInsets.all(8), child: Text('بطاقة طويلة')),
              ),
            ),
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
  }
}

/// يفتح الصفحة ويقيسها من داخلها، كما تفعل لوحة القيادة.
Future<BlankReport?> _measure(WidgetTester tester, double tallHeight) async {
  await tester.binding.setSurfaceSize(const Size(390, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: _Page(key: key, tallCardHeight: tallHeight)),
    ),
  ));
  await tester.pump();
  return measurePage(key.currentContext!);
}

void main() {
  testWidgets('المقياس يرى كل بطاقة ويسمّيها بعنوانها', (tester) async {
    final report = await _measure(tester, 300);
    expect(report, isNotNull);
    // بطاقتان لا أقل: لو رأى المقياس صفراً لمرّ الحارس التالي كذباً.
    expect(report!.cards, hasLength(2));
    expect(report.cards.map((c) => c.label), containsAll(['بطاقة ممتلئة', 'بطاقة طويلة']));
  });

  testWidgets('المقياس يقيس الفراغ داخل البطاقة الطويلة', (tester) async {
    final report = await _measure(tester, 300);
    final tall = report!.cards.firstWhere((c) => c.label == 'بطاقة طويلة');
    final full = report.cards.firstWhere((c) => c.label == 'بطاقة ممتلئة');
    // الطويلة فيها نصٌّ واحد أعلاها، فالباقي فراغ.
    expect(tall.gap, greaterThan(200));
    // والقصيرة ممتلئة نسبياً، فلا يجوز أن يُبلَّغ عنها بالقدر نفسه.
    expect(full.gap, lessThan(tall.gap));
  });

  testWidgets('المقياس يسمّي البطاقة الأطول من شاشتين', (tester) async {
    final short = await _measure(tester, 300);
    expect(short!.tallCards, isEmpty);

    final long = await _measure(tester, 1200);
    expect(long!.tallCards, hasLength(1));
    expect(long.tallCards.single.label, 'بطاقة طويلة');
  });

  testWidgets('المقياس يقيس ذيل الصفحة لا ارتفاع الشاشة', (tester) async {
    final report = await _measure(tester, 300);
    // الذيل = ٢٠٠ بكسل بعد آخر بطاقة **زائد** الجزء الفارغ من أسفل البطاقة
    // الطويلة نفسها. وهذا هو المقصود: الفراغ فراغٌ سواء وقع داخل آخر بطاقة
    // أو بعدها — والمستخدم يرى الأبيض لا يرى حدود البطاقات.
    expect(report!.tail, greaterThan(400));
    expect(report.tail, lessThan(600));
    // وارتفاع الصفحة ارتفاع محتواها لا ارتفاع السطح (٤٠٠٠).
    expect(report.contentHeight, lessThan(1000));
  });

  testWidgets('النصّ المنسوخ يحمل الأرقام كلها', (tester) async {
    final report = await _measure(tester, 1200);
    final text = report!.toText();
    expect(text, contains('بطاقة طويلة'));
    expect(text, contains('ارتفاع الصفحة'));
    expect(text, contains('الفراغ في الذيل'));
  });

  testWidgets('النافذة تعرض سطراً لكل بطاقة وتحذّر من الطويلة', (tester) async {
    final report = await _measure(tester, 1200);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BlankReportDialog(report: report!),
      ),
    ));
    await tester.pump();

    expect(find.text('بطاقة ممتلئة'), findsWidgets);
    expect(find.text('بطاقة طويلة'), findsWidgets);
    expect(find.textContaining('أطول من شاشتين'), findsOneWidget);
  });

  testWidgets('صفحة بلا تمرير تُعيد لا شيء ولا تختلق رقماً', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(key: key, child: const Text('لا تمرير هنا'))),
    ));
    await tester.pump();
    expect(measurePage(key.currentContext!), isNull);
  });
}
