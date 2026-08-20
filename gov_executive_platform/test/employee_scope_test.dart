// نطاق الموظف: الأعمال المُسنَدة إليه، ودمج التدفّقات التي تحلّ محلّ
// الاستعلامات المفتوحة.
//
// حارس عطلٍ وقع فعلاً: موظف معتمد لم ترَ صفحته مشروعاً ولا عملاً. والسبب
// أن مجموعتَي `works` و`approvalRequests` كانتا تُطلبان **كاملتين بلا
// نطاق**، وقواعد Firestore ترفض ولا تُصفّي — فيُرفض الطلب كله وتظهر
// الصفحة فارغة كأن لا بيانات. والعلاج تدفّقات مُقيَّدة تُدمج.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';

AppUser _user(UserRole role, {String? dept = 'd1', String id = 'u1'}) => AppUser(
      id: id,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

WorkItem _work(String id, {required String dept, required String assignee, int day = 1}) => WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: dept,
      assigneeUid: assignee,
      assigneeName: 'فلان',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      dueDate: DateTime(2026, 3, day),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('دمج التدفّقات', () {
    // لو كُتب التدفّقان في قائمة واحدة لداس أحدهما الآخر عند كل لقطة،
    // فتظهر البيانات وتختفي بلا سبب. الدمج بالمعرّف هو ما يمنع ذلك.
    test('يجمع المصادر بلا تكرار', () {
      final merged = AppStore.mergeById<WorkItem>((w) => w.id, [
        [_work('a', dept: 'd1', assignee: 'u1'), _work('b', dept: 'd1', assignee: 'u2')],
        [_work('b', dept: 'd1', assignee: 'u2'), _work('c', dept: 'd1', assignee: 'u1')],
      ]);
      expect(merged.map((w) => w.id).toSet(), {'a', 'b', 'c'});
      expect(merged.length, 3);
    });

    test('مصدر فارغ لا يمحو ما جاء به غيره', () {
      final merged = AppStore.mergeById<WorkItem>((w) => w.id, [
        [_work('a', dept: 'd1', assignee: 'u1')],
        const <WorkItem>[],
      ]);
      expect(merged.map((w) => w.id), ['a']);
    });

    test('بلا مصادر إطلاقاً — قائمة فارغة لا خطأ', () {
      expect(AppStore.mergeById<WorkItem>((w) => w.id, const []), isEmpty);
    });
  });

  group('نطاق أعمال الموظف', () {
    // القرار: الموظف يرى ما أُسنِد إليه وحده. أعمال الإدارة لمن يديرها.
    test('الموظف يرى المُسنَد إليه لا أعمال زملائه', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..works = [
          _work('mine', dept: 'd1', assignee: 'u1'),
          _work('colleague', dept: 'd1', assignee: 'u2'),
          _work('other-dept', dept: 'd9', assignee: 'u1'),
        ];
      expect(store.visibleWorks.map((w) => w.id).toSet(), {'mine', 'other-dept'},
          reason: 'العمل المُسنَد إليه يتبعه ولو نُقل إلى إدارة أخرى');
    });

    test('صاحب صلاحية إدارة الأعمال يرى أعمال إدارته', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'mw'},
        })
        ..works = [
          _work('mine', dept: 'd1', assignee: 'u1'),
          _work('colleague', dept: 'd1', assignee: 'u2'),
          _work('other-dept', dept: 'd9', assignee: 'u3'),
        ];
      expect(store.visibleWorks.map((w) => w.id).toSet(), {'mine', 'colleague'});
    });

    test('مدير الإدارة يرى أعمال إدارته كاملةً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.departmentManager)
        ..works = [
          _work('a', dept: 'd1', assignee: 'u2'),
          _work('b', dept: 'd9', assignee: 'u3'),
        ];
      expect(store.visibleWorks.map((w) => w.id), ['a']);
    });
  });

  group('نطاق مشاريع الموظف', () {
    // الاطّلاع على مشاريع الإدارة صار حقاً أساسياً لا صلاحية — والواجهة
    // يجب أن توافق القاعدة، وإلا عرضت فراغاً على بيانات وصلت فعلاً.
    test('الموظف بلا أي صلاحية يرى مشاريع إدارته', () {
      final store = AppStore()..currentUser = _user(UserRole.employee);
      expect(store.hasPermission(RolePermission.selfAssignProjects), isFalse);
      expect(store.canViewDepartment('d1'), isTrue);
    });
  });
}
