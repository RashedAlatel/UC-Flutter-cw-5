import 'package:flutter/material.dart';

/// شريط حقول التصفية أعلى الشاشات — **بعرض يتبع الشاشة لا بعرضٍ ثابت**.
///
/// كانت الحقول بعروض مثبّتة (٢٨٠ و٢٢٠ بكسل)، وهي معقولة على سطح المكتب
/// وتتجاوز شاشة الهاتف. والأسوأ أن التجاوز يقع **بلا أي خطأ**: الحقول داخل
/// `Wrap`، و`Wrap` لا يُبلّغ عن خروج أبنائه عن حدوده — فيخرج عنوان الحقل من
/// الصفحة صامتاً، ولا يكشفه إلا القياس الهندسي أو عينُ من يفتحها على جواله.
///
/// فهنا يُقاس العرض المتاح: إن ضاق أخذ كل حقل السطر كاملاً، وإلا فعرضه
/// المفضَّل — بحدٍّ أقصى هو عرض السطر على أي حال.
class FilterBar extends StatelessWidget {
  /// كل حقل مع عرضه المفضَّل على الشاشات الواسعة.
  final List<({double preferredWidth, Widget child})> fields;

  /// دون هذا العرض يأخذ كل حقل سطراً كاملاً.
  final double stackBelow;

  final double spacing;
  final double runSpacing;

  const FilterBar({
    super.key,
    required this.fields,
    this.stackBelow = 560,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      final stack = available.isFinite && available < stackBelow;
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final field in fields)
            SizedBox(
              width: !available.isFinite
                  ? field.preferredWidth
                  : (stack ? available : field.preferredWidth.clamp(0.0, available)),
              child: field.child,
            ),
        ],
      );
    });
  }
}
