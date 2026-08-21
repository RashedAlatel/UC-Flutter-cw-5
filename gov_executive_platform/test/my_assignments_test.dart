// «المُسنَد إليّ»: ما يخصّ المستخدم أينما كان — ولو خارج إدارته.
//
// بقية الشاشات مبنية على **الإدارة**. فمن أُسنِد إليه مشروع أو عمل في إدارة
// أخرى كان يبحث عنه بين ما ليس له، أو لا يجده. وأسوأ حالة كانت مدير الإدارة:
// تصفية الأعمال عنده كانت **إدارته وحدها**، فعملٌ أُسنِد إليه شخصياً في إدارة
// أخرى يختفي عنه تماماً — يصله إشعار بعملٍ لا يجده في المنصة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/my_assignments_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _mine = 'd-mine';
const _other = 'd-other';
const _me = 'u-me';

AppUser _user(UserRole role, {List<String> depts = const [_mine]}) => AppUser(
      id: _me,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _mine,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(
  String id,
  String dept, {
  List<String> managers = const [],
  List<String> executors = const [],
  DateTime? due,
}) =>
    Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: due ?? DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      managerUids: managers,
      executorUids: executors,
    );

WorkItem _work(String id, String dept, {String assignee = '', bool done = false, DateTime? due}) => WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: dept,
      assigneeUid: assignee,
      assigneeName: 'مستخدم',
      status: done ? TaskStatus.done : TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: done ? 100 : 30,
      dueDate: due ?? DateTime(2026, 6, 30),
      completedDate: done ? DateTime(2026, 6, 1) : null,
      isRecurring: false,
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('العمل المُسنَد خارج الإدارة', () {
    // العطل بعينه: تصفية أعمال مدير الإدارة كانت بإدارته وحدها.
    test('مدير الإدارة يرى عملاً أُسنِد إليه في إدارة أخرى', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.departmentManager)
        ..works = [
          _work('w-far', _other, assignee: _me),
          _work('w-dept', _mine, assignee: 'someone'),
        ];
      expect(store.visibleWorks.map((w) => w.id).toSet(), {'w-far', 'w-dept'});
      expect(store.myWorks.map((w) => w.id), ['w-far']);
    });

    test('والموظف كذلك يرى المُسنَد إليه خارج إدارته', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = const RolePermissionsConfig({'employee': <String>{}})
        ..works = [_work('w-far', _other, assignee: _me), _work('w-dept', _mine, assignee: 'someone')];
      expect(store.visibleWorks.map((w) => w.id), ['w-far'],
          reason: 'بلا صلاحية إدارة الأعمال لا يرى أعمال زملائه، ويرى ما أُسنِد إليه');
    });

    test('ولا يتكرر العمل حين يكون داخل إدارته ومُسنَداً إليه معاً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.departmentManager)
        ..works = [_work('w1', _mine, assignee: _me)];
      expect(store.visibleWorks.length, 1);
    });
  });

  group('المشروع المُسنَد خارج الإدارة', () {
    test('المنفّذ يرى مشروعه ولو كان في إدارة أخرى', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..projects = [_project('far', _other, executors: [_me]), _project('none', _other)];
      expect(store.visibleProjects.map((p) => p.id), ['far']);
      expect(store.myProjects.map((p) => p.id), ['far']);
    });

    test('ومدير المشروع كذلك', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer)
        ..projects = [_project('far', _other, managers: [_me])];
      expect(store.myProjects.map((p) => p.id), ['far']);
    });
  });

  group('ترتيب ما هو مُسنَد', () {
    test('المشاريع بالأقرب استحقاقاً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..projects = [
          _project('late', _mine, executors: [_me], due: DateTime(2026, 12, 1)),
          _project('soon', _mine, executors: [_me], due: DateTime(2026, 3, 1)),
        ];
      expect(store.myProjects.map((p) => p.id), ['soon', 'late']);
    });

    // المنجَز لا يتصدّر قائمة ما يحتاج عملاً.
    test('والأعمال: غير المنجَز أولاً ثم الأقرب موعداً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..works = [
          _work('done', _mine, assignee: _me, done: true, due: DateTime(2026, 1, 1)),
          _work('later', _mine, assignee: _me, due: DateTime(2026, 9, 1)),
          _work('soon', _mine, assignee: _me, due: DateTime(2026, 2, 1)),
        ];
      expect(store.myWorks.map((w) => w.id), ['soon', 'later', 'done']);
    });
  });

  group('الشاشة', () {
    Future<void> pump(WidgetTester tester, AppStore store) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: MyAssignmentsScreen()),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('تعرض المشروع والعمل وتسمّي الدور', (tester) async {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..departments = [
          const Department(
              id: _other, name: 'إدارة أخرى', headName: 'ر', colorValue: 0xFF1B5E4A, iconKey: 'settings'),
        ]
        ..projects = [_project('far', _other, managers: [_me])]
        ..works = [_work('w1', _other, assignee: _me)];
      await pump(tester, store);

      expect(find.text('مشروع far'), findsOneWidget);
      expect(find.text('عمل w1'), findsOneWidget);
      expect(find.textContaining('دورك: مدير المشروع'), findsOneWidget);
      // إدارة المشروع تُذكر حين تخالف إدارة المستخدم — وهي علّة الشاشة.
      expect(find.textContaining('إدارة المشروع: إدارة أخرى'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('وتشرح الفراغ بدل صفحة خالية', (tester) async {
      await pump(tester, AppStore()..currentUser = _user(UserRole.employee));
      expect(find.text('لم تُسنَد إليك مشاريع بعد'), findsOneWidget);
      expect(find.text('لم يُسنَد إليك عمل بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
