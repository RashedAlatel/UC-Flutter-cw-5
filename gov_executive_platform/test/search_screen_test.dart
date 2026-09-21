// شاشةُ البحث الموحّدة — ما تعرضه، وما تقوله حين لا تعرض.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **النوعُ يفصل**: شريحةُ «مشروع» تُخفي الأعمال، و«عمل» تُخفي المشاريع.
//     وهو الفلترُ الذي أوجب هذه الشاشة أصلاً — لا معنى له في الشاشتين
//     القائمتين.
//
// (٢) **وحدودُ البيانات تُقال**: العملُ بلا قسمٍ وبلا مديرِ مشروع، فاختيارُ
//     أيّهما يُخرج الأعمال. وفراغٌ صامتٌ يُقرأ عطلاً — وقد قرأه مسؤولُ
//     النظام كذلك مرّةً وكلّف يوماً.
//
// (٣) **والفلاترُ تبقى**: تُحفظ في المتجر لا في حالة الودجة، فلا تُفقد عند
//     فتح مشروعٍ والعودة. وحالةُ الودجة تموت بخروجها من الشجرة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/record_filter.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/search_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _dept = 'd-1';

AppStore _store() => AppStore()
  ..currentUser = AppUser(
    id: 'u-admin',
    name: 'مسؤول',
    email: 'a@moj.gov.kw',
    phone: '',
    role: UserRole.systemAdmin,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  )
  ..departments = [
    const Department(
      id: _dept,
      name: 'إدارة تطوير النظم',
      headName: '',
      colorValue: 0xFF0B5D3B,
      iconKey: 'apps',
    ),
  ]
  ..projects = [
    Project(
      id: 'p1',
      departmentId: _dept,
      name: 'رقمنة صحيفة الدعوى',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2030, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 30,
    ),
  ]
  ..works = [
    WorkItem(
      id: 'w1',
      title: 'صيانة الخوادم',
      description: '',
      departmentId: _dept,
      assigneeUid: 'u-x',
      assigneeName: 'منفّذ',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      dueDate: DateTime(2030, 1, 1),
      createdByUid: 'u-1',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SearchScreen()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('تعرض النوعين معاً بلا فلتر', (tester) async {
    await _pump(tester, _store());
    expect(find.text('رقمنة صحيفة الدعوى'), findsOneWidget);
    expect(find.text('صيانة الخوادم'), findsOneWidget);
    expect(find.textContaining('2 سجلاً'), findsOneWidget);
  });

  testWidgets('والنوعُ يفصل: «مشروع» تُخفي الأعمال', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(kinds: {RecordKind.project}));
    await _pump(tester, store);
    expect(find.text('رقمنة صحيفة الدعوى'), findsOneWidget);
    expect(find.text('صيانة الخوادم'), findsNothing);
  });

  testWidgets('و«عمل» تُخفي المشاريع', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(kinds: {RecordKind.work}));
    await _pump(tester, store);
    expect(find.text('صيانة الخوادم'), findsOneWidget);
    expect(find.text('رقمنة صحيفة الدعوى'), findsNothing);
  });

  testWidgets('وعددُ ما طُوي يُقال', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(query: 'رقمنة'));
    await _pump(tester, store);
    expect(find.textContaining('1 من 2'), findsOneWidget);
  });

  // ــ وحدُّ البيانات يُقال لا يُترك يُستنتج ــ
  testWidgets('واختيارُ قسمٍ يقول إن الأعمالَ لا تتبع أقساماً', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(sectionId: 's-1'));
    await _pump(tester, store);
    expect(find.textContaining('لا تتبع أقساماً'), findsOneWidget);
  });

  testWidgets('واختيارُ مديرٍ يقول إن للعمل مُسنَداً إليه لا مديراً', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(managerUid: 'u-m'));
    await _pump(tester, store);
    expect(find.textContaining('مُسنَدٌ إليه'), findsOneWidget);
  });

  testWidgets('وبلا نتيجةٍ تُقال طريقُ الخروج لا الفراغُ وحده', (tester) async {
    final store = _store()
      ..setRecordFilter(kSearchFilterKey, const RecordFilter(query: 'لا يوجد شيء بهذا'));
    await _pump(tester, store);
    expect(find.textContaining('إعادة الضبط'), findsWidgets);
  });

  testWidgets('وزرُّ إعادة الضبط لا يظهر بلا فلتر', (tester) async {
    await _pump(tester, _store());
    expect(find.textContaining('إعادة ضبط الفلاتر'), findsNothing);
  });

  testWidgets('ويظهر بعددِ ما فُعِّل', (tester) async {
    final store = _store()
      ..setRecordFilter(
          kSearchFilterKey, const RecordFilter(query: 'رقمنة', departmentId: _dept));
    await _pump(tester, store);
    expect(find.textContaining('إعادة ضبط الفلاتر (2)'), findsOneWidget);
  });

  // ــــ وقيمةٌ ليست بين الخيارات لا تُسقط الشاشة ــــ
  //
  // `DropdownButtonFormField` **يرمي** إن كانت قيمتُه ليست في عناصره. وذلك
  // يقع في العمل: قسمٌ مختارٌ ثم مُسحت إدارتُه، أو مستخدمٌ أُوقف حسابُه،
  // أو تصنيفٌ حُذف — والفلترُ يبقى في المتجر طولَ الجلسة فيبقى معه
  // الانهيار. وقد كشفه اختبارُ القسم أعلاه قبل أن يكشفه مستخدم.
  group('وقيمةٌ غائبةٌ عن الخيارات', () {
    testWidgets('قسمٌ لا وجود له لا يُسقط الشاشة', (tester) async {
      final store = _store()
        ..setRecordFilter(kSearchFilterKey, const RecordFilter(sectionId: 'ما-حُذف'));
      await _pump(tester, store);
      expect(find.textContaining('البحث'), findsWidgets);
    });

    testWidgets('ومستخدمٌ لا وجود له كذلك', (tester) async {
      final store = _store()
        ..setRecordFilter(
            kSearchFilterKey, const RecordFilter(executorUid: 'حسابٌ-مُوقف'));
      await _pump(tester, store);
      expect(find.textContaining('البحث'), findsWidgets);
    });

    testWidgets('وإدارةٌ لا وجود لها كذلك', (tester) async {
      final store = _store()
        ..setRecordFilter(
            kSearchFilterKey, const RecordFilter(departmentId: 'إدارةٌ-مُلغاة'));
      await _pump(tester, store);
      expect(find.textContaining('البحث'), findsWidgets);
    });
  });

  // ــــ والفلاترُ تبقى طوال الجلسة ــــ
  //
  // تُحفظ في المتجر لا في حالة الودجة. وهذا ما يُقاس: بناءُ الشاشة من جديد
  // — كما يقع عند فتح مشروعٍ والعودة — يجدها كما تُركت.
  group('وبقاءُ الفلاتر', () {
    test('تبقى بعد إعادة بناء الشاشة', () {
      final store = _store()
        ..setRecordFilter(kSearchFilterKey, const RecordFilter(departmentId: _dept));
      expect(store.recordFilterFor(kSearchFilterKey).departmentId, _dept);
    });

    // ــ ولا تتلاقح الشاشات ــ
    //
    // ولو كانت خانةً واحدة لَضيّق تصفيةُ المشاريع صفحةَ الأعمال معها، فيرى
    // المستخدم قائمةً مصفّاة لم يصفِّها هو.
    test('وخانةُ كلِّ شاشةٍ مستقلّة', () {
      final store = _store()
        ..setRecordFilter('projects', const RecordFilter(departmentId: _dept));
      expect(store.recordFilterFor('works').departmentId, isNull);
      expect(store.recordFilterFor(kSearchFilterKey).departmentId, isNull);
    });

    test('ومسحُها يُصفّرها', () {
      final store = _store()
        ..setRecordFilter(kSearchFilterKey, const RecordFilter(departmentId: _dept))
        ..clearRecordFilter(kSearchFilterKey);
      expect(store.recordFilterFor(kSearchFilterKey).isEmpty, isTrue);
    });
  });
}
