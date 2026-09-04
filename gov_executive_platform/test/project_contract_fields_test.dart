// بياناتُ العقد على المشروع — والغيابُ يُقال ولا يُملأ.
//
// ــــ المبدأ الذي يحكم هذا الملفّ كلَّه ــــ
//
// **`null` تعني «غير مسجّل» لا صفراً.** ومشاريعُ الوزارة المائةُ والثمانية
// المستوردة لا تحمل عقوداً في المنصة. فلو قُرئ غيابُ `contractValue` صفراً
// لَظهرت «قيمة العقد: ٠٫٠٠٠ د.ك» على مشروعٍ قيمتُه مئاتُ الألوف — وذلك
// **ادّعاءُ رقمٍ** لا نقصُ بيان، ويُقرأ في تقريرٍ يُرفع إلى وزير.
//
// وهي القاعدة نفسُها التي حكمت `completedAt` على المهام قبل دورتين.
//
// ــــ والفخُّ الثاني: مستندٌ يُولد ناقصاً ــــ
//
// `toMap` تُكتب عند الإنشاء، وقواعدُ Firestore تمنع مسّ حقولٍ **تُضاف لأوّل
// مرّة في تعديل**. فوقع مرّتين في هذا المستودع أن رُدّ أوّلُ تعديلٍ على
// سجلٍّ وُلد ناقصاً — في الأعمال (`ba220b7`) وفي المهام. فيُقاس هنا أن
// المفاتيح السبعة **تُكتب دائماً ولو فارغة**.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/utils/formatters.dart';

const _contractKeys = [
  'contractDate',
  'contractStartDate',
  'contractEndDate',
  'invoiceDueDate',
  'durationDays',
  'contractValue',
  'contractorName',
];

Project _project({
  DateTime? contractDate,
  DateTime? contractStartDate,
  DateTime? contractEndDate,
  DateTime? invoiceDueDate,
  int? durationDays,
  double? contractValue,
  String contractorName = '',
}) =>
    Project(
      id: 'p1',
      departmentId: 'd1',
      name: 'مشروع العدالة الرقمية',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      contractDate: contractDate,
      contractStartDate: contractStartDate,
      contractEndDate: contractEndDate,
      invoiceDueDate: invoiceDueDate,
      durationDays: durationDays,
      contractValue: contractValue,
      contractorName: contractorName,
    );

/// مشروعٌ **كما وُلد قبل حقول العقد** — بلا أيٍّ من مفاتيحها.
final _legacyDoc = <String, dynamic>{
  'departmentId': 'd1',
  'name': 'مشروع قديم',
  'description': '',
  'startDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
  'dueDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
  'status': 'onTrack',
  'priority': 'medium',
  'progressPercent': 40,
};

