// دورُ «مراقب» في العميل — **مرآةُ القاعدة، والحَكَمُ هي**.
//
// ــــ ولماذا تُقاس المرآةُ أصلاً والخادمُ يرفض؟ ــــ
//
// لأنّ الخادمَ يرفض **بعد** أن يضغط المستخدمُ الزرّ. فالمرآةُ المنحرفة لا
// تفتح باباً — بل تَعِدُ بما يُرفض: يرى المراقبُ «حفظ» و«حذف» و«تعديل»،
// فيكتب ثمّ تُردّ كتابتُه برسالةٍ لا يفهمها. وهو صنفُ العطل الذي تكرّر في
// هذه المنصّة حتى صار له حارسٌ (`permission_parity`).
//
// وما يُقاس هنا شيئان:
//
// (١) **أنّ المراقبَ لا يكتب** — في المواضع التسعة التي يُمنع فيها التنفيذيّ.
//     ونسخُ `!isExecutive` إلى تسعةِ مواضعَ نسخٌ يُنسى عند العاشر، فالقرارُ
//     `isWatcher` واحدةً كما في القواعد حرفاً.
//
// (٢) **وأنّ التنفيذيَّ لم يتغيّر** — فتعميمُ شرطٍ قائمٍ على دورٍ جديدٍ
//     يسهل أن يوسّعه أو يضيّقه على القديم بلا قصد.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';

const _dept = 'd-1';

AppUser _user(UserRole role, {String id = 'u-1', String? dept = _dept}) => AppUser(
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

Project _project() => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      // والمراقبُ **عضوٌ في المشروع** عمداً: العضويّةُ هي الطريقُ الذي يفتح
      // الكتابةَ بلا صلاحية، وهي التي نُسيت للتنفيذيّ في أربعة مواضع.
      managerUids: const ['u-1'],
    );

