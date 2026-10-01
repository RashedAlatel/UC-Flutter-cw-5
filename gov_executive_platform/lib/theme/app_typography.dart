/// سلّمُ النصّ — **حجمٌ ووزنٌ لكلّ دور**.
///
/// ــــ ووزنُ ٦٠٠ ليس من السلّم ــــ
///
/// الخطُّ المحزوم مع المنصة (Tajawal) فيه **أربعةُ أوزانٍ فقط**: ٤٠٠ و٥٠٠
/// و٧٠٠ و٨٠٠ — راجع `pubspec.yaml`. و`w600` مستعملٌ في مواضعَ عدّة بلا
/// ملفٍّ يقابله، فيصطنعه المحرّكُ بتثخينٍ حسابيّ: حروفٌ أثقل قليلاً وأقلُّ
/// انتظاماً، وفي العربية أوضحُ لأنّ الوصلَ بين الحروف يتشوّه.
///
/// فما كان `w600` يصير `w500` أو `w700` بقصد. ولا يُمنع `w600` بحارس —
/// يُصلَح حيث وُجد، ويُكتب هنا سببُه.
library;

import 'package:flutter/material.dart';

import 'app_palette.dart';

/// أدوارُ النصّ في المنصة.
class AppType {
  static const _family = 'Tajawal';

  /// عنوانُ الصفحة في الشريط القياديّ.
  static const pageTitle = TextStyle(
      fontFamily: _family, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25);

  /// رقمٌ كبيرٌ في بطاقة مؤشّر.
  static const metric = TextStyle(
      fontFamily: _family, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1);

  /// عنوانُ قسمٍ داخل الصفحة.
  static const sectionTitle = TextStyle(
      fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.ink);

  /// عنوانُ بطاقة.
  static const cardTitle = TextStyle(
      fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.ink);

  /// وصفٌ ثانويٌّ تحت عنوانِ بطاقة.
  static const cardSubtitle = TextStyle(
      fontFamily: _family, fontSize: 11, color: AppPalette.slate600, height: 1.5);

  /// متنٌ عاديّ.
  static const body = TextStyle(fontFamily: _family, fontSize: 12.5, height: 1.6);

  /// وسمٌ أو عنوانُ حقل.
  static const label = TextStyle(
      fontFamily: _family, fontSize: 11.5, fontWeight: FontWeight.w700);

  /// نصٌّ داخل شارة.
  static const pill = TextStyle(
      fontFamily: _family, fontSize: 11.5, fontWeight: FontWeight.w700);

  /// أصغرُ ما يُقرأ — تواريخُ وأعدادٌ ثانوية.
  static const micro = TextStyle(fontFamily: _family, fontSize: 10.5);
}
