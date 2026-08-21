import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بطاقة مؤشر مضغوطة بطراز أدوات BI (حدود رفيعة، بدون ظل، بدون شارة أيقونة
/// كبيرة): تسمية صغيرة أعلى، رقم كبير، ومؤشر اتجاه اختياري أسفله.
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle!,
                        style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// نفس المؤشر بلا بطاقة — للعرض داخل الشريط القيادي على خلفية الهوية.
///
/// وهو ليس نسخةً ثانية من [KpiCard]: كلاهما يُغذّى من نفس دالة حساب المؤشر في
/// شاشة اللوحة، فلا يفترق الرقم بين الشريط والبطاقة أبداً. المختلف هو اللباس
/// وحده — والألوان تُشتقّ من الخلفية لا تُفترض.
class KpiMetric extends StatelessWidget {
  final String title;
  final String value;

  /// لون المعنى (نجاح/خطر/تحذير) كما هو في المنصة — تُرفع إضاءته هنا ليُقرأ
  /// على الداكن مع حفظ دلالته.
  final Color color;

  /// هل يُلوَّن الرقم بلون المعنى؟ الأرقام المحايدة تبقى بلون النص الأساسي،
  /// فلا يصير الشريط قوس قزح ويفقد اللونُ معناه.
  final bool emphasize;

  const KpiMetric({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onBrand(AppColors.primary);
    final onDark = fg == Colors.white;
    // على الخلفية الداكنة تُرفع إضاءة لون المعنى؛ وعلى الفاتحة يُترك كما هو.
    final valueColor = !emphasize ? fg : (onDark ? AppColors.liftForDark(color) : color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // سطران لا سطر: على الهاتف يضيق العمود إلى نصف الشاشة، فتُقتطع تسمية
        // مثل «متوسط التأخير عن الخطة» إلى «متوسط التأخير عن الخـ» — وهي
        // مقروءة تماماً في سطرين.
        SizedBox(
          height: 30,
          child: Text(
            title,
            style: AppText.label.copyWith(color: fg.withValues(alpha: 0.68), fontSize: 11.5, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: AppText.pageTitle.copyWith(color: valueColor, fontSize: 34, height: 1),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
