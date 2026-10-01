// صفحة «المُسنَد إليّ»، ودخول العمل.
//
// ثلاثة أشياء لا تكشفها القراءة:
//
// ١) **الصفحة كانت محجوبة عن مسؤول النظام والمستخدم التنفيذي** بشرطٍ في
//    القائمة الجانبية، بحجّة أن من يرى كل الإدارات «لوحته أصلاً هي كل شيء».
//    وهي حجّة خاطئة: رؤية كل شيء ليست معرفة ما هو عليّ أنا.
//
// ٢) **العضوية لا الدور** هي معيار ما يُعرض. فمن ليس عضواً في شيء يرى حالاً
//    فارغة، ومن هو عضو يرى ما هو عضو فيه — أياً كان دوره.
//
// ٣) **بطاقة العمل كانت بلا `onTap`** إطلاقاً، فمن أُسنِد إليه عمل لا يجد
//    موضعاً يقرأ فيه سجلّه ولا يكتب فيه تحديثه.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/my_assignments_screen.dart';
import 'package:gov_exec_platform/screens/work_detail_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-tech';
const _me = 'me';

AppUser _user(String id, UserRole role) => AppUser(
      id: id,
      name: id == _me ? 'أنا' : 'زميل $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(
  String id, {
  List<String> managerUids = const [],
  List<String> executorUids = const [],
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      managerUids: managerUids,
      executorUids: executorUids,
    );

WorkItem _work(String id, {required String assignee}) => WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: _dept,
      assigneeUid: assignee,
      assigneeName: assignee == _me ? 'أنا' : 'زميل',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 20,
      dueDate: DateTime(2099, 1, 1),
      createdByUid: _me,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store(UserRole role) => AppStore()
  ..currentUser = _user(_me, role)
  ..users = [_user(_me, role), _user('other', UserRole.employee)]
  ..departments = [
    Department(id: _dept, name: 'إدارة تقنية المعلومات', headName: 'رئيس', colorValue: 0xFF1B5E4A, iconKey: 'settings'),
  ]
  ..projects = [
    _project('mine-manager', managerUids: const [_me]),
    _project('mine-executor', executorUids: const [_me]),
    _project('not-mine', managerUids: const ['other']),
  ]
  ..works = [
    _work('mine', assignee: _me),
    _work('theirs', assignee: 'other'),
  ];

Future<void> _pump(WidgetTester tester, Widget child, AppStore store, {Size size = const Size(420, 1400)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // المتجر **فوق** `MaterialApp` كما في `main.dart` بالضبط: وضعُه تحته يجعل
  // كل صفحة تُفتح بـ`push` خارج نطاقه — فينجح الاختبار على شاشةٍ ساكنة
  // ويسقط على أول انتقال، وهو ما لا يقع في التطبيق الحقيقي.
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('المدخل في القائمة الجانبية', () {
    // القرار يُختبر من مصدره `navKeysFor` لا من الشاشة: الشلّ يستورد كل شاشة
    // في المنصة ومنها ما يستورد `package:web`، فلا يُستورَد من اختبار — وهو
    // ما جعل كل شرطٍ في القائمة خارج مدى أي حارس حتى اليوم.
    for (final role in UserRole.values) {
      test('«المُسنَد إليّ» يظهر للدور ${role.name}', () {
        expect(navKeysFor(_store(role)), contains(NavKey.myAssignments),
            reason: 'الصفحة ليست مرتبطة بدور: مضمونها العضوية وحدها');
      });
    }

    test('ويظهر لمن لا عضوية له إطلاقاً', () {
      // مدخلٌ يظهر ويختفي بتبدّل البيانات يُقرأ عطلاً. والحال الفارغة تقول
      // للمستخدم إنه ليس عضواً في شيء — وهذا جوابٌ لا صمت.
      final lonely = AppStore()..currentUser = _user('nobody', UserRole.employee);
      expect(navKeysFor(lonely), contains(NavKey.myAssignments));
    });
  });

  group('ما يُعرض: العضوية لا الدور', () {
    testWidgets('يظهر ما أنا مديره وما أنا منفّذه، دون ما ليس لي', (tester) async {
      await _pump(tester, const MyAssignmentsScreen(), _store(UserRole.employee));
      expect(find.text('مشروع mine-manager'), findsOneWidget);
      expect(find.text('مشروع mine-executor'), findsOneWidget);
      expect(find.text('مشروع not-mine'), findsNothing);
    });

    // كل دور بلا استثناء: شُكي أن العمل لا يظهر لمدير الإدارة والمستخدم
    // التنفيذي ومدير المشروع رغم إسناده إليهم.
    for (final role in UserRole.values) {
      testWidgets('ويظهر العمل المُسنَد إليّ في دور ${role.name}', (tester) async {
        await _pump(tester, const MyAssignmentsScreen(), _store(role));
        expect(find.text('عمل mine'), findsOneWidget);
        expect(find.text('عمل theirs'), findsNothing);
      });
    }

    testWidgets('ومسؤول النظام يرى عضويته هو لا كل المنصة', (tester) async {
      // رؤية كل شيء ليست معرفة ما هو عليّ: الصفحة تُجيب عن الثانية.
      await _pump(tester, const MyAssignmentsScreen(), _store(UserRole.systemAdmin));
      expect(find.text('مشروع mine-manager'), findsOneWidget);
      expect(find.text('مشروع not-mine'), findsNothing);
    });
  });

  group('الدخول إلى العمل', () {
    testWidgets('نقر بطاقة العمل يفتح صفحته', (tester) async {
      await _pump(tester, const MyAssignmentsScreen(), _store(UserRole.employee));
      await tester.tap(find.text('عمل mine'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkDetailScreen), findsOneWidget);
    });

    testWidgets('وفيها زرّ التحديث اليومي للمُسنَد إليه', (tester) async {
      final store = _store(UserRole.employee);
      await _pump(tester, const WorkDetailScreen(workId: 'mine'), store);
      expect(find.text('تحديث يومي'), findsOneWidget);
      expect(find.text('سجل التحديثات اليومية'), findsOneWidget);
    });

    testWidgets('وعملٌ محذوف يقول ذلك ولا يترك شاشة بيضاء', (tester) async {
      await _pump(tester, const WorkDetailScreen(workId: 'ghost'), _store(UserRole.employee));
      expect(find.textContaining('لم يعد موجوداً'), findsOneWidget);
    });
  });
}
