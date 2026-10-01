import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// مؤشّرٌ داخل الشريط القيادي — على خلفية الهوية.
///
/// ــــ وكان في هذا الملفّ بطاقةٌ فحُذفت ــــ
///
/// `KpiCard` عاشت هنا، تُصيَّر في خمس شاشات، **وفيها `onTap` لم تُمرَّر
/// قيمةً قطّ**: خطّافٌ بُني ولم يُوصَل. فلمّا انتقلت الشاشاتُ الخمس إلى
/// `StatCard` — وفيها النغمةُ والتدرّجُ والضغط — لم يبقَ لها مستدعٍ واحد،
/// فحُذفت.
///
/// ــــ وهذا ليس نسخةً ثانيةً منها ــــ
///
/// كلاهما يُغذّى من `_kpiData` في شاشة اللوحة، فلا يفترق الرقمُ بين الشريط
/// والبطاقة أبداً. المختلفُ اللباسُ وحده — وهذا يعيش على خلفية الهوية،
/// فألوانُه تُشتقّ منها ولا تُفترض.
class KpiMetric extends StatelessWidget {
  final String title;
  final String value;

  /// لون المعنى (نجاح/خطر/تحذير) كما هو في المنصة — تُرفع إضاءته هنا ليُقرأ
  /// على الداكن مع حفظ دلالته.
  final Color color;

  /// هل يُلوَّن الرقم بلون المعنى؟ الأرقام المحايدة تبقى بلون النص الأساسي،
  /// فلا يصير الشريط قوس قزح ويفقد اللونُ معناه.
  final bool emphasize;

  /// ما يقع عند الضغط — **و`null` تعني أنّ المؤشّر لا يُضغط أصلاً**.
  ///
  /// فلا مؤشّرَ يبدو قابلاً للضغط ولا يستجيب: المؤشّرُ الذي لا قائمةَ خلفه
  /// لا يُحاط بسطحٍ يُضيء تحت المؤشّر ولا تتبدّل عليه إشارةُ الفأرة.
  final VoidCallback? onTap;

  const KpiMetric({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.emphasize = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onBrand(AppColors.primary);
    final onDark = fg == Colors.white;
    // على الخلفية الداكنة تُرفع إضاءة لون المعنى؛ وعلى الفاتحة يُترك كما هو.
    final valueColor = !emphasize ? fg : (onDark ? AppColors.liftForDark(color) : color);

    final body = Column(
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

    // ــ والحشوةُ تُوضع سواءٌ أكان يُضغط أم لا ــ
    //
    // في الشريط مؤشّراتٌ تُضغط وأخرى لا تُضغط جنباً إلى جنب. ولو كانت
    // الحشوةُ تابعةً للضغط لانزاح بعضُها عن بعض ستّةَ بكسلات — ويُقرأ ذلك
    // اعوجاجاً في الصفّ لا فرقاً في المعنى.
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: body,
    );
    if (onTap == null) return padded;

    // ــ سطحُ ضغطٍ يُقرأ على الهوية لا على الأبيض ــ
    //
    // الشريطُ ملوَّنٌ بلون الهوية، فسطحُ الضغط الافتراضي (رماديٌّ شفّاف)
    // يكاد لا يُرى عليه. فيُشتقّ من لون النصّ المحسوب للخلفية — وهو الذي
    // يُقرأ عليها بحكم اشتقاقه منها.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: fg.withValues(alpha: 0.08),
        splashColor: fg.withValues(alpha: 0.12),
        child: padded,
      ),
    );
  }
}
