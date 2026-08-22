// أعطالٌ أربعة كانت تمرّ صامتة على صفحة الموظف، وترتيبُها.
//
// وأخطرها الأول: المشروع المُعتمَد كان يخرج **بلا عضو واحد**، فلا يظهر في
// «المُسنَد إليّ» ولا لمن قدّم الطلب وسجّل نفسه منفّذاً فيه. ولم يسقط أي
// اختبار، لأن الكتابة تقع في دالة خلفية لا يقرؤها `flutter test` — فيُقاس
// هنا **ما يُرسَل إليها**، ويُقاس على الخادم بفحص منفصل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_sort.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/models/work_sort.dart';
import 'package:gov_exec_platform/screens/works_list_screen.dart';
import 'package:gov_exec_platform/widgets/user_permissions_dialog.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _dept = 'd1';

AppUser _user({
  String id = 'u1',
  UserRole role = UserRole.employee,
  String? dept = _dept,
  Map<String, bool> overrides = const {},
}) =>
    AppUser(
      id: id,
      name: 'موظف',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
      permissionOverrides: overrides,
    );

Project _project(String id, {DateTime? createdAt, DateTime? start}) => Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: start ?? DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      createdAt: createdAt,
    );

void main() {
  _scopeEditorGuards();
  _newestSortGuards();

  group('عضوية المشروع تصل إلى المستند', () {
    test('المشروع يُقرأ بأعضائه ويُكتب بهم', () {
      final p = Project.fromMapForTest('p1', {
        'name': 'مشروع',
        'managerUids': ['u1'],
        'executorUids': ['u2'],
      });
      expect(p.hasMember('u1'), isTrue);
      expect(p.hasMember('u2'), isTrue);
      // الحقل المفرد الموروث يبقى متسقاً مع أول عنصر — قاعدة الأمان تشترطه.
      expect(p.toMap()['managerUid'], 'u1');
      expect(p.toMap()['managerUids'], ['u1']);
      expect(p.toMap()['executorUids'], ['u2']);
    });

    test('ومشروعٌ بلا أعضاء لا يخصّ أحداً', () {
      // هذا ما كان يُكتب فعلاً عند كل اعتماد طلب — والسبب في أن «المُسنَد
      // إليّ» تبقى فارغة مهما أُضيف من مشاريع.
      final p = Project.fromMapForTest('p1', {'name': 'مشروع'});
      expect(p.hasMember('u1'), isFalse);
      expect(p.managerUid, isNull);
    });
  });

  group('تاريخ الإضافة والترتيب بالأحدث', () {
    test('مستند بلا تاريخ إضافة يُقرأ بـ null لا بتاريخ مختلق', () {
      // `DateTime.now()` هنا يجعل كل مشروع مستورد «مُضافاً الآن» فيتصدّر
      // الترتيب كذباً — وهو أسوأ من ألّا يُرتَّب.
      final p = Project.fromMapForTest('p1', {'name': 'مشروع'});
      expect(p.createdAt, isNull);
    });

    test('الأحدث إضافةً يقدّم المُضاف حديثاً لا المبتدئ حديثاً', () {
      final oldStartNewAdd = _project('p1', start: DateTime(2020, 1, 1), createdAt: DateTime(2026, 8, 1));
      final newStartOldAdd = _project('p2', start: DateTime(2026, 7, 1), createdAt: DateTime(2026, 2, 1));
      final ordered = sortProjects(
        projects: [newStartOldAdd, oldStartNewAdd],
        sort: ProjectSort.newest,
      );
      expect(ordered.map((p) => p.id), ['p1', 'p2']);
    });

    test('والمستورد بلا تاريخ إضافة يُرتَّب ببدئه ولا يُسقط الترتيب', () {
      final imported = _project('old', start: DateTime(2019, 1, 1));
      final recent = _project('new', createdAt: DateTime(2026, 8, 1));
      final ordered = sortProjects(
        projects: [imported, recent],
        sort: ProjectSort.newest,
      );
      expect(ordered.map((p) => p.id), ['new', 'old']);
    });
  });

  group('ترتيب الأعمال', () {
    WorkItem work(String id, {required DateTime createdAt, double progress = 0}) => WorkItem(
          id: id,
          title: 'عمل $id',
          description: '',
          departmentId: _dept,
          assigneeUid: 'u1',
          assigneeName: 'موظف',
          status: TaskStatus.todo,
          priority: PriorityLevel.medium,
          progressPercent: progress,
          dueDate: DateTime(2099, 1, 1),
          createdByUid: 'admin',
          createdAt: createdAt,
        );

    test('الأحدث إضافةً أولاً', () {
      final sorted = sortWorks([
        work('a', createdAt: DateTime(2026, 1, 1)),
        work('b', createdAt: DateTime(2026, 8, 1)),
      ], WorkSort.newest);
      expect(sorted.map((w) => w.id), ['b', 'a']);
    });

    test('والأقل إنجازاً أولاً', () {
      final sorted = sortWorks([
        work('a', createdAt: DateTime(2026, 1, 1), progress: 90),
        work('b', createdAt: DateTime(2026, 1, 1), progress: 10),
      ], WorkSort.progress);
      expect(sorted.map((w) => w.id), ['b', 'a']);
    });
  });

  group('مفاتيح صفحتَي الموظف', () {
    test('الموظف بلا المفتاحين، وبقية الأدوار بهما', () {
      final defaults = RolePermissionsConfig.defaults();
      expect(defaults.has(UserRole.employee, RolePermission.viewDashboard), isFalse);
      expect(defaults.has(UserRole.employee, RolePermission.viewDepartmentPage), isFalse);
      for (final role in const [
        UserRole.executiveViewer,
        UserRole.departmentManager,
        UserRole.projectOfficer,
      ]) {
        expect(defaults.has(role, RolePermission.viewDashboard), isTrue, reason: role.name);
        expect(defaults.has(role, RolePermission.viewDepartmentPage), isTrue, reason: role.name);
      }
    });

    test('ومسؤول النظام لا يُفحص بالأعلام', () {
      final store = AppStore()..currentUser = _user(role: UserRole.systemAdmin, dept: null);
      expect(store.hasPermission(RolePermission.viewDashboard), isTrue);
    });

    test('ومسؤول النظام يفتحها لموظف بعينه', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {RolePermission.viewDashboard.key: true})
        ..rolePermissions = RolePermissionsConfig.defaults();
      expect(store.hasPermission(RolePermission.viewDashboard), isTrue);
      expect(store.hasPermission(RolePermission.viewDepartmentPage), isFalse,
          reason: 'المفتاحان منفصلان — فتحُ أحدهما لا يفتح الآخر');
    });

    test('مفتاحٌ لم يعرفه المستند المخزَّن يُقرأ من المبدئي لا منعاً', () {
      // مستند settings/rolePermissions مكتوبٌ فعلاً في المنصة الحيّة بلا
      // 'dsh' ولا 'dpg'. ولولا هذا لفقد كل مستخدم قائم — غير الموظف —
      // الصفحتين لحظة النشر، بلا أن يقرّر أحد منعهما.
      final stored = RolePermissionsConfig.fromMap({
        'executiveViewer': ['vad', 'mr', 'agd'],
        'departmentManager': ['mw'],
        'projectOfficer': <String>[],
        'employee': <String>[],
        // بلا '_knownKeys' — كما كُتب قبل وجود المفتاحين.
      });
      expect(stored.has(UserRole.departmentManager, RolePermission.viewDashboard), isTrue);
      expect(stored.has(UserRole.employee, RolePermission.viewDashboard), isFalse,
          reason: 'والموظف يبقى بلا المفتاح — المبدئي لا يمنحه إياه');
    });

    test('وما مُنع صراحةً بعد أن عرفه المستند يبقى ممنوعاً', () {
      final stored = RolePermissionsConfig.fromMap({
        'departmentManager': ['mw'],
        RolePermissionsConfig.knownKeysField: RolePermission.values.map((p) => p.key).toList(),
      });
      expect(stored.has(UserRole.departmentManager, RolePermission.viewDashboard), isFalse,
          reason: 'المستند يعرف المفتاح ولم يمنحه — فهذا منعٌ لا جهل');
    });
  });

  group('نموذج إضافة عمل', () {
    Future<void> pump(WidgetTester tester, AppStore store) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: WorkFormDialog()),
          ),
        ),
      ));
      await tester.pump();
    }

    AppStore store({required bool canManage}) => AppStore()
      ..currentUser = _user(overrides: canManage ? {RolePermission.manageWorks.key: true} : const {})
      ..rolePermissions = RolePermissionsConfig.defaults()
      ..departments = [
        Department(id: _dept, name: 'الدعم الفني', headName: 'رئيس', colorValue: 0xFF1B5E4A, iconKey: 'build'),
      ];

    testWidgets('من يطلب عملاً يستطيع كتابة اسمه', (tester) async {
      // العطل: كل الحقول كانت مشروطة بـ`canManageWorks`، فالطالب يفتح
      // النموذج ولا يكتب حرفاً — ومسار الطلب في `_submit` شيفرة ميتة.
      await pump(tester, store(canManage: false));
      final title = tester.widget<TextField>(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            (w.decoration?.labelText == 'اسم العمل')),
      );
      expect(title.enabled, isTrue, reason: 'الطالب يكتب اسم العمل');
    });

    testWidgets('ولافتة تقول له إنه طلب', (tester) async {
      await pump(tester, store(canManage: false));
      expect(find.textContaining('طلب إضافة عمل يعتمده مدير الإدارة'), findsOneWidget);
    });

    testWidgets('والحالة تبقى مقفلة عليه', (tester) async {
      await pump(tester, store(canManage: false));
      final status = tester.widget<DropdownButtonFormField<TaskStatus>>(
        find.byType(DropdownButtonFormField<TaskStatus>),
      );
      expect(status.onChanged, isNull, reason: 'الحالة يحدّدها المعتمِد لا الطالب');
    });

    testWidgets('ومن يملك الإدارة لا لافتة له والحالة مفتوحة', (tester) async {
      await pump(tester, store(canManage: true));
      expect(find.textContaining('طلب إضافة عمل يعتمده'), findsNothing);
      final status = tester.widget<DropdownButtonFormField<TaskStatus>>(
        find.byType(DropdownButtonFormField<TaskStatus>),
      );
      expect(status.onChanged, isNotNull);
    });
  });
}

