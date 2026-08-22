// الإجراء الجماعي: تنبيه المشاريع المتأخرة.
//
// ثلاثة أشياء لا تكشفها القراءة:
//
// ١) **الصلاحية**. الزرّ كان معلَّقاً بـ`ntf` وهي مغلقة لكل الأدوار
//    افتراضياً — فلم يكن يراه إلا مسؤول النظام. وصار بمفتاح مستقلّ مفتوح
//    للأدوار الثلاثة التي تتابع مشاريع لا تنفّذها، ومغلق على «موظف».
//
// ٢) **الرابط**. `Uri.base` خارج المتصفح مجلّد العمل، فرابطٌ يُبنى منه في
//    اختبار يخرج `file:///home/…` — وفي بريدٍ رسمي لا يفتح شيئاً.
//
// ٣) **استبعاد مشروع يُسقط مستلماً**. من كان له مشروع واحد في الدفعة يخرج
//    من قائمة المستلمين حين يُستبعَد مشروعه — لا يبقى ليصله بريدٌ فارغ.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/late_alert.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/utils/platform_url.dart';

const _dept = 'd-1';

AppUser _u(String id, {String email = 'x@moj.gov.kw', UserStatus status = UserStatus.approved}) =>
    AppUser(
      id: id,
      name: 'الموظف $id',
      email: email,
      phone: '',
      role: UserRole.employee,
      departmentId: _dept,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

Project _p(
  String id, {
  List<String> managers = const [],
  List<String> executors = const [],
  int lateDays = 5,
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime.now().subtract(Duration(days: lateDays)),
      status: ProjectStatus.delayed,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      managerUids: managers,
      executorUids: executors,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('الصلاحية', () {
    final defaults = RolePermissionsConfig.defaults();

    for (final role in [
      UserRole.executiveViewer,
      UserRole.departmentManager,
      UserRole.projectOfficer,
    ]) {
      test('${role.name} يملك تنبيه المتأخرات جماعياً', () {
        expect(defaults.has(role, RolePermission.bulkDelayAlerts), isTrue);
      });
    }

    test('و«موظف» لا يملكها إلا بمنحٍ صريح', () {
      expect(defaults.has(UserRole.employee, RolePermission.bulkDelayAlerts), isFalse);
      final granted = defaults.toggled(
          UserRole.employee, RolePermission.bulkDelayAlerts, true);
      expect(granted.has(UserRole.employee, RolePermission.bulkDelayAlerts), isTrue);
    });

    test('وهي في شبكة صلاحيات الأدوار فيضبطها مسؤول النظام', () {
      expect(RolePermission.roleAssignable, contains(RolePermission.bulkDelayAlerts));
    });

    // المفتاح جديد، والمستند الحيّ لا يعرفه. ولولا `_knownKeys` لقُرئ غيابه
    // منعاً، فلا يراه أحدٌ في المنصة الحيّة ويُظنّ أن الميزة لم تُنشر.
    test('ومستندٌ حيٌّ لا يعرف المفتاح يُقرأ من المبدئي لا منعاً', () {
      final stored = {
        for (final r in UserRole.configurable) r.name: <String>['dsh'],
        RolePermissionsConfig.knownKeysField: ['dsh', 'dpg', 'vad'],
        RolePermissionsConfig.feedbackAssignableField: true,
      };
      final parsed = RolePermissionsConfig.fromMap(stored);
      expect(parsed.has(UserRole.departmentManager, RolePermission.bulkDelayAlerts), isTrue);
      expect(parsed.has(UserRole.employee, RolePermission.bulkDelayAlerts), isFalse);
    });
  });

  group('عنوان المنصة', () {
    test('عنوان متصفح حقيقي يُقرأ بلا استعلام ولا وسم', () {
      expect(baseUrlOf(Uri.parse('https://moj.web.app/?v=3#x')), 'https://moj.web.app/');
    });

    test('ومسار المجلّد يبقى — حذفه يكسر الرابط', () {
      expect(baseUrlOf(Uri.parse('https://moj.gov.kw/platform/')), 'https://moj.gov.kw/platform/');
    });

    test('و`file:` ليس عنوان منصة، فيُقال «لا رابط» بدل رابطٍ كاذب', () {
      expect(baseUrlOf(Uri.parse('file:///home/user/app/')), '');
    });
  });

  group('بناء الرابط المباشر', () {
    test('يُضاف الاستعلام إلى عنوان بلا استعلام', () {
      expect(projectLink('https://moj.web.app/', 'p1'), 'https://moj.web.app/?project=p1');
    });

    test('وإلى عنوانٍ فيه استعلام بـ&', () {
      expect(projectLink('https://moj.web.app/?a=1', 'p1'), 'https://moj.web.app/?a=1&project=p1');
    });

    test('وعنوانٌ فارغ يعني لا رابط', () {
      expect(projectLink('', 'p1'), '');
    });
  });

  group('نصّ الرسالة', () {
    test('يحمل الاسم والاستحقاق وأيام التأخير ونسبة الإنجاز والرابط والمطلوب', () {
      final me = _u('a');
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'], lateDays: 7)],
        users: [me],
        baseUrl: 'https://moj.web.app/',
      );
      expect(msgs, hasLength(1));
      final body = msgs.first.body;
      expect(body, contains('مشروع p1'));
      expect(body, contains('تاريخ الاستحقاق:'));
      expect(body, contains('أيام التأخير: 7'));
      expect(body, contains('نسبة الإنجاز:'));
      expect(body, contains('https://moj.web.app/?project=p1'));
      expect(body, contains('خطة الاستدراك'));
    });

    test('وبلا عنوان منصة يسقط سطر الرابط ولا يُكتب رابطٌ ناقص', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'])],
        users: [_u('a')],
      );
      expect(msgs.first.body, isNot(contains('رابط المشروع')));
    });
  });

  group('المستلمون', () {
    test('رسالة واحدة لكل شخص تسرد مشاريعه، لا رسالة لكل مشروع', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a']), _p('p2', executors: ['a'])],
        users: [_u('a')],
      );
      expect(msgs, hasLength(1));
      expect(msgs.first.projects, hasLength(2));
    });

    test('ومن كان مديراً ومنفّذاً على المشروع نفسه لا يُحسب مرتين', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'], executors: ['a'])],
        users: [_u('a')],
      );
      expect(msgs.first.projects, hasLength(1));
    });

    test('ومن لا بريد له يسقط — الرسالة إليه تُفشل الدفعة كلها', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'])],
        users: [_u('a', email: '  ')],
      );
      expect(msgs, isEmpty);
    });

    test('وغير المعتمَد يسقط كذلك', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'])],
        users: [_u('a', status: UserStatus.suspended)],
      );
      expect(msgs, isEmpty);
    });

    test('واستبعاد مستلم يُخرجه وحده ويُبقي غيره', () {
      final msgs = buildLateAlerts(
        lateProjects: [_p('p1', managers: ['a'], executors: ['b'])],
        users: [_u('a'), _u('b')],
        excludedUids: {'a'},
      );
      expect(msgs.map((m) => m.user.id), ['b']);
    });

    test('واستبعاد مشروع يُسقط من لم يكن له غيره', () {
      final all = [_p('p1', managers: ['a']), _p('p2', managers: ['b'])];
      final kept = all.where((p) => p.id != 'p1').toList();
      final msgs = buildLateAlerts(lateProjects: kept, users: [_u('a'), _u('b')]);
      expect(msgs.map((m) => m.user.id), ['b']);
    });
  });
}
