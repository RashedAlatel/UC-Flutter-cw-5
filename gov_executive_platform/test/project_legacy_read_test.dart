// قراءةُ مستندِ مشروعٍ لا تنهار بنوعٍ مفاجئ.
//
// ــــ الحادثةُ ــــ
//
// اختفت مشاريعُ وزارة العدل كلُّها — مئةٌ وأربعةٌ وثمانون — يوماً كاملاً،
// والسببُ **مستندٌ واحد** حمل `contractEndDate` نصّاً بدل ختمٍ زمني:
//
//     '2026-05-17T00:00:00.000'
//
// كتبَه مسارُ اعتماد تعديل المشروع (أُصلح في `approval_stage.ts`)، وقرأه
// النموذجُ `as Timestamp?` فرمى. والقراءةُ يومَها ذرّية، فأسقط المستندُ
// الواحدُ الباقين معه.
//
// ــــ ولماذا تُحصَّن القراءةُ وقد أُصلحت الكتابة ــــ
//
// لأنهما يحرسان شيئين مختلفين: تلك تمنع نصّاً **جديداً**، وهذه تُنجّي
// المنصّة من نصٍّ **مكتوبٍ سلفاً** — أو من أيّ نوعٍ يكتبه مسارٌ لم يُكتب
// بعد. وثمنُ الحصانة معلوم: `null` تُقرأ «غير مسجّل»، ولا يُختلق صفرٌ ولا
// يُدسّ تاريخُ اليوم.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/project.dart';

/// القيمةُ نفسُها التي أخفت المنصّة — بصمةُ `toIso8601String()` في Dart:
/// بلا `Z`، وبثلاث خاناتٍ للأجزاء.
const _iso = '2026-05-17T00:00:00.000';

Map<String, dynamic> _map([Map<String, dynamic> extra = const {}]) => {
      'name': 'الربط مع وزارة الداخلية',
      'departmentId': 'dept_support',
      ...extra,
    };

Project _read([Map<String, dynamic> extra = const {}]) =>
    Project.fromMapForTest('dept_support_p8', _map(extra));

void main() {
  group('نصُّ تاريخٍ في حقل ختمٍ زمني', () {
    // ــ إعادةُ الإنتاج: هذا هو المستندُ الذي أخفى مئةً وأربعةً وثمانين ــ
    test('يُقرأ تاريخاً ولا يُسقط المشروع', () {
      final p = _read({'contractEndDate': _iso});
      expect(p.contractEndDate, DateTime.parse(_iso));
    });

    test('وفي كلّ حقول العقد الأربعة', () {
      final p = _read({
        'contractDate': _iso,
        'contractStartDate': _iso,
        'contractEndDate': _iso,
        'invoiceDueDate': _iso,
      });
      expect(p.contractDate, isNotNull);
      expect(p.contractStartDate, isNotNull);
      expect(p.contractEndDate, isNotNull);
      expect(p.invoiceDueDate, isNotNull);
    });

    test('وفي تواريخ المشروع نفسِه', () {
      final p = _read({'startDate': _iso, 'dueDate': _iso});
      expect(p.startDate, DateTime.parse(_iso));
      expect(p.dueDate, DateTime.parse(_iso));
    });

    // ــ ونصٌّ ليس تاريخاً لا يُختلق له تاريخ ــ
    //
    // «غير مسجّل» قيمةٌ تُقال. ولو رُدّ تاريخُ اليوم لَظهر مشروعٌ بعقدٍ
    // ينتهي اليوم، وهو أسوأ من فراغ: رقمٌ يُتّخذ عليه قرار.
    test('وما ليس تاريخاً يُقرأ «غير مسجّل» لا اليوم', () {
      final p = _read({'contractEndDate': 'قريباً إن شاء الله'});
      expect(p.contractEndDate, isNull);
    });

    test('وحقلُ تاريخٍ رقمٌ لا يُقرأ تاريخاً', () {
      expect(_read({'contractEndDate': 17}).contractEndDate, isNull);
    });
  });

  group('ورقمٌ كُتب نصّاً', () {
    test('يُقرأ رقماً', () {
      final p = _read({'durationDays': '90', 'contractValue': '15000.5'});
      expect(p.durationDays, 90);
      expect(p.contractValue, 15000.5);
    });

    // وصفرٌ يُختلق أسوأ من فراغ: مدّةُ عقدٍ صفراً تُقرأ التزاماً منتهياً.
    test('وما ليس رقماً يُقرأ «غير مسجّل» لا صفراً', () {
      final p = _read({'durationDays': 'تسعون', 'contractValue': 'غير محدّد'});
      expect(p.durationDays, isNull);
      expect(p.contractValue, isNull);
    });

    test('ونسبةُ الإنجاز نصّاً تُقرأ رقماً', () {
      expect(_read({'progressPercent': '35'}).progressPercent, 35);
    });

    // النسبةُ ليست اختيارية: غيابُها صفرٌ صادق — لم يُنجز شيء.
    test('وغيابُها صفرٌ لا عدم', () {
      expect(_read().progressPercent, 0);
    });
  });

  group('والغيابُ التامُّ لا ينهار', () {
    test('مستندٌ بأدنى الحقول يُقرأ', () {
      final p = Project.fromMapForTest('p-فارغ', const {});
      expect(p.id, 'p-فارغ');
      expect(p.name, '');
      expect(p.contractEndDate, isNull);
      expect(p.durationDays, isNull);
    });

    // مشاريعُ الوزارة المستوردة لا تحمل حقولَ العقد أصلاً.
    test('ومستندٌ بلا حقول عقدٍ يُقرأ بلا اختلاق', () {
      final p = _read();
      expect(p.contractDate, isNull);
      expect(p.contractorName, '');
    });
  });

  // ــ والختمُ الحقيقيُّ يبقى مقروءاً كما كان ــ
  //
  // الحصانةُ لا تُقايَض بالصواب: أكثرُ مستندات المنصّة تحمل ختماً صحيحاً،
  // ولو انكسرت قراءتُه لَكان العلاجُ أسوأ من الداء.
  test('ختمُ Firestore يُقرأ كما هو — وهو حالُ كلّ المستندات السليمة', () {
    final p = _read({'contractEndDate': Timestamp.fromDate(DateTime(2026, 5, 17))});
    expect(p.contractEndDate, DateTime(2026, 5, 17));
  });

  test('و`DateTime` مباشرةً كذلك', () {
    final p = _read({'contractEndDate': DateTime(2026, 5, 17)});
    expect(p.contractEndDate, DateTime(2026, 5, 17));
  });

  test('وتواريخُ المشروع الأساسية من ختمٍ سليم', () {
    final p = _read({
      'startDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
      'dueDate': Timestamp.fromDate(DateTime(2026, 3, 16)),
    });
    expect(p.startDate, DateTime(2026, 1, 15));
    expect(p.dueDate, DateTime(2026, 3, 16));
  });
}
