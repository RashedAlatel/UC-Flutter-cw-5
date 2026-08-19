import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شعار الوزارة الرسمي.
///
/// يحاول عرض `assets/images/logo.png` الذي يضعه مسؤول النظام؛ وإن لم يكن
/// الملف موجوداً بعد يعرض رمزاً رسمياً بديلاً (ميزان العدل) مرسوماً بالكود
/// بألوان الهوية. هذا يعني أن المنصة تعمل وتُبنى بشكل سليم قبل رفع الشعار
/// وبعده دون أي تعديل على الكود — راجع `assets/images/README.md`.
class MinistryLogo extends StatelessWidget {
  /// القطر الكلي للشعار.
  final double size;

  /// عندما تكون الخلفية داكنة (الشريط الجانبي الأخضر مثلاً) يُعرض الرمز
  /// البديل بالأبيض والذهبي؛ وعلى الخلفيات الفاتحة يُعرض بلون الهوية.
  final bool onDark;

  const MinistryLogo({super.key, this.size = 40, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // يُستدعى حين لا يكون ملف الشعار مرفوعاً بعد.
      errorBuilder: (context, error, stackTrace) => _FallbackEmblem(size: size, onDark: onDark),
    );
  }
}

class _FallbackEmblem extends StatelessWidget {
  final double size;
  final bool onDark;

  const _FallbackEmblem({required this.size, required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: size >= 56 ? 2 : 1.4),
      ),
      child: Icon(
        Icons.balance_rounded,
        color: onDark ? AppColors.accent : Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
