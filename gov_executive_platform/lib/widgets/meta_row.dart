import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// صفّ حقائق قصيرة أسفل البطاقة.
///
/// **أين تقع الحراسة فعلاً:** `Wrap` يعطي أبناءه عرضاً غير محدود، ولا يُبلّغ
/// عن تجاوزٍ إطلاقاً — فالنص الطويل بداخله يُرسم بطوله كاملاً ويخرج من
/// البطاقة **بصمت**، بلا خطأ ولا استثناء. وهذا ما وقع على هاتف مسؤول
/// النظام، وما لم تكشفه الاختبارات لأنها كانت تنتظر استثناءً لا يأتي.
///
/// فالحراسة ليست هنا بل في البند نفسه: [MetaChip] يقتطع نصّه إن كان أبوه
/// **محدود العرض**، و[MetaLine] يأخذ السطر كاملاً لما طال بطبيعته. وهذا
/// الصفّ يوحّد المسافات فحسب، ويجعل موضع البنود مكاناً واحداً يُراجَع.
///
/// وقد جُرِّب فرضُ حدٍّ هنا بـ `ConstrainedBox`، فأثبتت طفرةٌ متعمَّدة أنه
/// **لا أثر له**: أبناء `Wrap` تُرسم خارج حدوده بلا اعتراض. فأُزيل بدل أن
/// يبقى سطراً يوهم بحمايةٍ لا يقدّمها.
class MetaRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const MetaRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: spacing, runSpacing: runSpacing, children: children);
}

/// حقيقة واحدة: أيقونة ونص. يُقتطع النص بثلاث نقاط **داخل** البطاقة إن ضاق
/// المكان، ولا يخرج منها.
class MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const MetaChip({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        // `Flexible` لا `Expanded`: البند يأخذ قدر حاجته حين يتّسع المكان،
        // فتصطفّ عدة بنود في السطر — ويتقلّص وحده حين يضيق.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// سطر نصّي طويل بطبيعته (أسماء المنفّذين مثلاً) — يأخذ عرض البطاقة كاملاً.
///
/// حشرُ نصٍّ طويل في صفٍّ من حقائق قصيرة هو أصل الخروج عن الإطار: الصف
/// مصمَّم لكلماتٍ معدودة. فما طال يُفرد له سطره، بحدٍّ أقصى سطرين ثم اقتطاع.
class MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const MetaLine({super.key, required this.icon, required this.text, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.7,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
