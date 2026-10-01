import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ترويسةٌ تنزل أزرارُها سطراً حين يضيق العرض.
///
/// ــــ العطل الذي أوجدها ــــ
///
/// لقطةٌ من هاتف مسؤول النظام: عنوان مشروعٍ من سبع كلمات يُرسم **حرفاً أو
/// حرفين في كل سطر** — «مشرو / ع ممار / سه و / صيانه» — فيشغل نصف الشاشة
/// طولاً وتصير البطاقة غير مقروءة.
///
/// وسببه صفٌّ يجمع على سطرٍ واحد عنواناً في `Expanded` وشارةً وأربعة أزرار
/// أيقونات. والثابت يأخذ عرضه أولاً — أربعة أزرار بـ٤٨ لكلٍّ منها وشارةٌ
/// بنحو ٧٠ = ~٢٦٢ — وعلى آيفون SE لا يبقى للعنوان إلا نحو ٢٥ بكسل.
/// و`Expanded` **لا يشتكي**: يأخذ ما بقي مهما ضاق، فيلتفّ النص حرفاً حرفاً.
///
/// ــــ ولماذا ويدجت مشتركة لا إصلاحٌ في مكانه؟ ــــ
///
/// لأن `CommandBand` يعالج هذا بعينه منذ جولةٍ سابقة: `LayoutBuilder` وعتبة،
/// وتحتها العنوان بعرضٍ كامل والأزرار في `Wrap`. فالمعالجة الثانية في مكانٍ
/// آخر تجعل في المنصة حلَّين لمسألةٍ واحدة يفترقان بأول تعديل.
///
/// وهي تُختبر وحدها: شاشةُ تفصيل المشروع تطلب Firestore في `build`، فلا
/// تُبنى في بيئة الاختبار أصلاً — واختبارٌ لا يُبنى لا يحرس شيئاً.
class ResponsiveHeaderRow extends StatelessWidget {
  /// العنوان وما تحته — يأخذ ما بقي من العرض فوق العتبة، وكلَّه تحتها.
  final Widget title;

  /// الشارات والأزرار. تبقى بترتيبها في الحالين.
  final List<Widget> actions;

  /// دونها تنزل الأزرار سطراً. ويُترك مُعامَلاً لأجل الاختبار وحده — والقيمة
  /// المستعملة في المنصة واحدة.
  final double breakpoint;

  const ResponsiveHeaderRow({
    super.key,
    required this.title,
    this.actions = const [],
    this.breakpoint = AppWidth.narrowHeader,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return title;
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), ...actions],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بعرضٍ كامل صراحةً: `Column` لا تمدّ أبناءها، فيأخذ العنوان عرضه
          // الطبيعي ويترك بياضاً بجانبه.
          SizedBox(width: double.infinity, child: title),
          const SizedBox(height: AppSpace.xs),
          // `Wrap` لا `Row`: الأزرار تسع في سطرٍ واحد على أضيق هاتف، وإن
          // أُضيف خامسٌ يوماً نزل سطراً بدل أن يُطفح الإطار.
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    });
  }
}
