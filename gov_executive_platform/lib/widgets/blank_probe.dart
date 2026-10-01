import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ــــ قياس الفراغ في صفحةٍ معروضة: وقت التشغيل، على شاشة المستخدم وببياناته ــــ
//
// ولماذا يعيش هذا في المنصة لا في مجلد الاختبارات؟
//
// شكا المستخدم من فراغٍ أبيض بطول شاشة في أسفل لوحة القيادة، وأخفقت ثلاث
// جولات من الإصلاح متتابعة. والسبب أن الحارس كان يقيس لوحةً **ببيانات
// اخترعتُها**: ثلاثون مشروعاً، وإدارةٌ واحدة، ومستخدمان. فيقول «الذيل ٧٤
// بكسل» صادقاً فيما قاس، كاذباً عمّا يُرى — إذ لوحة الوزارة تعمل على مئات
// المشاريع وعشرات الإدارات. وقد ظهر عندها أن بطاقة «ترتيب الإدارات» وحدها
// تبلغ ٦٢٥٧ بكسلاً — ثماني شاشات هاتف — ولا يكشفها قياسٌ ينظر إلى الذيل.
//
// وبيانات المستخدم لا سبيل لي إليها: مشروع Firebase عنده لا عندي. فالمقياس
// الذي يعمل **عنده** هو وحده الذي يرى ما يرى، ويسمّي الودجة المذنبة بدل أن
// تُخمَّن جولةً بعد جولة.
//
// والقياس نفسه هو قياس `test/dashboard_blank_tail_test.dart` حرفياً، فلا
// يفترق ما يراه المستخدم عمّا يحرسه الاختبار.

/// بطاقةٌ مقيسة: ارتفاعها، وآخر ما رُسم داخلها، والفراغ بينهما.
class CardMeasurement {
  final String label;
  final double height;

  /// المسافة من أعلى البطاقة إلى أسفل آخر عنصر رُسم فيها.
  final double paintedHeight;

  const CardMeasurement({
    required this.label,
    required this.height,
    required this.paintedHeight,
  });

  /// الفراغ أسفل آخر محتوى داخل البطاقة. وقد يكون سالباً حين يخرج المحتوى
  /// عن البطاقة عمداً (جدولٌ يُمرَّر أفقياً)، وهذا ليس عطلاً.
  double get gap => height - paintedHeight;
}

/// حصيلة قياس صفحة كاملة.
class BlankReport {
  final List<CardMeasurement> cards;

  /// ارتفاع محتوى الصفحة كله (لا ارتفاع الشاشة).
  final double contentHeight;

  /// الفراغ بعد آخر ما رُسم في الصفحة.
  final double tail;

  /// عرض الشاشة وقت القياس — فبه تُفهم بقية الأرقام.
  final double screenWidth;

  const BlankReport({
    required this.cards,
    required this.contentHeight,
    required this.tail,
    required this.screenWidth,
  });

  /// حدّ «البطاقة الطويلة»: ما تجاوز شاشتي هاتف. وهو الحدّ نفسه الذي يحرسه
  /// `test/dashboard_blank_tail_test.dart`.
  static const double tallCard = 900;

  /// حدّ «الفراغ المريب» داخل بطاقة.
  static const double wideGap = 120;

  List<CardMeasurement> get tallCards => cards.where((c) => c.height > tallCard).toList();

  /// نصٌّ واحد يُنسخ ويُرسل — أنفع من وصفٍ بالكلام أو تسجيلِ شاشة.
  String toText() {
    final buffer = StringBuffer()
      ..writeln('قياس الفراغ — عرض الشاشة ${screenWidth.toStringAsFixed(0)}')
      ..writeln('ارتفاع الصفحة ${contentHeight.toStringAsFixed(0)} · '
          'الفراغ في الذيل ${tail.toStringAsFixed(0)}')
      ..writeln('البطاقات (${cards.length}):');
    for (final c in cards) {
      buffer.writeln('  ${c.label} | ارتفاع ${c.height.toStringAsFixed(0)}'
          ' | فراغ ${c.gap.toStringAsFixed(0)}');
    }
    return buffer.toString();
  }
}

/// هل يرسم هذا العنصر شيئاً مرئياً بذاته؟
///
/// النصوص والأيقونات وحدها: الرسوم البيانية تُرسم بـ`CustomPaint` ولا تُحصى
/// هنا، فيُبالغ القياس في فراغ بطاقات الرسوم لا يُقلّله — وهذا الاتجاه
/// الآمن: تحذيرٌ زائد خيرٌ من عطلٍ صامت.
bool paintsSomething(Widget w) {
  if (w is Text) return (w.data ?? '').trim().isNotEmpty;
  if (w is Icon) return true;
  if (w is RichText) return true;
  return false;
}

