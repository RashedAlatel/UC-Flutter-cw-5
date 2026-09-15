// رفع الشكوى: من حقٍّ مفروض إلى صلاحيةٍ يضبطها مسؤول النظام.
//
// ــ تاريخ هذا الملف ــ
//
// كُتب أولاً ليحرس أن رفع الشكوى **حق أساسي** لا صلاحية، بعد عطلٍ وقع فعلاً:
// التبويب لم يظهر لأحد إطلاقاً، لأن الحق عومل معاملة صلاحية دور ومستند
// `settings/rolePermissions` مكتوبٌ في المنصة الحيّة — والمخزَّن يُقدَّم على
// أي إعداد مبدئي في الشيفرة.
//
// ثم قرّر مسؤول النظام أن يضبطه لكل دور. فانقلب العقد، وبقي **الدرس**:
// نقلُ الحق إلى الشبكة يُعيد العطل نفسه حرفياً — المستند الحيّ يزعم في
// `_knownKeys` أنه يعرف المفتاح وهو غائب عن كل دور، فيُقرأ منعاً. ولذلك
// عَلَمُ الانتقال، وهذا الملف يحرسه.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_role.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

AppUser _user(
  UserRole role, {
  Map<String, bool> overrides = const {},
}) =>
    AppUser(
      id: 'u1',
      name: 'موظف',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: 'd1',
      permissionOverrides: overrides,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

/// صورة المستند المكتوب في المنصة اليوم: يعرف كل المفاتيح، ولا يمنح `sfb`
/// لأحد — لأنها كانت حقاً أساسياً لا يُكتب في مجموعة أي دور. وبلا علامة
/// الانتقال.
final _liveDocument = RolePermissionsConfig.fromMap({
  'employee': <String>[],
  'projectOfficer': <String>[],
  'departmentManager': ['mw'],
  'executiveViewer': ['vad'],
  RolePermissionsConfig.knownKeysField: RolePermission.values.map((p) => p.key).toList(),
});

void main() {
  group('الانتقال لا يسحب الحق من أحد', () {
    for (final role in UserRole.configurable) {
      test('${role.name} يبقى يرفع الشكوى قبل قرار مسؤول النظام', () {
        final store = AppStore()
          ..currentUser = _user(role)
          ..rolePermissions = _liveDocument;
        expect(store.canSubmitFeedback, isTrue,
            reason: 'المستند الحيّ لا يحمل قراراً في sfb — والغياب هنا ليس منعاً');
      });
    }

    test('ومسؤول النظام دائماً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.systemAdmin)
        ..rolePermissions = _liveDocument;
      expect(store.canSubmitFeedback, isTrue);
    });

    test('وحامل الدور المخصص كذلك', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.custom).copyWith(customRoleId: 'r1')
        ..customRoles = [CustomRole(id: 'r1', name: 'منسّق تنفيذي')];
      expect(store.canSubmitFeedback, isTrue);
    });

    test('وحاملُ دورٍ مخصص لم يعد موجوداً لا يُمنح شيئاً', () {
      // دورٌ حُذف من الإعدادات وبقي معرّفه على الحساب: لا يُقرأ منحاً — وهو
      // الاتجاه الآمن، فالمنح المجهول أخطر من المنع.
      final store = AppStore()..currentUser = _user(UserRole.custom);
      expect(store.canSubmitFeedback, isFalse);
    });
  });

  group('وبعد القرار يحكم الإعداد', () {
    RolePermissionsConfig decided(Map<String, List<String>> byRole) =>
        RolePermissionsConfig.fromMap({
          ...byRole,
          RolePermissionsConfig.knownKeysField:
              RolePermission.values.map((p) => p.key).toList(),
          RolePermissionsConfig.feedbackAssignableField: true,
        });

    test('من مُنح يرفع', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = decided({
          'employee': ['sfb'],
        });
      expect(store.canSubmitFeedback, isTrue);
    });

    test('ومن مُنع لا يرفع', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = decided({'employee': <String>[]});
      expect(store.canSubmitFeedback, isFalse);
    });

    test('والاستثناء الفردي يعلو على قرار الدور', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee, overrides: const {'sfb': true})
        ..rolePermissions = decided({'employee': <String>[]});
      expect(store.canSubmitFeedback, isTrue);
    });
  });

  group('الشبكة', () {
    test('المفتاح صار يظهر في شبكة صلاحيات الأدوار', () {
      // هذا ما طلبه مسؤول النظام: أن يقرّره لكل دور بيده.
      expect(RolePermission.roleAssignable, contains(RolePermission.submitFeedback));
    });

    test('ومتابعة الوارد بقيت صلاحية كما كانت', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = _liveDocument;
      expect(store.canManageFeedback, isFalse);
    });
  });
}
