/// بطاقةُ مؤشّر — رقمٌ كبيرٌ يُقرأ من بعيد، **وتُضغط**.
///
/// ــــ وهنا التدرّجُ والظلّ، ولا في غيرهما ــــ
///
/// قرارُ المنصة المكتوب: حدٌّ رفيعٌ وظلٌّ شبهُ معدوم — الطابعُ الحكوميّ،
/// والظلالُ الطافيةُ تُقرأ تطبيقاً تجاريّاً. وهذا القرارُ **باقٍ للجداول
/// والقوائم**، ويُستثنى منه بطاقاتُ المؤشّرات ورؤوسُ الصفحات: هي ما يُرى
/// أوّلاً، وفيها يُحتاج إلى ما يجذب العين.
///
/// ــــ وتُضغط فتفتح تفاصيلَها ــــ
///
/// `KpiCard.onTap` موجودةٌ في المنصة **ولم تُمرَّر قيمةً قطّ** في عشرين
/// موضعاً: خطّافٌ بُني ولم يُوصَل. فرقمٌ يُعرض ولا يُفتح يترك القارئَ
/// يبحث عن أصحابه في شاشةٍ أخرى.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  /// نغمةُ المعنى — هي التي تقول للقارئ: أهذا خبرٌ سارٌّ أم نذير؟
  final StatusTone tone;

  /// سطرٌ تحت الرقم — «٣ أكثرُ من الأسبوع الماضي».
  final String? subtitle;

  /// ما يقع عند الضغط. وحين يكون `null` لا تُعرض إشارةُ الضغط أصلاً —
  /// فبطاقةٌ تبدو قابلةً للضغط ولا تستجيب عطلٌ في عين مستعملها.
  final VoidCallback? onTap;

  /// هل يُملأ السطحُ بتدرّج؟ يُشعَل لما يُنذر فيُرى أوّلاً.
  final bool emphasize;

  /// ارتفاعُ البلاطة — واحدٌ لكلّ الشبكة فلا تتفاوت الصفوف.
  static const double tileHeight = 108;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
    this.subtitle,
    this.onTap,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = emphasize ? tone.onFill : AppColors.textPrimary;
    final muted = emphasize
        ? tone.onFill.withValues(alpha: 0.82)
        : AppColors.textSecondary;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: muted)),
              ),
              Icon(icon, size: 16, color: emphasize ? tone.onFill : tone.fill),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppType.metric.copyWith(color: onSurface)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.micro.copyWith(color: muted, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );

    return SizedBox(
      height: tileHeight,
      child: Material(
        color: emphasize ? tone.fill : AppColors.surface,
        // والتدرّجُ من درجةٍ إلى درجةٍ في اللون نفسِه، لا بين لونين: تدرّجٌ
        // بين معنيين يقول شيئين في سطحٍ واحد.
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: emphasize ? 2 : 0,
        shadowColor: tone.fill.withValues(alpha: 0.35),
        child: Ink(
          decoration: BoxDecoration(
            gradient: emphasize
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [tone.fill, _deepen(tone.fill)],
                  )
                : null,
            border: emphasize ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: body,
          ),
        ),
      ),
    );
  }

  /// الطرفُ الداكنُ من التدرّج — بنسبةٍ لا بطرحٍ ثابت، فاللونُ الداكنُ
  /// أصلاً يسودّ بالطرح فيضيع معناه.
  static Color _deepen(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.74).clamp(0.0, 1.0)).toColor();
  }
}
