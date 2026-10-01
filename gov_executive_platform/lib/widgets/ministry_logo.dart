import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شعار الوزارة الرسمي داخل قرص أبيض.
///
/// الشعار نفسه (`assets/images/logo.png`) بخلفية شفافة، ويُعرض هنا فوق قرص
/// أبيض ثابت ليقرأ كخاتم رسمي فوق الشريط الأخضر ولا يلتصق بلونه — وهو نفس
/// ظهوره على الأوراق الرسمية البيضاء. على الأسطح البيضاء (الشريط العلوي،
/// بطاقات التسجيل) يذوب القرص في الخلفية فلا يُحدث فرقاً.
///
/// إن لم يكن ملف الشعار موجوداً يُعرض رمز رسمي بديل مرسوم بالكود، فتبقى
/// المنصة تعمل وتُبنى دون صورة مكسورة — راجع `assets/images/README.md`.
class MinistryLogo extends StatelessWidget {
  /// القطر الكلي للقرص الأبيض.
  final double size;

  /// على الخلفيات الداكنة يُرسم حدّ ذهبي رفيع حول القرص لربطه بالهوية؛ وعلى
  /// الخلفيات الفاتحة يُترك بلا حدّ حتى لا يظهر القرص كعنصر دخيل.
  final bool onDark;

  const MinistryLogo({super.key, this.size = 40, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    // الشعار مرسوم داخل مربّع بهامش، فنُصغّره إلى ٧٦٪ من القطر ليدخل كاملاً
    // داخل القرص الدائري دون أن تُقصّ أطرافه (أجنحة الشعار ودرعه السفلي).
    final inner = size * 0.76;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: onDark ? Border.all(color: AppColors.accent, width: size >= 56 ? 1.6 : 1.2) : null,
      ),
      child: Image.asset(
        'assets/images/logo.png',
        width: inner,
        height: inner,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // يُستدعى حين لا يكون ملف الشعار موجوداً.
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.balance_rounded,
          color: AppColors.primary,
          size: inner * 0.7,
        ),
      ),
    );
  }
}
