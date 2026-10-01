import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/department_section.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/department_detail_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// شاشة الإدارة تعرض شجرة الأقسام: القسم، ثم قسمه الفرعي تحته، ثم المشاريع
/// التي لا قسم لها في مجموعة مستقلة. هذا الاختبار يحرس أن المشروع لا يختفي
/// من الشاشة بسبب التقسيم — وهو الخطر الحقيقي في ميزة كهذه.
AppStore _store({required UserRole role}) {
  final store = AppStore()
    ..currentUser = AppUser(
      id: 'u1',
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '+96555555555',
      role: role,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
      departmentId: 'd1',
      departmentIds: const ['d1'],
    );

  store.departments = const [
    Department(id: 'd1', name: 'إدارة تطوير النظم', headName: 'رئيس الإدارة', colorValue: 0xFF0E4D3C, iconKey: 'memory'),
  ];
  store.sections = const [
    DepartmentSection(id: 's1', departmentId: 'd1', name: 'قسم النظم الآلية'),
    DepartmentSection(id: 's1a', departmentId: 'd1', parentId: 's1', name: 'وحدة الرسوم'),
  ];
  Project p(String id, String name, String? section) => Project(
        id: id,
        departmentId: 'd1',
        name: name,
        description: 'وصف',
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 31),
        status: ProjectStatus.onTrack,
        priority: PriorityLevel.medium,
        progressPercent: 20,
        sectionId: section,
      );
  store.projects = [
    p('p1', 'مشروع داخل القسم', 's1'),
    p('p2', 'مشروع داخل القسم الفرعي', 's1a'),
    p('p3', 'مشروع بلا قسم', null),
  ];
  return store;
}

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.binding.setSurfaceSize(const Size(1100, 2400));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: AppTheme.theme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: DepartmentDetailScreen(departmentId: 'd1')),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('الشجرة تعرض القسم وقسمه الفرعي وكل المشاريع بلا فقد', (tester) async {
    await _pump(tester, _store(role: UserRole.systemAdmin));

    expect(find.text('قسم النظم الآلية'), findsOneWidget);
    expect(find.text('وحدة الرسوم'), findsOneWidget);
    expect(find.text('مشروع داخل القسم'), findsOneWidget);
    expect(find.text('مشروع داخل القسم الفرعي'), findsOneWidget);
    expect(find.text('مشروع بلا قسم'), findsOneWidget);
    expect(find.text('مشاريع بلا قسم'), findsOneWidget);
  });

  testWidgets('عدّاد القسم الأعلى يشمل مشروع قسمه الفرعي', (tester) async {
    await _pump(tester, _store(role: UserRole.systemAdmin));
    expect(find.text('2 مشروعاً'), findsOneWidget); // القسم الأعلى: مشروعه + مشروع الفرعي
    expect(find.text('1 مشروعاً'), findsOneWidget); // القسم الفرعي
  });

  testWidgets('أدوات إدارة الأقسام لا تظهر لموظف', (tester) async {
    await _pump(tester, _store(role: UserRole.employee));
    expect(find.text('إضافة قسم'), findsNothing);
    // الشجرة نفسها تبقى ظاهرة للقراءة.
    expect(find.text('قسم النظم الآلية'), findsOneWidget);
  });

  testWidgets('مسؤول النظام يرى زر إضافة قسم', (tester) async {
    await _pump(tester, _store(role: UserRole.systemAdmin));
    expect(find.text('إضافة قسم'), findsOneWidget);
  });

  testWidgets('بند «نقل القسم إلى إدارة أخرى» لمسؤول النظام وحده', (tester) async {
    await _pump(tester, _store(role: UserRole.systemAdmin));
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('نقل القسم إلى إدارة أخرى'), findsOneWidget);
  });

  testWidgets('مدير الإدارة يدير أقسامه لكن لا ينقلها بين الإدارات', (tester) async {
    await _pump(tester, _store(role: UserRole.departmentManager));
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('إعادة التسمية'), findsOneWidget);
    expect(find.text('نقل القسم إلى إدارة أخرى'), findsNothing);
  });
}
