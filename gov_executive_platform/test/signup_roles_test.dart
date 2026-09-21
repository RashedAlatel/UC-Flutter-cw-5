// الأدوار عند التسجيل، والدور الذي سيُمنح فعلاً عند الاعتماد.
//
// الاختيار في المتصفح **طلب** لا منح، والمنح يقع عند الاعتماد من حمولة
// الطلب. هذان أمران منفصلان، وهذه الاختبارات تحرس كليهما: أن يجد الموظف
// دوره في القائمة، وأن يرى مسؤول النظام ما سيمنحه فعلاً لا ما كُتب له.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/decision_center_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

ApprovalRequest _registration({
  required String description,
  required Map<String, dynamic> payload,
}) =>
    ApprovalRequest(
      id: 'r1',
      type: ApprovalType.registration,
      status: DecisionStatus.pending,
      title: 'طلب تسجيل عضو جديد: فلان',
      description: description,
      priority: PriorityLevel.medium,
      delayImpactDays: 0,
      requestedByUid: 'u1',
      requestedByName: 'فلان',
      requestedDate: DateTime(2026, 8, 20),
      payload: payload,
    );

void main() {
  group('أدوار التسجيل المعروضة', () {
    // القائمة نفسها في `signup_screen.dart` خاصة بحالتها، فيُحرَس هنا العقد
    // الذي تقوم عليه: الأدوار الأربعة موجودة بأسمائها العربية.
    test('الأدوار الأربعة معروفة وبأسمائها', () {
      expect(UserRole.employee.label, 'موظف');
      expect(UserRole.departmentManager.label, 'مدير إدارة');
      expect(UserRole.executiveViewer.label, 'مستخدم تنفيذي');
      expect(UserRole.projectOfficer.label, 'مدير مشروع');
    });

    // البوابة التي لا تُمسّ: «مسؤول نظام» ليس دوراً يُطلب عند التسجيل، لا في
    // القائمة ولا في الأدوار القابلة للضبط.
    test('مسؤول النظام خارج الأدوار القابلة للضبط', () {
      expect(UserRole.configurable, isNot(contains(UserRole.systemAdmin)));
      expect(UserRole.configurable, isNot(contains(UserRole.custom)));
      expect(UserRole.configurable, contains(UserRole.employee));
    });
  });

  group('الدور الذي سيُمنح يُقرأ من الحمولة', () {
    test('طلب تسجيل عادي يعرض دوره', () {
      final r = _registration(
        description: 'الدور المطلوب: موظف',
        payload: {'uid': 'u1', 'requestedRole': 'employee'},
      );
      expect(r.grantedRoleLabel, 'موظف');
    });

    // جوهر هذه الجولة: الوصف يكتبه العميل، والحمولة هي ما تُنفَّذ. فطلبٌ
    // وصفه بريء وحمولته «مسؤول نظام» كان يمرّ باعتمادٍ يبدو روتينياً.
    test('وصفٌ يخالف الحمولة لا يُخفيها', () {
      final r = _registration(
        description: 'الدور المطلوب: موظف',
        payload: {'uid': 'u1', 'requestedRole': 'systemAdmin'},
      );
      expect(r.grantedRoleLabel, 'مسؤول نظام');
    });

    // `UserRole.fromName` ترجع projectOfficer لكل اسم مجهول، فاستعمالها هنا
    // كان سيعرض «مدير مشروع» لحمولة شاذة — أي يُطمئن حيث يجب أن يُنبّه.
    test('اسم دور مجهول يُعرض كما هو لا مترجماً', () {
      final r = _registration(
        description: '',
        payload: {'uid': 'u1', 'requestedRole': 'root'},
      );
      expect(r.grantedRoleLabel, 'root');
    });

    test('حمولة بلا دور لا تعرض شيئاً', () {
      expect(_registration(description: '', payload: {'uid': 'u1'}).grantedRoleLabel, isNull);
      expect(_registration(description: '', payload: {'requestedRole': '  '}).grantedRoleLabel, isNull);
    });

    test('الأنواع الأخرى لا يُعرض لها دور', () {
      final r = ApprovalRequest(
        id: 'r2',
        type: ApprovalType.projectCreate,
        status: DecisionStatus.pending,
        title: 'مشروع جديد',
        description: '',
        priority: PriorityLevel.medium,
        delayImpactDays: 0,
        requestedByUid: 'u1',
        requestedByName: 'فلان',
        requestedDate: DateTime(2026, 8, 20),
        payload: const {'requestedRole': 'systemAdmin'},
      );
      expect(r.grantedRoleLabel, isNull);
    });
  });

  // لا يكفي أن يكون الـ getter صحيحاً: العبرة بما تراه عينُ مسؤول النظام
  // على بطاقة الطلب قبل ضغطه «موافقة». فتُبنى الشاشة الحقيقية.
  group('بطاقة الطلب في مركز القرار', () {
    Future<void> pump(WidgetTester tester, ApprovalRequest r) async {
      final store = AppStore()..approvalRequests = [r];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: ChangeNotifierProvider<AppStore>.value(
          value: store,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: DecisionCenterScreen()),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('تنطق بالدور المخالف للوصف', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        _registration(
          description: 'الدور المطلوب: موظف',
          payload: {'uid': 'u1', 'requestedRole': 'systemAdmin'},
        ),
      );
      expect(find.text('سيُمنح عند الموافقة دور: مسؤول نظام'), findsOneWidget);
    });

    testWidgets('طلب ليس تسجيلاً بلا سطر دور', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        ApprovalRequest(
          id: 'r2',
          type: ApprovalType.deadlineChange,
          status: DecisionStatus.pending,
          title: 'تعديل موعد',
          description: '',
          priority: PriorityLevel.medium,
          delayImpactDays: 0,
          requestedByUid: 'u1',
          requestedByName: 'فلان',
          requestedDate: DateTime(2026, 8, 20),
        ),
      );
      expect(find.textContaining('سيُمنح عند الموافقة دور'), findsNothing);
    });
  });
}
