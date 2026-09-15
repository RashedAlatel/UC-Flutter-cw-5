// صلاحيتان اشتُكي منهما: تخصيص لوحة القيادة، ورفع الشكاوى.
//
// ــ الأولى ــ
// كان زرّ «تخصيص اللوحة» معروضاً لكل مستخدم بلا استثناء، بحجّة أن «كلاً
// يعدّل لوحته هو». وأثرُه أن **مسؤول النظام يضبط لوحة الدور فلا تقع على
// أحد**: أيّ مستخدم خصّص لوحته مرةً واحدة تعلو طبقتُه الشخصية على لوحة
// الدور أبداً. فاشتكى المستخدم من الأمرين معاً — أن الصلاحية ظاهرة لمن لم
// تُمنح له، وأنه لا يستطيع التحكم بلوحة المستخدم التنفيذي. وهما وجهان
// لعطلٍ واحد.
//
// ــ الثانية ــ
// «رفع الشكاوى» كان حقاً مفروضاً بـ`return true` في الشيفرة، فلا سبيل
// لمسؤول النظام إلى ضبطه لدور. وإخراجُه إلى الشبكة خطِرٌ بذاته: المستند
// الحيّ يزعم في `_knownKeys` أنه «يعرف» المفتاح وهو غائب عن كل دور — فيُقرأ
// منعاً، ويفقد كل موظف في الوزارة التبويب لحظة النشر. فالعلامة تحرس ذلك.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

AppUser _user(UserRole role, {Map<String, bool> overrides = const {}}) => AppUser(
      id: 'u',
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      status: UserStatus.approved,
      permissionOverrides: overrides,
      createdAt: DateTime(2026, 1, 1),
    );

const _personal = [DashboardWidgetConfig(id: 'p1', type: DashboardWidgetType.statusPieChart)];
const _role = [DashboardWidgetConfig(id: 'r1', type: DashboardWidgetType.deptBarChart)];

void main() {
  group('تخصيص اللوحة بصلاحية', () {
    test('المستخدم التنفيذي لا يملكها افتراضياً', () {
      final store = AppStore()..currentUser = _user(UserRole.executiveViewer);
      expect(store.canManageDashboard, isFalse,
          reason: 'المبدئي لا يمنح md للمستخدم التنفيذي');
    });

    test('ومدير الإدارة كذلك', () {
      final store = AppStore()..currentUser = _user(UserRole.departmentManager);
      expect(store.canManageDashboard, isFalse);
    });

    test('ومسؤول النظام يملكها', () {
      final store = AppStore()..currentUser = _user(UserRole.systemAdmin);
      expect(store.canManageDashboard, isTrue);
    });

    test('ومن مُنحها فرداً يملكها', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.executiveViewer, overrides: const {'md': true});
      expect(store.canManageDashboard, isTrue);
    });
  });

  group('الطبقة الشخصية تُهمَل لمن لا يملك التخصيص', () {
    // جوهر شكوى «لا أستطيع التحكم في لوحة المستخدم التنفيذي».
    test('لوحة الدور هي ما يُعرض ولو كان له تخصيص محفوظ', () {
      expect(
        DashboardWidgetConfig.resolveLayers(
          personal: _personal,
          role: _role,
          personalAllowed: false,
        ).single.id,
        'r1',
      );
    });

    test('ومن يملكها تُعرض له لوحته هو', () {
      expect(
        DashboardWidgetConfig.resolveLayers(
          personal: _personal,
          role: _role,
          personalAllowed: true,
        ).single.id,
        'p1',
      );
    });

    test('والتخصيص المحفوظ لا يُحذف — يعود إن أُعيدت الصلاحية', () {
      // القرار عرضٌ لا محو: لو حُذف لضاع عمل المستخدم بسحبٍ مؤقت للصلاحية.
      final store = AppStore()
        ..currentUser = _user(UserRole.executiveViewer)
        ..setDashboardWidgetsForTest(_personal);
      expect(store.dashboardWidgets.map((w) => w.id), isNot(contains('p1')));

      store.currentUser = _user(UserRole.executiveViewer, overrides: const {'md': true});
      expect(store.dashboardWidgets.single.id, 'p1');
    });
  });

  group('رفع الشكاوى صار يُضبط للدور', () {
    test('لم يعد حقاً أساسياً مفروضاً', () {
      expect(RolePermission.baseline, isNot(contains(RolePermission.submitFeedback)));
      expect(RolePermission.roleAssignable, contains(RolePermission.submitFeedback),
          reason: 'يجب أن يظهر في شبكة «صلاحيات الأدوار»');
    });

    test('ومن مُنع منه صراحةً لدوره لا يرفع', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = const RolePermissionsConfig({'employee': <String>{}});
      expect(store.canSubmitFeedback, isFalse);
    });

    test('ومن مُنح لدوره يرفع', () {
      final store = AppStore()
        ..currentUser = _user(UserRole.employee)
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'sfb'},
        });
      expect(store.canSubmitFeedback, isTrue);
    });

    // ــ حارس الانتقال، وهو الأهم ــ
    test('مستندٌ حيّ بلا علامة الانتقال يُبقي الحق للجميع', () {
      // هذه صورة المستند المكتوب في المنصة اليوم: يزعم أنه يعرف كل المفاتيح
      // (بما فيها sfb) بينما sfb غائبة عن كل دور لأنها كانت حقاً أساسياً.
      final live = RolePermissionsConfig.fromMap({
        'employee': <String>[],
        'departmentManager': ['mw'],
        RolePermissionsConfig.knownKeysField:
            RolePermission.values.map((p) => p.key).toList(),
      });
      for (final role in UserRole.configurable) {
        expect(live.has(role, RolePermission.submitFeedback), isTrue,
            reason: 'قبل قرار مسؤول النظام لا يُسحب الحق من ${role.name}');
      }
    });

    test('وبعد أول حفظ يصير قرار مسؤول النظام هو الحاكم', () {
      final decided = RolePermissionsConfig.fromMap({
        'employee': <String>[],
        RolePermissionsConfig.knownKeysField:
            RolePermission.values.map((p) => p.key).toList(),
        RolePermissionsConfig.feedbackAssignableField: true,
      });
      expect(decided.has(UserRole.employee, RolePermission.submitFeedback), isFalse);
    });

    test('والحفظ يكتب العلامة', () {
      expect(
        RolePermissionsConfig.defaults().toMap()[RolePermissionsConfig.feedbackAssignableField],
        isTrue,
      );
    });
  });
}
