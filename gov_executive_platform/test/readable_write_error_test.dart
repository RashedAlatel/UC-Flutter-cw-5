// رسالةُ الرفض تقول ما يُفعل، لا رمزاً.
//
// ــــ لماذا ــــ
//
// «تعذّر الحفظ: [cloud_firestore/permission-denied] Missing or insufficient
// permissions.» — هذه هي الرسالة التي وصلت مسؤول النظام ثلاث مرات، ولا
// تقول لأحدٍ ما يفعله.
//
// وأكثرُ أسبابها في هذه المنصة **بطاقةُ دخولٍ لم تُختم**: القواعد تقرأ
// البطاقة، والواجهةُ تقرأ سجلَّ المستخدم — فيفترقان بعد ترقيةٍ أو نقلٍ بين
// الإدارات، فتقول الواجهة «تستطيع» ويقول الخادم «لا».
//
// والسببُ الخام يبقى ملحقاً: من يُصلح يحتاجه، ومن يقرأ يتجاوزه.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';

void main() {
  group('رفضُ الصلاحية يُقال بلغةٍ تُقرأ', () {
    final msg = AppStore.readableWriteError(
      Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.'),
    );

    test('يذكر أن الخادم ردّ الحفظ', () {
      expect(msg, contains('ردّ الخادم الحفظ'));
    });

    test('ويسمّي السبب الأرجح — البطاقة', () {
      expect(msg, contains('بطاقة دخولك'));
    });

    test('ويذكر ما يُفعل', () {
      expect(msg, contains('تسجيل الخروج والدخول'));
    });

    // ولا يُخفي الرمز: من يُصلح العطل يحتاجه.
    test('ويُبقي السبب الخام ملحقاً', () {
      expect(msg, contains('permission-denied'));
    });

    test('ويُصيب الصيغة الكبيرة كذلك', () {
      final upper = AppStore.readableWriteError(Exception('PERMISSION_DENIED'));
      expect(upper, contains('ردّ الخادم الحفظ'));
    });
  });

  group('وما ليس رفضَ صلاحيةٍ لا يُلبَس لبوسَه', () {
    // انقطاعُ الشبكة له علاجٌ آخر تماماً — وتوجيهُ صاحبه إلى تسجيل الخروج
    // يُضيّع وقتَه على عطلٍ ليس عنده.
    test('انقطاع الشبكة يُعرض كما هو', () {
      final msg = AppStore.readableWriteError(Exception('unavailable: network error'));
      expect(msg, startsWith('تعذّر الحفظ:'));
      expect(msg, contains('network error'));
      expect(msg, isNot(contains('بطاقة دخولك')));
    });

    test('وخطأٌ مجهول كذلك', () {
      final msg = AppStore.readableWriteError(Exception('شيءٌ آخر'));
      expect(msg, startsWith('تعذّر الحفظ:'));
      expect(msg, isNot(contains('ردّ الخادم الحفظ')));
    });
  });
}
