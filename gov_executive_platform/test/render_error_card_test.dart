import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/widgets/render_error_card.dart';

/// ودجة تفشل عمداً، لنتأكد أن الفشل **يُقرأ** لا أن يُرسم مستطيلاً صامتاً.
class _AlwaysThrows extends StatelessWidget {
  const _AlwaysThrows();

  @override
  Widget build(BuildContext context) => throw StateError('عطل مُتعمَّد للاختبار');
}

void main() {
  testWidgets('استثناء أثناء البناء يُعرض نصّاً عربياً لا مستطيلاً صامتاً', (tester) async {
    // نُثبّت البنّاء كما يفعل main()، ثم نُسقط ودجة عمداً. ويُعاد الأصل داخل
    // جسم الاختبار لا عبر addTearDown: إطار الاختبارات يتحقّق من أن البنّاء
    // عاد إلى أصله **قبل** تشغيل دوال التنظيف، فالاستعادة المتأخرة تفشل.
    final original = ErrorWidget.builder;
    ErrorWidget.builder = (details) => RenderErrorCard(message: details.exceptionAsString());

    await tester.pumpWidget(const MaterialApp(home: _AlwaysThrows()));

    // الاستثناء متوقَّع: نستهلكه حتى لا يُفشل الاختبار.
    expect(tester.takeException(), isA<StateError>());

    expect(find.text('تعذّر عرض هذه الشاشة'), findsOneWidget);
    expect(find.textContaining('عطل مُتعمَّد للاختبار'), findsOneWidget);
    expect(find.textContaining('إصدار'), findsOneWidget);

    ErrorWidget.builder = original;
  });

  testWidgets('البطاقة تُبنى بلا MaterialApp — قد تُستدعى فوق الجذر نفسه', (tester) async {
    // هذا ليس تفصيلاً: الاستثناء قد يقع فوق شجرة MaterialApp فلا يبقى ثيم ولا
    // اتجاه موروث، وبطاقةٌ تعتمد على موروث غائب ترمي خطأً ثانياً يخفي الأول.
    await tester.pumpWidget(const RenderErrorCard(message: 'خطأ بلا سياق'));
    expect(tester.takeException(), isNull);
    expect(find.text('تعذّر عرض هذه الشاشة'), findsOneWidget);
    expect(find.text('خطأ بلا سياق'), findsOneWidget);
  });
}
