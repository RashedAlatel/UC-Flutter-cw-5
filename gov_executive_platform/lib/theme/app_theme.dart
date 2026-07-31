import 'package:flutter/material.dart';

/// نظام الألوان والتنسيق الموحد للمنصة
class AppColors {
  static const Color primary = Color(0xFF0B3D66); // أزرق حكومي داكن
  static const Color primaryLight = Color(0xFF1565A6);
  static const Color accent = Color(0xFFC9A227); // ذهبي
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE8A33D);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565A6);

  static const Color textPrimary = Color(0xFF1C2733);
  static const Color textSecondary = Color(0xFF5B6B79);
  static const Color border = Color(0xFFE1E6EB);

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
        return const Color(0xFF64A56E);
      case 'medium':
        return warning;
      case 'high':
        return const Color(0xFFE0692B);
      case 'critical':
        return danger;
      default:
        return textSecondary;
    }
  }
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}
