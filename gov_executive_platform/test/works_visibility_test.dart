import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';

AppUser _user(String id, UserRole role, {String? dept, List<String> depts = const []}) => AppUser(
      id: id,
      name: id,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

WorkItem _work(String id, String dept, String assignee, {TaskStatus status = TaskStatus.todo, DateTime? completed}) =>
    WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: dept,
      assigneeUid: assignee,
      assigneeName: assignee,
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: status == TaskStatus.done ? 100 : 30,
      dueDate: DateTime(2026, 6, 1),
      completedDate: completed,
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store() => AppStore()
  ..works = [
    _work('w1', 'd1', 'emp1'),
    _work('w2', 'd1', 'emp2'),
    _work('w3', 'd2', 'emp3'),
    _work('w4', 'd2', 'emp1', status: TaskStatus.done, completed: DateTime(2026, 5, 20)),
  ];

void main() {
  group('نطاق رؤية الأعمال حسب الدور', () {
    test('مسؤول النظام يرى كل الأعمال', () {
      final s = _store()..currentUser = _user('admin', UserRole.systemAdmin);
      expect(s.visibleWorks.length, 4);
    });

    test('مدير الإدارة يرى أعمال إداراته فقط', () {
      final s = _store()..currentUser = _user('mgr', UserRole.departmentManager, depts: ['d1']);
      expect(s.visibleWorks.map((w) => w.id).toList(), ['w1', 'w2']);
    });

    test('الموظف يرى الأعمال المُسنَدة إليه فقط', () {
      final s = _store()..currentUser = _user('emp1', UserRole.employee, dept: 'd1');
      expect(s.visibleWorks.map((w) => w.id).toSet(), {'w1', 'w4'});
    });

    test('الموظف بصلاحية إدارة الأعمال يرى أعمال إدارته كذلك', () {
      final s = _store()
        ..currentUser = _user('emp1', UserRole.employee, dept: 'd1')
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'mw'},
        });
      expect(s.visibleWorks.map((w) => w.id).toSet(), {'w1', 'w2', 'w4'});
    });

    test('سجل الإنجاز يعرض المنجَزة فقط مرتّبة بالأحدث', () {
      final s = _store()..currentUser = _user('admin', UserRole.systemAdmin);
      expect(s.completedWorks.map((w) => w.id).toList(), ['w4']);
    });
  });

  group('صلاحية تعديل العمل', () {
    test('الموظف يعدّل عمله المُسنَد إليه دون بقية الأعمال', () {
      final s = _store()..currentUser = _user('emp1', UserRole.employee, dept: 'd1');
      expect(s.canEditWork(_work('w1', 'd1', 'emp1')), isTrue);
      expect(s.canEditWork(_work('w2', 'd1', 'emp2')), isFalse);
    });

    test('مدير الإدارة بصلاحية إدارة الأعمال يعدّل أعمال إدارته', () {
      final s = _store()
        ..currentUser = _user('mgr', UserRole.departmentManager, depts: ['d1'])
        ..rolePermissions = const RolePermissionsConfig({
          'departmentManager': {'mw'},
        });
      expect(s.canEditWork(_work('w2', 'd1', 'emp2')), isTrue);
      expect(s.canEditWork(_work('w3', 'd2', 'emp3')), isFalse);
    });
  });

  group('نموذج الصلاحيات', () {
    test('مسؤول النظام يملك كل الصلاحيات دائماً', () {
      final s = _store()..currentUser = _user('admin', UserRole.systemAdmin);
      for (final p in RolePermission.values) {
        expect(s.hasPermission(p), isTrue, reason: p.label);
      }
    });

    test('تبديل صلاحية لا يؤثر على بقية الأدوار', () {
      const base = RolePermissionsConfig({
        'employee': <String>{},
        'projectOfficer': {'mw'},
      });
      final next = base.toggled(UserRole.employee, RolePermission.manageWorks, true);
      expect(next.has(UserRole.employee, RolePermission.manageWorks), isTrue);
      expect(next.has(UserRole.projectOfficer, RolePermission.manageWorks), isTrue);
      // النسخة الأصلية لم تتغيّر (غير قابلة للتعديل في مكانها).
      expect(base.has(UserRole.employee, RolePermission.manageWorks), isFalse);
    });

    test('بوابات الاعتماد الثلاث ليست ضمن الصلاحيات القابلة للتفويض', () {
      final keys = RolePermission.values.map((p) => p.key).toSet();
      // لا مفتاح لتسجيل الأعضاء أو إضافة المشاريع أو تعديل المواعيد النهائية.
      expect(keys.contains('approveRegistration'), isFalse);
      expect(keys.contains('approveNewProject'), isFalse);
      expect(keys.contains('approveDeadline'), isFalse);
    });
  });
}
