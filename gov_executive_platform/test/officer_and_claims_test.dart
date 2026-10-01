// نطاق مدير المشروع، ومقارنة بطاقة الدخول بسجل المستخدم.
//
// حارس عطلين وقعا فعلاً:
// - مدير مشروع لم يرَ مشاريع إدارته فلم يجد ما ينضمّ إليه.
// - ومقارنة البطاقة كانت تقارن الجمع بالمفرد، فلا تتّفق أبداً لغير مدير
//   الإدارة، ولا تفحص المفرد الذي تحتكم إليه قواعد الخادم أصلاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

AppUser _user(
  UserRole role, {
  String id = 'u1',
  String? dept = 'd1',
  List<String> depts = const [],
}) =>
    AppUser(
      id: id,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(
  String id,
  String dept, {
  List<String> managers = const [],
  List<String> executors = const [],
}) =>
    Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      managerUids: managers,
      executorUids: executors,
    );

void main() {
  group('نطاق المشاريع قاعدة واحدة لكل الأدوار', () {
    // العطل بعينه: مدير المشروع كان يرى ما هو عضو فيه وحده.
    test('مدير المشروع يرى مشاريع إدارته ليضيف نفسه', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer)
        ..projects = [
          _project('mine', 'd1', managers: ['u1']),
          _project('dept', 'd1'),
          _project('other', 'd9'),
        ];
      expect(store.visibleProjects.map((p) => p.id).toSet(), {'mine', 'dept'});
    });

    test('والموظف كذلك بلا أي صلاحية', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = const RolePermissionsConfig({'employee': <String>{}})
        ..projects = [_project('dept', 'd1'), _project('other', 'd9')];
      expect(store.hasPermission(RolePermission.selfAssignProjects), isFalse);
      expect(store.visibleProjects.map((p) => p.id), ['dept']);
    });

    // العضوية تبقى في الشرط: قد يُسنَد المستخدم إلى مشروع خارج إدارته.
    test('ومشروعٌ خارج إدارته أُسنِد إليه يبقى ظاهراً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer)
        ..projects = [_project('far', 'd9', executors: ['u1'])];
      expect(store.visibleProjects.map((p) => p.id), ['far']);
    });

    test('ومدير الإدارة يرى إداراته كلها', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.departmentManager, dept: 'd1', depts: ['d1', 'd2'])
        ..projects = [_project('a', 'd1'), _project('b', 'd2'), _project('c', 'd9')];
      expect(store.visibleProjects.map((p) => p.id).toSet(), {'a', 'b'});
    });

    test('وبلا إدارة ولا عضوية لا يرى شيئاً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee, dept: null)
        ..projects = [_project('a', 'd1')];
      expect(store.visibleProjects, isEmpty);
      expect(store.myDepartmentIds, isEmpty);
    });
  });

  group('الانضمام يبقى بصلاحية', () {
    test('بلا الصلاحية لا ينضمّ ولو رأى المشروع', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer)
        ..rolePermissions = const RolePermissionsConfig({'projectOfficer': <String>{}})
        ..projects = [_project('dept', 'd1')];
      expect(store.visibleProjects.length, 1, reason: 'الاطّلاع حق');
      expect(store.canSelfAssign(_project('dept', 'd1')), isFalse, reason: 'والانضمام صلاحية');
    });

    test('وبها ينضمّ داخل إدارته لا خارجها', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer)
        ..rolePermissions = const RolePermissionsConfig({
          'projectOfficer': {'sap'},
        });
      expect(store.canSelfAssign(_project('a', 'd1')), isTrue);
      expect(store.canSelfAssign(_project('b', 'd9')), isFalse);
    });
  });
}
