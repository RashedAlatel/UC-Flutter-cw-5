import 'package:flutter/material.dart';

/// نظام الألوان والتنسيق الموحد للمنصة.
/// [primary] و [accent] قابلان للتخصيص من قِبل مسؤول النظام (شاشة "إعدادات
/// المظهر")، لذا هما حقلان قابلان للتغيير وقت التشغيل وليسا ثابتين (const) —
/// خلافاً لبقية الألوان الدلالية (نجاح/تحذير/خطر...) التي تبقى ثابتة عمداً
/// لأنها تحمل معنى وظيفياً لا يجوز تخصيصه. راجع [AppColors.applyBrand].
class AppColors {
  static Color primary = const Color(0xFF0E4D3C); // أخضر كويتي عميق (افتراضي)
  static Color primaryLight = const Color(0xFF1A7A5E);
  static Color primaryDark = const Color(0xFF072E24);
  static Color accent = const Color(0xFFC9A227); // ذهبي رسمي (افتراضي)

  static const Color defaultPrimary = Color(0xFF0E4D3C);
  static const Color defaultAccent = Color(0xFFC9A227);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF1E7A4D);
  static const Color warning = Color(0xFFC98A15);
  static const Color danger = Color(0xFFC0392B);
  static const Color info = Color(0xFF1F6FA8);

  static const Color textPrimary = Color(0xFF15202B);
  static const Color textSecondary = Color(0xFF5F6B7A);
  static const Color border = Color(0xFFE3E8EF);

  /// خلفية اللوحة المتدرّجة — تُستخدم في شاشة الدخول والرموز الدائرية.
  /// مُشتقّة من لوني الهوية الحاليين حتى تواكب أي تخصيص من مسؤول النظام.
  static LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [primaryDark, primary, primaryLight],
      );

  /// تدرّج الشريط الجانبي الرسمي: أخضر داكن صلب مع انحدار خفيف جداً يمنحه
  /// عمقاً دون أن يبدو زخرفياً — الطابع المعتمد في البوابات الحكومية.
  static LinearGradient get sidebarGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primary, primaryDark],
      );

  /// ألوان أعمدة الرسوم البيانية بالترتيب — مصدر واحد بدل نسخة في كل رسم.
  ///
  /// ليست `const` عمداً: [primary] و[accent] لونا هوية تُضبطان من إعدادات
  /// المظهر، فالقائمة تُبنى عند الطلب لتتبعهما.
  static List<Color> get chartPalette => [primary, accent, info, success, warning, danger];

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

  static Color taskStatusColor(String status) {
    switch (status) {
      case 'todo':
        return textSecondary;
      case 'inProgress':
        return info;
      case 'review':
        return accent;
      // «بانتظار الاعتماد» تحذيرٌ لا نجاح: العمل واقفٌ على مكتبٍ لا يتقدّم،
      // ولونُ النجاح عليه يجعله يبدو منتهياً وهو ليس كذلك.
      case 'awaitingApproval':
        return warning;
      case 'blocked':
        return danger;
      case 'done':
        return success;
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
    // الدرجة الداكنة تُشتق بنسبة مئوية لا بطرح ثابت: مع الألوان الداكنة أصلاً
    // (كالأخضر الرسمي) كان الطرح الثابت يُنتج أسود شبه صافٍ يفقد لون الهوية.
    AppColors.primaryDark = hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }

  static void resetBrand() => applyBrand(primary: defaultPrimary, accent: defaultAccent);

  /// لون النص فوق خلفية من ألوان الهوية — يُشتقّ من إضاءتها الفعلية.
  ///
  /// ليس تزيّداً: كل الألوان الجاهزة في «إعدادات المظهر» داكنة، **لكن الشاشة
  /// تقبل إدخالاً حرّاً بالـhex**. فلو أدخل مسؤول النظام لوناً فاتحاً وبقي
  /// النص أبيض ثابتاً لصار الشريط القيادي غير مقروء إطلاقاً — وهو أول ما
  /// يُرى في المنصة.
  static Color onBrand(Color background) =>
      background.computeLuminance() > 0.42 ? textPrimary : Colors.white;

  /// نفس لون المعنى، مرفوع الإضاءة ليُقرأ على خلفية داكنة.
  ///
  /// ألوان المعنى (نجاح/تحذير/خطر/معلومة) ثابتة عمداً لأنها تحمل دلالة لا
  /// ذوقاً، فلا يجوز استبدالها بغيرها على الشريط. والحل رفع الإضاءة مع حفظ
  /// درجة اللون وتشبّعه: يبقى الأحمر أحمر، ويصير مقروءاً على الأخضر العميق
  /// بدل أن يذوب فيه.
  static Color liftForDark(Color semantic) {
    final hsl = HSLColor.fromColor(semantic);
    return hsl.withLightness((hsl.lightness + 0.30).clamp(0.0, 1.0)).toColor();
  }
}

/// إيقاع المسافات — مضاعفات أربعة.
///
/// اللوحة اليوم بلا إيقاع: مسافات مكتوبة يدوياً بقيم متفرقة، فلا تجد العين
/// ترتيباً. هذه القيم تُطبَّق على لوحة القيادة في هذه الجولة، وتنتشر لاحقاً.
abstract final class AppSpace {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// سلّم الاستدارة — ثلاث قيم بدل إحدى عشرة متفرقة.
abstract final class AppRadius {
  /// أعمدة الرسوم والعناصر الصغيرة.
  static const double sm = 4;

  /// البطاقات والحقول والأزرار.
  static const double md = 10;

  /// الشارات والكبسولات.
  static const double pill = 999;
}

/// سلّم الخط — ست درجات.
///
/// **بالأوزان الموجودة فعلاً لا غير**: ملفات Tajawal المضمَّنة أربعة
/// (٤٠٠ و٥٠٠ و٧٠٠ و٨٠٠). والوزن ٦٠٠ المستعمل في بقية المنصة **لا ملف له**،
/// فيصطنعه المحرّك اصطناعاً — وهو أحد أسباب إحساس «الخط غير محكم».
abstract final class AppText {
  static const TextStyle pageTitle =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25);
  static const TextStyle metric =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1);
  static const TextStyle cardTitle =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w800);
  static const TextStyle body =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, fontWeight: FontWeight.w400);
  static const TextStyle label =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w700);
  static const TextStyle micro =
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10, fontWeight: FontWeight.w400);
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
      // titleMedium هو الطراز الذي تعتمده حقول DropdownButtonFormField/
      // TextField داخلياً لعرض القيمة المُدخَلة حين لا يُحدَّد "style" صراحةً
      // — تصغيره هنا يمنع تراكب نص القيمة (بحجمه الافتراضي الكبير ~16) مع
      // تسمية الحقل العائمة الأصغر (labelStyle بحجم 13.5) في كل قوائم
      // التصفية المنسدلة عبر التطبيق دفعة واحدة.
      textTheme: base.textTheme.apply(fontFamily: fontFamily).copyWith(
            titleMedium: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
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
      // بطاقات رسمية: حدّ رفيع واضح وظل خفيف جداً بدل الظل العائم الكبير.
      // البطاقة "الطافية" بظل قوي تُقرأ كتطبيق تجاري؛ الحدّ الدقيق مع ظل شبه
      // معدوم هو الطابع المعتمد في المنصات الحكومية والتقارير الرسمية.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle: const TextStyle(fontFamily: fontFamily, color: AppColors.textSecondary, fontSize: 13.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
