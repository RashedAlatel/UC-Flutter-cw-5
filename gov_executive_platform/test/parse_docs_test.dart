// مستندٌ واحدٌ مشوَّه لا يُخفي المنصّة — وختمُ بطاقةٍ يُخفق لا يمرّ صامتاً.
//
// ــــ الحادثةُ التي أوجبت هذا الملف ــــ
//
// اختفت مئةٌ وواحدٌ وثمانون مشروعاً من منصّة الوزارة، ولم يظهر على الشاشة
// حرفٌ واحد يقول لماذا. ومضى يومٌ في التخمين: أهو الحذف؟ أم القواعد؟ أم
// الفهارس؟ ولم تكن المنصّة تملك كيف تقول أيَّها وقع.
//
// وبابا الصمت اللذان قِيسا هنا اثنان:
//
// (١) **القراءةُ الذرّية**: `snap.docs.map(fromDoc).toList()` ترمي كلَّها من
//     أجل مستندٍ واحد، فتبقى القائمةُ على ما كانت — ولا خطأ يُلتقط، لأن
//     `onError` تلتقط أخطاء التدفّق وحدها.
//
// (٢) **ختمُ البطاقة المُهمَل**: `_reconcileClaims` تكتشف افتراق البطاقة عن
//     السجل ثم تُهمل ما يُعيده `syncMyClaims`. فمن أخفق ختمُه يمضي ببطاقةٍ
//     ميتة تردّ قراءاتِه وكتاباتِه، والشاشةُ تسمح ولا تقول.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/project.dart';

/// خريطةُ مشروعٍ سليمة — بأقلّ ما يُقرأ به.
Map<String, dynamic> _good(int i) => {
      'name': 'مشروع $i',
      'departmentId': 'd-1',
      'durationDays': 90,
    };

/// وخريطةٌ مشوَّهة: المدّةُ نصٌّ لا رقم — وهو ما يقع حين يُستورد حقلٌ من
/// جدولٍ خارجي أو يكتبه مسارٌ لا يفحص نوعَه.
Map<String, dynamic> _bad() => {
      'name': 'مشروع مشوَّه',
      'departmentId': 'd-1',
      'durationDays': '90',
    };

List<Map<String, dynamic>> _hundredAndOne() => [
      for (var i = 0; i < 100; i++) _good(i),
      _bad(),
    ];

