// من يكتب التحديث اليومي — والشاشةُ لا تَعِد بما يردّه الخادم.
//
// ــــ الحادثةُ التي أوجبت هذا الملف ــــ
//
// موظّفٌ في إدارة المشروع ضغط «إضافة تحديث يومي»، فكتب عملَ يومه، ثم ردّه
// الخادم: `permission-denied`. والشاشةُ هي التي كذبت لا القاعدة:
//
//   • `canEditProject` كانت تُرجع `true` لكلّ موظفٍ إدارتُه إدارةَ المشروع.
//   • وقاعدةُ `dailyUpdates/create` لا تقبل إلا مسؤولَ النظام، أو مديرَ
//     الإدارة، أو **عضواً في المشروع** (مديراً كان أو منفّذاً).
//
// ومشاريعُ الوزارة المستوردة بلا مديرٍ ولا منفّذٍ مسجّل، فلم يكن أحدٌ من
// الموظفين عضواً في شيء — فكان كلُّ ضغطةٍ منهم تُردّ.
//
// ــــ وما يُقاس هنا ــــ
//
// **الدائرةُ كاملةً**، لا الحالةُ التي وقعت وحدها: سبعةُ أدوارٍ يُقاس كلٌّ
// منها، لأن مرآةً تُصلَح في طرفٍ وتُترك في طرفٍ آخر تعود بعد شهر.
//
// والحَكَمُ هي `firestore.rules` — راجع `test_rules/daily_update.rules.test.mjs`
// وفيه «وموظف في الإدارة ليس عضواً — يُرفض». وهذا الملفّ مرآتُها في الواجهة.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

const _dept = 'dept_systems';
const _other = 'dept_support';