WorkItem _work() => WorkItem(
      id: 'w1',
      departmentId: _dept,
      title: 'عمل',
      description: '',
      assigneeUid: 'u-1',
      assigneeName: 'مستخدم',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      dueDate: DateTime(2026, 6, 1),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _storeFor(UserRole role) => AppStore()..currentUser = _user(role);

void main() {
  group('المراقبُ لا يكتب شيئاً', () {
    late AppStore store;
    setUp(() => store = _storeFor(UserRole.monitor));

    test('ولا يملك مشروعاً هو مديرُه في السجلّ', () {
      expect(store.ownsProject(_project()), isFalse);
    });

    test('ولا يعدّل مشروعاً', () {
      expect(store.canEditProject(_project()), isFalse);
      expect(store.canEditProjectDetails(_project()), isFalse);
    });

    test('ولا يعدّل عملاً', () {
      expect(store.canEditWorkDetails(_work()), isFalse);
    });

    test('ولا يحذف مشروعاً ولا عملاً', () {
      expect(store.canSoftDeleteProject(_project()), isFalse);
      expect(store.canSoftDeleteWork(_work()), isFalse);
    });

    test('ولا يضع خططاً أسبوعية', () {
      expect(store.canWriteWeeklyPlans, isFalse);
    });
  });

  // ــ والضابط: التنفيذيُّ لم يتغيّر بتعميم الشرط ــ
  group('والتنفيذيُّ كما كان', () {
    late AppStore exec;
    setUp(() => exec = _storeFor(UserRole.executiveViewer));

    test('ممنوعٌ من الكتابة كما كان', () {
      expect(exec.canEditProject(_project()), isFalse);
      expect(exec.canSoftDeleteWork(_work()), isFalse);
      expect(exec.canWriteWeeklyPlans, isFalse);
    });
  });

  // ــ وضابطٌ ثانٍ: المنعُ عن **دورٍ** لا عن الجميع ــ
  //
  // ولولاه لَمرّ `return false` مطلقٌ في تلك المواضع فبدا أنّ الحراسةَ تعمل،
  // وإنما المحروسُ كلُّ أحد — وهو عطلٌ آخر لا حراسة.
  group('ومديرُ الإدارة يكتب', () {
    late AppStore mgr;
    setUp(() => mgr = _storeFor(UserRole.departmentManager));

    test('يعدّل مشروعَ إدارته ويحذفه', () {
      expect(mgr.canEditProject(_project()), isTrue);
      expect(mgr.canSoftDeleteProject(_project()), isTrue);
      expect(mgr.canWriteWeeklyPlans, isTrue);
    });
  });


  // ــــ ومن يتابعهم: قائمتُه هي نطاقُه ــــ
  //
  // وهذا قلبُ الدور لا تفصيلٌ فيه: شاشةُ «متابعة الأشخاص» تُبنى من
  // `trackablePeople`، وهي تردّ «الكلَّ» لمن يرى كلَّ الإدارات و«موظّفي
  // إداراتي» للمدير و**الفراغَ لمن سواهما**. فمراقبٌ بلا فرعٍ هنا يفتح
  // الشاشةَ فيجدها خاليةً — ودورُه كلُّه متابعةُ أشخاص.
  group('ومن يتابعهم المراقب', () {
    AppStore storeWithPeople(List<String> watched) {
      final me = AppUser(
        id: 'u-mon', name: 'مراقب', email: 'm@moj.gov.kw', phone: '',
        role: UserRole.monitor, departmentId: 'd-9', departmentIds: const ['d-9'],
        status: UserStatus.approved, createdAt: DateTime(2026, 1, 1),
        watchedUids: watched,
      );
      return AppStore()
        ..currentUser = me
        ..users = [
          me,
          _user(UserRole.employee, id: 'u-a'),
          _user(UserRole.employee, id: 'u-b'),
          _user(UserRole.systemAdmin, id: 'u-admin', dept: null),
        ];
    }

    test('يتابع من سُمّوا له لا غير', () {
      final store = storeWithPeople(['u-a']);
      expect(store.trackablePeople.map((u) => u.id), ['u-a']);
      expect(store.canTrackPeople, isTrue);
    });

    // ــ والضابط: من أُفرغت قائمتُه لا يتابع أحداً ــ
    //
    // ولولاه لَمرّ فرعٌ يردّ «كلَّ المعتمَدين» للمراقب فبدا أنّ الدورَ يعمل،
    // وإنما هو يرى الجميع.
    test('ومن أُفرغت قائمتُه لا يتابع أحداً — ولا يظهر له المدخل', () {
      final store = storeWithPeople(const []);
      expect(store.trackablePeople, isEmpty);
      expect(store.canTrackPeople, isFalse);
    });

    test('ولا يتابع من ليس في قائمته وإن كان معتمَداً', () {
      final store = storeWithPeople(['u-a']);
      expect(store.trackablePeople.map((u) => u.id), isNot(contains('u-b')));
    });
  });
  group('وصلاحياتُه المبدئية', () {
    final perms = RolePermissionsConfig.defaults();

    // ولا واحدةَ منها تكتب: مداخلُ عرضٍ وشكوى لا أكثر.
    test('يرى اللوحةَ وصفحةَ الإدارة ويرسل ملاحظةً ويفتح مركزَ القيادة', () {
      for (final key in ['dsh', 'dpg', 'sfb', 'vcc']) {
        final p = RolePermission.values.firstWhere((e) => e.key == key);
        expect(perms.has(UserRole.monitor, p), isTrue, reason: key);
      }
    });

    test('ولا يملك إدارةَ الأعمال ولا تنبيهَ المتأخرين ولا أيَّ مفتاحِ كتابة', () {
      for (final key in ['mw', 'bla', 'mr', 'agd', 'vad', 'mtd']) {
        final p = RolePermission.values.firstWhere((e) => e.key == key);
        expect(perms.has(UserRole.monitor, p), isFalse, reason: key);
      }
    });
  });

  group('وموضعُه في الأدوار', () {
    // لا يُختار عند التسجيل: المراقبةُ تُسنَد بقرارٍ وتُسمّى قائمتُها، ولا
    // يطلبها المرءُ لنفسه. و`GRANTABLE_ROLES` على الخادم ترفضه لو طُلب.
    test('ليس من أدوار التسجيل الذاتي', () {
      expect(UserRole.assignable, isNot(contains(UserRole.monitor)));
    });

    // ولا تُضبط صلاحياتُه من شاشة الأدوار: تعريفُه أنّه يرى ولا يكتب، وشاشةٌ
    // تمنحه «إدارة الأعمال» تجعله شيئاً آخر باسمه القديم.
    test('ولا تُضبط صلاحياتُه من شاشة صلاحيات الأدوار', () {
      expect(UserRole.configurable, isNot(contains(UserRole.monitor)));
    });

    test('وليس دوراً موروثاً، وله تسميةٌ عربية', () {
      expect(UserRole.monitor.isLegacy, isFalse);
      expect(UserRole.monitor.label, 'مراقب');
    });
  });
}
