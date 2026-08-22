// تقويم التحديثات اليومية، وطلب تغيير مدير المشروع.
//
// ــ التقويم ــ
// السجل النصّي يجيب عن «ماذا كُتب» ولا يجيب عن «أين الفجوات». والتقويم
// يجيب عنهما معاً — بشرط أن يصبغ الأيام صبغاً صحيحاً: يومٌ فيه تحديث، ويومٌ
// مضى بلا تحديث، ويومٌ فيه عائق. وصبغةٌ خاطئة أسوأ من لا تقويم: تُري
// المتابعَ انتظاماً لم يقع.
//
// ــ تغيير المدير ــ
// كان متعذّراً على مسؤول النظام نفسه — لا زرّ في المنصة يفعله. والبوابة
// الآن: مدير الإدارة والمستخدم التنفيذي **يطلبان**، ومسؤول النظام يبتّ
// ويغيّر مباشرةً. ولا يبتّ فيه غيره.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/month_calendar.dart' show dayOnly;
import 'package:gov_exec_platform/widgets/updates_calendar.dart';

const _dept = 'd1';

AppUser _user(UserRole role, {List<String> depts = const [_dept]}) => AppUser(
      id: 'u-${role.name}',
      name: role.label,
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: depts.isEmpty ? null : depts.first,
      departmentIds: depts,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project() => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 40,
      managerUids: const ['old-manager'],
    );

void main() {
  group('خلاصة اليوم في التقويم', () {
    final today = dayOnly(DateTime.now());
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    Future<void> pump(WidgetTester tester, Map<DateTime, DayDigest> digests,
        {void Function(DateTime)? onOpen}) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: UpdatesCalendar(
                firstDay: DateTime(today.year, today.month, 1),
                lastDay: today,
                digests: digests,
                onOpenDay: onOpen ?? (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('المدَيان معروضان: شهري وأسبوعي', (tester) async {
      await pump(tester, const {});
      expect(find.text('شهري'), findsOneWidget);
      expect(find.text('أسبوعي'), findsOneWidget);
    });

    testWidgets('العرض الأسبوعي يُظهر ملخّص اليوم ونسبته وعائقه', (tester) async {
      // مربّع الشهر على الهاتف نحو خمسين بكسلاً لا يتّسع لملخّص — فالمضمون
      // في الأسبوعي، والحال في الشهري. ووعدُ ملخّصٍ في خمسين بكسلاً وعدٌ
      // لا يقع.
      await pump(tester, {
        twoDaysAgo: DayDigest(
          day: twoDaysAgo,
          summary: 'تم الانتهاء من الربط',
          count: 1,
          progress: 75,
          hasBlocker: true,
        ),
      });
      await tester.tap(find.text('أسبوعي'));
      await tester.pumpAndSettle();

      expect(find.text('تم الانتهاء من الربط'), findsOneWidget);
      expect(find.textContaining('إنجاز 75'), findsOneWidget);
      expect(find.text('يوجد عائق'), findsOneWidget);
    });

    testWidgets('واليوم الذي مضى بلا تحديث يقول ذلك', (tester) async {
      await pump(tester, const {});
      await tester.tap(find.text('أسبوعي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لا يوجد تحديث لهذا اليوم'), findsWidgets);
    });

    testWidgets('والنقر على يوم يُبلّغ به', (tester) async {
      DateTime? opened;
      await pump(tester, const {}, onOpen: (d) => opened = d);
      await tester.tap(find.text('أسبوعي'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('لا يوجد تحديث لهذا اليوم').first);
      await tester.pump();
      expect(opened, isNotNull);
    });

    testWidgets('ومفتاح الألوان معروض — بلا شرحٍ لا تُقرأ الصبغة', (tester) async {
      await pump(tester, const {});
      expect(find.text('فيه تحديث'), findsOneWidget);
      expect(find.text('مضى بلا تحديث'), findsOneWidget);
      expect(find.text('فيه عائق'), findsOneWidget);
    });
  });

  group('من يطلب تغيير مدير المشروع', () {
    AppStore storeFor(UserRole role, {List<String> depts = const [_dept]}) =>
        AppStore()..currentUser = _user(role, depts: depts);

    test('مسؤول النظام — نعم', () {
      expect(storeFor(UserRole.systemAdmin).canRequestManagerChange(_project()), isTrue);
    });

    test('ومدير الإدارة في إدارته — نعم', () {
      expect(storeFor(UserRole.departmentManager).canRequestManagerChange(_project()), isTrue);
    });

    test('ومدير إدارة أخرى — لا', () {
      expect(
        storeFor(UserRole.departmentManager, depts: const ['d-other'])
            .canRequestManagerChange(_project()),
        isFalse,
      );
    });

    test('والموظف — لا', () {
      expect(storeFor(UserRole.employee).canRequestManagerChange(_project()), isFalse);
    });

    test('ومدير المشروع نفسه — لا', () {
      // من يقود المشروع لا يقرّر من يخلفه.
      expect(storeFor(UserRole.projectOfficer).canRequestManagerChange(_project()), isFalse);
    });
  });

  group('من يبتّ في الطلب', () {
    ApprovalRequest request() => ApprovalRequest(
          id: 'r1',
          type: ApprovalType.managerChange,
          status: DecisionStatus.pending,
          title: 'طلب تغيير مدير المشروع',
          description: 'سبب',
          priority: PriorityLevel.medium,
          delayImpactDays: 0,
          departmentId: _dept,
          requestedByUid: 'x',
          requestedByName: 'مدير الإدارة',
          requestedDate: DateTime(2026, 8, 22),
        );

    test('مسؤول النظام وحده', () {
      final admin = AppStore()..currentUser = _user(UserRole.systemAdmin);
      expect(admin.canApprove(request()), isTrue);
    });

    test('ولا مدير الإدارة — وهو مقدّم الطلب', () {
      final manager = AppStore()..currentUser = _user(UserRole.departmentManager);
      expect(manager.canApprove(request()), isFalse,
          reason: 'من طلب النقل لا يعتمده — وإلا فالبوابة بلا معنى');
    });

    test('ولا المستخدم التنفيذي ولو ملك اعتماد القرارات العامة', () {
      // `agd` تفتح «قرار تنفيذي» وحده. ونقلُ قيادة مشروع ليس منه.
      final exec = AppStore()..currentUser = _user(UserRole.executiveViewer);
      expect(exec.canApprove(request()), isFalse);
    });
  });
}
