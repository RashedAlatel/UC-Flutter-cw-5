// ربطُ المشروع بسجلّ المورّدين — **إضافةٌ لا استبدال**.
//
// ــــ ما يُقاس ــــ
//
// كان `Project.vendorName` نصّاً، وفي تعليقه «ويُربط لاحقاً بسجلّ
// المورّدين». فبُني السجلّ وأُضيف `vendorId` **إلى جانبه**.
//
// والخطرُ في هذه الإضافة واحدٌ ومعروف: `toMap` تكتب المستندَ كاملاً، فحقلٌ
// غائبٌ عن `copyWith` **يُمحى في أوّل تعديل**. وقد وقع ذلك ثلاث مرّاتٍ في
// `project.dart` قبل اليوم.
//
// والثاني: مشاريعُ الوزارة المستوردة تحمل الاسمَ نصّاً بلا معرّفٍ يقابله،
// فيجب أن تبقى مقروءةً كما هي.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

Project _project({String vendorName = '', String vendorId = ''}) => Project(
      id: 'p1',
      departmentId: 'd1',
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      vendorName: vendorName,
      vendorId: vendorId,
    );

void main() {
  group('المورّد: الاسمُ يبقى والمعرّفُ يُضاف', () {
    test('مشروعٌ قديمٌ باسمٍ بلا معرّفٍ يبقى مقروءاً', () {
      final p = _project(vendorName: 'شركةُ النظم');
      expect(p.vendorName, 'شركةُ النظم');
      expect(p.vendorId, isEmpty, reason: 'وفارغٌ يعني اسماً بلا سجلّ');
    });

    test('والربطُ يُضيف المعرّفَ ولا يمحو الاسم', () {
      final linked = _project(vendorName: 'شركةُ النظم').copyWith(vendorId: 'v-7');
      expect(linked.vendorId, 'v-7');
      expect(linked.vendorName, 'شركةُ النظم');
    });

    // ــ وهذا هو الخطأُ الذي وقع ثلاث مرّات ــ
    //
    // `toMap` تكتب المستندَ كاملاً. فحقلٌ غائبٌ عن `copyWith` يُمحى في
    // أوّل تعديلٍ لحقلٍ آخر — بلا أن يقصد ذلك أحد.
    test('وتعديلُ حقلٍ آخر لا يمحو المورّد', () {
      final before = _project(vendorName: 'شركةُ النظم', vendorId: 'v-7');
      final after = before.copyWith(name: 'اسمٌ جديد');
      expect(after.vendorId, 'v-7');
      expect(after.vendorName, 'شركةُ النظم');
    });

    test('و`copyWith` تحمل كلَّ حقلٍ في `toMap`', () {
      final before = _project(vendorName: 'شركةُ النظم', vendorId: 'v-7');
      final after = before.copyWith(name: 'اسمٌ جديد');
      final a = before.toMap()..remove('name');
      final b = after.toMap()..remove('name');
      expect(b, a, reason: 'تعديلُ حقلٍ واحدٍ لا يمحو البقيّة');
    });

    test('والمعرّفُ يُكتب في المستند ويُقرأ منه', () {
      final map = _project(vendorName: 'شركة', vendorId: 'v-7').toMap();
      expect(map['vendorId'], 'v-7');
      expect(map['vendorName'], 'شركة');
    });

    // ــ ومستندٌ كُتب قبل هذه الدورة لا يحمل الحقلَ إطلاقاً ــ
    test('ومستندٌ بلا الحقل يُقرأ فارغاً لا ينهار', () {
      final map = _project(vendorName: 'شركة').toMap()..remove('vendorId');
      expect(map.containsKey('vendorId'), isFalse);
      expect(map['vendorName'], 'شركة');
    });
  });
}
