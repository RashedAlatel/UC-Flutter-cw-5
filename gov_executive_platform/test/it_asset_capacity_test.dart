// سعةُ الأصل: **«لم تُقَس» ليست «صفراً»**.
//
// ــــ ولماذا ملفٌّ خاصٌّ لهذا ــــ
//
// قِيس الفرقُ أوّلاً في `AttentionEngine` بطفرةٍ تجعل الغائبَ صفراً —
// **فنجت**، ولم تكن نجاةً حقيقيّة: الصفرُ لا يتجاوز حدّاً موجباً، فالجوابُ
// واحدٌ في الحالتين ولا يفرّق بينهما تنبيه.
//
// فالفرقُ حيث يُرى فعلاً: **في القراءة وفي الشاشة**. مستندٌ بلا الحقل
// يجب أن يُقرأ `null` فتقول الشاشةُ «السعةُ غيرُ مقيسة»، ومستندٌ فيه صفرٌ
// صريحٌ يُقرأ صفراً فتقول «٠٪». وجمعُهما يجعل أصلاً لم يُنظر إليه أحدٌ قطّ
// يبدو مقيساً وفارغاً — وهو ادّعاءُ رقمٍ لا نقصُ بيان.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/it_asset.dart';

Map<String, dynamic> _doc({bool withCapacity = true, Object? capacity = 40}) => {
      'kind': 'server',
      'name': 'خادم',
      'status': 'live',
      'criticality': 'tier2',
      'capacityThreshold': 85,
      'createdByUid': 'u1',
      'createdAt': DateTime(2026, 1, 1),
      if (withCapacity) 'capacityUsedPercent': capacity,
    };

void main() {
  group('«لم تُقَس» ليست «صفراً»', () {
    test('مستندٌ بلا الحقل يُقرأ غيرَ مقيس', () {
      final a = ITAsset.fromMap('a1', _doc(withCapacity: false));
      expect(a.capacityUsedPercent, isNull);
      expect(a.isOverCapacity, isFalse);
    });

    // ــ وصفرٌ صريحٌ يبقى صفراً ــ
    //
    // ولو قُرئ `null` لَضاع فرقٌ حقيقيّ: قرصٌ قيس فوُجد فارغاً غيرُ قرصٍ
    // لم يُنظر إليه.
    test('وصفرٌ مكتوبٌ يُقرأ صفراً لا غياباً', () {
      final a = ITAsset.fromMap('a1', _doc(capacity: 0));
      expect(a.capacityUsedPercent, 0);
      expect(a.isOverCapacity, isFalse);
    });

    test('وقيمةٌ مكتوبةٌ تُقرأ كما هي', () {
      expect(ITAsset.fromMap('a1', _doc(capacity: 40)).capacityUsedPercent, 40);
    });

    // ــ ونصٌّ مكان الرقم لا يُسقط المستند ــ
    //
    // راجع `safe_read.dart`: مستندٌ واحدٌ حمل تاريخاً نصّاً أسقط مئةً
    // وأربعةً وثمانين مشروعاً يوماً كاملاً.
    test('ونصٌّ رقميٌّ يُقرأ رقماً', () {
      expect(ITAsset.fromMap('a1', _doc(capacity: '55')).capacityUsedPercent, 55);
    });

    test('ونصٌّ لا يُقرأ رقماً يُقرأ غيرَ مقيس', () {
      final a = ITAsset.fromMap('a1', _doc(capacity: 'غير معروف'));
      expect(a.capacityUsedPercent, isNull);
      expect(a.isOverCapacity, isFalse);
    });

    test('والحدُّ الغائبُ يُقرأ خمسةً وثمانين', () {
      final d = _doc()..remove('capacityThreshold');
      expect(ITAsset.fromMap('a1', d).capacityThreshold, 85);
    });
  });

  group('متى يُعدّ متجاوزاً', () {
    ITAsset a(num? used, {AssetStatus status = AssetStatus.live, int threshold = 85}) =>
        ITAsset(
          id: 'a1',
          kind: AssetKind.server,
          name: 'خادم',
          status: status,
          capacityUsedPercent: used,
          capacityThreshold: threshold,
          createdByUid: 'u1',
          createdAt: DateTime(2026, 1, 1),
        );

    test('فوق الحدّ متجاوز', () => expect(a(90).isOverCapacity, isTrue));

    // والحدُّ نفسُه ليس تجاوزاً: بلغه ولم يتجاوزه.
    test('وعند الحدّ بالضبط ليس متجاوزاً', () => expect(a(85).isOverCapacity, isFalse));

    test('ودونه ليس متجاوزاً', () => expect(a(84).isOverCapacity, isFalse));

    test('والخارجُ من الخدمة لا يُحاسَب', () {
      expect(a(99, status: AssetStatus.retired).isOverCapacity, isFalse);
    });

    test('والمتعثّرُ يُحاسَب — هو في الخدمة', () {
      expect(a(99, status: AssetStatus.degraded).isOverCapacity, isTrue);
    });
  });
}
