// مركزُ قيادة القطاع: ما يعرضه، ولمن، وحين لا يوجد شيء.
//
// ــــ ما يُقاس ــــ
//
// (١) **أنّه يعرض ما يحتاج تدخّلاً لا كلَّ شيء** — وهي القاعدةُ التي بُني
//     لأجلها: «الإدارةُ بالاستثناء».
// (٢) وأنّ **الفراغَ يُقال** ولا يُترك صفحةً بيضاء: منصّةٌ كلُّ شيءٍ فيها
//     يسير في موعده يجب أن تقول ذلك صراحةً.
// (٣) وأنّ **المدخلَ لا يظهر لمن لا صلاحيةَ له** — وهو ترتيبٌ لا حراسة:
//     القواعدُ لم تتغيّر، والبياناتُ مصفّاةٌ بنطاق القارئ أصلاً.
// (٤) وأنّ **الشاشةَ تُبنى على مقاس الهاتف** بلا خروج نصّ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/command_center_screen.dart';
import 'package:gov_exec_platform/screens/master_calendar_screen.dart';
import 'package:gov_exec_platform/screens/team_workload_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-it';

AppUser _user({
  UserRole role = UserRole.systemAdmin,
  Map<String, bool> overrides = const {},
}) =>
    AppUser(
      id: 'u1',
      name: 'مدير القطاع',
      email: 'head@moj.gov.kw',
      phone: '',
      role: role,
      permissionOverrides: overrides,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project({
  String id = 'p1',
  String name = 'مشروعٌ متأخّر',
  int dueInDays = -20,
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: name,
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime.now().add(Duration(days: dueInDays)),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      nextAction: 'خطوةٌ تالية',
      executorUids: const ['u1'],
    );

AppStore _store({List<Project> projects = const [], AppUser? user}) => AppStore()
  ..currentUser = user ?? _user()
  ..users = [user ?? _user()]
  ..departments = const [
    Department(
        id: _dept,
        name: 'إدارة نظم المعلومات',
        headName: 'رئيس',
        colorValue: 0xFF1B5E4A,
        iconKey: 'settings',
        sectorId: 'it'),
  ]
  ..projects = projects
  // و«حُدِّث اليوم» لكلّ مشروع: `lastUpdateByProject` مشتقٌّ من التحديثات
  // اليومية لا مكتوبٌ بيده، فلا يطغى بابُ الإهمال على ما يُقاس.
  ..dailyUpdates = [
    for (final p in projects)
      DailyUpdate(
        id: 'u-${p.id}',
        projectId: p.id,
        departmentId: _dept,
        authorUid: 'u1',
        authorName: 'مدير القطاع',
        date: DateTime.now(),
        achievements: 'تقدّم',
        completedTasks: const [],
        newRisks: const [],
        blockers: const [],
        decisionsRequired: const [],
        progressPercent: 40,
      ),
  ];

Future<void> _pump(WidgetTester tester, Widget screen, AppStore store,
    {Size size = const Size(1400, 2400)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: screen),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('مركزُ القيادة يعرض ما يحتاج تدخّلاً', () {
    testWidgets('مشروعٌ متأخّرٌ يظهر باسمه وسببه', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const CommandCenterScreen(), store);
      expect(find.text('مشروعٌ متأخّر'), findsWidgets);
      expect(find.textContaining('متأخّر'), findsWidgets);
    });

    // ــ والفراغُ يُقال ولا يُترك صفحةً بيضاء ــ
    testWidgets('وبلا شيءٍ يحتاج تدخّلاً تُقال الطمأنينةُ صراحةً', (tester) async {
      final store = _store(projects: [_project(dueInDays: 90)]);
      await _pump(tester, const CommandCenterScreen(), store);
      expect(find.text('لا شيءَ يحتاج تدخّلاً'), findsOneWidget);
    });

    testWidgets('ومنصّةٌ بلا مشاريعَ لا تسقط', (tester) async {
      await _pump(tester, const CommandCenterScreen(), _store());
      expect(find.text('لا شيءَ يحتاج تدخّلاً'), findsOneWidget);
    });

    testWidgets('وتُبنى على مقاس الهاتف بلا خروجِ نصّ', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const CommandCenterScreen(), store,
          size: const Size(390, 1800));
      expect(tester.takeException(), isNull);
    });
  });

  group('والمدخلُ يظهر بصلاحيته', () {
    test('مسؤولُ النظام يراه', () {
      expect(navKeysFor(_store()), contains(NavKey.commandCenter));
    });

    test('ومديرُ الإدارة يراه', () {
      final store = _store(user: _user(role: UserRole.departmentManager));
      expect(navKeysFor(store), contains(NavKey.commandCenter));
    });

    // ــ ومغلقٌ لدور «موظف» كـ`dsh` تماماً ــ
    //
    // شاشتُه تبدأ من عمله لا من لوحة المنصة. **وهو ترتيبٌ لا حراسة**:
    // قواعدُ Firestore لم تتغيّر، ومن أُخفي عنه المدخلُ لم يُمنع من بيانٍ
    // كان يراه.
    test('والموظّفُ لا يراه', () {
      final store = _store(user: _user(role: UserRole.employee));
      expect(navKeysFor(store), isNot(contains(NavKey.commandCenter)));
    });

    test('ويُفتح لفردٍ باستثناءٍ من مسؤول النظام', () {
      final store = _store(
        user: _user(role: UserRole.employee, overrides: const {'vcc': true}),
      );
      expect(navKeysFor(store), contains(NavKey.commandCenter));
    });
  });

  group('وحملُ الفريق', () {
    testWidgets('يعرض تصنيفاتِ الحمل الأربعة', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const TeamWorkloadScreen(), store);
      expect(find.text('حملٌ زائد'), findsWidgets);
      expect(find.text('حملٌ خفيف'), findsWidgets);
    });

    testWidgets('وبلا فريقٍ يُقال ذلك', (tester) async {
      final store = _store()..users = const [];
      await _pump(tester, const TeamWorkloadScreen(), store);
      expect(find.textContaining('لا موظّفين'), findsWidgets);
    });
  });

  group('وتقويمُ القطاع', () {
    testWidgets('يعرض الشهرَ ويطلب اختيارَ يوم', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const MasterCalendarScreen(), store);
      expect(find.text('اختر يوماً لعرض أحداثه'), findsOneWidget);
    });

    // ــ والأحداثُ مُشتقّةٌ لا مخزَّنة ــ
    //
    // فمشروعٌ واحدٌ يُنتج حدثَي بدايةٍ واستحقاقٍ بلا أن يُكتب حرفٌ في قاعدة
    // البيانات.
    testWidgets('ومشروعٌ واحدٌ يُنتج حدثين بلا مجموعةِ أحداث', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const MasterCalendarScreen(), store);
      expect(find.textContaining('حدثاً في النطاق المعروض'), findsOneWidget);
    });

    testWidgets('وعلى مقاس الهاتف لا يخرج شيء', (tester) async {
      final store = _store(projects: [_project()]);
      await _pump(tester, const MasterCalendarScreen(), store,
          size: const Size(390, 1800));
      expect(tester.takeException(), isNull);
    });
  });
}