AppUser _user(UserRole role, {required String id, String? dept = _dept}) => AppUser(
      id: id,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

/// مشروعٌ **بلا مديرٍ ولا منفّذٍ مسجّل** — وهو حالُ مشاريع الوزارة المستوردة،
/// والحالُ التي وقع فيها العطل.
Project _project({
  List<String> managers = const [],
  List<String> executors = const [],
  String dept = _dept,
}) =>
    Project(
      id: 'p-sna',
      departmentId: dept,
      name: 'تجديد تراخيص تحليل امان الشبكة SNA',
      description: '',
      startDate: DateTime(2026, 1, 14),
      dueDate: DateTime(2026, 3, 15),
      status: ProjectStatus.delayed,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      managerUids: managers,
      executorUids: executors,
    );

AppStore _store(UserRole role, {String id = 'u-1', String? dept = _dept}) =>
    AppStore()..currentUser = _user(role, id: id, dept: dept);

void main() {
  group('من يكتب التحديث اليومي', () {
    test('مسؤولُ النظام — على أي مشروع', () {
      expect(
        _store(UserRole.systemAdmin, dept: null).canSubmitDailyUpdate(_project()),
        isTrue,
      );
    });

    test('ومديرُ إدارة المشروع', () {
      expect(
        _store(UserRole.departmentManager).canSubmitDailyUpdate(_project()),
        isTrue,
      );
    });

    test('ومديرُ المشروع نفسُه — ولو من إدارةٍ أخرى', () {
      expect(
        _store(UserRole.employee, id: 'u-m', dept: _other)
            .canSubmitDailyUpdate(_project(managers: ['u-m'])),
        isTrue,
      );
    });

    test('والمنفّذُ المسجَّل عليه', () {
      expect(
        _store(UserRole.employee, id: 'u-x')
            .canSubmitDailyUpdate(_project(executors: ['u-x'])),
        isTrue,
      );
    });
  });

  group('ومن لا يكتب', () {
    // ــ هذه هي الحالةُ التي وقعت ــ
    //
    // موظّفٌ في إدارة المشروع، والمشروعُ بلا أعضاء. كانت الشاشةُ تقول «نعم»
    // والخادمُ يقول «لا»، فيضيع عملُ يومه بين الاثنين.
    test('موظّفٌ في الإدارة ليس عضواً في المشروع', () {
      expect(
        _store(UserRole.employee, id: 'u-2').canSubmitDailyUpdate(_project()),
        isFalse,
        reason: 'قاعدةُ dailyUpdates/create تردّه — فلا تَعِده الشاشة',
      );
    });

    test('ولا موظّفٌ في إدارةٍ أخرى', () {
      expect(
        _store(UserRole.employee, id: 'u-3', dept: _other)
            .canSubmitDailyUpdate(_project()),
        isFalse,
      );
    });

    test('ولا مديرُ إدارةٍ أخرى', () {
      expect(
        _store(UserRole.departmentManager, dept: _other)
            .canSubmitDailyUpdate(_project()),
        isFalse,
      );
    });

    // التنفيذي يقرأ كلَّ الإدارات ولا يغيّر شيئاً — قاعدةٌ قائمة في المنصة.
    test('ولا المستخدمُ التنفيذي وإن رأى كلَّ شيء', () {
      expect(
        _store(UserRole.executiveViewer, dept: null).canSubmitDailyUpdate(_project()),
        isFalse,
      );
    });

    // ــ وهذا هو ما يقيس فرعَ التنفيذي فعلاً ــ
    //
    // الاختبارُ السابق لا يعضّ: تنفيذيٌّ بلا إدارةٍ ولا عضوية يسقط في
    // `return false` الأخيرة على أي حال، فحذفُ فرعِه لا يُغيّر جوابه —
    // وقد نجت عليه طفرةٌ فعلاً. والحالُ التي تقيسه: **تنفيذيٌّ مسجَّلٌ
    // عضواً**، نُقل إلى دورٍ يطّلع ولا يكتب واسمُه باقٍ على مشاريع قديمة.
    //
    // وهي قاعدةٌ قائمة في المنصّة: قاعدةُ حذف التحديث اليومي تحمل
    // `!isExecutive()` صراحةً للسبب نفسه.
    test('ولا التنفيذيُّ وإن بقي اسمُه مسجَّلاً على مشروعٍ قديم', () {
      expect(
        _store(UserRole.executiveViewer, id: 'u-v', dept: null)
            .canSubmitDailyUpdate(_project(executors: ['u-v'])),
        isFalse,
        reason: 'يطّلع ولا يكتب — والعضويةُ القديمة لا تنقض ذلك',
      );
    });

    // ــ والدورُ لا يُغني عن العضوية ــ
    //
    // «مدير مشروع» دورٌ على الشخص، والعضويةُ صفةٌ على المشروع. وقد كانت
    // القاعدةُ تخلط بينهما فيفتح صاحبُ الدور كلَّ مشاريع المنصة.
    test('ولا صاحبُ دور «مدير مشروع» في مشروعٍ ليس عضواً فيه', () {
      expect(
        _store(UserRole.projectOfficer, id: 'u-4').canSubmitDailyUpdate(_project()),
        isFalse,
      );
    });

    test('ولا مستخدمَ بلا حساب', () {
      expect(AppStore().canSubmitDailyUpdate(_project()), isFalse);
    });
  });

  // ــــ وما يُقال لمن لا يستطيع ــــ
  //
  // إخفاءُ الزرّ وحده يُبدّل عطلاً بعطل: كان الموظفُ يضغط ويُردّ، فيصير لا
  // يجد ما يضغط **ولا يعرف لماذا** — وذلك يُظنّ عطلاً في المنصّة.
  group('والسببُ يُقال، ومعه المخرج', () {
    test('ومن يكتب لا يُقال له شيء', () {
      expect(
        _store(UserRole.departmentManager).dailyUpdateBlockReason(_project()),
        isNull,
      );
    });

    // ــ والمخرجُ قائمٌ في المنصّة: بطاقةُ «فريق المشروع» في الصفحة نفسِها ــ
    test('وصاحبُ «الانضمام لمشاريع الإدارة» يُدلّ على بطاقة الفريق', () {
      final store = _store(UserRole.employee, id: 'u-2')
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'sap'},
        });
      final why = store.dailyUpdateBlockReason(_project())!;
      expect(why, contains('فريق المشروع'));
      expect(why, contains('منفّذاً'));
    });

    test('ومن لا يملكها يُدلّ على مدير إدارته', () {
      final why = _store(UserRole.employee, id: 'u-2')
          .dailyUpdateBlockReason(_project())!;
      expect(why, contains('مدير إدارتك'));
      expect(why, isNot(contains('فريق المشروع')), reason: 'بابٌ لا يُفتح له');
    });

    // ــ ولا يُدلّ على بابٍ لا يُفتح ــ
    //
    // التنفيذي يطّلع ولا يكتب بقاعدةٍ قائمة، لا بنقصٍ يُصلَح بانضمام.
    test('والتنفيذيُّ يُقال له إن ذلك صفتُه لا نقصٌ فيه', () {
      final why = _store(UserRole.executiveViewer, dept: null)
          .dailyUpdateBlockReason(_project())!;
      expect(why, contains('يطّلع'));
      expect(why, isNot(contains('اطلب')));
    });

    test('ولا يُقال شيءٌ قبل تسجيل الدخول', () {
      expect(AppStore().dailyUpdateBlockReason(_project()), isNull);
    });
  });

  // ــ والدائرتان واحدة ــ
  //
  // `canSubmitDailyUpdate` اسمٌ ثانٍ لـ`canEditProject`، ولو افترقتا لَعاد
  // العطلُ من الباب الذي أُغلق.
  test('وكتابةُ التحديث هي تعديلُ المشروع — دائرةٌ واحدة', () {
    for (final store in [
      _store(UserRole.systemAdmin, dept: null),
      _store(UserRole.departmentManager),
      _store(UserRole.employee, id: 'u-2'),
      _store(UserRole.executiveViewer, dept: null),
    ]) {
      final p = _project();
      expect(store.canSubmitDailyUpdate(p), store.canEditProject(p));
    }
  });
}
