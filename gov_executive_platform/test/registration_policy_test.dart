// سياسة التسجيل: نطاقات البريد الوزاري المقبولة.
//
// الفحص في نموذج التسجيل لطفٌ بالموظف لا حراسة — الحراسة الفعلية في دالة
// الاعتماد على الخادم. لكن لطفاً يخطئ أسوأ من غيابه: رفض بريد صحيح يمنع
// موظفاً من التسجيل بلا سبب مفهوم، وقبول بريد خارجي يوهمه أن طلبه سيمرّ.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/registration_policy.dart';

void main() {
  group('تنقية النطاق المكتوب بيد الإنسان', () {
    test('يقبل النطاق بعلامة @ وبأحرف كبيرة وببريد كامل', () {
      expect(RegistrationPolicy.normalizeDomain('@moj.gov.kw'), 'moj.gov.kw');
      expect(RegistrationPolicy.normalizeDomain('MOJ.GOV.KW'), 'moj.gov.kw');
      expect(RegistrationPolicy.normalizeDomain(' user@Moj.Gov.Kw '), 'moj.gov.kw');
      expect(RegistrationPolicy.normalizeDomain('.moj.gov.kw.'), 'moj.gov.kw');
    });
  });

  group('قبول البريد', () {
    const policy = RegistrationPolicy(allowedEmailDomains: ['moj.gov.kw', 'e.gov.kw']);

    test('يقبل أي نطاق من القائمة', () {
      expect(policy.allows('fahad@moj.gov.kw'), isTrue);
      expect(policy.allows('nora@e.gov.kw'), isTrue);
      expect(policy.allows('FAHAD@MOJ.GOV.KW'), isTrue, reason: 'حالة الأحرف لا تغيّر ملكية البريد');
    });

    test('يرفض ما خرج عن القائمة', () {
      expect(policy.allows('fahad@gmail.com'), isFalse);
      // نطاق فرعي ليس النطاق نفسه، وقبوله ثغرة: أي أحد يملك moj.gov.kw.evil.com
      expect(policy.allows('x@sub.moj.gov.kw'), isFalse);
      expect(policy.allows('x@moj.gov.kw.evil.com'), isFalse);
      expect(policy.allows('بلا-علامة'), isFalse);
    });

    // منصة لم يضبط مسؤولها النطاقات بعد يجب ألا تمنع كل الموظفين من التسجيل.
    test('القائمة الفارغة تعني لا قيد', () {
      expect(const RegistrationPolicy().allows('anyone@example.com'), isTrue);
    });
  });

  group('القراءة من الخادم', () {
    test('تُنقّي النطاقات المخزّنة وتتجاهل الفارغ منها', () {
      final policy = RegistrationPolicy.fromMap({
        'allowedEmailDomains': ['@MOJ.GOV.KW', '  ', 'e.gov.kw'],
        'requireEmailVerification': false,
      });
      expect(policy.allowedEmailDomains, ['moj.gov.kw', 'e.gov.kw']);
      expect(policy.requireEmailVerification, isFalse);
    });

    test('المستند الغائب يعطي سياسة افتراضية تشترط التأكيد ولا تقيّد النطاق', () {
      final policy = RegistrationPolicy.fromMap(null);
      expect(policy.allowedEmailDomains, isEmpty);
      expect(policy.requireEmailVerification, isTrue);
    });
  });
}