// ــــ محرِّر نطاق المنحة ــــ
//
// «إدارات محدَّدة» كانت **ميتة**: النقر عليها يضبط `GrantScope(departmentIds: [])`،
// وهي `isEmpty` بتعريفها — فالزرّ يرتدّ إلى «مغلقة» ولا تظهر إدارة واحدة.
// وسببها أن الوضع المعروض كان يُشتقّ من القيمة، و«محدَّدة ولم تُختر بعد»
// و«مغلقة» لهما القيمة نفسها ومعنيان مختلفان.
void _scopeEditorGuards() {
  group('محرِّر نطاق المنحة', () {
    Future<void> pump(WidgetTester tester, AppUser target) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = AppStore()
        ..currentUser = _user(id: 'admin', role: UserRole.systemAdmin, dept: null)
        ..users = [target]
        ..rolePermissions = RolePermissionsConfig.defaults()
        ..departments = [
          Department(id: _dept, name: 'الدعم الفني', headName: 'ر', colorValue: 0xFF1B5E4A, iconKey: 'build'),
          Department(id: 'd2', name: 'الشؤون المالية', headName: 'ر', colorValue: 0xFF8E6F2E, iconKey: 'build'),
        ];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: UserPermissionsDialog(user: target)),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('اختيار «إدارات محدَّدة» يُظهر الإدارات ولا يرتدّ', (tester) async {
      await pump(tester, _user());
      expect(find.text('الدعم الفني'), findsNothing, reason: 'قبل الاختيار لا مربعات');

      await tester.tap(find.text('إدارات محدَّدة').first);
      await tester.pump();

      expect(find.text('الدعم الفني'), findsWidgets, reason: 'الإدارات تظهر بعد الاختيار');
      expect(find.text('الشؤون المالية'), findsWidgets);
      expect(find.textContaining('اختر إدارة واحدة على الأقل'), findsWidgets,
          reason: 'ويُقال إن المنحة لا تسري قبل الاختيار');
    });

    testWidgets('ومنحةٌ بإدارات محفوظة تفتح على وضعها', (tester) async {
      final granted = AppUser(
        id: 'u9',
        name: 'موظف',
        email: 'u9@moj.gov.kw',
        phone: '',
        role: UserRole.employee,
        departmentId: _dept,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        scopedGrants: const {'mpr': GrantScope(departmentIds: [_dept])},
      );
      await pump(tester, granted);
      expect(find.text('الدعم الفني'), findsWidgets, reason: 'تُعرض المربعات بلا نقر');
    });
  });
}

