// قاعدة الإسناد الواحدة — جدولها كاملاً، لا عيّنة منه.
//
// ــــ لماذا ٣٦ حالة مكتوبة بدل «اختبار مثال»؟ ــــ
//
// لأن العطل الذي أدّى إلى هذه القاعدة كان **حالة واحدة لم يفكّر فيها أحد**:
// الموظف يفتح «إضافة عمل» فيجد المسؤول التنفيذي في القائمة. واختبارُ مثالٍ
// أو مثالين يمرّ فوق تلك الحالة كما مرّت الشيفرة.
//
// فالجدول هنا مكتوب صراحةً — ستة أدوار فاعلة × ستة أدوار هدفاً — ويُطابَق
// حرفاً. ومن أراد تغيير القاعدة يغيّر الجدول ويرى ماذا تغيّر بالضبط.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/assignment_policy.dart';
import 'package:gov_exec_platform/models/enums.dart';

const _dept = 'd-1';

AppUser _u(UserRole role, {String? dept = _dept, UserStatus status = UserStatus.approved}) =>
    AppUser(
      id: '${role.name}-${dept ?? 'none'}-${status.name}',
      name: role.label,
      email: '',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

/// من يحقّ لكل دور أن يُسنِد إليه. مكتوبٌ باليد لا محسوباً — وإلا لاختبر
/// الاختبارُ نفسه بنفس المعادلة التي يفحصها.
const Map<UserRole, Set<UserRole>> _allowed = {
  UserRole.systemAdmin: {
    UserRole.systemAdmin,
    UserRole.executiveViewer,
    UserRole.departmentManager,
    UserRole.projectOfficer,
    UserRole.custom,
    UserRole.employee,
  },
  UserRole.executiveViewer: {
    UserRole.executiveViewer,
    UserRole.departmentManager,
    UserRole.projectOfficer,
    UserRole.custom,
    UserRole.employee,
  },
  UserRole.departmentManager: {
    UserRole.departmentManager,
    UserRole.projectOfficer,
    UserRole.custom,
    UserRole.employee,
  },
  UserRole.projectOfficer: {UserRole.projectOfficer, UserRole.custom, UserRole.employee},
  UserRole.custom: {UserRole.projectOfficer, UserRole.custom, UserRole.employee},
  UserRole.employee: {UserRole.employee},
};

void main() {
  test('جدول الرتب كاملاً: ٣٦ زوجاً (فاعل × هدف)', () {
    for (final actorRole in UserRole.values) {
      for (final targetRole in UserRole.values) {
        final expected = _allowed[actorRole]!.contains(targetRole);
        final actual = canAssignTo(
          actor: _u(actorRole),
          target: _u(targetRole),
          departmentId: _dept,
        );
        expect(actual, expected,
            reason: '«${actorRole.label}» يُسنِد إلى «${targetRole.label}»: '
                'المتوقَّع ${expected ? 'مسموح' : 'ممنوع'} والواقع '
                '${actual ? 'مسموح' : 'ممنوع'}');
      }
    }
  });

  test('المرء يُسنِد إلى نفسه مهما كان دوره — بلا استثناء مكتوب', () {
    for (final role in UserRole.values) {
      final me = _u(role);
      expect(canAssignTo(actor: me, target: me, departmentId: _dept), isTrue,
          reason: role.label);
    }
  });

  test('المسؤول التنفيذي محجوب عن كل من دونه، وظاهرٌ لمسؤول النظام وحده', () {
    final exec = _u(UserRole.executiveViewer);
    final pool = [exec, _u(UserRole.employee), _u(UserRole.departmentManager)];

    for (final actor in [UserRole.employee, UserRole.projectOfficer, UserRole.departmentManager]) {
      final list = eligibleAssignees(
        allUsers: pool,
        actor: _u(actor),
        departmentId: _dept,
      );
      expect(list.any((u) => u.id == exec.id), isFalse, reason: actor.label);
    }

    final adminList = eligibleAssignees(
      allUsers: pool,
      actor: _u(UserRole.systemAdmin),
      departmentId: _dept,
    );
    expect(adminList.any((u) => u.id == exec.id), isTrue);
  });

  test('غير المعتمَد لا يُسنَد إليه ولو كان أدنى رتبة', () {
    final pending = _u(UserRole.employee, status: UserStatus.pending);
    expect(
      canAssignTo(actor: _u(UserRole.systemAdmin), target: pending, departmentId: _dept),
      isFalse,
    );
  });

  test('نطاق الإدارة يُقصي من هو خارجها، والنطاق الفارغ لا يُقصي أحداً', () {
    final other = _u(UserRole.employee, dept: 'd-2');
    final admin = _u(UserRole.systemAdmin);
    expect(canAssignTo(actor: admin, target: other, departmentId: _dept), isFalse);
    expect(canAssignTo(actor: admin, target: other, departmentId: ''), isTrue);
    expect(canAssignTo(actor: admin, target: other, departmentId: null), isTrue);
  });

  test('exclude يُخرج من هو مديرٌ الآن — «تغييرٌ» إلى من يقود ليس تغييراً', () {
    final a = _u(UserRole.employee);
    final b = _u(UserRole.projectOfficer);
    final list = eligibleAssignees(
      allUsers: [a, b],
      actor: _u(UserRole.departmentManager),
      departmentId: _dept,
      exclude: {b.id},
    );
    expect(list.map((u) => u.id), [a.id]);
  });

  test('سبب القائمة الفارغة يميّز «لا أحد في الإدارة» عن «كلهم أعلى منك»', () {
    final empty = emptyAssigneeReason(allUsers: const [], actor: _u(UserRole.employee));
    expect(empty, contains('لا يوجد حساب معتمَد'));

    final blocked = emptyAssigneeReason(
      allUsers: [_u(UserRole.executiveViewer)],
      actor: _u(UserRole.employee),
      departmentId: _dept,
    );
    expect(blocked, contains('أعلى منك'));
  });
}
