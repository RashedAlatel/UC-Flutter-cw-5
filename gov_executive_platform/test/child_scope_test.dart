// بأيّ شرطٍ تُقرأ مستندات المشروع التابعة — والمديرُ الثاني هو المقياس.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// اشتراك `dailyUpdates` (وكذلك `tasks` و`risks` و`blockers`) كان يُصفّي
// لمدير المشروع بـ`where('managerUid', ==, uid)` — وهو **الحقل المفرد
// الموروث**، أي أوّلُ المديرين وحده. فمن كان المديرَ الثاني فصاعداً لا
// يصله تحديثٌ واحد على مشروعه، **ولو كان هو كاتبَه بيده**.
//
// وهذا ما اشتكى منه: «يجب أن يظهر له التحديث الذي قام بإضافته».
//
// وما يُقاس هنا هو **وصفُ الاستعلام** لا نتيجتُه: الاستعلام نفسه لا يعمل
// إلا بـFirestore حيّ. فأُخرج القرار إلى دالّةٍ نقيّة تُعيد قائمة شروط،
// وهذه الاختبارات تقرؤها. وهي أضعف من قياسٍ على قاعدةٍ حقيقية ويُقال ذلك
// صراحةً — لكنها تعضّ: أيُّ رجوعٍ إلى المفرد وحده يُسقطها.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/child_scope.dart';

void main() {
  group('مدير المشروع', () {
    test('يُقرأ بالقائمة `managerUids` — لا بالمفرد وحده', () {
      final filters = childScopeFilters(officer: true, manager: false, uid: 'u-2');

      expect(
        filters,
        contains(const ChildFilter.arrayContains('managerUids', 'u-2')),
        reason: 'بغير هذا الشرط لا يصل المديرَ الثاني فصاعداً شيء',
      );
    });

    // والمفرد يبقى تدفّقاً ثانياً — لا بديلاً عن الأول ولا مُلغىً: ما كُتب
    // قبل أن تُنسخ القائمة على المستندات لا يحمل إلا المفرد، فإسقاطه يمحو
    // تاريخ المشروع كلَّه عن أوّل مديريه.
    test('ويبقى المفرد الموروث تدفّقاً ثانياً للمستندات القديمة', () {
      final filters = childScopeFilters(officer: true, manager: false, uid: 'u-2');

      expect(filters, hasLength(2));
      expect(filters, contains(const ChildFilter.equals('managerUid', 'u-2')));
    });

    // بلا معرِّف حساب لا تُفتح المجموعة كاملةً: القواعد **ترفض ولا تُصفّي**،
    // فطلبٌ بلا نطاق يُردّ كلُّه فتظهر لافتةٌ حمراء بدل قائمةٍ فارغة.
    test('وبلا معرِّف حساب لا يُقرأ شيء — ولا تُفتح المجموعة كاملةً', () {
      final filters = childScopeFilters(officer: true, manager: false, uid: null);

      expect(filters, isNotEmpty);
      expect(filters, contains(const ChildFilter.equals('departmentId', noDepartmentSentinel)));
    });
  });

  group('مدير الإدارة', () {
    test('يُقرأ بإداراته كلِّها لا بواحدة', () {
      final filters = childScopeFilters(
        officer: false,
        manager: true,
        uid: 'u-1',
        departmentIds: ['d-1', 'd-2'],
      );

      expect(filters, [
        const ChildFilter.whereIn('departmentId', ['d-1', 'd-2'])
      ]);
    });

    // Firestore يحدّ `whereIn` بثلاثين قيمة، وتجاوزُه خطأٌ وقت التشغيل لا
    // وقت التحليل — فلا يظهر إلا لمن يدير أكثر من ثلاثين إدارة.
    test('وتُقتطع القائمة عند ثلاثين — حدُّ Firestore', () {
      final many = List.generate(40, (i) => 'd-$i');
      final filters =
          childScopeFilters(officer: false, manager: true, uid: 'u-1', departmentIds: many);

      expect((filters.single.value as List).length, 30);
    });

    test('وبلا إدارةٍ واحدة لا يُقرأ شيء', () {
      final filters = childScopeFilters(officer: false, manager: true, uid: 'u-1');

      expect(filters, [const ChildFilter.equals('departmentId', noDepartmentSentinel)]);
    });
  });

  group('وسائر المستخدمين', () {
    test('الموظف يُقرأ بإدارته', () {
      final filters =
          childScopeFilters(officer: false, manager: false, uid: 'u-1', scopedDept: 'd-9');

      expect(filters, [const ChildFilter.equals('departmentId', 'd-9')]);
    });

    // مسؤول النظام والمستخدم التنفيذي: `scopedDept` فارغ عندهما، والقائمة
    // الفارغة تعني «المجموعة كاملةً بلا تصفية» — وهو المقصود لهما وحدهما.
    test('ومن يرى كل الإدارات يُقرأ بلا تصفية', () {
      final filters = childScopeFilters(officer: false, manager: false, uid: 'u-admin');

      expect(filters, isEmpty);
    });
  });
}
