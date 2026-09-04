// من يُراسَل في المشروع — ومن لا يُراسَل وإن حمل الاسم نفسه.
//
// ــــ الحال التي أوجدت هذا الملف ــــ
//
// صار التوقيف يحذف حساب الدخول، فصارت العودة تمرّ بتسجيلٍ جديد يُدمَج مع
// القديم. فبقي في `users` **مستندان بالاسم والبريد نفسيهما**: القديم
// الموقوف وعليه `mergedIntoUid`، والجديد المعتمَد. و`recipientsForProject`
// تُطابق المنفّذين **بالاسم** — فتُرجع التوأمين معاً، ويصل الشخصَ الواحد
// بريدان من رسالةٍ واحدة.
//
// وعطلٌ ثانٍ من جنس عطل الدمج نفسه: كانت الدالّة تُطابق `managerUid`
// المفرد الموروث — أي **أوّل المديرين وحده** — فلا يصل المديرَ الثاني
// فصاعداً إشعارٌ على مشروعٍ هو مسؤولٌ عنه.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/work_item.dart';

AppUser _user({
  required String id,
  required String name,
  UserStatus status = UserStatus.approved,
  String? mergedIntoUid,
}) =>
    AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: UserRole.employee,
      departmentId: 'd-1',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      mergedIntoUid: mergedIntoUid,
    );

Project _project({
  List<String> managerUids = const [],
  List<String> executorUids = const [],
  List<String> executorNames = const [],
}) =>
    Project(
      id: 'p1',
      departmentId: 'd-1',
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      managerUids: managerUids,
      executorUids: executorUids,
      executorNames: executorNames,
    );

void main() {
  group('AppUser.isContactable', () {
    test('المعتمَد يُراسَل', () {
      expect(_user(id: 'u1', name: 'أحمد').isContactable, isTrue);
    });

    test('والموقوف لا يُراسَل', () {
      expect(
        _user(id: 'u1', name: 'أحمد', status: UserStatus.suspended).isContactable,
        isFalse,
      );
    });

    test('والمعلَّق لا يُراسَل من قوائم المشروع', () {
      expect(
        _user(id: 'u1', name: 'أحمد', status: UserStatus.pending).isContactable,
        isFalse,
      );
    });

    // الشرط الثاني: حسابٌ معتمَدٌ في ظاهره لكنه ظلُّ حسابٍ انتقل صاحبُه.
    test('والمندمج لا يُراسَل ولو بقيت حالُه معتمَدة', () {
      expect(
        _user(id: 'u-old', name: 'أحمد', mergedIntoUid: 'u-new').isContactable,
        isFalse,
      );
    });
  });

  group('recipientsForProject', () {
    test('التوأم الموقوف المندمج لا يظهر مستلماً — فلا يصل الشخصَ بريدان', () {
      final store = AppStore()
        ..users = [
          _user(
            id: 'u-old',
            name: 'أحمد الفهد',
            status: UserStatus.suspended,
            mergedIntoUid: 'u-new',
          ),
          _user(id: 'u-new', name: 'أحمد الفهد'),
        ];

      // المطابقة بالاسم هي بابُ الازدواج: الاسم واحدٌ والمستندان اثنان.
      final got = store.recipientsForProject(_project(executorNames: ['أحمد الفهد']));

      expect(got.map((u) => u.id), ['u-new']);
    });

    test('والمديرُ الثاني يصله ما يصل الأول', () {
      final store = AppStore()
        ..users = [
          _user(id: 'm1', name: 'المدير الأول'),
          _user(id: 'm2', name: 'المدير الثاني'),
        ];

      final got = store.recipientsForProject(_project(managerUids: ['m1', 'm2']));

      expect(got.map((u) => u.id).toSet(), {'m1', 'm2'});
    });

    test('والمنفّذ يُطابَق بمعرِّفه كما يُطابَق باسمه', () {
      final store = AppStore()
        ..users = [
          _user(id: 'm1', name: 'المدير'),
          _user(id: 'e1', name: 'المنفّذ'),
        ];

      final got = store.recipientsForProject(
        _project(managerUids: ['m1'], executorUids: ['e1']),
      );

      expect(got.map((u) => u.id).toSet(), {'m1', 'e1'});
    });

    test('ومن لا صلة له بالمشروع لا يُراسَل', () {
      final store = AppStore()
        ..users = [
          _user(id: 'm1', name: 'المدير'),
          _user(id: 'x', name: 'غريب'),
        ];

      final got = store.recipientsForProject(_project(managerUids: ['m1']));

      expect(got.map((u) => u.id), ['m1']);
    });
  });

  group('recipientsForWork', () {
    test('المُسنَد إليه يُراسَل', () {
      final store = AppStore()..users = [_user(id: 'a1', name: 'مُنفِّذ')];
      final work = WorkItem(
        id: 'w1',
        departmentId: 'd-1',
        title: 'عمل',
        description: '',
        assigneeUid: 'a1',
        assigneeName: 'مُنفِّذ',
        priority: PriorityLevel.medium,
        status: TaskStatus.inProgress,
        progressPercent: 0,
        dueDate: DateTime(2026, 6, 1),
        createdByUid: 'u-admin',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(store.recipientsForWork(work).map((u) => u.id), ['a1']);
    });

    test('وحسابٌ مندمج أُسنِد إليه عملٌ قديم لا يُراسَل', () {
      final store = AppStore()
        ..users = [_user(id: 'a1', name: 'مُنفِّذ', mergedIntoUid: 'a2')];
      final work = WorkItem(
        id: 'w1',
        departmentId: 'd-1',
        title: 'عمل',
        description: '',
        assigneeUid: 'a1',
        assigneeName: 'مُنفِّذ',
        priority: PriorityLevel.medium,
        status: TaskStatus.inProgress,
        progressPercent: 0,
        dueDate: DateTime(2026, 6, 1),
        createdByUid: 'u-admin',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(store.recipientsForWork(work), isEmpty);
    });
  });
}
