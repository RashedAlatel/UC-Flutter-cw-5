// بأيّ شرطٍ تُقرأ مستندات المشروع التابعة — والعضويّة هي المقياس.
//
// ــــ عطلان متتاليان في هذا الموضع ــــ
//
// **الأول**: الاشتراك كان يُصفّي لصاحب دور «مدير مشروع» بالحقل المفرد
// الموروث `managerUid` — أي أوّل المديرين وحده. فصُحّح إلى القائمة.
//
// **والثاني — وهو الذي بقي**: ذلك التصحيح لا يمسّ أحداً. فدور «مدير
// مشروع» **موروثٌ لا يُمنح**: `GRANTABLE_ROLES` في الخادم هي «مستخدم
// تنفيذي، مدير إدارة، موظف» لا غير. ومديرو المشاريع أدوارُهم «موظف»،
// فيُصفّى لهم **بالإدارة وحدها** — ومن كان عضواً في مشروعٍ خارج إدارته،
// أو لم تُختم إدارتُه في بطاقته بعد، لا يصله تحديثٌ واحد.
//
// فصارت **العضوية بُعداً للقراءة** كما هي في المشاريع منذ زمن. وهذا ما
// يُقاس هنا؛ وأثرُه على القواعد مُقاسٌ على المحاكي في
// `test_rules/member_read.rules.test.mjs`.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/child_scope.dart';

/// هل في التدفّقات ما يقرأ بعضويّة هذا المعرِّف؟
bool _hasMembership(List<ChildFilter> filters, String uid) =>
    filters.contains(ChildFilter.arrayContains('managerUids', uid)) &&
    filters.contains(ChildFilter.arrayContains('executorUids', uid));

void main() {
  group('العضوية تُقرأ لكل مستخدم — لا لدورٍ بعينه', () {
    // العطل بعينه: موظفٌ يقود مشروعاً. وهو **الحال الشائع** بعد أن فُصلت
    // قيادة المشروع عن الدور الأساسي.
    test('الموظف العادي يُقرأ له بعضويّته', () {
      final filters = childScopeFilters(manager: false, uid: 'u-1', scopedDept: 'd-1');

      expect(_hasMembership(filters, 'u-1'), isTrue,
          reason: 'بغير العضوية لا يصل عضوَ المشروع تحديثٌ إن اختلفت إدارته');
    });

    test('ومدير الإدارة كذلك — عضويّته لا تسقط بنطاقه', () {
      final filters =
          childScopeFilters(manager: true, uid: 'u-1', departmentIds: ['d-1']);

      expect(_hasMembership(filters, 'u-1'), isTrue);
    });

    // نطاق الإدارة **يبقى**: لم يُستبدل بالعضوية بل أُضيفت إليه.
    test('ونطاق الإدارة يبقى مضافاً لا بديلاً', () {
      final filters = childScopeFilters(manager: false, uid: 'u-1', scopedDept: 'd-1');

      expect(filters, contains(const ChildFilter.equals('departmentId', 'd-1')));
    });

    test('ومدير الإدارة يقرأ إداراته كلَّها', () {
      final filters =
          childScopeFilters(manager: true, uid: 'u-1', departmentIds: ['d-1', 'd-2']);

      expect(filters, contains(const ChildFilter.whereIn('departmentId', ['d-1', 'd-2'])));
    });

    // المستندات التي كُتبت قبل أن تُنسخ القائمة لا تحمل إلا المفرد.
    test('والمفرد الموروث يبقى تدفّقاً للمستندات القديمة', () {
      final filters = childScopeFilters(manager: false, uid: 'u-1', scopedDept: 'd-1');

      expect(filters, contains(const ChildFilter.equals('managerUid', 'u-1')));
    });
  });

  group('ومن لم تُختم إدارتُه بعد', () {
    // ــ الخلط الذي كان يُفرغ الشاشة بلا سبب ظاهر ــ
    //
    // كان «بلا إدارة» و«يرى كل الإدارات» يُنتجان الشيء نفسه: تصفيةً فارغة،
    // أي طلبَ المجموعة كاملةً — فتردّها القواعد بالكامل. وختمُ البطاقة لا
    // يتزامن مع تعديل السجل، فالحال يقع فعلاً.
    test('يُقرأ له بعضويّته ولا تُفتح المجموعة كاملةً', () {
      final filters = childScopeFilters(manager: false, uid: 'u-1');

      expect(filters, isNotEmpty, reason: 'التصفية الفارغة تعني المجموعة كلَّها');
      expect(_hasMembership(filters, 'u-1'), isTrue);
      expect(filters, isNot(contains(const ChildFilter.equals('departmentId', 'd-1'))));
    });

    test('وبلا عضويةٍ ولا إدارة لا يُقرأ شيء', () {
      final filters = childScopeFilters(manager: false);

      expect(filters, [const ChildFilter.equals('departmentId', noDepartmentSentinel)]);
    });
  });

  group('ومن يرى كل الإدارات', () {
    // له وحده تُفتح المجموعة كاملةً — بمعاملٍ صريح لا باستنتاج.
    test('يُقرأ بلا تصفية', () {
      expect(childScopeFilters(manager: false, viewsAll: true, uid: 'u-admin'), isEmpty);
    });

    test('ولو كان مدير إدارةٍ يرى الكل', () {
      expect(
        childScopeFilters(manager: true, viewsAll: true, uid: 'u-1', departmentIds: ['d-1']),
        isEmpty,
      );
    });
  });

  group('وحدود Firestore محفوظة', () {
    // تجاوز الثلاثين خطأٌ وقت التشغيل لا وقت التحليل — فلا يظهر إلا لمن
    // يدير أكثر من ثلاثين إدارة.
    test('قائمة الإدارات تُقتطع عند ثلاثين', () {
      final many = List.generate(40, (i) => 'd-$i');
      final filters = childScopeFilters(manager: true, uid: 'u-1', departmentIds: many);
      final dept = filters.firstWhere((f) => f.op == ChildFilterOp.whereIn);

      expect((dept.value as List).length, 30);
    });
  });
}
