// لونُ الحالة معنى، فلا يتبدّل بتبدّل الهوية.
//
// ــــ القاعدةُ التي اتّفقنا عليها ــــ
//
// «اللونُ يُستخدم لنقل معنى لا للزينة»: الأحمرُ خطرٌ أو تأخير، والأخضرُ
// نجاحٌ أو إنجاز، والبرتقاليُّ يحتاج انتباهاً، والأزرقُ معلومةٌ أو نشاط،
// والرماديُّ غيرُ نشط. وهذه القاعدةُ تنكسر إن كان أحدُ ألوان المعنى **هو
// لونَ الهوية نفسَه** — لأنّ مسؤول النظام يغيّر الهوية من شاشة المظهر.
//
// ــــ وما قِيس قبل الإصلاح ــــ
//
// حالةُ المهمّة «مراجعة» كانت تُلوَّن بـ`accent`، ولونُ التمييز يُختار من
// عشرة جاهزةٍ أو بإدخالٍ حرّ. فمن اختار أحمرَ تمييزٍ صارت «قيد المراجعة»
// حمراءَ كـ«متعثّرة»، ومن اختار أخضرَ صارت كـ«منجزة». **تغييرُ الهوية كان
// يغيّر معنىً في المنصة.**
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/theme/status_palette.dart';

void main() {
  // كلُّ اختبارٍ يُعيد الهويةَ إلى أصلها، وإلا سرى تغييرُ أحدِها إلى ما بعده
  // — والألوانُ متغيّراتٌ ساكنةٌ عامّة في هذه المنصة.
  setUp(AppColors.resetBrand);
  tearDown(AppColors.resetBrand);

  group('لونُ المعنى لا يتبع الهوية', () {
    // ــ الحدُّ الذي انكسر ــ
    test('حالةُ «قيد المراجعة» لا تتبدّل بتبدّل لون التمييز', () {
      final before = StatusPalette.task('review');
      AppColors.applyBrand(
        primary: AppColors.defaultPrimary,
        accent: const Color(0xFFB00020), // أحمرُ تمييزٍ يختاره مسؤول النظام
      );
      expect(
        StatusPalette.task('review'),
        before,
        reason: 'لونُ «قيد المراجعة» تبدّل مع الهوية — فصار معناها يتبع الذوق',
      );
    });

    // ولا تصير حمراءَ كالمتعثّرة، ولا خضراءَ كالمنجزة، مهما كانت الهوية.
    test('ولا تُخلط بحالةٍ أخرى مهما كانت الهوية', () {
      for (final accent in [
        const Color(0xFFB00020),
        const Color(0xFF1E7A4D),
        const Color(0xFF5F6B7A),
      ]) {
        AppColors.applyBrand(primary: AppColors.defaultPrimary, accent: accent);
        final review = StatusPalette.task('review');
        expect(review, isNot(StatusPalette.task('blocked')));
        expect(review, isNot(StatusPalette.task('done')));
        expect(review, isNot(StatusPalette.task('todo')));
      }
    });

    test('وكلُّ حالاتِ المهامّ والمشاريع ثابتةٌ مع الهوية', () {
      final beforeTasks = {
        for (final s in ['todo', 'inProgress', 'review', 'awaitingApproval', 'blocked', 'done'])
          s: StatusPalette.task(s),
      };
      final beforeProjects = {
        for (final s in ['onTrack', 'atRisk', 'delayed', 'completed'])
          s: StatusPalette.project(s),
      };
      AppColors.applyBrand(
        primary: const Color(0xFF7B1FA2),
        accent: const Color(0xFF00BCD4),
      );
      for (final e in beforeTasks.entries) {
        expect(StatusPalette.task(e.key), e.value, reason: 'مهمّة: ${e.key}');
      }
      for (final e in beforeProjects.entries) {
        expect(StatusPalette.project(e.key), e.value, reason: 'مشروع: ${e.key}');
      }
    });
  });

  group('والمعاني تُميَّز بعضُها عن بعض', () {
    // لونان متطابقان لمعنيين مختلفين يُبطلان فائدةَ اللون كلَّها.
    test('لا يتشارك معنيان لوناً واحداً', () {
      final byMeaning = {
        'نجاح': StatusPalette.success,
        'تحذير': StatusPalette.warning,
        'خطر': StatusPalette.danger,
        'معلومة': StatusPalette.info,
        'متوقف': StatusPalette.neutral,
      };
      final seen = <Color, String>{};
      for (final e in byMeaning.entries) {
        expect(seen.containsKey(e.value.fill), isFalse,
            reason: '«${e.key}» و«${seen[e.value.fill]}» بلونٍ واحد');
        seen[e.value.fill] = e.key;
      }
    });

    // ــ ولونُ العائق كان حرفاً بلا اسم في ستّة مواضع ــ
    test('ولونُ العائق مسمّىً في النظام لا حرفاً مكرّراً', () {
      expect(StatusPalette.blocker.fill, isNot(StatusPalette.danger.fill),
          reason: 'العائقُ ليس خطراً: أحدُهما يوقف العمل والآخر يهدّده');
      expect(StatusPalette.blocker.fill, isNot(StatusPalette.warning.fill));
    });

    test('وأولوياتُ العمل أربعُ درجاتٍ متمايزة', () {
      final colors = [
        for (final p in ['low', 'medium', 'high', 'critical']) StatusPalette.priority(p),
      ];
      expect(colors.toSet().length, 4, reason: 'درجتا أولويةٍ بلونٍ واحد');
    });
  });

  group('وما لا يُعرف يُقال رمادياً لا يُخترع', () {
    test('حالةٌ مجهولةٌ تُقرأ محايدةً لا تُلوَّن بالخطأ', () {
      expect(StatusPalette.task('شيءٌ لم يوجد بعد'), StatusPalette.neutral.fill);
      expect(StatusPalette.project(''), StatusPalette.neutral.fill);
      expect(StatusPalette.priority('لا شيء'), StatusPalette.neutral.fill);
    });
  });

  group('ولونُ النصّ فوق اللون مقروء', () {
    // ــ وهذا ما يمنع بطاقةً لا يُقرأ رقمُها ــ
    //
    // فاللونُ المعنويُّ يُملأ به سطحٌ ويُكتب فوقه، ولو اختير النصُّ بالظنّ
    // لَظهر أبيضُ على أصفر.
    test('كلُّ معنىً نصُّه فوقه بتباينٍ كافٍ', () {
      for (final t in StatusPalette.allTones) {
        final ratio = _contrast(t.fill, t.onFill);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'تباينُ «${t.name}» ${ratio.toStringAsFixed(2)} — والنصُّ لا يُقرأ');
      }
    });

    test('والسطحُ الهادئ يحمل نصَّه كذلك', () {
      for (final t in StatusPalette.allTones) {
        final ratio = _contrast(t.soft, t.text);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'تباينُ «${t.name}» الهادئ ${ratio.toStringAsFixed(2)}');
      }
    });
  });
}

/// نسبةُ التباين بين لونين — معيار WCAG.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
