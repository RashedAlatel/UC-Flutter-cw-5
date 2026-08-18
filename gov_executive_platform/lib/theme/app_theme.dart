import 'package:flutter/material.dart';

/// نظام الألوان والتنسيق الموحد للمنصة.
/// [primary] و [accent] قابلان للتخصيص من قِبل مسؤول النظام (شاشة "إعدادات
/// المظهر")، لذا هما حقلان قابلان للتغيير وقت التشغيل وليسا ثابتين (const) —
/// خلافاً لبقية الألوان الدلالية (نجاح/تحذير/خطر...) التي تبقى ثابتة عمداً
/// لأنها تحمل معنى وظيفياً لا يجوز تخصيصه. راجع [AppColors.applyBrand].
class AppColors {
  static Color primary = const Color(0xFF4B3585); // بنفسجي عميق (افتراضي)
  static Color primaryLight = const Color(0xFF7A5FC4);
  static Color primaryDark = const Color(0xFF2E2058);
  static Color accent = const Color(0xFFB1479E); // أوركيدي دافئ (افتراضي)

  static const Color defaultPrimary = Color(0xFF4B3585);
  static const Color defaultAccent = Color(0xFFB1479E);

  static const Color background = Color(0xFFF3F5F9);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFE0982E);
  static const Color danger = Color(0xFFD1453B);
  static const Color info = Color(0xFF2874A6);

  static const Color textPrimary = Color(0xFF1A2531);
  static const Color textSecondary = Color(0xFF64707E);
  static const Color border = Color(0xFFE6EAF0);

  /// خلفية اللوحة المتدرّجة (الشريط الجانبي العائم + خلفية الشاشة الرئيسية)،
  /// مُشتقّة من لوني الهوية الحاليين حتى تواكب أي تخصيص من مسؤول النظام.
  static LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [primaryDark, primary, Color.lerp(primary, accent, 0.55)!],
      );

  static Color statusColor(String status) {
    switch (status) {
      case 'onTrack':
        return success;
      case 'atRisk':
        return warning;
      case 'delayed':
        return danger;
      case 'completed':
        return info;
      default:
        return textSecondary;
    }
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'low':
        return const Color(0xFF5C9E68);
      case 'medium':
        return warning;
      case 'high':
        return const Color(0xFFD97A3A);
      case 'critical':
        return danger;
      default:
        return textSecondary;
    }
  }

  /// يطبّق لوني الهوية (الأساسي والتمييز) على مستوى المنصة كاملة، ويشتق منهما
  /// درجتين فاتحة وداكنة تلقائياً (تُستخدمان في التدرجات والقائمة الجانبية).
  static void applyBrand({required Color primary, required Color accent}) {
    AppColors.primary = primary;
    AppColors.accent = accent;
    final hsl = HSLColor.fromColor(primary);
    AppColors.primaryLight = hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 1.0)).toColor();
    AppColors.primaryDark = hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }

  static void resetBrand() => applyBrand(primary: defaultPrimary, accent: defaultAccent);
}

class AppTheme {
  static const String fontFamily = 'Tajawal';

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // بطاقات "عائمة" بظل ناعم بدل الحدود المسطّحة، لتقرأ كبطاقات بيضاء
      // طافية فوق خلفية اللوحة المتدرّجة (بحسب التصميم المرجعي المعتمد).
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 6,
        shadowColor: AppColors.primaryDark.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: AppColors.textSecondary, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontFamily: fontFamily),
        secondaryLabelStyle: const TextStyle(fontFamily: fontFamily),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
