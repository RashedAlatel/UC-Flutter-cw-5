// شريط التحديد الجماعي في صفحة المشاريع — ظهوره ومداه.
//
// ــــ ما الذي لا تكشفه القراءة؟ ــــ
//
// أن «تحديد الكل» في أكثر المنصات يعني **ما ظهر على الشاشة**. فمن صفّى ٤٧
// مشروعاً متأخراً وضغط «تحديد الكل» يظنّ أنه نبّه سبعةً وأربعين وقد نبّه
// عشرة، ولا شيء يقول له ذلك — لا رسالة ولا عدد.
//
// فالحارس يشترط أن **العدد المكتوب على الزرّ** هو عدد كل المطابق للفلتر،
// وأن التحديد ينتج بالفعل ذلك العدد.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/projects_list_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _dept = 'd-1';

AppUser _u(String id, UserRole role) => AppUser(
      id: id,
      name: 'صاحب $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _p(String id, {required bool late_}) => Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: late_
          ? DateTime.now().subtract(const Duration(days: 9))
          : DateTime.now().add(const Duration(days: 90)),
      status: late_ ? ProjectStatus.delayed : ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      managerUids: const ['me'],
      createdAt: DateTime(2026, 1, 1),
    );

/// اثنا عشر متأخراً وثلاثة على المسار — عددٌ يفوق ما يظهر في نافذة الاختبار،
/// فلو كان التحديد محصوراً بالمعروض لظهر الفرق.
AppStore _store(UserRole role) => AppStore()
  ..currentUser = _u('me', role)
  ..users = [_u('me', role)]
  ..departments = [
    Department(
        id: _dept,
        name: 'إدارة تقنية المعلومات',
        headName: 'رئيس',
        colorValue: 0xFF1B5E4A,
        iconKey: 'settings'),
  ]
  ..projects = [
    for (var i = 0; i < 12; i++) _p('late$i', late_: true),
    for (var i = 0; i < 3; i++) _p('ok$i', late_: false),
  ];

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.theme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: ProjectsListScreen()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// يضبط فلتر الحالة على «متأخر» من القائمة المنسدلة.
Future<void> _filterLate(WidgetTester tester) async {
  final dropdown = find.byType(DropdownButtonFormField<ProjectStatus?>);
  expect(dropdown, findsOneWidget);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text('متأخر').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('بلا فلتر «متأخر» لا يظهر شريط التحديد', (tester) async {
    await _pump(tester, _store(UserRole.departmentManager));
    expect(find.textContaining('تحديد جميع المشاريع المتأخرة'), findsNothing);
  });

  testWidgets('ومعه يظهر، ويحمل عدد كل المطابق للفلتر لا المعروض', (tester) async {
    await _pump(tester, _store(UserRole.departmentManager));
    await _filterLate(tester);
    expect(find.text('تحديد جميع المشاريع المتأخرة الـ12'), findsOneWidget);
    expect(find.textContaining('لا ما يظهر أمامك على الشاشة فقط'), findsOneWidget);
  });

  testWidgets('والتحديد يشمل الاثني عشر كلها', (tester) async {
    await _pump(tester, _store(UserRole.departmentManager));
    await _filterLate(tester);
    final selectAll = find.text('تحديد جميع المشاريع المتأخرة الـ12');
    await tester.ensureVisible(selectAll);
    await tester.pumpAndSettle();
    await tester.tap(selectAll);
    await tester.pumpAndSettle();
    expect(find.text('حُدِّد 12 من 12'), findsOneWidget);
    expect(find.text('إرسال تنبيه التأخير (12)'), findsOneWidget);
  });

  testWidgets('و«موظف» بلا الصلاحية لا يرى الشريط ولا زرّ التنبيه', (tester) async {
    await _pump(tester, _store(UserRole.employee));
    await _filterLate(tester);
    expect(find.textContaining('تحديد جميع المشاريع المتأخرة'), findsNothing);
    expect(find.textContaining('تنبيه 12 مشروعاً متأخراً'), findsNothing);
  });

  testWidgets('ومدير المشروع يراه — الأدوار الثلاثة تملكه افتراضياً', (tester) async {
    await _pump(tester, _store(UserRole.projectOfficer));
    await _filterLate(tester);
    expect(find.text('تحديد جميع المشاريع المتأخرة الـ12'), findsOneWidget);
  });
}
