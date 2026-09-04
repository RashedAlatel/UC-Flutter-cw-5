// الدور المكتوب لحظة التسجيل — وهو **حاجزٌ في القواعد لا تفصيلٌ في العميل**.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// في جولة فصل الدور عن قيادة المشروع صارت قاعدة إنشاء `/users` تشترط
// `request.resource.data.role == 'employee'`، وبقيت `signUp` تكتب
// `projectOfficer`. فكل تسجيلٍ جديد يُرفض.
//
// وأسوأ ما فيه ترتيبُ الخطوات في `signUp`: حساب المصادقة يُنشأ **قبل** كتابة
// السجل. فالموظف يخرج بحساب دخولٍ حيّ بلا سجلٍّ في المنصة — لا يدخل، ولا
// يسجّل من جديد لأن بريده «مسجَّل مسبقاً». عالقٌ لا يُخرجه إلا حذفٌ يدوي.
//
// ــــ ولماذا لم يصح شيء؟ ــــ
//
// لأن الطرفين صحيحان كلٌّ في نفسه: اختبار القواعد يفحص القاعدة بدورٍ مكتوبٍ
// يدوياً، واختبار الأدوار يفحص `UserRole.assignable` — ولا واحد منهما يمرّ
// على **ما تكتبه `signUp` فعلاً**. فهذه الفجوة بالضبط ما يسدّه هذا الملف:
// يقرأ الدور المشترط من `firestore.rules` نفسه، ويقارنه بما يُكتب.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/enums.dart';

/// المستند كما تبنيه الشيفرة الحقيقية — لا نسخةٌ منها.
///
/// و`signUp` نفسها لا تُستدعى: تنادي Firebase Auth وFirestore وكلاهما غير
/// متاح هنا. فالمشترك بينهما `AppStore.signupUserRecord`، وهو ما تكتبه
/// `signUp` حرفاً. ولو بُني المستند في هذا الملف لَمرّ الاختبار وهو لا يفحص
/// شيئاً — وذلك أسوأ من غيابه، لأنه يُطَمئن.
Map<String, dynamic> signupDoc() => AppStore.signupUserRecord(
      uid: 'u-new',
      name: 'موظف جديد',
      email: 'new@moj.gov.kw',
      phone: '',
      departmentId: 'd-1',
      createdAt: DateTime(2026, 1, 1),
    ).toMap();

/// الدور الذي تشترطه قاعدة إنشاء `/users`، مقروءاً من ملف القواعد نفسه.
///
/// ولا يُكتب هنا نصّاً: لو كُتب لصار في المنصة موضعان يقولان «الحاجز
/// employee»، ولافترقا عند أول تعديل — وهو الافتراق نفسه الذي أنتج العطل.
String roleRequiredByRules() {
  final rules = File('firestore.rules').readAsStringSync();
  final match = RegExp(r"request\.resource\.data\.role == '(\w+)'").firstMatch(rules);
  expect(match, isNotNull,
      reason: 'لم يُعثر على شرط الدور في قاعدة إنشاء /users — هل تغيّرت صيغته؟');
  return match!.group(1)!;
}

void main() {
  group('ما يكتبه التسجيل يطابق ما تشترطه القاعدة', () {
    test('الدور المكتوب هو الدور المشترط حرفاً', () {
      expect(
        signupDoc()['role'],
        roleRequiredByRules(),
        reason: 'سجل التسجيل يُرفض على الخادم، ويبقى حساب الدخول حيّاً بلا سجل',
      );
    });

    test('والحالة «بانتظار الموافقة» كما تشترط القاعدة', () {
      expect(signupDoc()['status'], 'pending');
    });

    // الحقلان اللذان تشترط القاعدة خلوّهما: من كتبهما على سجله لحظة التسجيل
    // منح نفسه ما لم يمنحه أحد.
    test('ولا استثناء بريد ولا صلاحيات فردية', () {
      final doc = signupDoc();
      expect(doc['emailVerificationExempt'], isNot(true));
      expect((doc['permissionOverrides'] as Map?) ?? const {}, isEmpty);
    });

    // ولولا هذا لَكفى أن يُعاد الدور الموروث إلى `signUp` فيمرّ الاختبار
    // الأول بتغيير الطرفين معاً — وهو ما يُبطل معناه.
    test('والحاجز أدنى الأدوار لا دورٌ موروث', () {
      expect(roleRequiredByRules(), UserRole.employee.name);
      expect(roleRequiredByRules(), isNot(UserRole.projectOfficer.name));
    });
  });
}
