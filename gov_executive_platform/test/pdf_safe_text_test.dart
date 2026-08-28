// النصُّ الذي كان يُسقط تصدير PDF — ويُقاس هنا في المولّد نفسه.
//
// ــــ لماذا يُبنى ملفٌّ حقيقيّ في هذا الاختبار ــــ
//
// لأن دالةً نقيّةً تُعيد النصّ المنقّى **لا تُثبت أن المولّد يقبله**. وقد
// كانت هذه بعينها طريقةَ اكتشاف العطل: بناءُ الملفّ لا فحصُ النصّ. فيُبنى
// هنا ملفٌّ من كل نصٍّ قيس أنه يكسر، ويُشترط أن يخرج ببايتاته.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:gov_exec_platform/utils/pdf_safe_text.dart';

/// يبني صفحةً واحدةً فيها [text] — ويرمي إن رفضها المولّد.
Future<int> renderLength(String text) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font),
    ),
    build: (_) => pw.Text(text, style: pw.TextStyle(font: font)),
  ));
  return (await doc.save()).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // النصوصُ التي قيس أنها تُسقط المولّد: همزةٌ في أوّل السلسلة تليها حركة.
  const breaking = ['أُنجزت', 'أَنجزت', 'أّنجزت', 'أُ', 'أُفق العدالة', 'إِدارة', 'آُخر'];

  group('ما كان يكسر المولّد يمرّ بعد التنقية', () {
    for (final text in breaking) {
      testWidgets('«$text»', (tester) async {
        expect(await renderLength(pdfSafeText(text)), greaterThan(400));
      });
    }

    // وإثباتُ أن العطل حقيقيّ لا مفترض: النصُّ الخام نفسُه يرمي.
    testWidgets('والخامُ نفسُه يرمي — فالتنقية ليست احتياطاً بلا سبب', (tester) async {
      await expectLater(renderLength('أُنجزت'), throwsA(isA<RangeError>()));
    });
  });

  group('ولا تمسّ التنقيةُ ما لا يكسر', () {
    test('الحركةُ في وسط الكلمة تبقى', () {
      expect(pdfSafeText('مسجَّل'), 'مسجَّل');
      expect(pdfSafeText('إنجازُ الأسبوع'), 'إنجازُ الأسبوع');
      expect(pdfSafeText('المُسنَد إليه'), 'المُسنَد إليه');
    });

    test('وحرفٌ غيرُ قابلٍ للتفكيك يبقى بحركته', () {
      // «مُشروع» قيس أنه يمرّ، فلا يُنقّى.
      expect(pdfSafeText('مُشروع'), 'مُشروع');
      expect(pdfSafeText('اُ'), 'اُ');
    });

    test('والنصُّ اللاتيني والفارغ والحرفُ الواحد بلا تغيير', () {
      expect(pdfSafeText(''), '');
      expect(pdfSafeText('أ'), 'أ');
      expect(pdfSafeText('MOJ Report'), 'MOJ Report');
    });

    test('وتُسقط الحركة الأولى وحدها لا الكلمة', () {
      expect(pdfSafeText('أُنجزت'), 'أنجزت');
      expect(pdfSafeText('أُفق العدالة'), 'أفق العدالة');
      // حركتان متتاليتان: تُسقطان معاً، ويبقى ما بعدهما.
      expect(pdfSafeText('أُّنجزت'), 'أنجزت');
    });
  });
}
