import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/notify_templates.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';

AppUser _user(String id, String name, UserRole role, {String? dept, List<String> depts = const []}) => AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('قوالب الرسائل', () {
    final project = Project(
      id: 'p1',
      departmentId: 'd1',
      name: 'تطوير البوابة',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 3, 10),
      status: ProjectStatus.delayed,
      priority: PriorityLevel.high,
      progressPercent: 40,
      executorNames: const ['فهد المطيري'],
      managerUids: const ['u-mgr'],
    );

    final work = WorkItem(
      id: 'w1',
      title: 'جرد المستودع',
      description: '',
      departmentId: 'd1',
      assigneeUid: 'u-emp',
      assigneeName: 'نورة',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 25,
      dueDate: DateTime(2026, 4, 5),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

    test('التذكير بالموعد يحمل الاسم والتاريخ والنسبة', () {
      final c = NotifyContext.fromProject(project);
      final body = NotifyTemplate.deadlineReminder.bodyFor(c);
      expect(body, contains('تطوير البوابة'));
      expect(body, contains('٪')); // نسبة الإنجاز
      expect(NotifyTemplate.deadlineReminder.subjectFor(c), contains('تطوير البوابة'));
    });

    test('تنبيه التأخير يذكر عدد أيام التأخير المحسوب حيّاً', () {
      final c = NotifyContext.fromProject(project);
      final body = NotifyTemplate.delayAlert.bodyFor(c);
      expect(body, contains('${c.delayDays}'));
      expect(c.delayDays, greaterThan(0), reason: 'المشروع متأخر فعلاً في بياناته');
    });

    test('القوالب تعمل مع العمل كما مع المشروع', () {
      final c = NotifyContext.fromWork(work);
      expect(c.kind, 'العمل');
      expect(NotifyTemplate.statusUpdate.bodyFor(c), contains('جرد المستودع'));
      expect(NotifyTemplate.completionThanks.bodyFor(c), contains('جرد المستودع'));
    });

    test('الرسالة الحرة لا تُعبَّأ', () {
      final c = NotifyContext.fromProject(project);
      expect(NotifyTemplate.free.bodyFor(c), isEmpty);
      expect(NotifyTemplate.free.subjectFor(c), isEmpty);
    });

    test('بلا سياق لا يُعبَّأ أي قالب', () {
      for (final t in NotifyTemplate.values) {
        expect(t.bodyFor(null), isEmpty, reason: t.label);
      }
    });
  });

  group('مؤشرات الشخص', () {
    AppStore store() {
      final s = AppStore();
      s.users = [
        _user('u1', 'فهد المطيري', UserRole.employee, dept: 'd1'),
        _user('u2', 'نورة العنزي', UserRole.employee, dept: 'd2'),
      ];
      s.works = [
        WorkItem(
          id: 'w1', title: 'عمل ١', description: '', departmentId: 'd1',
          assigneeUid: 'u1', assigneeName: 'فهد المطيري', status: TaskStatus.done,
          priority: PriorityLevel.medium, progressPercent: 100,
          dueDate: DateTime(2026, 1, 5), completedDate: DateTime(2026, 1, 4),
          createdByUid: 'a', createdAt: DateTime(2026, 1, 1),
        ),
        WorkItem(
          id: 'w2', title: 'عمل ٢', description: '', departmentId: 'd1',
          assigneeUid: 'u1', assigneeName: 'فهد المطيري', status: TaskStatus.inProgress,
          priority: PriorityLevel.medium, progressPercent: 50,
          dueDate: DateTime(2020, 1, 1), // متأخر
          createdByUid: 'a', createdAt: DateTime(2026, 1, 1),
        ),
      ];
      s.projects = [
        Project(
          id: 'p1', departmentId: 'd1', name: 'مشروع', description: '',
          startDate: DateTime(2026, 1, 1), dueDate: DateTime(2026, 12, 1),
          status: ProjectStatus.onTrack, priority: PriorityLevel.medium,
          progressPercent: 60, executorNames: const ['فهد المطيري'],
        ),
      ];
      return s;
    }

    test('تُحسب الأعمال والمنجَز والمتأخر ومتوسط الإنجاز', () {
      final s = store();
      final stats = s.personStats(s.users.first);
      expect(stats.works, 2);
      expect(stats.worksDone, 1);
      expect(stats.worksOverdue, 1);
      expect(stats.avgWorkProgress, 75); // (100 + 50) / 2
    });

    test('المشاريع تُربط بالمنفّذ بالاسم وبالمدير بالمعرّف', () {
      final s = store();
      expect(s.projectsOf(s.users.first).map((p) => p.id), ['p1']);
      expect(s.projectsOf(s.users[1]), isEmpty);
    });

    test('من لا أعمال له تكون مؤشراته أصفاراً بلا قسمة على صفر', () {
      final s = store();
      final stats = s.personStats(s.users[1]);
      expect(stats.works, 0);
      expect(stats.avgWorkProgress, 0);
    });
  });

  group('صلاحية المراسلة', () {
    test('غير ممنوحة مبدئياً لأي دور أساسي', () {
      final s = AppStore()..currentUser = _user('u1', 'فهد', UserRole.departmentManager, depts: ['d1']);
      expect(s.canSendNotifications, isFalse);
    });

    test('تُمنح عبر إعداد صلاحيات الأدوار', () {
      final s = AppStore()
        ..currentUser = _user('u1', 'فهد', UserRole.departmentManager, depts: ['d1'])
        ..rolePermissions = const RolePermissionsConfig({
          'departmentManager': {'ntf'},
        });
      expect(s.canSendNotifications, isTrue);
    });

    test('مسؤول النظام يملكها دائماً', () {
      final s = AppStore()..currentUser = _user('a', 'مسؤول', UserRole.systemAdmin);
      expect(s.canSendNotifications, isTrue);
    });
  });
}
