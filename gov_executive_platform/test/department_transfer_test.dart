// نقلُ المشروع بين الإدارات — من يطلب، ومن يبتّ، وماذا يُعرض.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **من يطلب**: مديرُ إدارة المشروع (هو من يعرف أنه لم يعد من اختصاصه)،
//     والمستخدمُ التنفيذي في نطاق ما يراه، ومسؤولُ النظام. ولا يطلبه
//     الموظفُ ولا مديرُ المشروع: من يعمل في مشروعٍ لا ينقله من إدارته.
//
// (٢) **ومن يبتّ**: مسؤولُ النظام وحده، بلا استثناء ولا مفتاحٍ مفوَّض. وهو
//     أوسعُ أثراً من تغيير المدير: ذاك ينقل القيادة، وهذا ينقل **من يرى**.
//
// (٣) **وماذا يُعرض للمعتمِد**: الإدارةُ القديمة والجديدة من **الحمولة** لا
//     من المشروع وقت العرض — يبتّ بعد يومٍ أو يومين، وما يراه يجب أن يكون
//     ما كان وقت الطلب.
//
// والحَكَم في كل ذلك الخادمُ والقواعد؛ وما هنا مرآةٌ لهما: زرٌّ يظهر ثم يُردّ
// عند الضغط أسوأ من زرٍّ لا يظهر.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/decision_center_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _oldDept = 'd-old';
const _newDept = 'd-new';

