/// بطاقةُ المنصة — سطحٌ واحدٌ ورأسٌ واحد.
///
/// ــــ ما تبتلعه ــــ
///
/// كانت `_ChartCard` مكتوبةً **مرّتين، منحرفتين**: عنوانٌ بحجم ١٥ في لوحة
/// القيادة و١٤٫٥ في صفحة المشروع، وواحدةٌ تقبل وصفاً ثانويّاً و«تقصيراً
/// للمحتوى» والأخرى لا. وثالثةٌ في `custom_widget_view.dart` تكتب رأسَها
/// بيدها. فالانحرافُ هو المرض: نسخةٌ تُعدَّل ولا يبلغ التعديلُ أختَها.
///
/// ــــ والسطحُ هادئٌ بقرار ــــ
///
/// حدٌّ رفيعٌ وظلٌّ شبهُ معدوم — الطابعُ الحكوميّ. والظلالُ الطافيةُ
/// والتدرّجاتُ محصورةٌ ببطاقات المؤشّرات ورؤوس الصفحات، وهي ما يُرى أوّلاً.
/// راجع `StatCard`.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class AppCard extends StatelessWidget {
  /// عنوانُ البطاقة — ويُترك فارغاً لبطاقةٍ بلا رأس.
  final String? title;

  /// وصفٌ ثانويٌّ تحته.
  final String? subtitle;

  /// ما يُعرض في يمين الرأس: زرٌّ أو شارة.
  final Widget? trailing;

  final Widget child;

  /// ارتفاعُ البطاقة. وهو **سقفٌ** لا مقدارٌ مفروض حين [shrinkToChild].
  final double? height;

  /// هل يُترك للمحتوى أن يُقصّر البطاقة؟
  ///
  /// الرسومُ لا محتوى لها يُقاس فتحتاج ارتفاعاً محدّداً؛ أما القوائمُ فتعرف
  /// ارتفاعَها من صفوفها. وفرضُ ارتفاعٍ ثابتٍ على قائمةٍ من ثلاثة صفوف يترك
  /// فراغاً داخل البطاقة، وعلى الجوال — حيث كلُّ ودجةٍ بعرض السطر — تتراكم
  /// هذه الفراغاتُ فتصير الصفحةُ بيضاءَ أكثرَ مما هي مقروءة.
  final bool shrinkToChild;

  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.height,
    this.shrinkToChild = false,
    this.padding = const EdgeInsets.all(18),
  });

  /// ما يبقى للمحتوى بعد الرأس.
  double? get _childHeight {
    if (height == null) return null;
    final header = title == null ? 0.0 : (subtitle == null ? 50.0 : 68.0);
    return height! - header;
  }

  @override
  Widget build(BuildContext context) {
    final inner = _childHeight;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              AppCardHeader(title: title!, subtitle: subtitle, trailing: trailing),
              const SizedBox(height: 14),
            ],
            if (inner == null)
              child
            else if (shrinkToChild)
              ConstrainedBox(constraints: BoxConstraints(maxHeight: inner), child: child)
            else
              SizedBox(height: inner, child: child),
          ],
        ),
      ),
    );
  }
}

/// رأسُ البطاقة وحدَه — لمن يبني سطحَه بنفسه.
class AppCardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppCardHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.cardTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppType.cardSubtitle),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// عنوانُ قسمٍ داخل صفحة: شريطٌ ذهبيٌّ رفيعٌ ثمّ العنوان ثمّ فاصل.
///
/// وكان مكتوباً **ثلاثَ مرّات**: اثنتان متشابهتان، **والثالثةُ شيءٌ آخر** —
/// نصٌّ بحجم ١٤ بلا شريطٍ ولا فاصل، في شاشة المحذوفات. فتكسب المحذوفاتُ
/// شريطَها وتشبه أخواتِها، وهو المقصودُ من نظام التصميم.
///
/// ولا حشوةَ فيه: المستدعون يضعون تباعدَهم بأنفسهم، فحشوةٌ هنا تُضاعفه.
class SectionTitle extends StatelessWidget {
  final String text;

  /// عددٌ يُعرض بعد العنوان — «(١٢)» أو «(١٢ — ٣ قيد العمل)».
  final String? count;

  /// أيقونةٌ بعد الشريط — **لقسمٍ يُعرف بها**.
  ///
  /// وليست زينةً تُضاف لكلّ عنوان: «مثبّت لك» و«مشاريع تحت التركيز» كانا
  /// عنوانين مكتوبين بأيديهما، ولأحدهما دبّوسٌ يقول «هذا مثبَّت» قبل أن
  /// يُقرأ النصّ. فلو أُسقط في التوحيد لضاع معنىً كان قائماً.
  final IconData? icon;

  const SectionTitle(this.text, {super.key, this.count, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(text, style: AppType.sectionTitle)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(count!, style: AppType.label.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }
}