void main() {
  group('القراءةُ الذرّية — وهي العطل', () {
    // ــ إعادةُ الإنتاج: هذا هو ما كان مكتوباً في المتجر حرفاً بحرف ــ
    test('اليوم: مستندٌ واحدٌ مشوَّه يُسقط المئةَ السليمة معه', () {
      final maps = _hundredAndOne();
      expect(
        () => maps.map((m) => Project.fromMapForTest('p', m)).toList(),
        throwsA(isA<TypeError>()),
        reason: 'كلٌّ أو لا شيء — ولا سبيل إلى المئة السليمة',
      );
    });

    test('وبعدها: تُقرأ المئةُ ويسقط الواحد', () {
      final maps = _hundredAndOne();
      final read = AppStore.parseEach<Project, Map<String, dynamic>>(
        maps,
        (m) => m['name'] as String,
        (m) => Project.fromMapForTest('p', m),
      );
      expect(read.items.length, 100);
      expect(read.received, 101);
      expect(read.failures, hasLength(1));
    });

    // ــ ولا يكفي أن يُعدّ الساقط: يُسمَّى ــ
    //
    // «تعذّرت قراءة مستند» وصفٌ لا يُصلَح به شيء. والمعرِّفُ ونصُّ الخطأ
    // هما ما يجعل العطلَ يُصلَح في دقائق بدل يوم.
    test('ويُسمَّى الساقطُ بمعرِّفه وبنصّ خطئه', () {
      final read = AppStore.parseEach<Project, Map<String, dynamic>>(
        _hundredAndOne(),
        (m) => m['name'] as String,
        (m) => Project.fromMapForTest('p', m),
      );
      expect(read.failures.single, contains('مشروع مشوَّه'));
      expect(read.failures.single, contains('String'));
    });

    test('ولقطةٌ سليمةٌ كلُّها لا تُنتج شكوى', () {
      final read = AppStore.parseEach<Project, Map<String, dynamic>>(
        [for (var i = 0; i < 7; i++) _good(i)],
        (m) => m['name'] as String,
        (m) => Project.fromMapForTest('p', m),
      );
      expect(read.items, hasLength(7));
      expect(read.received, 7);
      expect(read.failures, isEmpty);
    });

    test('ولقطةٌ فارغة ليست عطلاً', () {
      final read = AppStore.parseEach<Project, Map<String, dynamic>>(
        const [],
        (m) => 'x',
        (m) => Project.fromMapForTest('p', m),
      );
      expect(read.items, isEmpty);
      expect(read.received, 0);
      expect(read.failures, isEmpty);
    });
  });

  group('وختمُ البطاقة يُقال إخفاقُه', () {
    test('اليوم كان يُهمَل — وبعدها يُعلن', () async {
      final store = AppStore();
      await store.syncClaimsOrReport(() async => 'unavailable');
      expect(store.dataErrors[AppStore.claimsErrorLabel], isNotNull);
    });

    // النصُّ يقول ما يقع وما يُفعل — لا رمزَ خطأٍ خام.
    test('ويقول إنّ الخادم سيردّ حتى تُختم، ويقترح الخروج والدخول', () async {
      final store = AppStore();
      await store.syncClaimsOrReport(() async => 'internal');
      final text = store.dataErrors[AppStore.claimsErrorLabel]!;
      expect(text, contains('تسجيل الخروج والدخول'));
      expect(text, contains('internal'), reason: 'والسببُ الخام يبقى لمن يُصلح');
    });

    test('ونجاحُ الختم يمحو الخبر', () async {
      final store = AppStore();
      await store.syncClaimsOrReport(() async => 'unavailable');
      await store.syncClaimsOrReport(() async => null);
      expect(store.dataErrors[AppStore.claimsErrorLabel], isNull);
    });
  });

  // ــــ وما وصل وما قُرئ يُسجَّلان حيث تقرؤهما الشاشة ــــ
  //
  // وهذا ما نجت عليه طفرةٌ أوّل مرّة: كان الوصلُ والقراءةُ يُكتبان في موضعٍ
  // يشترط Firestore حيّاً، فلا يبلغه قياس — ولو كتب العدّادُ رقماً خاطئاً
  // لَكذبت الشاشةُ على قارئها بثقة.
  group('تسجيلُ ما وصل وما قُرئ', () {
    List<int> parseInts(AppStore store, List<String> raw) => store.recordParse<int, String>(
          'projects',
          raw,
          (r) => r,
          int.parse,
        );

    test('العدّادُ يقول ما وصل لا ما قُرئ', () {
      final store = AppStore();
      parseInts(store, ['1', '2', 'س', '4']);
      expect(store.docCounts['projects']!.received, 4);
      expect(store.docCounts['projects']!.parsed, 3);
    });

    test('وما قُرئ يُعاد ولا يسقط بسقوط جاره', () {
      final store = AppStore();
      expect(parseInts(store, ['1', 'س', '3']), [1, 3]);
    });

    test('ويُكتب خبرُ الإخفاق بالعددين وباسم الساقط', () {
      final store = AppStore();
      parseInts(store, ['1', 'س']);
      final text = store.dataErrors['projects']!;
      expect(text, contains('وصل 2'));
      expect(text, contains('قُرئ 1'));
      expect(text, contains('س'));
    });

    // ــ ولا يبقى خبرُ إخفاقٍ بعد لقطةٍ سليمة ــ
    //
    // لافتةٌ معلّقة بعد أن صُلح العطلُ تُفقد اللافتةَ معناها.
    test('ولقطةٌ سليمةٌ تمحو خبرَ لقطةٍ أخفقت', () {
      final store = AppStore();
      parseInts(store, ['1', 'س']);
      parseInts(store, ['1', '2']);
      expect(store.dataErrors['projects'], isNull);
      expect(store.docCounts['projects'], (received: 2, parsed: 2));
    });
  });

  // ــــ و«صفرُ مشاريع» يصير خبراً يُقرأ ــــ
  //
  // «لا توجد مشاريع مسجّلة بعد» جملةٌ تصف القائمة ولا تصف الحال. وقد قيلت
  // لمسؤول نظامٍ ومنصّتُه تحمل مئةً وواحداً وثمانين مشروعاً.
  group('خبرُ تدفّق المشاريع', () {
    test('بلا لقطةٍ وصلت بعد: لا خبر — ولا يُدّعى عطل', () {
      expect(AppStore().projectsArrivalNote, isNull);
    });

    test('لم يصل شيء: النطاقُ هو القائل لا الشبكة', () {
      final store = AppStore()..docCounts['projects'] = (received: 0, parsed: 0);
      expect(store.projectsArrivalNote, contains('لم يصل'));
      expect(store.projectsArrivalNote, contains('النطاق'));
    });

    test('وصل ولم يُقرأ كلُّه: بالعددين', () {
      final store = AppStore()..docCounts['projects'] = (received: 181, parsed: 4);
      expect(store.projectsArrivalNote, contains('181'));
      expect(store.projectsArrivalNote, contains('4'));
    });

    // ــ ولا يُقال خبرٌ حيث لا خبر ــ
    //
    // منصّةٌ جديدة بلا مشاريع حالٌ مشروعة، ولا يُخوَّف صاحبُها بلا سبب.
    test('وقُرئ كلُّ ما وصل: لا خبر', () {
      final store = AppStore()..docCounts['projects'] = (received: 12, parsed: 12);
      expect(store.projectsArrivalNote, isNull);
    });
  });

  // ــــ ومن غُيّر دورُه لا يُترك ساعةً ببطاقةٍ قديمة ــــ
  //
  // الخادمُ يكتب `claimsUpdatedAt` مع كل ختم، ومستمعُ `users/{uid}` يراه.
  group('ختمٌ جديد يُعرف من ختمٍ نعرفه', () {
    final t0 = DateTime(2026, 9, 2, 8);
    final t1 = DateTime(2026, 9, 2, 9);

    test('ختمٌ أحدثُ مما نعرف: نعم', () {
      expect(AppStore.claimsRestamped(t0, t1), isTrue);
    });

    // أوّلُ لقطةٍ تقول ما هو قائم لا أنّ شيئاً تغيّر. وتجديدُ الرمز عندها
    // نداءُ شبكةٍ في كل فتحةِ صفحة بلا سبب.
    test('وأوّلُ لقطةٍ ليست تغييراً', () {
      expect(AppStore.claimsRestamped(null, t1), isFalse);
    });

    test('وحسابٌ لم يُختم قطّ لا يُوقظ شيئاً', () {
      expect(AppStore.claimsRestamped(t0, null), isFalse);
    });

    test('والختمُ نفسُه ليس ختماً جديداً', () {
      expect(AppStore.claimsRestamped(t0, t0), isFalse);
    });

    // ساعةُ الخادم قد تعود إلى الوراء في نادرِ الحالات؛ ولا يُقرأ ذلك ختماً.
    test('وختمٌ أقدمُ مما نعرف ليس ختماً جديداً', () {
      expect(AppStore.claimsRestamped(t1, t0), isFalse);
    });
  });
}
