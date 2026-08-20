// نطاق مدير الإدارة، ولافتة رفض القراءة.
//
// حارس عطلٍ وقع فعلاً: مدير إدارة مُسنَد لإدارة فيها مشاريع لم يرَ شيئاً —
// لا مشاريعه ولا حتى التعميمات العامة — وبلا أي رسالة تشرح السبب.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/data_access_banner.dart';

AppUser _manager({String? dept, List<String> depts = const []}) => AppUser(
      id: 'm1',
      name: 'مدير الإدارة',
      email: 'm1@moj.gov.kw',
      phone: '',
      role: UserRole.departmentManager,
      departmentId: dept,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(String id, String dept) => Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 40,
    );

void main() {
  group('نطاق إدارات المدير', () {
    test('القائمة الجمع تُستعمل حين تكون ممتلئة', () {
      final store = AppStore()..currentUser = _manager(dept: 'd1', depts: ['d2', 'd3']);
      expect(store.myDepartmentIds, ['d2', 'd3']);
    });

    // العطل نفسه: حساب أُنشئ قبل وجود حقل الإدارات الجمع يحمل المفرد وحده،
    // فكان نطاقه يصير فارغاً — واستعلامه `departmentId == '__none__'` — فلا
    // يرى مشروعاً واحداً من إدارته.
    test('الرجوع إلى الإدارة المفردة حين تفرغ القائمة', () {
      final store = AppStore()..currentUser = _manager(dept: 'd1');
      expect(store.myDepartmentIds, ['d1']);
    });

    test('بلا إدارة إطلاقاً يبقى النطاق فارغاً', () {
      final store = AppStore()..currentUser = _manager();
      expect(store.myDepartmentIds, isEmpty);
    });

    test('مشاريع المدير تُصفّى بإدارته المفردة لا تُحجب عنه', () {
      final store = AppStore()
        ..currentUser = _manager(dept: 'd1')
        ..projects = [_project('p1', 'd1'), _project('p2', 'd9')];
      expect(store.visibleProjects.map((p) => p.id), ['p1']);
    });
  });

  group('أخطاء قراءة البيانات', () {
    test('لا لافتة حين لا خطأ', () {
      expect(AppStore().hasDataErrors, isFalse);
    });

    test('رفض الصلاحية يُميَّز عن انقطاع الشبكة', () {
      final store = AppStore();
      // نحاكي ما يصل من الخادم عبر المسار العلني نفسه.
      store.dataErrors['projects'] = '[cloud_firestore/permission-denied] Missing or insufficient permissions.';
      expect(store.hasDataErrors, isTrue);
      expect(store.hasPermissionErrors, isTrue);

      store.dataErrors
        ..clear()
        ..['projects'] = '[cloud_firestore/unavailable] Failed to connect';
      expect(store.hasDataErrors, isTrue);
      expect(store.hasPermissionErrors, isFalse);
    });
  });

  group('لافتة رفض القراءة', () {
    Future<void> pump(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: DataAccessBanner()),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('لا تظهر حين لا خطأ', (tester) async {
      await pump(tester, AppStore());
      expect(find.byType(OutlinedButton), findsNothing);
    });

    // جوهر هذه الجولة: رفض الصلاحية كان يعود صامتاً فتبقى الشاشة فارغة بلا
    // سبب. اللافتة تقول صراحةً إن ما يراه المستخدم ناقص لا معدوم.
    testWidgets('تسمّي البيانات المحجوبة وتقود إلى التشخيص', (tester) async {
      final store = AppStore();
      store.dataErrors['projects'] = '[cloud_firestore/permission-denied] Missing or insufficient permissions.';
      store.dataErrors['announcements'] = '[cloud_firestore/permission-denied] Missing or insufficient permissions.';
      await pump(tester, store);

      expect(find.textContaining('صلاحيات حسابك غير مكتملة'), findsOneWidget);
      expect(find.textContaining('projects'), findsOneWidget);
      expect(find.text('تشخيص حسابي'), findsOneWidget);
    });

    testWidgets('عطل الشبكة لا يُلام على الصلاحيات', (tester) async {
      final store = AppStore();
      store.dataErrors['projects'] = '[cloud_firestore/unavailable] Failed to connect';
      await pump(tester, store);
      expect(find.textContaining('تعذّر تحميل بعض البيانات'), findsOneWidget);
    });
  });

  // بصمات الصلاحيات: مسؤول النظام يمنح صلاحية فتُختم على الخادم، بينما يبقى
  // المستخدم حاملاً بطاقته القديمة حتى ينتهي أجل رمزه. فيرى الصلاحية ممنوحة
  // ولا تعمل، ولا شيء يفسّر له السبب — ما لم تُقارَن البصمتان.
  group('مقارنة بصمات الصلاحيات', () {
    test('المتوقَّع يُشتقّ من إعدادات الدور', () {
      final store = AppStore()
        ..currentUser = _manager(dept: 'd1')
        ..rolePermissions = const RolePermissionsConfig({
          'departmentManager': {'mw', 'sap'},
        });
      expect(store.expectedPermissionKeys, {'mw', 'sap'});
    });

    test('بطاقة تنقصها صلاحية ممنوحة تُكشف', () {
      final store = AppStore()
        ..currentUser = _manager(dept: 'd1')
        ..rolePermissions = const RolePermissionsConfig({
          'departmentManager': {'mw', 'sap'},
        });
      final inToken = store.tokenPermissionKeys({
        'perms': {'mw': true, 'sap': false},
      });
      expect(inToken, {'mw'});
      expect(store.expectedPermissionKeys.difference(inToken), {'sap'},
          reason: 'الصلاحية ممنوحة في الإعدادات وغائبة عن البطاقة — وهذا ما يجب أن يُكشف');
    });

    test('بطاقة بلا حقل صلاحيات إطلاقاً لا تُسقط المقارنة', () {
      final store = AppStore()..currentUser = _manager(dept: 'd1');
      expect(store.tokenPermissionKeys(const {}), isEmpty);
    });

    // مسؤول النظام صلاحياته كاملة عبر isAdmin() في القواعد لا عبر أعلام في
    // البطاقة، فمقارنته بها تُنتج اختلافاً وهمياً دائماً ومزامنة لا تنتهي.
    test('مسؤول النظام خارج المقارنة', () {
      final admin = AppStore()
        ..currentUser = AppUser(
          id: 'a1',
          name: 'مسؤول',
          email: 'a@moj.gov.kw',
          phone: '',
          role: UserRole.systemAdmin,
          status: UserStatus.approved,
          createdAt: DateTime(2026, 1, 1),
        );
      expect(admin.expectedPermissionKeys, isEmpty);
    });
  });
}
