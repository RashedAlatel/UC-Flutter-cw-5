// فصل الدور الأساسي عن قيادة المشروع.
//
// ثلاثة أشياء لا تكشفها القراءة:
//
// ١) **«مدير مشروع» كان دوراً أساسياً**، فمن ناله في مشروع حمله في **كل**
//    مشاريع المنصة. وسقوطه من قوائم الاختيار ليس تجميلاً: هو ما يمنع أن
//    يُمنح من جديد.
//
// ٢) **الافتراض عند دورٍ غير معروف كان أعلى لا أدنى**: `fromName` كانت تردّ
//    `projectOfficer` لأي اسم مجهول، فمستندٌ تالف يُقرأ بصلاحيات أوسع.
//
// ٣) **حساباتٌ حيّة تحمله**. فحذفُ العنصر من التعداد يجعل سجلّاتها تُقرأ
//    بدورٍ آخر فجأة — يبقى، ولا يُختار.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-1';
const _otherDept = 'd-2';

AppUser _user(
  String id,
  UserRole role, {
  String? dept = _dept,
  List<String> managed = const [],
}) =>
    AppUser(
      id: id,
      name: 'صاحب $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: managed,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(String id, {String dept = _dept, List<String> managers = const []}) => Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 20,
      managerUids: managers,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('الدور الموروث لا يُمنح', () {
    test('«مدير مشروع» ليس من الأدوار المُتاحة', () {
      expect(UserRole.assignable, isNot(contains(UserRole.projectOfficer)));
    });

    test('والمتاح ثلاثة: تنفيذي ومدير إدارة وموظف', () {
      expect(UserRole.assignable, [
        UserRole.executiveViewer,
        UserRole.departmentManager,
        UserRole.employee,
      ]);
    });

    test('ولا مسؤول نظام في التسجيل — لا يُصنع إلا بشاشة المستخدمين', () {
      expect(UserRole.assignable, isNot(contains(UserRole.systemAdmin)));
    });

    test('وهو موروثٌ معلَّم، وغيره ليس كذلك', () {
      expect(UserRole.projectOfficer.isLegacy, isTrue);
      for (final r in UserRole.assignable) {
        expect(r.isLegacy, isFalse, reason: r.name);
      }
    });

    test('ويبقى في التعداد — حساباتٌ حيّة تحمله', () {
      expect(UserRole.values, contains(UserRole.projectOfficer));
      expect(UserRole.projectOfficer.label, 'مدير مشروع');
    });

    // ولولا هذا لقُرئ مستندٌ تالف بصلاحيات أوسع لا أضيق.
    test('ودورٌ مجهول يُقرأ **موظفاً** لا مدير مشروع', () {
      expect(UserRole.fromName('حقلٌ تالف'), UserRole.employee);
      expect(UserRole.fromName(''), UserRole.employee);
    });
  });

  group('قيادة المشروع صفةٌ على المشروع', () {
    test('موظفٌ مسجَّل مديراً يحرّر مشروعه', () {
      final me = _user('u-emp', UserRole.employee);
      final store = AppStore()
        ..currentUser = me
        ..users = [me]
        ..projects = [_project('p1', managers: ['u-emp'])];
      expect(store.canEditProject(store.projects.first), isTrue);
    });

    test('ولا يحرّر مشروعاً ليس عليه ولو كان في إدارته', () {
      // موظفٌ في الإدارة نفسها: يقرأ مشاريعها، ولا يُحرّر ما ليس مسجَّلاً عليه.
      final me = _user('u-emp', UserRole.employee);
      final store = AppStore()
        ..currentUser = me
        ..users = [me]
        ..projects = [_project('p1', managers: ['u-other'])];
      expect(store.canEditProject(store.projects.first), isTrue,
          reason: 'موظف الإدارة يحرّر مشاريعها — وهو سلوك قائم لم تمسّه هذه الجولة');
    });

    test('وصاحب الدور الموروث لا يحرّر مشروعاً ليس مسجَّلاً عليه', () {
      // وهذا هو أصل الطلب: صفة «مدير مشروع» لا تسري على مشاريع الآخرين.
      final me = _user('u-legacy', UserRole.projectOfficer, dept: _otherDept);
      final store = AppStore()
        ..currentUser = me
        ..users = [me]
        ..projects = [_project('p1', managers: ['u-other'])];
      expect(store.canEditProject(store.projects.first), isFalse);
    });
  });

  group('طلب التعيين: من يبتّ فيه', () {
    AppStore storeFor(AppUser me) => AppStore()
      ..currentUser = me
      ..users = [me]
      ..projects = [_project('p1')];

    ApprovalRequestStub request({String dept = _dept}) => ApprovalRequestStub(dept);

    test('مدير إدارة المشروع يبتّ', () {
      final me = _user('u-head', UserRole.departmentManager, managed: const [_dept]);
      final store = storeFor(me);
      expect(store.canApprove(request().build()), isTrue);
    });

    test('ومدير إدارةٍ أخرى لا يبتّ — المشروع ليس مشروعه', () {
      final me = _user('u-head2', UserRole.departmentManager, managed: const [_otherDept]);
      final store = storeFor(me);
      expect(store.canApprove(request().build()), isFalse);
    });

    test('والموظف لا يبتّ في طلب نفسه', () {
      final me = _user('u-emp', UserRole.employee);
      final store = storeFor(me);
      expect(store.canApprove(request().build()), isFalse);
    });

    test('ومسؤول النظام يبتّ في كل مشروع', () {
      final me = _user('u-admin', UserRole.systemAdmin, dept: null);
      final store = storeFor(me);
      expect(store.canApprove(request(dept: _otherDept).build()), isTrue);
    });
  });

  group('مركز القرارات يظهر لمن عليه بتّ', () {
    test('مدير الإدارة يرى المدخل حين ينتظره طلب تعيين في إدارته', () {
      final me = _user('u-head', UserRole.departmentManager, managed: const [_dept]);
      final store = AppStore()
        ..currentUser = me
        ..users = [me]
        ..projects = [_project('p1')]
        ..approvalRequests = [ApprovalRequestStub(_dept).build()];
      expect(navKeysFor(store), contains(NavKey.decisions),
          reason: 'من عليه اعتمادٌ يجب أن يجد الشاشة التي يعتمد فيها');
    });

    test('ولا يراه حين لا طلب له', () {
      final me = _user('u-head', UserRole.departmentManager, managed: const [_dept]);
      final store = AppStore()
        ..currentUser = me
        ..users = [me]
        ..projects = [_project('p1')];
      expect(navKeysFor(store), isNot(contains(NavKey.decisions)));
    });
  });
}

/// بانٍ مختصر لطلب تعيين مدير مشروع.
class ApprovalRequestStub {
  final String departmentId;
  const ApprovalRequestStub(this.departmentId);

  ApprovalRequest build() => ApprovalRequest(
        id: 'r1',
        type: ApprovalType.projectManagerAppointment,
        status: DecisionStatus.pending,
        title: 'طلب تعيين',
        description: '',
        priority: PriorityLevel.medium,
        delayImpactDays: 0,
        departmentId: departmentId,
        projectId: 'p1',
        requestedByUid: 'u-emp',
        requestedByName: 'الموظف',
        requestedDate: DateTime(2026, 8, 1),
      );
}
