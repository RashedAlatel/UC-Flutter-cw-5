// أسبوعُ العمل والعطل — **ونظيرُهما على الخادم**.
//
// ــــ ولماذا يُقاسان هنا وهناك ــــ
//
// `WorkWeek.isWorkingDay` في Dart و`isWorkingDay` في `status_scope.ts`
// **جوابان لسؤالٍ واحد** مكتوبان بلغتين. ولا مفرّ: الخادمُ يفحص عند
// الكتابة، والشاشةُ تصبغ التقويمَ قبل أن تسأل الخادم.
//
// وهذا الملفُّ يقيس **الأيامَ نفسَها** التي يقيسها `status_scope.test.mjs`
// — فلو انحرف أحدُهما عن الآخر لَشكا أحدُ الملفّين. وبلا ذلك يبقى الانحرافُ
// صامتاً حتى يرى موظّفٌ يومَه أخضرَ في الشاشة ويردَّه الخادم.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/work_week.dart';

void main() {
  // ٢٠ سبتمبر ٢٠٢٦ أحدٌ، و٢٤ خميس، و٢٥ جمعة، و٢٦ سبت — وهي التواريخُ
  // نفسُها في `status_scope.test.mjs`.
  final sunday = DateTime(2026, 9, 20);
  final thursday = DateTime(2026, 9, 24);
  final friday = DateTime(2026, 9, 25);
  final saturday = DateTime(2026, 9, 26);

  group('أيامُ العمل: الأحد إلى الخميس', () {
    test('الأحدُ إلى الخميس عملٌ', () {
      for (var i = 0; i < 5; i++) {
        final day = sunday.add(Duration(days: i));
        expect(WorkWeek.isWorkingDay(day, const {}), isTrue,
            reason: '${WorkWeek.keyOf(day)} يومُ عمل');
      }
    });

    test('والجمعةُ والسبتُ ليسا عملاً', () {
      expect(WorkWeek.isWorkingDay(friday, const {}), isFalse);
      expect(WorkWeek.isWorkingDay(saturday, const {}), isFalse);
    });

    test('وتُعرفان عطلةً أسبوعيّةً لا رسميّة', () {
      // والفرقُ يُقال للقارئ: «الجمعة» ليست «عيد الفطر».
      expect(WorkWeek.isWeekend(friday), isTrue);
      expect(WorkWeek.isWeekend(sunday), isFalse);
    });

    // ــ وبلا هذا يصير كلُّ عيدٍ غياباً جماعيّاً ــ
    test('ويومُ عملٍ سُجّل عطلةً ليس عملاً', () {
      expect(WorkWeek.isWorkingDay(sunday, {WorkWeek.keyOf(sunday)}), isFalse);
    });
  });

  group('ومفتاحُ اليوم بصيغة التخزين نفسِها', () {
    test('الشهرُ واليومُ بخانتين', () {
      expect(WorkWeek.keyOf(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('والوقتُ لا يدخل فيه', () {
      expect(WorkWeek.keyOf(DateTime(2026, 9, 20, 23, 59)), '2026-09-20');
    });

    test('ويطابق ما يكتبه الخادم', () {
      // صيغةُ `dayKeyOf` في `status_scope.ts` حرفاً بحرف.
      expect(WorkWeek.keyOf(sunday), '2026-09-20');
    });
  });

  group('وأيامُ العمل بين تاريخين — مقامُ كلّ نسبة', () {
    test('أسبوعٌ كاملٌ خمسةُ أيامِ عمل', () {
      final days = WorkWeek.workingDaysBetween(sunday, saturday, const {});
      expect(days.length, 5);
      expect(WorkWeek.keyOf(days.first), '2026-09-20');
      expect(WorkWeek.keyOf(days.last), '2026-09-24');
    });

    test('وعطلةٌ رسميّةٌ تُنقص يوماً', () {
      final days = WorkWeek.workingDaysBetween(
          sunday, saturday, {WorkWeek.keyOf(thursday)});
      expect(days.length, 4);
    });

    test('والطرفان داخلان', () {
      expect(WorkWeek.workingDaysBetween(sunday, sunday, const {}).length, 1);
    });

    // ــ ومدىً مقلوبٌ لا يدور بلا نهاية ــ
    //
    // وهو الحارسُ نفسُه المكتوب في `DepartmentSection.levelIn`: خطأٌ في
    // التاريخ كان سيُجمّد الواجهة لا أن يُظهر رقماً خاطئاً.
    test('ومدىً مقلوبٌ يعيد قائمةً خالية', () {
      expect(WorkWeek.workingDaysBetween(saturday, sunday, const {}), isEmpty);
    });

    test('ومدىً طويلٌ جدّاً ينتهي ولا يُعلَّق', () {
      final days = WorkWeek.workingDaysBetween(
          DateTime(2020, 1, 1), DateTime(2040, 1, 1), const {});
      expect(days.length, lessThanOrEqualTo(3660));
      expect(days, isNotEmpty);
    });
  });
}