AppUser _user(UserRole role, {String id = 'u-1', String? dept = _oldDept}) => AppUser(
      id: id,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project({String dept = _oldDept, DateTime? transferredAt, String? previous}) => Project(
      id: 'p1',
      departmentId: dept,
      name: 'رقمنة صحيفة الدعوى',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      previousDepartmentId: previous,
      departmentTransferredAt: transferredAt,
    );

ApprovalRequest _transferRequest({
  DecisionStatus status = DecisionStatus.pending,
  String dept = _oldDept,
}) =>
    ApprovalRequest(
      id: 'r-move',
      type: ApprovalType.departmentTransfer,
      status: status,
      title: 'نقل المشروع "رقمنة صحيفة الدعوى" إلى إدارة "إدارة النظم"',
      description: 'المشروع صار من اختصاص إدارة النظم',
      priority: PriorityLevel.medium,
      delayImpactDays: 0,
      departmentId: dept,
      projectId: 'p1',
      requestedByUid: 'u-9',
      requestedByName: 'مدير الإدارة',
      requestedDate: DateTime(2026, 8, 20),
      payload: const {
        'projectId': 'p1',
        'projectName': 'رقمنة صحيفة الدعوى',
        'oldDepartmentId': _oldDept,
        'oldDepartmentName': 'إدارة التخطيط',
        'newDepartmentId': _newDept,
        'newDepartmentName': 'إدارة النظم',
        'reason': 'المشروع صار من اختصاص إدارة النظم',
      },
    );

AppStore _store(UserRole role, {String? dept = _oldDept}) => AppStore()
  ..currentUser = _user(role, dept: dept)
  ..departments = [
    Department(id: _oldDept, name: 'إدارة التخطيط', headName: 'أ', colorValue: 0xFF1B5E20, iconKey: 'balance'),
    Department(id: _newDept, name: 'إدارة النظم', headName: 'ب', colorValue: 0xFF1B5E20, iconKey: 'balance'),
  ];

Future<void> _pump(WidgetTester tester, AppStore store, ApprovalRequest r) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  store.approvalRequests = [r];
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

void main() {
  group('من يطلب النقل', () {
    test('مديرُ إدارة المشروع', () {
      expect(_store(UserRole.departmentManager).canRequestDepartmentTransfer(_project()), isTrue);
    });

    test('ولا مديرُ إدارةٍ أخرى', () {
      expect(
        _store(UserRole.departmentManager, dept: 'd-third')
            .canRequestDepartmentTransfer(_project()),
        isFalse,
      );
    });

    test('والمستخدمُ التنفيذي في نطاق ما يراه', () {
      expect(
        _store(UserRole.executiveViewer, dept: null).canRequestDepartmentTransfer(_project()),
        isTrue,
      );
    });

    test('ومسؤولُ النظام', () {
      expect(
        _store(UserRole.systemAdmin, dept: null).canRequestDepartmentTransfer(_project()),
        isTrue,
      );
    });

    // من يعمل في المشروع لا ينقله من إدارته: ذلك قرارُ من يملك الإدارة.
    test('ولا مديرُ المشروع ولا الموظف', () {
      expect(_store(UserRole.projectOfficer).canRequestDepartmentTransfer(_project()), isFalse);
      expect(_store(UserRole.employee).canRequestDepartmentTransfer(_project()), isFalse);
    });
  });

  group('ومن يبتّ — مسؤولُ النظام وحده', () {
    test('مسؤولُ النظام يبتّ', () {
      expect(_store(UserRole.systemAdmin, dept: null).canApprove(_transferRequest()), isTrue);
    });

    // ــ وهذا هو الحدُّ ــ
    //
    // مديرُ الإدارة **يطلب** النقل ولا يبتّ فيه، ولو بتّ لَأخرج مشروعاً من
    // إدارته بقرار طرفٍ واحد. والفرقُ بين «يطلب» و«يبتّ» هو المقيس هنا.
    test('ومديرُ إدارة المشروع يطلب ولا يبتّ', () {
      final store = _store(UserRole.departmentManager);
      expect(store.canRequestDepartmentTransfer(_project()), isTrue);
      expect(store.canApprove(_transferRequest()), isFalse);
    });

    test('ولا المستخدمُ التنفيذي — يطلب ولا يبتّ كذلك', () {
      final store = _store(UserRole.executiveViewer, dept: null);
      expect(store.canRequestDepartmentTransfer(_project()), isTrue);
      expect(store.canApprove(_transferRequest()), isFalse);
    });

    test('ولا مديرُ المشروع ولا الموظف', () {
      expect(_store(UserRole.projectOfficer).canApprove(_transferRequest()), isFalse);
      expect(_store(UserRole.employee).canApprove(_transferRequest()), isFalse);
    });
  });

  group('وطلبٌ معلّق يُعرض لصاحبه', () {
    test('يُعثر عليه بالمشروع', () {
      final store = _store(UserRole.departmentManager)..approvalRequests = [_transferRequest()];
      expect(store.pendingTransferFor(_project())?.id, 'r-move');
    });

    test('ومبتوتٌ فيه ليس معلّقاً', () {
      final store = _store(UserRole.departmentManager)
        ..approvalRequests = [_transferRequest(status: DecisionStatus.approved)];
      expect(store.pendingTransferFor(_project()), isNull);
    });

    test('وطلبٌ على مشروعٍ آخر لا يُحسب', () {
      final store = _store(UserRole.departmentManager)..approvalRequests = [_transferRequest()];
      final other = Project(
        id: 'p2',
        departmentId: _oldDept,
        name: 'آخر',
        description: '',
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 31),
        status: ProjectStatus.onTrack,
        priority: PriorityLevel.medium,
        progressPercent: 0,
      );
      expect(store.pendingTransferFor(other), isNull);
    });
  });

  group('وأثرُ النقل على المشروع', () {
    test('مشروعٌ لم يُنقل لا أثرَ له', () {
      expect(_project().wasTransferred, isFalse);
    });

    test('والمنقولُ يحمل إدارتَه السابقة وتاريخَ نقله', () {
      final moved = _project(
        dept: _newDept,
        previous: _oldDept,
        transferredAt: DateTime(2026, 8, 21),
      );
      expect(moved.wasTransferred, isTrue);
      expect(moved.previousDepartmentId, _oldDept);
      expect(moved.departmentTransferredAt, DateTime(2026, 8, 21));
    });

    // تاريخٌ بلا إدارةٍ سابقة نصفُ خبر: «نُقل من ؟» لا يُعرض.
    test('وتاريخٌ بلا إدارةٍ سابقة ليس نقلاً', () {
      expect(_project(transferredAt: DateTime(2026, 8, 21)).wasTransferred, isFalse);
      expect(_project(previous: _oldDept).wasTransferred, isFalse);
    });

    // ــ والنسخُ لا يمحو الأثر ــ
    //
    // `toMap` تكتب المستند كاملاً، ونسخةٌ بلا الحقلين تمحو من مشروعٍ منقولٍ
    // أنه نُقل. وهو العطلُ نفسُه الذي عضّ في علامات الحذف.
    test('و`copyWith` تحمل الأثر معها', () {
      final moved = _project(
        dept: _newDept,
        previous: _oldDept,
        transferredAt: DateTime(2026, 8, 21),
      );
      final renamed = moved.copyWith(name: 'اسم جديد');
      expect(renamed.wasTransferred, isTrue);
      expect(renamed.previousDepartmentId, _oldDept);
    });

    // ومشروعٌ لم يُنقل لا يُكتب له المفتاح أصلاً: العميلُ لا يقرّر أنه لم
    // يُنقل، والخادمُ وحده يكتب هذين الحقلين.
    test('ولا يُكتب المفتاح لمشروعٍ لم يُنقل', () {
      expect(_project().toMap().containsKey('previousDepartmentId'), isFalse);
      expect(_project().toMap().containsKey('departmentTransferredAt'), isFalse);
      final moved = _project(previous: _oldDept, transferredAt: DateTime(2026, 8, 21));
      expect(moved.toMap()['previousDepartmentId'], _oldDept);
      expect(moved.toMap().containsKey('departmentTransferredAt'), isTrue);
    });
  });

  group('وبطاقةُ الطلب تعرض القديمة والجديدة', () {
    testWidgets('من الحمولة لا من المشروع وقت العرض', (tester) async {
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), _transferRequest());
      expect(find.text('نقل المشروع بين الإدارات'), findsWidgets);
      expect(
        find.textContaining('الإدارة الحالية: إدارة التخطيط', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('الإدارة المستقبِلة: إدارة النظم', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('والسببُ يُقرأ قبل الموافقة', (tester) async {
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), _transferRequest());
      expect(
        find.textContaining('المشروع صار من اختصاص إدارة النظم', findRichText: true),
        findsWidgets,
      );
    });

    // ــ ويُقال ما يقع قبل الضغط لا بعده ــ
    //
    // ثلاثةُ أشياء يخشاها من يعتمد: أن يضيع شيء، وألّا تنتقل الصلاحيات،
    // وألّا يُعرف من نقل. فتُنفى الثلاثة صراحةً في البطاقة.
    testWidgets('وأثرُ الاعتماد مكتوبٌ في البطاقة', (tester) async {
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), _transferRequest());
      expect(find.textContaining('لا يُحذف منها شيء'), findsOneWidget);
      expect(find.textContaining('ويفقدها مديرُ الإدارة'), findsOneWidget);
      expect(find.textContaining('ويُسجَّل تاريخ النقل'), findsOneWidget);
    });

    testWidgets('وأزرارُ البتّ لمسؤول النظام وحده', (tester) async {
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), _transferRequest());
      expect(find.text('موافقة'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
      // والإعادةُ للتعديل لطلب تعديل البيانات وحده — لا مسارَ لتصحيح هذا.
      expect(find.text('إعادة للتعديل'), findsNothing);
    });

    testWidgets('ولا تُعرض لمدير الإدارة وهو مقدّمُ الطلب', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _transferRequest());
      // البطاقةُ تُعرض له — يقرأ أين وصل طلبُه — والأزرارُ لا.
      expect(find.text('نقل المشروع بين الإدارات'), findsWidgets);
      expect(find.text('موافقة'), findsNothing);
      expect(find.text('رفض'), findsNothing);
    });
  });
}
