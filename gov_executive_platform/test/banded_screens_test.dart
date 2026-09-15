// الشريط القيادي على كل شاشات المنصة.
//
// الشريط الآن ترويسة أربع عشرة شاشة، لا لوحة القيادة وحدها. وخطره أنه عريض
// وملوّن: عنوانٌ أطول قليلاً، أو زرّان بدل زر، يخرجان من الشاشة على الجوال
// **بصمت** — فـ`Wrap` و`Row` يعطيان أبناءهما عرضاً غير محدود ولا يرميان
// استثناءً. ولذلك القياس هنا هندسي لا اعتماداً على `takeException`.
//
// وهذا الملف يمرّ على كل شاشة مصفَّحة بمقاس هاتف حقيقي.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/custom_role.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/audit_log_screen.dart';
import 'package:gov_exec_platform/screens/decision_center_screen.dart';
import 'package:gov_exec_platform/screens/departments_list_screen.dart';
import 'package:gov_exec_platform/screens/feedback_screen.dart';
import 'package:gov_exec_platform/screens/my_assignments_screen.dart';
import 'package:gov_exec_platform/screens/people_tracking_screen.dart';
import 'package:gov_exec_platform/screens/projects_list_screen.dart';
import 'package:gov_exec_platform/screens/registration_settings_screen.dart';
import 'package:gov_exec_platform/screens/role_permissions_screen.dart';
import 'package:gov_exec_platform/screens/roles_management_screen.dart';
import 'package:gov_exec_platform/screens/user_management_screen.dart';
import 'package:gov_exec_platform/screens/works_list_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/command_band.dart';

const _dept = 'd-tech';

AppUser _user(String id, String name, UserRole role) => AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(String id) => Project(
      id: id,
      departmentId: _dept,
      name: 'نظام الاستشارات الأسرية $id',
      description: 'وصف',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.high,
      progressPercent: 60,
      executorNames: const ['إسحاق الخباز (تحليل ودراسة)', 'أحمد المليجي'],
      managerUids: const ['admin'],
    );

AppStore _store() => AppStore()
  ..currentUser = _user('admin', 'مسؤول النظام', UserRole.systemAdmin)
  ..users = [
    _user('admin', 'مسؤول النظام', UserRole.systemAdmin),
    _user('u1', 'عبدالرحمن بن عبدالعزيز المطيري', UserRole.employee),
  ]
  ..departments = [
    Department(
      id: _dept,
      name: 'الإدارة العامة لتقنية المعلومات والتحول الرقمي',
      headName: 'رئيس القسم',
      colorValue: 0xFF1B5E4A,
      iconKey: 'settings',
    ),
  ]
  ..customRoles = [CustomRole(id: 'r1', name: 'منسّق تنفيذي')]
  ..projects = [_project('p1'), _project('p2')]
  ..works = [
    WorkItem(
      id: 'w1',
      title: 'جرد المستودع',
      description: '',
      departmentId: _dept,
      assigneeUid: 'u1',
      assigneeName: 'عبدالرحمن بن عبدالعزيز المطيري',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      dueDate: DateTime(2099, 1, 1),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

/// كل نصّ مرسوم يقع داخل عرض الشاشة، عدا ما يُمرَّر أفقياً عمداً.
void _expectInside(WidgetTester tester, Size size, String screen) {
  final offenders = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! Text) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize || !object.attached) continue;

    var scrolls = false;
    element.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Scrollable && (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
        scrolls = true;
        return false;
      }
      return true;
    });
    if (scrolls) continue;

    // الزاويتان تُحوَّلان كلتاهما: عناوين الحقول العائمة تُصغَّر بتحويل مقياس،
    // فقياس العرض وحده يبالغ فيها ويُبلّغ عن خروجٍ لا يقع.
    final a = object.localToGlobal(Offset.zero).dx;
    final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
    final left = a < b ? a : b;
    final right = a < b ? b : a;
    if (left < -0.5 || right > size.width + 0.5) {
      offenders.add('«${widget.data}» من ${left.toStringAsFixed(0)} إلى ${right.toStringAsFixed(0)}');
    }
  }
  expect(offenders, isEmpty, reason: 'في «$screen» خرجت نصوص عن الشاشة:\n${offenders.join('\n')}');
}

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: _store(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: screen),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  // أضيق ما يُستعمل عملياً (آيفون SE) وأشيع مقاس حديث (آيفون ١٦ برو).
  const phones = {'iPhone SE': Size(375, 1400), 'iPhone 16 Pro': Size(402, 1400)};

  final screens = <String, Widget>{
    'المشاريع': const ProjectsListScreen(),
    'الأعمال': const WorksListScreen(),
    'الإدارات': const DepartmentsListScreen(),
    'المُسنَد إليّ': const MyAssignmentsScreen(),
    'الشكاوى والاقتراحات': const FeedbackScreen(),
    'مركز القرار': const DecisionCenterScreen(),
    'متابعة الأشخاص': const PeopleTrackingScreen(),
    'إدارة المستخدمين': const UserManagementScreen(),
    'إدارة الأدوار': const RolesManagementScreen(),
    'صلاحيات الأدوار': const RolePermissionsScreen(),
    'سجل التدقيق': const AuditLogScreen(),
    'سياسة التسجيل': const RegistrationSettingsScreen(),
  };

  for (final phone in phones.entries) {
    group('بمقاس ${phone.key}', () {
      for (final screen in screens.entries) {
        testWidgets('${screen.key}: الشريط لا يُخرج نصاً عن الشاشة', (tester) async {
          await _pump(tester, screen.value, phone.value);
          expect(tester.takeException(), isNull);
          expect(find.byType(CommandBand), findsOneWidget, reason: 'الشاشة بلا شريط');
          _expectInside(tester, phone.value, screen.key);
        });
      }
    });
  }

  testWidgets('الشريط يظهر على الشاشة العريضة كذلك', (tester) async {
    await _pump(tester, const ProjectsListScreen(), const Size(1400, 1200));
    expect(find.byType(CommandBand), findsOneWidget);
    _expectInside(tester, const Size(1400, 1200), 'المشاريع — عريض');
  });
}
