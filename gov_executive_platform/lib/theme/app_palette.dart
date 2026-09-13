/// درجاتُ الألوان — أساسُ نظام التصميم.
///
/// ــــ لماذا درجاتٌ لا ألوانٌ مفردة ــــ
///
/// المنصةُ تحتاج من كلِّ لونٍ **ثلاثةَ أدوار**: سطحٌ هادئٌ يُملأ به مساحة،
/// ولونٌ صريحٌ يُرسم به شريطٌ أو نقطة، ونصٌّ داكنٌ يُقرأ على السطح الهادئ.
/// ولونٌ واحدٌ لا يؤدّي الثلاثة: ما يُقرأ نصّاً يسوَدّ سطحاً، وما يصلح سطحاً
/// لا يُرى شريطاً.
///
/// ــــ وثابتةٌ لا مولَّدة، إلا لونَ الهوية ــــ
///
/// درجاتُ المعنى **مكتوبةٌ بأعيانها**: اختيرت ليقرأ النصُّ عليها بتباينٍ
/// كافٍ، وذلك يُقاس ولا يُولَّد — ومولِّدٌ يرفع الإضاءةَ بنسبةٍ ثابتة يُنتج
/// أصفرَ لا يُقرأ عليه شيء. ويُقاس التباينُ في `status_palette_test.dart`.
///
/// ولونُ **الهوية** وحدَه يُولَّد بـ[Swatch.from]: يختاره مسؤولُ النظام
/// فلا سبيل إلى كتابة درجاته سلفاً.
///
/// ــــ ولماذا تُسمّى كلُّ درجةٍ وحدَها ــــ
///
/// `AppColors.success` وأخواتُها `const`، وتُقرأ في تعبيراتٍ ثابتة في
/// عشرات الملفّات (`const TextStyle(color: …)`). وDart **لا تقرأ حقلَ
/// كائنٍ** في تعبيرٍ ثابت. فتُسمّى كلُّ درجةٍ حقلاً ثابتاً، ويُبنى منها
/// [Swatch] للمرور عليها — واللونُ مكتوبٌ مرّةً واحدة لا مرّتين.
library;

import 'package:flutter/material.dart';

/// درجاتُ لونٍ واحد — من أفتحِ سطحٍ إلى أدكنِ نصّ.
class Swatch {
  /// سطحٌ هادئٌ جدّاً — خلفيةُ شارةٍ أو صفٍّ مميَّز.
  final Color s50;

  /// حدُّ السطح الهادئ.
  final Color s100;

  /// درجةٌ متوسّطةٌ فاتحة — للتدرّجات.
  final Color s300;

  /// **اللونُ الصريح**: الشريطُ والنقطةُ والملء.
  final Color s600;

  /// أدكنُ منه — الطرفُ الداكن في التدرّج.
  final Color s700;

  /// نصٌّ يُقرأ على [s50].
  final Color s800;

  const Swatch({
    required this.s50,
    required this.s100,
    required this.s300,
    required this.s600,
    required this.s700,
    required this.s800,
  });

  /// يولّد درجاتٍ من لونٍ واحد — **للهوية وحدَها**.
  ///
  /// ولا تُستعمل لألوان المعنى: التوليدُ يحفظ درجةَ اللون ويحرّك الإضاءة،
  /// فيُنتج من الأصفر سطحاً لا يُقرأ عليه نصّ. وألوانُ المعنى مكتوبةٌ
  /// بأعيانها ومقيسٌ تباينُها.
  factory Swatch.from(Color base) {
    final hsl = HSLColor.fromColor(base);
    Color at(double lightness, {double? saturation}) => hsl
        .withLightness(lightness.clamp(0.0, 1.0))
        .withSaturation((saturation ?? hsl.saturation).clamp(0.0, 1.0))
        .toColor();
    return Swatch(
      s50: at(0.96, saturation: hsl.saturation * 0.45),
      s100: at(0.90, saturation: hsl.saturation * 0.55),
      s300: at(0.68),
      s600: base,
      // بنسبةٍ لا بطرحٍ ثابت: مع لونٍ داكنٍ أصلاً — كالأخضر الرسمي — يُنتج
      // الطرحُ الثابت أسودَ شبهَ صافٍ فتضيع الهوية. وهو الدرسُ المكتوب في
      // `AppColors.applyBrand`.
      s700: at(hsl.lightness * 0.72),
      s800: at(hsl.lightness * 0.52),
    );
  }
}

/// ألوانُ المعنى بدرجاتها — **ثابتةٌ لا يغيّرها أحد**.
///
/// وثباتُها قرارٌ لا إغفال: «الأحمرُ خطر، والأخضرُ نجاح» قاعدةٌ تسري على
/// المنصة كلِّها، ولو تبعت ذوقاً لَتبدّل المعنى بتبدّله. راجع
/// `status_palette.dart`.
class AppPalette {
  /// نجاحٌ وإنجازٌ ومؤشّرٌ إيجابيّ.
  static const Color green50 = Color(0xFFE9F5EE);
  static const Color green100 = Color(0xFFC6E5D3);
  static const Color green300 = Color(0xFF63B487);
  static const Color green600 = Color(0xFF1E7A4D);
  static const Color green700 = Color(0xFF17613D);
  static const Color green800 = Color(0xFF0F4429);
  static const green = Swatch(s50: green50, s100: green100, s300: green300, s600: green600, s700: green700, s800: green800);

