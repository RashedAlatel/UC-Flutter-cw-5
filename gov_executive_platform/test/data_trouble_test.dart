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

    // ــ العطلُ الخامس: فهرسٌ لم يصل قاعدةَ البيانات ــ
    //
    // وقع على شاشة مسؤول النظام بعد نشر المرحلة الأولى: استعلامان بحقلين
    // (`uid` مع مدىً على التاريخ) يحتاجان فهرساً مركَّباً، وقد كُتب في
    // `firestore.indexes.json` ولم يبلغ المشروعَ الحيّ.
    //
    // **فقالت اللافتةُ «تأكد من اتصال الشبكة»** — نصيحةٌ لا تُصلح شيئاً،
    // وابتلعت معها رسالةَ Firestore التي تحمل **رابطَ إنشاء الفهرس جاهزاً**.
    // وهو بعينه ما تشكو منه هذه الدالّةُ في تعليقها: جملةٌ واحدةٌ لأعطالٍ
    // علاجُها مختلف تُضيّع اليومَ الذي ضاع.
    test('فهرسٌ ناقصٌ يُسمّى ولا يُقال «تحقّق من الشبكة»', () {
      final r = AppStore.describeDataErrors(
        {
          'dailyStatuses/حالتي':
              '[cloud_firestore/failed-precondition] The query requires an index. '
                  'You can create it here: https://console.firebase.google.com/x',
        },
        const {},
      );
      expect(r.kind, DataTrouble.missingIndex);
      expect(r.body, isNot(contains('الشبكة')),
          reason: 'عطلٌ لا تُصلحه شبكةٌ لا يُقال فيه «تحقّق من الشبكة»');
    });

    // ــ والرابطُ أثمنُ ما في الرسالة ــ
    //
    // Firestore يعطي رابطاً يُنشئ الفهرسَ بضغطة. وابتلاعُه يحوّل عطلاً
    // علاجُه دقيقةٌ إلى عطلٍ يحتاج تشخيصاً.
    test('ورسالةُ الخادم تمرّ كما هي، وفيها الرابط', () {
      final r = AppStore.describeDataErrors(
        {
          'weeklyPlans/خطّتي':
              '[cloud_firestore/failed-precondition] The query requires an index. '
                  'You can create it here: https://console.firebase.google.com/abc',
        },
        const {},
      );
      expect(r.body, contains('https://console.firebase.google.com/abc'));
      expect(r.body, contains('weeklyPlans/خطّتي'), reason: 'ويُسمَّى المستمع');
    });

    // ــ والصيغةُ الثانية: «فهرسٌ مركَّب» ــ
    test('وصيغةُ «composite index» تُصنَّف كذلك', () {
      final r = AppStore.describeDataErrors(
        {'works': 'The query requires a composite index.'},
        const {},
      );
      expect(r.kind, DataTrouble.missingIndex);
    });

    // ــ والرمزُ مع الكلمة: صياغةٌ ثالثةٌ لم نرَها بعد تبقى مقروءة ــ
    test('ورمزٌ مع كلمة index يُصنَّف ولو تغيّرت الصياغة', () {
      final r = AppStore.describeDataErrors(
        {'works': '[cloud_firestore/failed-precondition] missing index for this query'},
        const {},
      );
      expect(r.kind, DataTrouble.missingIndex);
    });

    // ــ ولا يُكتفى بالرمز وحدَه ــ
    //
    // `failed-precondition` يخرج لأعطالٍ أخرى. ولو صُنِّفت فهرساً لَقيل
    // لصاحبها «انشر الفهارس» — وهي نصيحةٌ خاطئةٌ بقدر «تحقّق من الشبكة»
    // التي أوجبت هذا الفرع أصلاً.
    test('وعطلُ failed-precondition لا يخصّ فهرساً يبقى خارج الفرع', () {
      final r = AppStore.describeDataErrors(
        {'works': '[cloud_firestore/failed-precondition] The Cloud Firestore API is not available'},
        const {},
      );
      expect(r.kind, DataTrouble.network,
          reason: 'نصيحةُ نشر الفهارس لا تُصلح عطلاً ليس فهرساً');
    });

    test('ونصُّ «requires an index» وحدَه يكفي للتصنيف', () {
      // فبعضُ الإصدارات لا تُلحق الرمزَ بالنصّ.
      final r = AppStore.describeDataErrors(
        {'works': 'The query requires an index.'},
        const {},
      );
      expect(r.kind, DataTrouble.missingIndex);
    });

    // ــ ولا يبتلع الفرعُ الجديدُ ما ليس له ــ
    //
    // وحارسٌ يشكو مما لا عيبَ فيه لا يُقرأ يومَ يشكو من عيب.
    test('وانقطاعُ الشبكة يبقى انقطاعاً', () {
      final r = AppStore.describeDataErrors(
        {'works': 'unavailable: network error'},
        const {},
      );
      expect(r.kind, DataTrouble.network);
    });

    // والرفضُ يبقى رفضاً: هو أعلى في الترتيب، وعلاجُه المزامنة لا النشر.
    test('ورفضُ الصلاحية يبقى رفضاً ولو جاء معه فهرس', () {
      final r = AppStore.describeDataErrors(
        {
          'works': 'permission-denied',
          'weeklyPlans/خطّتي': 'The query requires an index.',
        },
        const {},
      );
      expect(r.kind, DataTrouble.permission);
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
