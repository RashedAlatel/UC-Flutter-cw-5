// الصلاحيات المقيَّدة بنطاق: الإنشاء المباشر، والاعتماد، وحدود كل منهما.
//
// هذه أول صلاحية في المنصة تفتح **بوابة** كانت محصورة بمسؤول النظام
// (إضافة المشاريع)، بقرار صريح منه. فالحراسة هنا ليست تفصيلاً: الأصل
// مغلق، والمنح فردي بنطاق، والسحب فوري — وما عدا ذلك يبقى مغلقاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

const _mine = 'd-mine';
const _other = 'd-other';

AppUser _user({
  UserRole role = UserRole.employee,
  String? dept = _mine,
  List<String> depts = const [],
  Map<String, GrantScope> grants = const {},
}) =>
    AppUser(
      id: 'u1',
      name: 'موظف',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: depts,
      scopedGrants: grants,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

ApprovalRequest _request(ApprovalType type, {String? dept = _mine}) => ApprovalRequest(
      id: 'r1',
      type: type,
      status: DecisionStatus.pending,
      title: 'طلب',
      description: '',
      priority: PriorityLevel.medium,
      delayImpactDays: 0,
      departmentId: dept,
      requestedByUid: 'someone',
      requestedByName: 'فلان',
      requestedDate: DateTime(2026, 8, 20),
    );

void main() {
  group('نطاق الإنشاء المباشر', () {
    test('بلا منحة لا إنشاء — وهذا هو الأصل لكل المستخدمين', () {
      final store = AppStore()..currentUser = _user();
      expect(store.canCreateIn(_mine), isFalse);
      expect(store.hasPermission(RolePermission.manageProjects), isFalse);
    });

    test('منحة بإدارة تسري فيها وحدها', () {
      final store = AppStore()
        ..currentUser = _user(grants: {'mpr': const GrantScope(departmentIds: [_mine])});
      expect(store.canCreateIn(_mine), isTrue);
      expect(store.canCreateIn(_other), isFalse);
    });

    test('ومنحة «كل الإدارات» تسري في أي إدارة', () {
      final store = AppStore()..currentUser = _user(grants: {'mpr': GrantScope.all});
      expect(store.canCreateIn(_mine), isTrue);
      expect(store.canCreateIn(_other), isTrue);
    });

    // نطاق فارغ ليس منحاً — ولو قُرئ «الكل» لانفتحت المنصة كلها بالخطأ.
    test('منحة بنطاق فارغ لا تسري على شيء', () {
      final store = AppStore()
        ..currentUser = _user(grants: {'mpr': const GrantScope(departmentIds: [])});
      expect(store.hasPermission(RolePermission.manageProjects), isFalse);
      expect(store.canCreateIn(_mine), isFalse);
      expect(store.canCreateIn(null), isFalse);
    });

    test('ومسؤول النظام يُنشئ في كل إدارة بلا منحة مكتوبة', () {
      final store = AppStore()..currentUser = _user(role: UserRole.systemAdmin, dept: null);
      expect(store.canCreateIn(_other), isTrue);
      expect(store.scopeFor(RolePermission.manageProjects).allDepartments, isTrue);
    });
  });

  group('من يبتّ في الطلبات', () {
    test('البوابات الباقية لمسؤول النظام وحده', () {
      final store = AppStore()
        ..currentUser = _user(grants: {
          'mpr': GrantScope.all,
          'apr': GrantScope.all,
        });
      expect(store.canApprove(_request(ApprovalType.registration)), isFalse,
          reason: 'تسجيل الأعضاء لم يُطلب فتحه ولا مفتاح له');
      expect(store.canApprove(_request(ApprovalType.deadlineChange)), isFalse,
          reason: 'تعديل المواعيد النهائية كذلك');
      // البوابة الثالثة: أُضيفت بقرار صريح من مسؤول النظام — كل بريد يخرج
      // باسم المنصة يمرّ بموافقته. وأوسعُ منحتين في المنصة مجتمعتين لا
      // تفتحانها، وهذا ما يُقاس هنا.
      expect(store.canApprove(_request(ApprovalType.notifySend)), isFalse,
          reason: 'إرسال البريد بوابة لا يفتحها مفتاح مفوَّض');
    });

    test('ولا صلاحية «إرسال الإشعارات» نفسها تفتح بوابة البريد', () {
      // `ntf` تُجيز **كتابة** الطلب لا البتّ فيه. ولولا هذا التمييز لعاد
      // مدير الإدارة يرسل بلا رقابة من باب آخر — وهو العطل الذي أُغلق.
      final store = AppStore()
        ..currentUser = _user(role: UserRole.departmentManager, dept: _mine, depts: [_mine])
        ..rolePermissions = RolePermissionsConfig({
          'departmentManager': {RolePermission.sendNotifications.key},
        });
      expect(store.canSendNotifications, isTrue, reason: 'يكتب الطلب');
      expect(store.canApprove(_request(ApprovalType.notifySend)), isFalse, reason: 'ولا يبتّ فيه');
    });

    test('اعتماد إضافة المشاريع بمنحة داخل نطاقها', () {
      final store = AppStore()
        ..currentUser = _user(grants: {'apr': const GrantScope(departmentIds: [_mine])});
      expect(store.canApprove(_request(ApprovalType.projectCreate)), isTrue);
      expect(store.canApprove(_request(ApprovalType.projectCreate, dept: _other)), isFalse);
    });

    test('وبلا منحة لا اعتماد', () {
      final store = AppStore()..currentUser = _user();
      expect(store.canApprove(_request(ApprovalType.projectCreate)), isFalse);
    });

    // العمل ليس بوابة: أقرب من يعرف أولويات الإدارة يبتّ فيه.
    test('إضافة عمل يعتمدها مدير الإدارة صاحبته', () {
      final store = AppStore()
        ..currentUser = _user(role: UserRole.departmentManager, dept: _mine, depts: [_mine]);
      expect(store.canApprove(_request(ApprovalType.workCreate)), isTrue);
      expect(store.canApprove(_request(ApprovalType.workCreate, dept: _other)), isFalse);
    });

    test('وموظفٌ عادي لا يعتمد عملاً ولو في إدارته', () {
      final store = AppStore()..currentUser = _user();
      expect(store.canApprove(_request(ApprovalType.workCreate)), isFalse);
    });

    test('ومسؤول النظام يبتّ في كل شيء', () {
      final store = AppStore()..currentUser = _user(role: UserRole.systemAdmin, dept: null);
      for (final t in ApprovalType.values) {
        expect(store.canApprove(_request(t)), isTrue, reason: t.label);
      }
    });
  });

  group('الطلب مفتوح والبتّ محكوم', () {
    test('الموظف يطلب إضافة مشروع في إدارته', () {
      final store = AppStore()..currentUser = _user();
      expect(store.canRequestNewProject(_mine), isTrue);
      expect(store.canRequestNewProject(_other), isFalse);
      expect(store.canApprove(_request(ApprovalType.projectCreate)), isFalse,
          reason: 'يطلب ولا يعتمد');
    });

    test('ويطلب إضافة عمل في إدارته', () {
      final store = AppStore()..currentUser = _user();
      expect(store.canRequestNewWork(_mine), isTrue);
      expect(store.canRequestNewWork(_other), isFalse);
      expect(store.canRequestNewWork(null), isFalse);
    });
  });

  group('المنحة خارج شبكة الأدوار', () {
    test('لا تظهر في «صلاحيات الأدوار»', () {
      for (final p in RolePermission.scoped) {
        expect(RolePermission.roleAssignable, isNot(contains(p)), reason: p.label);
      }
    });

    test('ولا يمنحها دور مهما ضُبط', () {
      final store = AppStore()
        ..currentUser = _user()
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'mpr', 'apr'},
        });
      expect(store.canCreateIn(_mine), isFalse,
          reason: 'كُتبت في إعدادات الدور ولا أثر لها — تُمنح لفرد بنطاق وحده');
    });
  });

  group('مقارنة النطاق ببطاقة الدخول', () {
    test('نطاق مختلف عن البطاقة يُكشف', () {
      final store = AppStore()
        ..currentUser = _user(grants: {'mpr': const GrantScope(departmentIds: [_mine, _other])});
      final inToken = store.tokenScopeFor(
        {'scopes': {'mpr': [_mine]}},
        RolePermission.manageProjects,
      );
      expect(inToken, isNot(store.scopeFor(RolePermission.manageProjects)));
    });

    test('وبطاقة بلا نطاقات إطلاقاً تُقرأ فارغة لا شاملة', () {
      final store = AppStore()..currentUser = _user();
      final inToken = store.tokenScopeFor(const {}, RolePermission.manageProjects);
      expect(inToken.isEmpty, isTrue);
      expect(inToken.allDepartments, isFalse);
    });

    test('و«كل الإدارات» تُقرأ من النجمة', () {
      final store = AppStore()..currentUser = _user();
      final inToken = store.tokenScopeFor(
        {'scopes': {'mpr': '*'}},
        RolePermission.manageProjects,
      );
      expect(inToken.allDepartments, isTrue);
    });
  });
}
