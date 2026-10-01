// حقولُ حافظة المشاريع: **إضافةٌ لا تكسر شيئاً**.
//
// ــــ الشرطُ الذي وضعه مسؤولُ النظام ــــ
//
// «حافظ على جميع الوظائف الحالية · أيُّ تعديلٍ يجب ألّا يكسر الميزاتِ
// الحالية · لا تحذف أيّ بيانات حالية».
//
// ولذلك يُقاس هنا شيئان لا واحد:
//
// (١) **مستندٌ قديمٌ يُقرأ بلا ترحيل.** المنصّةُ حيّةٌ فيها مئاتُ المشاريع
//     كُتبت قبل هذه الحقول. ومستندٌ بلا الحقل يجب أن يُقرأ فارغاً لا أن
//     يُسقط المشروع — وهو بعينه ما أسقط مشاريعَ الوزارة يوماً كاملاً حين
//     رمى القارئُ على تاريخٍ وصل نصّاً.
//
// (٢) **و`copyWith` تنقلها.** `toMap` تكتب المستندَ كاملاً، فنسخةٌ بلا هذه
//     الحقول **تمحوها من كلّ مشروعٍ يُعدَّل** بلا أن يقصد ذلك أحد. وهو
//     تحذيرٌ مكتوبٌ مرّتين في `project.dart` — للنقل وللحذف — وهذه ثالثتُه.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

Project _project({Map<String, dynamic> extra = const {}}) =>
    Project.fromMapForTest('p-old', {
      'departmentId': 'd1',
      'name': 'مشروعٌ قديم',
      'description': 'كُتب قبل حقول الحافظة',
      'startDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
      'dueDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'status': 'onTrack',
      'priority': 'medium',
      'progressPercent': 40,
      ...extra,
    });

void main() {
  group('مستندٌ قديمٌ يُقرأ بلا ترحيل', () {
    test('مشروعٌ بلا حقول الحافظة يُقرأ ولا يُسقَط', () {
      final p = _project();
      expect(p.name, 'مشروعٌ قديم');
      expect(p.progressPercent, 40);
    });

    test('وحقولُ الحافظة الغائبةُ تُقرأ فارغةً لا مخترَعة', () {
      final p = _project();
      expect(p.businessOwnerUid, '');
      expect(p.sponsorName, '');
      expect(p.vendorName, '');
      expect(p.criticality, '');
      expect(p.currentPhase, '');
      expect(p.nextAction, '');
      expect(p.nextActionDate, isNull);
      expect(p.actualCompletionDate, isNull);
      expect(p.budget, isNull);
    });

    test('وتُقرأ حين تُكتب', () {
      final p = _project(extra: {
        'businessOwnerName': 'مدير إدارة العقود',
        'criticality': 'tier1',
        'currentPhase': 'التحليل',
        'nextAction': 'اعتماد وثيقة المتطلبات',
        'nextActionDate': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'budget': 125000,
      });
      expect(p.businessOwnerName, 'مدير إدارة العقود');
      expect(p.criticality, 'tier1');
      expect(p.nextAction, 'اعتماد وثيقة المتطلبات');
      expect(p.nextActionDate, DateTime(2026, 3, 1));
      expect(p.budget, 125000);
    });

    // ــ ونوعٌ غيرُ متوقَّعٍ لا يُسقط المشروع ــ
    //
    // وهو عينُ الصيغة التي أسقطت مشاريعَ الوزارة: قيمةٌ وصلت نصّاً في موضع
    // ختمٍ أو رقم.
    test('وتاريخٌ وصل نصّاً يُقرأ ولا يرمي', () {
      final p = _project(extra: {'nextActionDate': '2026-03-01T00:00:00.000'});
      expect(p.nextActionDate, DateTime(2026, 3, 1));
    });

    test('ورقمٌ وصل نصّاً كذلك', () {
      expect(_project(extra: {'budget': '125000'}).budget, 125000);
    });

    test('وقيمةٌ لا تُقرأ تبقى فارغةً ولا تُختلق', () {
      final p = _project(extra: {'nextActionDate': 'ليس تاريخاً', 'budget': 'لا رقم'});
      expect(p.nextActionDate, isNull);
      expect(p.budget, isNull);
    });
  });

  group('و`copyWith` تنقلها فلا تُمحى بتعديل', () {
    final full = _project(extra: {
      'businessOwnerUid': 'u-owner',
      'businessOwnerName': 'مالك العمل',
      'sponsorUid': 'u-sponsor',
      'sponsorName': 'الراعي',
      'vendorName': 'شركة التقنية',
      'criticality': 'tier1',
      'currentPhase': 'التطوير',
      'nextPhase': 'الاختبار',
      'nextAction': 'تسليم النسخة الأولى',
      'nextActionDate': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'actualCompletionDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
      'budget': 90000,
    });

    // ــ وهذا هو الحدُّ: تعديلُ الاسم وحدَه لا يمحو الحافظة ــ
    test('تعديلُ حقلٍ واحدٍ يُبقي حقولَ الحافظة كلَّها', () {
      final renamed = full.copyWith(name: 'اسمٌ جديد');
      expect(renamed.name, 'اسمٌ جديد');
      expect(renamed.businessOwnerUid, 'u-owner');
      expect(renamed.sponsorName, 'الراعي');
      expect(renamed.vendorName, 'شركة التقنية');
      expect(renamed.criticality, 'tier1');
      expect(renamed.currentPhase, 'التطوير');
      expect(renamed.nextPhase, 'الاختبار');
      expect(renamed.nextAction, 'تسليم النسخة الأولى');
      expect(renamed.nextActionDate, DateTime(2026, 4, 1));
      expect(renamed.actualCompletionDate, DateTime(2026, 5, 1));
      expect(renamed.budget, 90000);
    });

    // ــ وما يُكتب في المستند هو ما يُقرأ منه ــ
    //
    // فلو كُتب حقلٌ ولم يُقرأ لَضاع بصمتٍ عند أوّل إعادة تحميل.
    test('والدورةُ كاملةً: يُكتب ثمّ يُقرأ كما هو', () {
      final written = full.copyWith(nextAction: 'مراجعةُ الأمن').toMap();
      final back = Project.fromMapForTest('p-old', written);
      expect(back.nextAction, 'مراجعةُ الأمن');
      expect(back.businessOwnerName, 'مالك العمل');
      expect(back.budget, 90000);
      expect(back.criticality, 'tier1');
    });

    test('ولا تختلط الميزانيةُ بقيمة العقد', () {
      // الميزانيةُ ما رُصد، وقيمةُ العقد ما تُعوقد عليه — وقد يفترقان.
      final p = full.copyWith(contractValue: 80000);
      expect(p.budget, 90000);
      expect(p.contractValue, 80000);
    });

    test('ومسحُ العقد لا يمسّ الميزانية', () {
      final p = full.copyWith(contractValue: 80000).copyWith(clearContract: true);
      expect(p.contractValue, isNull);
      expect(p.budget, 90000, reason: 'الميزانيةُ ليست من العقد');
    });
  });

  group('والحَرِجيّةُ غيرُ الأولويّة', () {
    test('مشروعٌ منخفضُ الأولويّة قد يكون حَرِجاً', () {
      final p = _project(extra: {'priority': 'low', 'criticality': 'tier1'});
      expect(p.priority, PriorityLevel.low);
      expect(p.criticality, 'tier1');
    });
  });
}
