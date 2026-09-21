// إعادةُ جدولة المهمة: الحدُّ الذي طلبتَه، ومن يملكه.
//
// ــــ الحدّ ــــ
//
// «الاستحقاق وحده بحيث لا يتجاوز مدة نهاية المشروع». وهو مطبَّقٌ عند
// **إنشاء** المهمة منذ البداية (النموذجُ يقصّ الموعدَ عند موعد المشروع)،
// ولم يكن مطبَّقاً عند تعديلها لأن التعديل لم يكن موجوداً أصلاً.
//
// ــــ ولماذا يُقاس هنا ــــ
//
// مهمةٌ موعدُها بعد نهاية مشروعها تجعل شارةَ المشروع تناقض مهامَّه، ويُقرأ
// التأخيرُ خطأً في كل تقرير.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_task.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/task_reschedule.dart';

const _dept = 'd-1';
const _other = 'd-2';
final _projectDue = DateTime(2026, 3, 15);

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

Project _project({List<String> managers = const [], String dept = _dept}) => Project(
      id: 'p1',
      departmentId: dept,
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 14),
      dueDate: _projectDue,
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 20,
      managerUids: managers,
    );

ProjectTask _task() => ProjectTask(
      id: 't1',
      projectId: 'p1',
      departmentId: _dept,
      title: 'مهمة',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      assigneeUid: 'u-x',
      assigneeName: 'منفّذ',
      lastUpdated: DateTime(2026, 2, 1),
      dueDate: DateTime(2026, 2, 20),
      createdByUid: 'u-1',
    );

AppStore _store(
  UserRole role, {
  String id = 'u-1',
  String? dept = _dept,
  Set<String> perms = const {},
}) =>
    AppStore()
      ..currentUser = _user(role, id: id, dept: dept)
      ..rolePermissions = RolePermissionsConfig({role.name: perms})
      ..projects = [_project()];

void main() {
  group('الحدُّ: لا يتجاوز موعدَ المشروع', () {
    test('موعدٌ قبل موعد المشروع مقبول', () {
      expect(
        taskDueDateRejection(newDue: DateTime(2026, 3, 1), projectDue: _projectDue),
        isNull,
      );
    });

    // ــ واليومُ نفسُه مقبول ــ
    //
    // ولولا المقارنة باليوم لَرُدّ موعدٌ يوافق نهاية المشروع لفارق ساعات.
    test('واليومُ نفسُه مقبول مهما كانت ساعتُه', () {
      expect(
        taskDueDateRejection(
          newDue: DateTime(2026, 3, 15, 23, 59),
          projectDue: DateTime(2026, 3, 15, 8),
        ),
        isNull,
      );
    });

    test('ويومٌ بعده يُردّ', () {
      final why = taskDueDateRejection(
        newDue: DateTime(2026, 3, 16),
        projectDue: _projectDue,
      );
      expect(why, isNotNull);
      expect(why, contains('لا يتجاوز'));
    });

    // ــ والردُّ يقول المخرج لا الحدَّ وحده ــ
    test('ويقول المخرجَ: يُعدَّل موعدُ المشروع أوّلاً', () {
      final why = taskDueDateRejection(
        newDue: DateTime(2027, 1, 1),
        projectDue: _projectDue,
      )!;
      expect(why, contains('موعد المشروع'));
      expect(why, contains('مسار اعتماد'));
    });

    test('ويُسمّى الحدُّ بتاريخه لا بعبارةٍ عامة', () {
      final why = taskDueDateRejection(
        newDue: DateTime(2026, 4, 1),
        projectDue: _projectDue,
      )!;
      expect(why, contains('2026'));
      expect(why, contains('مارس'));
    });
  });

  group('ومن يُعيد الجدولة', () {
    test('مسؤولُ النظام', () {
      expect(_store(UserRole.systemAdmin, dept: null).canRescheduleTask(_task()), isTrue);
    });

    test('ومديرُ إدارة المشروع', () {
      expect(_store(UserRole.departmentManager).canRescheduleTask(_task()), isTrue);
    });

    test('ولا مديرُ إدارةٍ أخرى', () {
      expect(
        _store(UserRole.departmentManager, dept: _other).canRescheduleTask(_task()),
        isFalse,
      );
    });

    // ــ وهذه هي الصلاحيةُ المستقلّة التي طلبتَها ــ
    //
    // تُمنح لأفرادٍ بأعيانهم، ولا تفتح شيئاً آخر: لا مواعيدَ مشاريع، ولا
    // مستخدمين، ولا مشاريعَ أخرى.
    test('وصاحبُ «تعديل مواعيد المهام» في إدارته', () {
      expect(
        _store(UserRole.employee, id: 'u-9', perms: const {'mtd'})
            .canRescheduleTask(_task()),
        isTrue,
      );
    });

    test('ولا يملكها خارج إدارته', () {
      expect(
        _store(UserRole.employee, id: 'u-9', dept: _other, perms: const {'mtd'})
            .canRescheduleTask(_task()),
        isFalse,
      );
    });

    test('ولا الموظفُ بلا الصلاحية', () {
      expect(_store(UserRole.employee, id: 'u-9').canRescheduleTask(_task()), isFalse);
    });

    // ــ التنفيذي يطّلع ولا يغيّر — قاعدةٌ قائمة في المنصّة ــ
    //
    // **وإدارتُه إدارةُ المشروع** في هذا الاختبار بقصد: تنفيذيٌّ بلا إدارة
    // يُردّ على أي حال (لا يملك المشروع ولا ينتمي لإدارته)، فحذفُ فرعِه لا
    // يُغيّر جوابه — وقد نجت عليه طفرةٌ فعلاً. والحالُ التي تقيس الفرعَ
    // نفسَه: من مُنح الصلاحية **وهو في الإدارة**.
    test('ولا المستخدمُ التنفيذي وإن مُنحها في إدارة المشروع', () {
      expect(
        _store(UserRole.executiveViewer, perms: const {'mtd'})
            .canRescheduleTask(_task()),
        isFalse,
      );
    });

    test('ولا تنفيذيٌّ بلا إدارةٍ أصلاً', () {
      expect(
        _store(UserRole.executiveViewer, dept: null, perms: const {'mtd'})
            .canRescheduleTask(_task()),
        isFalse,
      );
    });

    test('ومهمةٌ لمشروعٍ لم يعد موجوداً لا يُعاد جدولتها', () {
      final store = _store(UserRole.systemAdmin, dept: null)..projects = [];
      expect(store.canRescheduleTask(_task()), isFalse);
    });
  });
}
