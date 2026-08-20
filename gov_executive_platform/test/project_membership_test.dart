// عضوية المشروع: القائمتان، والحقل المفرد الموروث، ونطاق الرؤية.
//
// أخطر ما في هذه الجولة أن مستندات المنصة القائمة كُتبت بحقل `managerUid`
// مفرد. لو لم تُشتقّ منه القائمة عند القراءة لفقد كل مديري المشاريع الحاليين
// مشاريعهم في لحظة النشر — وهو ما تحرسه الاختبارات الأولى هنا.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_role.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

Project _project(String id, String dept, {List<String> managers = const [], List<String> executors = const []}) =>
    Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      managerUids: managers,
      executorUids: executors,
    );

AppUser _user(UserRole role, {String? dept, String? customRoleId}) => AppUser(
      id: 'me',
      name: 'موظف',
      email: 'me@moj.gov.kw',
      phone: '',
      role: role,
      customRoleId: customRoleId,
      departmentId: dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('الحقل المفرد الموروث', () {
    test('القائمة تُشتقّ منه حين تغيب — فلا يفقد مدير قائم مشروعه', () {
      final p = Project.fromMapForTest('p1', {
        'departmentId': 'd1',
        'managerUid': 'u-old',
      });
      expect(p.managerUids, ['u-old']);
      expect(p.managerUid, 'u-old');
      expect(p.isManager('u-old'), isTrue);
    });

    test('القائمة تسبق المفرد حين توجد', () {
      final p = Project.fromMapForTest('p1', {
        'departmentId': 'd1',
        'managerUid': 'u-a',
        'managerUids': ['u-a', 'u-b'],
      });
      expect(p.managerUids, ['u-a', 'u-b']);
      expect(p.managerUid, 'u-a', reason: 'المفرد يعكس أول عنصر');
    });

    test('الكتابة تُبقي المفرد متسقاً مع القائمة — وهو شرط قاعدة الأمان', () {
      final map = _project('p1', 'd1', managers: ['u-a', 'u-b']).toMap();
      expect(map['managerUids'], ['u-a', 'u-b']);
      expect(map['managerUid'], 'u-a');

      final empty = _project('p2', 'd1').toMap();
      expect(empty['managerUids'], isEmpty);
      expect(empty['managerUid'], isNull, reason: 'مشروع بلا مديرين لا يحمل مفرداً معلّقاً');
    });
  });

  group('نطاق الرؤية', () {
    // كان مدير المشروع يُقيَّد بعضوياته وحدها، فلا يرى مشاريع إدارته ولا
    // يجد ما ينضمّ إليه — وهو ما اشتُكي منه. الاطّلاع داخل الإدارة صار
    // حقاً أساسياً لكل الأدوار، والانضمام وحده هو الذي بقي بصلاحية.
    test('مدير المشروع يرى مشاريع إدارته لا عضوياته وحدها', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer, dept: 'd1')
        ..projects = [
          _project('mine', 'd1', managers: ['me']),
          _project('mine-exec', 'd1', executors: ['me']),
          _project('other', 'd1'),
          _project('elsewhere', 'd9'),
        ];
      expect(store.visibleProjects.map((p) => p.id).toSet(), {'mine', 'mine-exec', 'other'});
    });

    // جوهر المطلب: لا يستطيع الموظف اختيار مشروع ينضمّ إليه إن لم يرَ إلا ما
    // هو عضو فيه أصلاً.
    test('صاحب الصلاحية يرى إدارته كاملةً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.custom, dept: 'd1', customRoleId: 'r1')
        ..customRoles = [const CustomRole(id: 'r1', name: 'منسّق', selfAssignProjects: true)]
        ..projects = [
          _project('a', 'd1'),
          _project('b', 'd1'),
          _project('elsewhere', 'd9'),
        ];
      expect(store.hasPermission(RolePermission.selfAssignProjects), isTrue);
      expect(store.visibleProjects.map((p) => p.id).toSet(), {'a', 'b'});
    });

    test('ويرى مشروعاً هو عضو فيه ولو خرج عن إدارته', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.custom, dept: 'd1', customRoleId: 'r1')
        ..customRoles = [const CustomRole(id: 'r1', name: 'منسّق', selfAssignProjects: true)]
        ..projects = [_project('moved', 'd9', executors: ['me'])];
      expect(store.visibleProjects.map((p) => p.id), ['moved']);
    });
  });

  group('حدود الانضمام في الواجهة', () {
    test('بلا الصلاحية لا انضمام', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.projectOfficer, dept: 'd1');
      expect(store.canSelfAssign(_project('p', 'd1')), isFalse);
    });

    test('بالصلاحية داخل إدارته فقط', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.custom, dept: 'd1', customRoleId: 'r1')
        ..customRoles = [const CustomRole(id: 'r1', name: 'منسّق', selfAssignProjects: true)];
      expect(store.canSelfAssign(_project('p', 'd1')), isTrue);
      expect(store.canSelfAssign(_project('p', 'd9')), isFalse,
          reason: 'لا معنى لانضمام موظف لمشروع إدارة لا يعمل فيها');
    });
  });
}