/// هل هذا العنصر داخل منطقة تُمرَّر أفقياً؟ (جدول المشاريع يخرج عن عرض
/// الصفحة بحقّ، فقياس ذيله يخلط القياس.)
bool inHorizontalScroll(Element element) {
  var scrolls = false;
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Scrollable &&
        (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
      scrolls = true;
      return false;
    }
    return true;
  });
  return scrolls;
}

/// يقيس الصفحة التي يقع [context] داخلها.
///
/// يُرجع `null` إن لم يجد صفحةً قابلة للقياس (لا `Scrollable` عمودياً) —
/// ولا يُخمَّن عندها رقم: تقريرٌ مُختلَق أسوأ من لا تقرير.
BlankReport? measurePage(BuildContext context) {
  final rootElement = context as Element;

  Element? scrollContent;
  double contentTop = 0;
  double contentBottom = 0;

  // ارتفاع المحتوى = ارتفاع **ابن** منطقة التمرير لا المنطقة نفسها: هذه
  // الأخيرة تملأ الشاشة دائماً، فقياسها يقيس الشاشة لا الصفحة.
  void findContent(Element e) {
    if (scrollContent != null) return;
    final object = e.renderObject;
    if (e.widget is Column && object is RenderBox && object.hasSize && object.attached) {
      var insideScroll = false;
      e.visitAncestorElements((a) {
        final w = a.widget;
        if (w is Scrollable && w.axisDirection == AxisDirection.down) {
          insideScroll = true;
          return false;
        }
        return true;
      });
      if (insideScroll) {
        scrollContent = e;
        contentTop = object.localToGlobal(Offset.zero).dy;
        contentBottom = object.localToGlobal(Offset(0, object.size.height)).dy;
        return;
      }
    }
    e.visitChildren(findContent);
  }

  rootElement.visitChildren(findContent);
  final content = scrollContent;
  if (content == null) return null;

  final cards = <CardMeasurement>[];
  var pagePainted = contentTop;

  void collect(Element e) {
    final object = e.renderObject;
    if (e.widget is Card && object is RenderBox && object.hasSize && object.attached) {
      final top = object.localToGlobal(Offset.zero).dy;
      var painted = top;
      var label = '؟';
      var named = false;

      void inside(Element child) {
        final childObject = child.renderObject;
        if (childObject is RenderBox && childObject.hasSize && childObject.attached) {
          final widget = child.widget;
          if (paintsSomething(widget) && !inHorizontalScroll(child)) {
            if (!named && widget is Text) {
              label = widget.data!.trim();
              named = true;
            }
            final bottom = childObject.localToGlobal(Offset(0, childObject.size.height)).dy;
            if (bottom > painted) painted = bottom;
          }
        }
        child.visitChildren(inside);
      }

      e.visitChildren(inside);
      cards.add(CardMeasurement(
        label: label,
        height: object.size.height,
        paintedHeight: painted - top,
      ));
    }

    // النصوص والأيقونات تُحصى للصفحة كلها، داخل البطاقات وخارجها.
    if (object is RenderBox && object.hasSize && object.attached) {
      if (paintsSomething(e.widget) && !inHorizontalScroll(e)) {
        final bottom = object.localToGlobal(Offset(0, object.size.height)).dy;
        if (bottom > pagePainted) pagePainted = bottom;
      }
    }
    e.visitChildren(collect);
  }

  content.visitChildren(collect);

  return BlankReport(
    cards: cards,
    contentHeight: contentBottom - contentTop,
    tail: contentBottom - pagePainted,
    screenWidth: MediaQuery.of(context).size.width,
  );
}

/// نافذة تعرض حصيلة القياس، ويُنسخ نصّها بضغطة.
class BlankReportDialog extends StatelessWidget {
  final BlankReport report;
  const BlankReportDialog({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final tall = report.tallCards;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('قياس الفراغ في هذه الصفحة',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Text(
                'ارتفاع الصفحة ${report.contentHeight.toStringAsFixed(0)} بكسل · '
                'الفراغ في ذيلها ${report.tail.toStringAsFixed(0)} · '
                'عرض الشاشة ${report.screenWidth.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
              ),
            ),
            if (tall.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  '⚠ ${tall.length} بطاقة أطول من شاشتين — وهي أرجح سبب الفراغ.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w700),
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: report.cards.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final card = report.cards[i];
                  final isTall = card.height > BlankReport.tallCard;
                  final isGappy = card.gap > BlankReport.wideGap;
                  return ListTile(
                    dense: true,
                    title: Text(card.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'ارتفاع ${card.height.toStringAsFixed(0)} · فراغ داخلها ${card.gap.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isTall || isGappy ? AppColors.danger : AppColors.textSecondary,
                        fontWeight: isTall || isGappy ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                report.toText(),
                style: const TextStyle(fontSize: 10.5, height: 1.6, color: AppColors.textSecondary),
                maxLines: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
