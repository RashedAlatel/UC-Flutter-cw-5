// دليلُ الإجراءات: ما يُقرأ من المستند، وما لا يُسقطه.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **نوعٌ مفاجئ لا يرمي**: تاريخٌ نصّاً، ورقمٌ نصّاً، وحقلٌ غائب.
//     وهو الدرسُ الذي كلّف المنصةَ ١٨٤ مشروعاً يوماً كاملاً — ويُطبَّق على
//     هذا النموذج **من يومه الأوّل** لا بعد أن يقع فيه ما وقع هناك.
//
// (٢) **وعنصرٌ فاسدٌ يسقط وحدَه**: خطوةٌ لا تُقرأ لا تُسقط الإجراءَ معها.
//
// (٣) **ولا يُختلق رقم**: مدّةٌ لم تُسجَّل ليست صفراً، ومجموعٌ ناقصٌ يُقال
//     ناقصاً.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/attachment.dart';
import 'package:gov_exec_platform/models/procedure.dart';

Procedure _read(Map<String, dynamic> json) => Procedure.fromMapForTest('p-1', json);

void main() {
  group('قراءةُ الإجراء لا ترمي مهما كُتب', () {
    test('تاريخٌ مكتوبٌ نصّاً يُقرأ تاريخاً', () {
      final p = _read({'title': 'إ', 'updatedAt': '2026-05-17T00:00:00.000'});
      expect(p.updatedAt, DateTime(2026, 5, 17));
    });

    test('وختمٌ زمنيّ كذلك', () {
      final p = _read({'title': 'إ', 'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 17))});
      expect(p.updatedAt, DateTime(2026, 5, 17));
    });

    // ــ وما لا يُقرأ يُقرأ «غير مسجّل» لا تاريخَ اليوم ــ
    test('ونوعٌ لا يُقرأ تاريخاً يُقرأ فراغاً لا اليوم', () {
      final p = _read({'title': 'إ', 'updatedAt': {'ليس': 'تاريخاً'}});
      expect(p.updatedAt, isNull);
    });

    test('ورقمُ النسخة نصّاً يُقرأ رقماً', () {
      expect(_read({'title': 'إ', 'version': '3'}).version, 3);
    });

    // نسخةٌ صفرٌ تعني «لا نسخة»، والإجراءُ القائم نسخته الأولى على الأقل.
    test('ونسخةٌ غائبةٌ هي الأولى لا الصفر', () {
      expect(_read({'title': 'إ'}).version, 1);
    });

    test('ومستندٌ فارغٌ تماماً يُقرأ ولا يرمي', () {
      final p = _read(const {});
      expect(p.title, '');
      expect(p.steps, isEmpty);
      expect(p.version, 1);
    });

    // ــ وغيابُ العلم «سارٍ» لا «مؤرشف» ــ
    //
    // فمستنداتٌ كُتبت قبل إضافة الحقل ليست مؤرشفة، وقراءتُها كذلك تُخفي
    // الدليلَ كلَّه بلا سبب.
    test('وغيابُ isActive يُقرأ سارياً', () {
      expect(_read({'title': 'إ'}).isActive, isTrue);
      expect(_read({'title': 'إ', 'isActive': false}).isActive, isFalse);
    });
  });

  group('والخطواتُ: عنصرٌ فاسدٌ يسقط وحدَه', () {
    test('تُقرأ بترتيبها في القائمة', () {
      final p = _read({
        'title': 'إ',
        'steps': [
          {'title': 'الأولى'},
          {'title': 'الثانية'},
        ],
      });
      expect(p.steps.map((s) => s.title).toList(), ['الأولى', 'الثانية']);
    });

    // ــ وهذا هو الحدُّ الذي يمنع تكرارَ حادثة المشاريع ــ
    //
    // خطوةٌ ليست خريطةً، أو بلا عنوان، تسقط وحدَها — ولا تُسقط الإجراءَ
    // ولا بقيّةَ خطواته معها.
    test('وما ليس خطوةً يسقط ولا يُسقط الإجراء', () {
      final p = _read({
        'title': 'إ',
        'steps': ['نصّ لا خريطة', {'title': 'صحيحة'}, 42, {'description': 'بلا عنوان'}],
      });
      expect(p.steps.map((s) => s.title).toList(), ['صحيحة']);
    });

    test('وقائمةُ خطواتٍ ليست قائمةً تُقرأ فارغة', () {
      expect(_read({'title': 'إ', 'steps': 'ليست قائمة'}).steps, isEmpty);
    });

    test('والمرفقاتُ تُقرأ مع الخطوة', () {
      final p = _read({
        'title': 'إ',
        'steps': [
          {
            'title': 'خ',
            'attachments': [
              {'name': 'نموذج.pdf', 'url': 'https://x/1', 'kind': 'upload'},
            ],
          },
        ],
      });
      expect(p.steps.single.attachments.single.name, 'نموذج.pdf');
      expect(p.steps.single.attachments.single.kind, AttachmentKind.upload);
    });

    test('وإدارةٌ فارغةٌ نصّاً تُقرأ «بلا إدارة»', () {
      final p = _read({
        'title': 'إ',
        'steps': [
          {'title': 'خ', 'departmentId': '   '},
        ],
      });
      expect(p.steps.single.departmentId, isNull);
    });
  });

  group('ولا يُختلق رقمٌ لم يُسجَّل', () {
    ProcedureStep step(int? days) =>
        ProcedureStep(title: 'خ', durationDays: days);

    test('مدّةٌ غائبةٌ ليست صفراً', () {
      final p = _read({
        'title': 'إ',
        'steps': [
          {'title': 'خ'},
        ],
      });
      expect(p.steps.single.durationDays, isNull);
    });

    // ــ وصفرٌ مكتوبٌ صراحةً يبقى صفراً ــ
    //
    // «تقع في يومها» قولٌ يُقال، وهو غير «لم تُحدَّد مدّتُها».
    test('وصفرٌ مكتوبٌ صراحةً يبقى صفراً', () {
      final p = _read({
        'title': 'إ',
        'steps': [
          {'title': 'خ', 'durationDays': 0},
        ],
      });
      expect(p.steps.single.durationDays, 0);
    });

    test('والمجموعُ مجموعُ ما سُجّل', () {
      final p = Procedure(id: 'p', title: 'إ', steps: [step(3), step(4)]);
      expect(p.totalDurationDays, 7);
      expect(p.hasCompleteDurations, isTrue);
    });

    // ــ ومجموعٌ ناقصٌ يُقال ناقصاً ــ
    //
    // فمجموعٌ مبنيٌّ على أصفارٍ مفترضة يُقرأ وعداً بمدّةٍ لم يقلها أحد.
    test('ومجموعٌ فيه خطوةٌ بلا مدّةٍ يُعلَم أنّه ناقص', () {
      final p = Procedure(id: 'p', title: 'إ', steps: [step(3), step(null)]);
      expect(p.totalDurationDays, 3);
      expect(p.hasCompleteDurations, isFalse);
    });

    test('وإجراءٌ بلا مُدَدٍ أصلاً لا مجموعَ له', () {
      final p = Procedure(id: 'p', title: 'إ', steps: [step(null)]);
      expect(p.totalDurationDays, isNull);
    });

    test('وإجراءٌ بلا خطواتٍ لا يُقال إنّ مُدَدَه كاملة', () {
      expect(const Procedure(id: 'p', title: 'إ').hasCompleteDurations, isFalse);
    });
  });

  group('والنسخةُ المحفوظة تُقرأ كما كانت', () {
    Map<String, dynamic> versionMap({Object? snapshot}) => {
          'procedureId': 'p-1',
          'versionNumber': 2,
          'savedByName': 'مدير',
          'note': 'تحديث سنوي',
          'snapshot': snapshot ??
              {
                'title': 'الإجراء كما كان',
                'version': 2,
                'steps': [
                  {'title': 'خطوةٌ حُذفت لاحقاً'},
                ],
              },
        };

    test('صورةُ الإجراء كاملةٌ لا فروقاً', () {
      final v = ProcedureVersion.fromMapForTest('v-1', versionMap());
      expect(v.versionNumber, 2);
      expect(v.note, 'تحديث سنوي');
      expect(v.snapshot.title, 'الإجراء كما كان');
      expect(v.snapshot.steps.single.title, 'خطوةٌ حُذفت لاحقاً');
    });

    // ومعرّفُ الصورة معرّفُ الإجراء لا معرّفُ مستند النسخة — فمن فتحها
    // يفتح إجراءً يعرف أصلَه.
    test('ومعرّفُ الصورة معرّفُ الإجراء', () {
      final v = ProcedureVersion.fromMapForTest('v-1', versionMap());
      expect(v.id, 'v-1');
      expect(v.snapshot.id, 'p-1');
    });

    // ــ ونسخةٌ لا تُفتح خيرٌ من دليلٍ لا يُفتح ــ
    test('وصورةٌ مفقودةٌ تُقرأ إجراءً فارغاً لا رمياً', () {
      final v = ProcedureVersion.fromMapForTest('v-1', versionMap(snapshot: 'تالف'));
      expect(v.snapshot.title, '');
      expect(v.snapshot.steps, isEmpty);
    });
  });
}