  /// تحذيرٌ وما يحتاج متابعة.
  static const Color amber50 = Color(0xFFFDF3E0);
  static const Color amber100 = Color(0xFFF6E0B4);
  static const Color amber300 = Color(0xFFE0AE4E);
  static const Color amber600 = Color(0xFFC98A15);
  static const Color amber700 = Color(0xFF9C6A0F);
  static const Color amber800 = Color(0xFF6B490A);
  static const amber = Swatch(s50: amber50, s100: amber100, s300: amber300, s600: amber600, s700: amber700, s800: amber800);

  /// خطرٌ وتأخيرٌ وحالةٌ حرجة.
  static const Color red50 = Color(0xFFFBEBE9);
  static const Color red100 = Color(0xFFF3C8C2);
  static const Color red300 = Color(0xFFDB776B);
  static const Color red600 = Color(0xFFC0392B);
  static const Color red700 = Color(0xFF992C21);
  static const Color red800 = Color(0xFF6B1E17);
  static const red = Swatch(s50: red50, s100: red100, s300: red300, s600: red600, s700: red700, s800: red800);

  /// معلومةٌ ونشاطٌ وعنصرٌ تنفيذي.
  static const Color blue50 = Color(0xFFE8F1F8);
  static const Color blue100 = Color(0xFFC2DAEC);
  static const Color blue300 = Color(0xFF5C9ACB);
  static const Color blue600 = Color(0xFF1F6FA8);
  static const Color blue700 = Color(0xFF185785);
  static const Color blue800 = Color(0xFF103C5C);
  static const blue = Swatch(s50: blue50, s100: blue100, s300: blue300, s600: blue600, s700: blue700, s800: blue800);

  /// **عائق**: يوقف العمل ولا يهدّده وحسب — فلونٌ بين التحذير والخطر.
  ///
  /// وكان `#E0692B` حرفاً مكرّراً في **عشرة** مواضع بلا اسم. وأُدكن هنا
  /// ليُقرأ النصُّ الأبيضُ عليه: تباينُ الأوّل كان ٣٫٤٨ ولا يكفي.
  static const Color orange50 = Color(0xFFFDEFE6);
  static const Color orange100 = Color(0xFFF7D3BB);
  static const Color orange300 = Color(0xFFE08A56);
  static const Color orange600 = Color(0xFFB9541C);
  static const Color orange700 = Color(0xFF954315);
  static const Color orange800 = Color(0xFF662E0E);
  static const orange = Swatch(s50: orange50, s100: orange100, s300: orange300, s600: orange600, s700: orange700, s800: orange800);

  /// تصنيفاتٌ وعناصرُ إدارية — ولا معنى إنذاريَّ لها.
  static const Color violet50 = Color(0xFFF1ECF8);
  static const Color violet100 = Color(0xFFD7C9EC);
  static const Color violet300 = Color(0xFF9678C7);
  static const Color violet600 = Color(0xFF5B3A9B);
  static const Color violet700 = Color(0xFF482E7C);
  static const Color violet800 = Color(0xFF322055);
  static const violet = Swatch(s50: violet50, s100: violet100, s300: violet300, s600: violet600, s700: violet700, s800: violet800);

  /// تدريبٌ وما يُصنَّف ولا يُنذر.
  static const Color teal50 = Color(0xFFE4F3F5);
  static const Color teal100 = Color(0xFFB9DFE5);
  static const Color teal300 = Color(0xFF4FA9B7);
  static const Color teal600 = Color(0xFF116C7B);
  static const Color teal700 = Color(0xFF0D5661);
  static const Color teal800 = Color(0xFF093C44);
  static const teal = Swatch(s50: teal50, s100: teal100, s300: teal300, s600: teal600, s700: teal700, s800: teal800);

  /// محايدٌ: خلفياتٌ وفواصلُ وما هو غيرُ نشط.
  static const Color slate50 = Color(0xFFF5F7FA);
  static const Color slate100 = Color(0xFFE3E8EF);
  static const Color slate300 = Color(0xFF98A4B3);
  static const Color slate600 = Color(0xFF5F6B7A);
  static const Color slate700 = Color(0xFF44505E);
  static const Color slate800 = Color(0xFF2B3642);
  static const slate = Swatch(s50: slate50, s100: slate100, s300: slate300, s600: slate600, s700: slate700, s800: slate800);
  // ــــ لونا الهوية الافتراضيان ــــ
  //
  // وهما **هويةٌ لا معنى**: يغيّرهما مسؤولُ النظام من شاشة المظهر، ولا
  // تسري عليهما قاعدةُ الدلالة. ويُسمَّيان هنا ليبقى كلُّ لونٍ في المنصة
  // مكتوباً بالرقم في ملفٍّ واحد.

  /// أخضرُ الكويت العميق — الهويةُ الافتراضية.
  static const Color brandGreen = Color(0xFF0E4D3C);

  /// ذهبيٌّ رسميّ — لونُ التمييز الافتراضي.
  static const Color brandGold = Color(0xFFC9A227);

  /// ودرجتاه المشتقّتان ابتداءً — تُعاد اشتقاقُهما مع كلّ تغييرِ هوية.
  static const Color brandGreenLight = Color(0xFF1A7A5E);
  static const Color brandGreenDark = Color(0xFF072E24);

  /// نصُّ المتن والعناوين.
  static const Color ink = Color(0xFF15202B);

  /// سطحُ البطاقات والحقول.
  static const Color surface = Colors.white;
}
