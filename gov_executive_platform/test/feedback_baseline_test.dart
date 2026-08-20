// رفع الشكوى حق أساسي، ومتابعة الوارد صلاحية.
//
// حارس عطلٍ وقع فعلاً: التبويب لم يظهر لأحد إطلاقاً. وسببه أن الحق عومل
// معاملة صلاحية دور، ومستند `settings/rolePermissions` مكتوبٌ في المنصة
// الحيّة — والمخزَّن يُقدَّم على أي إعداد مبدئي في الشيفرة، فتبقى مطفأة
// مهما غُيّر المبدئي.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
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

/// الحالة الحقيقية في منصة مسؤول النظام: المستند محفوظ ولا يمنح شيئاً.
const _storedAndEmpty = RolePermissionsConfig({
  'employee': <String>{},
  'projectOfficer': <String>{},
  'departmentManager': {'mw'},
  'executiveViewer': {'vad', 'mr', 'agd'},
});

void main() {
  group('رفع الشكوى حق لا صلاحية', () {
    test('الموظف يرفع شكوى ولو كان مستند الصلاحيات المحفوظ فارغاً', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = _storedAndEmpty;
      expect(store.canSubmitFeedback, isTrue);
    });

    test('وكذلك مدير المشروع ومدير الإدارة والمستخدم التنفيذي', () {
      for (final role in [UserRole.projectOfficer, UserRole.departmentManager, UserRole.executiveViewer]) {
        final store = AppStore()
          ..currentUser = _user(role)
          ..rolePermissions = _storedAndEmpty;
        expect(store.canSubmitFeedback, isTrue, reason: 'الدور: ${role.label}');
      }
    });

    // ولولا هذا لصار الحق مطلقاً لا يُسحب، وقد اشتُرط أن يبقى بيد مسؤول النظام.
    test('ويُسحب من فرد بعينه', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee, overrides: {'sfb': false})
        ..rolePermissions = _storedAndEmpty;
      expect(store.canSubmitFeedback, isFalse);
    });

    test('ولا يظهر في شبكة صلاحيات الأدوار', () {
      expect(RolePermission.roleAssignable, isNot(contains(RolePermission.submitFeedback)));
      expect(RolePermission.baseline, contains(RolePermission.submitFeedback));
    });
  });

  group('متابعة الوارد تبقى صلاحية تُمنح', () {
    test('لا تُمنح لأحد بمستند فارغ', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = _storedAndEmpty;
      expect(store.canManageFeedback, isFalse);
      expect(store.incomingFeedback, isEmpty);
    });

    test('وتُمنح لدور', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.departmentManager)
        ..rolePermissions = const RolePermissionsConfig({
          'departmentManager': {'mfb'},
        });
      expect(store.canManageFeedback, isTrue);
    });

    test('أو لفرد بعينه دون تغيير دوره', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee, overrides: {'mfb': true})
        ..rolePermissions = _storedAndEmpty;
      expect(store.canManageFeedback, isTrue);
    });

    test('وتبقى في شبكة صلاحيات الأدوار', () {
      expect(RolePermission.roleAssignable, contains(RolePermission.manageFeedback));
    });
  });

  // الحارس الذي يزامن البطاقات القديمة يعتمد على هذه المجموعة: لو لم تشمل
  // `sfb` لبقيت بطاقات المستخدمين الحاليين بلا البصمة، ولرفض الخادمُ إنشاء
  // الشكوى بينما التبويب ظاهر لهم — أسوأ من إخفائه.
  test('البصمة المتوقَّعة تشمل الحق الأساسي', () {
    final store = AppStore()
      ..currentUser = _user(UserRole.employee)
      ..rolePermissions = _storedAndEmpty;
    expect(store.expectedPermissionKeys, contains('sfb'));
    expect(store.expectedPermissionKeys.difference(store.tokenPermissionKeys(const {})), contains('sfb'));
  });

  test('ومسؤول النظام يبقى خارج المقارنة', () {
    final store = AppStore()..currentUser = _user(UserRole.systemAdmin);
    expect(store.canSubmitFeedback, isTrue);
    expect(store.canManageFeedback, isTrue);
    expect(store.expectedPermissionKeys, isEmpty);
  });
}
