// نماذجُ الحالات اليومية: ما يُقرأ، وما يُرفض، وما لا يُخترع.
//
// ــــ الدرسُ المدفوعُ ثمنُه ــــ
//
// اختفت مشاريعُ وزارة العدل كلُّها — مئةٌ وأربعةٌ وثمانون — يوماً كاملاً،
// والسببُ مستندٌ واحدٌ حمل تاريخاً نصّاً فرمى القارئُ وأسقط الباقين معه.
//
// فهذه النماذجُ تقرأ بقرّاء `safe_read.dart`، **وترمي مسمِّيةً** لا تُرجع
// `null` صامتاً: `_parseDocs` تلتقط لكلّ مستندٍ على حدة وتسمّيه في لافتة
// تعذُّر القراءة. و`null` كانت ستُسقط يوماً من تقويم موظّفٍ بلا أن يقول
// أحدٌ لماذا.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/daily_status.dart';
import 'package:gov_exec_platform/models/holiday.dart';
import 'package:gov_exec_platform/models/status_type.dart';
import 'package:gov_exec_platform/theme/status_palette.dart';

void main() {
  group('سجلُّ الحالة', () {
    final base = {
      'uid': 'u1',
      'userName': 'أحمد',
      'departmentId': 'd1',
      'sectionId': 's1',
      'dayKey': '2026-09-20',
      'kind': 'day',
      'typeId': 'present',
      'typeName': 'حضور',
      'toneKey': 'success',
    };

    test('يُقرأ بحقوله', () {
      final s = DailyStatus.fromMap('u1_2026-09-20', {...base});
      expect(s.uid, 'u1');
      expect(s.typeName, 'حضور');
      expect(s.kind, StatusKind.day);
      expect(s.wasCorrected, isFalse);
    });

    // ــ ويرمي مسمِّياً لا يُسقط صامتاً ــ
    test('وسجلٌّ بلا صاحبٍ يرمي', () {
      expect(() => DailyStatus.fromMap('x', {...base, 'uid': ''}), throwsFormatException);
    });

    test('وسجلٌّ بلا يومٍ يرمي', () {
      expect(() => DailyStatus.fromMap('x', {...base, 'dayKey': ''}), throwsFormatException);
    });

    // ــ ورقمٌ وصل نصّاً يُقرأ ولا يُسقط اليوم ــ
    //
    // وهو عينُ الصيغة التي أسقطت مشاريع الوزارة: قيمةٌ بنوعٍ غير متوقَّع.
    test('ووقتٌ وصل نصّاً يُقرأ رقماً', () {
      final s = DailyStatus.fromMap('x', {
        ...base,
        'kind': 'outing',
        'fromMinutes': '540',
        'toMinutes': 660,
      });
      expect(s.fromMinutes, 540);
      expect(s.toMinutes, 660);
    });

    test('ووقتٌ لا يُقرأ يبقى فارغاً ولا يُختلق', () {
      final s = DailyStatus.fromMap('x', {...base, 'fromMinutes': 'لا شيء'});
      expect(s.fromMinutes, isNull);
      expect(s.timeLabel, '');
    });

    test('ووقتُ الخروج يُعرض بساعتين ودقيقتين', () {
      final s = DailyStatus.fromMap('x', {
        ...base,
        'kind': 'outing',
        'fromMinutes': 540,
        'toMinutes': 665,
      });
      expect(s.timeLabel, '09:00 — 11:05');
    });

    test('ونوعٌ مجهولٌ يُقرأ ولا يُسقط السجلّ', () {
      final s = DailyStatus.fromMap('x', {...base, 'kind': 'شيءٌ آخر'});
      expect(s.kind, StatusKind.day);
    });

    test('وأثرُ التصحيح يُقرأ حين يوجد', () {
      final s = DailyStatus.fromMap('x', {
        ...base,
        'correctedByName': 'مدير الإدارة',
        'correctionNote': 'كان مسجّلاً حضوراً وهو في مهمّة',
      });
      expect(s.wasCorrected, isTrue);
      expect(s.correctedByName, 'مدير الإدارة');
    });
  });

  group('ونوعُ الحالة', () {
    test('يُقرأ بخصائصه', () {
      final t = StatusType.fromMap({
        'id': 'mission',
        'name': 'مهمّة رسميّة',
        'toneKey': 'info',
        'canBeOuting': true,
        'countsAsPresent': true,
        'requiresPlace': true,
        'order': 2,
      });
      expect(t, isNotNull);
      expect(t!.canBeDay, isTrue, reason: 'المبدئيُّ أنّه يصلح حالةً لليوم');
      expect(t.canBeOuting, isTrue);
      expect(t.requiresPlace, isTrue);
    });

    test('وبلا اسمٍ يُسقَط من القائمة', () {
      expect(StatusType.fromMap({'id': 'x'}), isNull);
      expect(StatusType.fromMap({'name': 'بلا معرّف'}), isNull);
      expect(StatusType.fromMap('ليس خريطة'), isNull);
    });

    // ــ ونغمةٌ مجهولةٌ محايدةٌ لا مخترَعة ــ
    test('ونغمةٌ لا يعرفها النظامُ تُقرأ محايدة', () {
      final t = StatusType.fromMap({'id': 'x', 'name': 'نوع', 'toneKey': 'وردي'});
      expect(StatusPalette.byToneKey(t!.toneKey), StatusPalette.neutral);
    });

    // ــ وكلُّ نغمةٍ يختارها مسؤولُ النظام لها ما يقابلها ــ
    //
    // ولولا هذا لَعرضت الشاشةُ خياراً يُنتج لوناً محايداً دائماً.
    test('وكلُّ خيارٍ معروضٍ له نغمةٌ حقيقيّة', () {
      for (final key in StatusPalette.toneChoices.keys) {
        expect(StatusPalette.byToneKey(key), isNot(StatusPalette.neutral),
            reason: 'الخيار «$key» لا يقابله لون',
            skip: key == 'neutral' ? 'المحايدُ محايدٌ بحقّه' : null);
      }
    });

    test('والبذرةُ ثمانيةُ أنواعٍ كما سُمّيت', () {
      final seed = StatusType.seed();
      expect(seed.length, 8);
      expect(seed.map((t) => t.name), contains('حضور'));
      expect(seed.map((t) => t.name), contains('إجازة طبيّة'));
      // وكلُّ نوعٍ في البذرة يصلح لشيء — وإلا لم يظهر للموظّف أصلاً.
      for (final t in seed) {
        expect(t.canBeDay || t.canBeOuting, isTrue, reason: '«${t.name}» لا يصلح لشيء');
      }
    });
  });

  group('والعطلة', () {
    test('تُقرأ بمفتاحها', () {
      final h = Holiday.fromMap({'dayKey': '2026-09-20', 'name': 'العيد الوطني'});
      expect(h!.dayKey, '2026-09-20');
      expect(h.name, 'العيد الوطني');
    });

    // ــ وقارئٌ يفترض صيغةً واحدةً هو ما أسقط مشاريع الوزارة ــ
    test('وتُقرأ من ختمٍ كما تُقرأ من نصّ', () {
      final h = Holiday.fromMap({'day': DateTime(2026, 9, 20), 'name': 'عيد'});
      expect(h!.dayKey, '2026-09-20');
    });

    test('وبلا يومٍ تُسقَط', () {
      expect(Holiday.fromMap({'name': 'بلا يوم'}), isNull);
    });

    test('وبلا اسمٍ تبقى بمسمّىً عام', () {
      expect(Holiday.fromMap({'dayKey': '2026-09-20'})!.name, 'عطلة رسميّة');
    });
  });
}