// ــــ ترتيب «الأحدث إضافةً» ــــ
//
// العطل الذي يحرسه: المقارنة كانت `(b.createdAt ?? b.startDate)` — أي أنها
// تقارن **تاريخ إضافة** مشروع بـ**تاريخ بدء** آخر. ومشاريع الوزارة المستوردة
// تحمل `startDate: DateTime(2026, 12, 1)` — في المستقبل — فكان كل مشروع
// مستورد يعلو على كل مشروع أضافه المستخدم اليوم.
void _newestSortGuards() {
  group('الأحدث إضافةً', () {
    /// بتاريخ البدء الحقيقي من ministry_import_data.dart — لا تاريخ مخترع.
    Project imported(String id) => Project(
          id: id,
          departmentId: _dept,
          name: 'مشروع مستورد $id',
          description: '',
          startDate: DateTime(2026, 12, 1),
          dueDate: DateTime(2027, 6, 1),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: 0,
        );

    test('المُضاف اليوم يسبق المستورد الذي يبدأ في المستقبل', () {
      final fresh = _project('new', createdAt: DateTime(2026, 8, 22));
      final ordered = sortProjects(
        projects: [imported('old'), fresh],
        sort: ProjectSort.newest,
      );
      expect(ordered.first.id, 'new',
          reason: 'تاريخ بدءٍ في المستقبل لا يجعل المشروع أحدثَ إضافةً');
    });

    test('وبين المعروفة يقدَّم الأحدث', () {
      final ordered = sortProjects(
        projects: [
          _project('a', createdAt: DateTime(2026, 3, 1)),
          _project('b', createdAt: DateTime(2026, 8, 1)),
        ],
        sort: ProjectSort.newest,
      );
      expect(ordered.map((p) => p.id), ['b', 'a']);
    });

    test('وبين المجهولة يبقى تاريخ البدء فيصلاً', () {
      final ordered = sortProjects(
        projects: [
          _project('early', start: DateTime(2025, 1, 1)),
          _project('late', start: DateTime(2026, 12, 1)),
        ],
        sort: ProjectSort.newest,
      );
      expect(ordered.map((p) => p.id), ['late', 'early']);
    });
  });
}
