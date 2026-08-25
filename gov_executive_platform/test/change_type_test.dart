// ما يُحفظ في «قبل/بعد» — المتغيّرُ وحده، لا المستند مرّتين.
//
// ــــ لماذا يُقاس هذا؟ ــــ
//
// طلبتَ تسجيل كل تغيير بالبيانات السابقة والجديدة. وأسهلُ تنفيذٍ لذلك حفظُ
// المستند كاملاً مرّتين — وهو أسوأُها: مشروعٌ فيه عشرون حقلاً يُكتب أربعين
// حقلاً في كل سطر، **ويختفي ما تغيّر فعلاً** بين ثمانية عشر حقلاً لم
// تتغيّر. فمن يفتح السطر ليعرف ماذا وقع يقرأ جدولين متطابقين تقريباً.
//
// والحالة الثانية التي تُقاس هنا أدقّ: قوائمُ العضوية تُبنى جديدةً في كل
// قراءة، فمقارنتُها بـ`==` تُرجع «مختلفة» دائماً. فلولا مقارنةٍ تفهم
// القوائم لَامتلأ سجل التدقيق بتعديلاتٍ لم تقع.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/change_type.dart';

void main() {
  group('diffMaps تحمل المتغيّر وحده', () {
    test('حقلٌ واحد تغيّر من بين ثلاثة', () {
      final d = diffMaps(
        {'name': 'مشروع', 'priority': 'medium', 'progress': 20},
        {'name': 'مشروع', 'priority': 'high', 'progress': 20},
      );

      expect(d, isNotNull);
      expect(d!.before, {'priority': 'medium'});
      expect(d.after, {'priority': 'high'});
    });

    test('وحقلٌ أُضيف — تغييرٌ يُسجَّل', () {
      final d = diffMaps({'name': 'مشروع'}, {'name': 'مشروع', 'sectionId': 's-1'});

      expect(d!.before, {'sectionId': null});
      expect(d.after, {'sectionId': 's-1'});
    });

    test('وحقلٌ أُزيل كذلك', () {
      final d = diffMaps({'name': 'مشروع', 'sectionId': 's-1'}, {'name': 'مشروع'});

      expect(d!.before, {'sectionId': 's-1'});
      expect(d.after, {'sectionId': null});
    });

    test('وأكثر من حقل', () {
      final d = diffMaps(
        {'name': 'أ', 'priority': 'low'},
        {'name': 'ب', 'priority': 'high'},
      );

      expect(d!.before.keys.toSet(), {'name', 'priority'});
      expect(d.after, {'name': 'ب', 'priority': 'high'});
    });
  });

  group('ولا يُكتب سطرٌ لتغييرٍ لم يقع', () {
    test('خريطتان متطابقتان — لا شيء', () {
      expect(diffMaps({'name': 'مشروع', 'progress': 20}, {'name': 'مشروع', 'progress': 20}), isNull);
    });

    // الحالة التي بُنيت لها المقارنةُ العميقة: قائمةٌ بالمحتوى نفسه في
    // كائنين مختلفين. و`==` عليها تُرجع false، فيُكتب تعديلٌ وهمي.
    test('وقائمتان بالمحتوى نفسه — لا تُعدّان تغييراً', () {
      expect(
        diffMaps(
          {'managerUids': ['m1', 'm2']},
          {'managerUids': ['m1', 'm2']},
        ),
        isNull,
      );
    });

    test('وخريطتان متداخلتان بالمحتوى نفسه', () {
      expect(
        diffMaps(
          {'closure': {'approverUid': 'u1', 'done': false}},
          {'closure': {'approverUid': 'u1', 'done': false}},
        ),
        isNull,
      );
    });

    // والترتيب داخل القائمة **فرقٌ حقيقي**: أوّل المديرين له معنىً في
    // المنصة (الحقل المفرد الموروث يُشتقّ منه).
    test('لكن ترتيبَ القائمة فرقٌ يُسجَّل', () {
      final d = diffMaps(
        {'managerUids': ['m1', 'm2']},
        {'managerUids': ['m2', 'm1']},
      );

      expect(d, isNotNull);
    });

    test('وعضوٌ أُضيف إلى القائمة فرقٌ بالطبع', () {
      final d = diffMaps(
        {'managerUids': ['m1']},
        {'managerUids': ['m1', 'm2']},
      );

      expect(d!.after, {
        'managerUids': ['m1', 'm2']
      });
    });
  });

  group('وأنواع التغيير تُقرأ من مفاتيحها', () {
    test('مفتاحٌ معروف', () {
      expect(ChangeType.fromKey('softDelete'), ChangeType.softDelete);
      expect(ChangeType.fromKey('convert'), ChangeType.convert);
    });

    // السطور المكتوبة قبل هذا التعداد لا تحمل الحقل إطلاقاً. وسطرٌ بنوعٍ
    // مجهول أولى أن يُعرض تحت «أخرى» من أن يُسقط السجلَّ عن الشاشة.
    test('ومفتاحٌ غائب أو مجهول يصير «أخرى» ولا يُرمى استثناء', () {
      expect(ChangeType.fromKey(null), ChangeType.other);
      expect(ChangeType.fromKey(''), ChangeType.other);
      expect(ChangeType.fromKey('نوعٌ لم يوجد قط'), ChangeType.other);
    });

    test('ولكل نوعٍ اسمٌ عربي يُعرض', () {
      for (final t in ChangeType.values) {
        expect(t.label.trim(), isNotEmpty, reason: 'النوع ${t.key} بلا اسم');
      }
    });

    // المفاتيح تُكتب في Firestore، فتكرارُها يخلط نوعين في التصفية.
    test('والمفاتيح لا تتكرّر', () {
      final keys = ChangeType.values.map((t) => t.key).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
