// أربعةُ أعطالٍ كانت تُقال جملةً واحدة — ولكلٍّ علاجٌ مختلف.
//
// ــــ ما كلّفه خلطُها ــــ
//
// اختفت مشاريعُ الوزارة، وكانت اللافتة — إن ظهرت — تقول «تعذّر تحميل بعض
// البيانات… تأكد من اتصال الشبكة». والشبكةُ سليمة. فمضى يومٌ بين الحذف
// والقواعد والفهارس، والجوابُ كان في مكانٍ رابع.
//
// فصار الصنفُ يُسمّى: بطاقةٌ ميتة (خروجٌ ودخول) · صلاحيةٌ ناقصة (مزامنة) ·
// مستنداتٌ وصلت ولم تُقرأ (يُصلحه المطوّر ويُسمَّى له المستند) · وما بقي.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';

void main() {
  group('صنفُ العطل يُسمّى', () {
    test('بطاقةٌ تخالف السجل', () {
      final r = AppStore.describeDataErrors(
        {AppStore.claimsErrorLabel: 'تعذّر الختم (unavailable)'},
        const {},
      );
      expect(r.kind, DataTrouble.claims);
      expect(r.body, contains('unavailable'));
    });

    test('وصلاحيةٌ ناقصة', () {
      final r = AppStore.describeDataErrors(
        {'projects': '[cloud_firestore/permission-denied] Missing or insufficient permissions'},
        const {},
      );
      expect(r.kind, DataTrouble.permission);
      expect(r.body, contains('projects'));
    });

    // ــ الخبرُ بالأرقام ــ
    test('ومستنداتٌ وصلت ولم تُقرأ — بعددها', () {
      final r = AppStore.describeDataErrors(
        {'projects': 'تعذّرت قراءة 177: p-14: TypeError'},
        <String, ({int received, int parsed})>{
          'projects': (received: 181, parsed: 4),
        },
      );
      expect(r.kind, DataTrouble.parse);
      expect(r.body, contains('وصل 181 مستنداً وقُرئ 4'));
      expect(r.body, contains('p-14'), reason: 'ويُسمَّى المستند');
      expect(r.body, contains('لم يمنع'), reason: 'ويُقال إن الخادم ليس السبب');
    });

    test('وما بقي: انقطاعٌ لا يُصنَّف', () {
      final r = AppStore.describeDataErrors(
        {'works': 'unavailable: network error'},
        const {},
      );
      expect(r.kind, DataTrouble.network);
      expect(r.body, contains('الشبكة'));
    });
  });

  group('والترتيبُ مقصود — الأشدُّ يُقدَّم', () {
    // من بطاقتُه ميتة تُردّ قراءاتُه كلُّها، فلا معنى لأن يُقال له
    // «تحقّق من الشبكة» ولا «زامِن صلاحياتك».
    test('البطاقةُ تسبق الصلاحية', () {
      final r = AppStore.describeDataErrors(
        {
          AppStore.claimsErrorLabel: 'تعذّر الختم',
          'projects': 'permission-denied',
        },
        const {},
      );
      expect(r.kind, DataTrouble.claims);
    });

    test('والصلاحيةُ تسبق عطلَ القراءة', () {
      final r = AppStore.describeDataErrors(
        {
          'works': 'permission-denied',
          'projects': 'تعذّرت قراءة 3',
        },
        <String, ({int received, int parsed})>{
          'projects': (received: 10, parsed: 7),
        },
      );
      expect(r.kind, DataTrouble.permission);
    });

    test('وعطلُ القراءة يسبق الانقطاع', () {
      final r = AppStore.describeDataErrors(
        {
          'works': 'unavailable',
          'projects': 'تعذّرت قراءة 3',
        },
        <String, ({int received, int parsed})>{
          'projects': (received: 10, parsed: 7),
        },
      );
      expect(r.kind, DataTrouble.parse);
    });
  });

  // ــ ولا يُدّعى عطلُ قراءةٍ حيث لا عطل ــ
  //
  // تدفّقٌ وصل كلُّه وقُرئ كلُّه ليس مصدرَ الشكوى، وإن كان له خطأٌ قديم.
  test('ولقطةٌ قُرئت كاملةً لا تُعدّ عطلَ قراءة', () {
    final r = AppStore.describeDataErrors(
      {'projects': 'unavailable'},
      <String, ({int received, int parsed})>{
        'projects': (received: 181, parsed: 181),
      },
    );
    expect(r.kind, DataTrouble.network);
  });

  test('وخريطةٌ فارغة لا تنهار', () {
    final r = AppStore.describeDataErrors(const {}, const {});
    expect(r.kind, DataTrouble.network);
  });
}