void main() {
  group('الحقولُ السبعة تُكتب وتُقرأ', () {
    test('كلُّ حقلٍ يُكتب بقيمته ويُقرأ كما كُتب', () {
      final p = _project(
        contractDate: DateTime(2026, 2, 1),
        contractStartDate: DateTime(2026, 2, 15),
        contractEndDate: DateTime(2027, 2, 14),
        invoiceDueDate: DateTime(2026, 3, 1),
        durationDays: 365,
        contractValue: 125000.5,
        contractorName: 'شركة النظم المتقدمة',
      );
      final back = Project.fromMapForTest('p1', p.toMap());

      expect(back.contractDate, DateTime(2026, 2, 1));
      expect(back.contractStartDate, DateTime(2026, 2, 15));
      expect(back.contractEndDate, DateTime(2027, 2, 14));
      expect(back.invoiceDueDate, DateTime(2026, 3, 1));
      expect(back.durationDays, 365);
      expect(back.contractValue, 125000.5);
      expect(back.contractorName, 'شركة النظم المتقدمة');
    });

    // الفخُّ الذي كلّف هذا المستودع دورتين: مستندٌ يُولد ناقصاً مفتاحاً.
    test('والمفاتيحُ السبعة تُكتب حتى حين لا تُسجَّل قيمة', () {
      final map = _project().toMap();
      for (final key in _contractKeys) {
        expect(map.containsKey(key), isTrue, reason: 'المفتاح «$key» غائبٌ عن toMap');
      }
      expect(map['contractDate'], isNull);
      expect(map['durationDays'], isNull);
      expect(map['contractValue'], isNull);
      expect(map['contractorName'], '');
    });

    // مشروعٌ كُتب قبل وجود الحقول يُقرأ بلا انهيار وبلا قيمٍ مختلقة.
    test('ومشروعٌ وُلد قبلها يُقرأ «غير مسجّل» لا صفراً', () {
      final old = Project.fromMapForTest('p-old', _legacyDoc);
      expect(old.contractDate, isNull);
      expect(old.contractStartDate, isNull);
      expect(old.contractEndDate, isNull);
      expect(old.invoiceDueDate, isNull);
      expect(old.durationDays, isNull);
      expect(old.contractValue, isNull);
      expect(old.contractorName, '');
      expect(old.hasContractData, isFalse);
    });

    // وقراءتُه ثم كتابتُه تُنتج المفاتيح — فلا يبقى ناقصاً بعد أول حفظ.
    test('وحفظُه بعد قراءته يُكمل مفاتيحه', () {
      final map = Project.fromMapForTest('p-old', _legacyDoc).toMap();
      for (final key in _contractKeys) {
        expect(map.containsKey(key), isTrue, reason: 'المفتاح «$key»');
      }
    });
  });

  group('«هل هناك عقدٌ أصلاً»', () {
    test('بلا شيءٍ منها: لا', () {
      expect(_project().hasContractData, isFalse);
    });

    // كلُّ حقلٍ وحده يكفي لإظهار البطاقة — وإلا اختفى ما سُجّل.
    test('وأيُّ حقلٍ منها وحده يكفي', () {
      expect(_project(contractDate: DateTime(2026, 1, 1)).hasContractData, isTrue);
      expect(_project(contractStartDate: DateTime(2026, 1, 1)).hasContractData, isTrue);
      expect(_project(contractEndDate: DateTime(2026, 1, 1)).hasContractData, isTrue);
      expect(_project(invoiceDueDate: DateTime(2026, 1, 1)).hasContractData, isTrue);
      expect(_project(durationDays: 30).hasContractData, isTrue);
      expect(_project(contractValue: 1000).hasContractData, isTrue);
      expect(_project(contractorName: 'شركة').hasContractData, isTrue);
    });

    // اسمٌ من فراغاتٍ ليس اسماً: بطاقةٌ تظهر لأجل مسافةٍ سهواً ضجيج.
    test('واسمٌ من فراغاتٍ لا يُعدّ تسجيلاً', () {
      expect(_project(contractorName: '   ').hasContractData, isFalse);
    });

    // وقيمةُ صفرٍ **مسجَّلة**: عقدٌ بلا مقابل شيءٌ، وغيابُ القيمة شيءٌ آخر.
    test('وقيمةُ صفرٍ مسجَّلةٌ لا غائبة', () {
      expect(_project(contractValue: 0).hasContractData, isTrue);
    });
  });

  group('copyWith تحمل العقد ولا تُسقطه', () {
    final full = _project(
      contractDate: DateTime(2026, 2, 1),
      durationDays: 365,
      contractValue: 5000,
      contractorName: 'شركة',
    );

    // العطلُ الذي يُخشى: تعديلُ الاسم يمحو العقد بلا أن يقصد ذلك أحد.
    test('تعديلُ حقلٍ آخر لا يمحو بيانات العقد', () {
      final renamed = full.copyWith(name: 'اسمٌ جديد');
      expect(renamed.contractDate, DateTime(2026, 2, 1));
      expect(renamed.durationDays, 365);
      expect(renamed.contractValue, 5000);
      expect(renamed.contractorName, 'شركة');
    });

    test('وتغييرُ حقلٍ من العقد يُغيّره وحده', () {
      final updated = full.copyWith(contractValue: 9000);
      expect(updated.contractValue, 9000);
      expect(updated.durationDays, 365);
      expect(updated.contractDate, DateTime(2026, 2, 1));
    });

    // «لا عقد» تُقال صراحةً: `null` وحدها تعني «لا تغيّر» في `copyWith`.
    test('والمسحُ فعلٌ صريح لا نسيان', () {
      final cleared = full.copyWith(clearContract: true);
      expect(cleared.contractDate, isNull);
      expect(cleared.durationDays, isNull);
      expect(cleared.contractValue, isNull);
      expect(cleared.contractorName, '');
      expect(cleared.hasContractData, isFalse);
      // وما ليس من العقد لا يُمسّ.
      expect(cleared.name, full.name);
    });
  });

  group('تنسيقُ المبلغ بالدينار', () {
    // الدينارُ ثلاثُ خاناتٍ لا خانتان: وحدتُه الصغرى الفلس (١/١٠٠٠).
    test('ثلاثُ خاناتٍ كسرية وفواصلُ آلاف', () {
      expect(Formatters.money(125000.5), '125٬000٫500 د.ك');
      expect(Formatters.money(1000), '1٬000٫000 د.ك');
      // وما دون الألف بلا فاصلة — لا «٬٩٩٩».
      expect(Formatters.money(999), '999٫000 د.ك');
      expect(Formatters.money(1234567.891), '1٬234٬567٫891 د.ك');
    });

    test('والمبلغُ الصغير بلا فاصلة', () {
      expect(Formatters.money(12.75), '12٫750 د.ك');
    });
  });
}
