// بطاقةُ طلب تعديل المشروع في مركز القرارات — وما يراه المعتمِد قبل توقيعه.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **من يُعرض له الزرّ.** والمرحلةُ هي الحَكَم لا الدور: مسؤولُ النظام
//     **لا يبتّ في مرحلة مدير الإدارة** — والخادمُ يردّه (`canActAtStage`)،
//     فزرٌّ يظهر له هناك يُقرأ عطلاً في المنصة لا حدّاً مقصوداً. وهذا
//     الملفُّ مرآةُ ذلك الحدّ.
//
// (٢) **وما يُطبَّق يُعرض لا ما وُصف.** الوصفُ نصٌّ كتبه الطالب، والحمولةُ
//     هي ما تُنفّذه الدالّة. فالجدولُ يُقرأ من الحمولة — كما `grantedRoleLabel`
//     و`notifyPreview` قبله.
//
// (٣) **والجوهريُّ يُميَّز.** تسعةُ حقولٍ تغيّر التزاماً أو مسؤوليةً أو
//     موعداً؛ ولو مرّت بلون الوصف لَمُرِّرت قيمةُ عقدٍ في سطرٍ يُشبه تصحيح
//     إملاء.
//
// (٤) **ومسارُ الطلب يُرى كاملاً.** مرحلتان لا يُرى منهما إلا الحاليةُ
//     تجعل مسؤول النظام يوقّع بلا أن يعرف أوافق مديرُ الإدارة أم لم يصله
//     الطلبُ بعد.
//
// والحَكَم في كل ذلك الخادمُ والقواعد؛ وما هنا ترتيبُ واجهةٍ لا سلطة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project_edit.dart';
import 'package:gov_exec_platform/screens/decision_center_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/field_changes_table.dart';

const _dept = 'd-1';

AppUser _user(UserRole role, {String id = 'u-1', String? dept = _dept}) => AppUser(
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

ApprovalRequest _editRequest({
  EditStage stage = EditStage.departmentManager,
  DecisionStatus status = DecisionStatus.pending,
  String dept = _dept,
  Map<String, dynamic> changes = const {
    'contractValue': {'before': 100000.0, 'after': 125000.5},
    'description': {'before': 'وصف قديم', 'after': 'وصف جديد'},
  },
  String reason = 'تصحيح ما ورد في العقد',
  List<StageStep> trail = const [],
}) =>
    ApprovalRequest(
      id: 'r-edit',
      type: ApprovalType.projectEdit,
      status: status,
      title: 'تعديل بيانات المشروع: رقمنة صحيفة الدعوى',
      description: 'الحقول المطلوب تعديلها: قيمة العقد، الوصف',
      priority: PriorityLevel.high,
      delayImpactDays: 0,
      departmentId: dept,
      projectId: 'p1',
      requestedByUid: 'u-9',
      requestedByName: 'مدير المشروع',
      requestedDate: DateTime(2026, 8, 20),
      stage: stage,
      stageTrail: trail,
      payload: {
        'projectId': 'p1',
        'projectName': 'رقمنة صحيفة الدعوى',
        'reason': reason,
        'changes': changes,
      },
    );

AppStore _store(UserRole role, {String? dept = _dept}) =>
    AppStore()..currentUser = _user(role, dept: dept);

/// وتُفتح الشاشةُ على «كل الحالات» حين يكون المقيسُ طلباً بُتّ فيه:
/// التصفيةُ المبدئية «بانتظار القرار»، فطلبٌ معتمَدٌ لا يُعرض أصلاً — ولو
/// نُسي ذلك لَمرّ اختبارٌ يقيس غيابَ نصٍّ في بطاقةٍ غائبة.
Future<void> _pump(
  WidgetTester tester,
  AppStore store,
  ApprovalRequest r, {
  bool allStatuses = false,
}) async {
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
  if (allStatuses) {
    await tester.tap(find.text('كل الحالات'));
    await tester.pump();
  }
}

void main() {
  group('من يبتّ — والمرحلةُ هي الحَكَم', () {
    test('مديرُ إدارة المشروع يبتّ في مرحلته', () {
      expect(_store(UserRole.departmentManager).canApprove(_editRequest()), isTrue);
    });

    // ــ الحدُّ الذي يُقاس هنا وحده ــ
    //
    // ولولا هذا الاختبار لَظهر لمسؤول النظام زرُّ «موافقة» على طلبٍ عند
    // مديرِ إدارته، ثم ردّه الخادمُ عند الضغط. وكان ذلك حالَ الشيفرة فعلاً:
    // `if (isAdmin) return true;` كان أولَ سطرٍ في `canApprove`.
    test('ومسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة', () {
      expect(
        _store(UserRole.systemAdmin, dept: null).canApprove(_editRequest()),
        isFalse,
        reason: 'المرحلةُ لمدير الإدارة — واختصارُها يُسقط رأيَ صاحب الإدارة',
      );
    });

    test('ويبتّ في مرحلته هو', () {
      expect(
        _store(UserRole.systemAdmin, dept: null)
            .canApprove(_editRequest(stage: EditStage.systemAdmin)),
        isTrue,
      );
    });

    test('ومديرُ الإدارة لا يبتّ في المرحلة الأخيرة', () {
      expect(
        _store(UserRole.departmentManager).canApprove(_editRequest(stage: EditStage.systemAdmin)),
        isFalse,
      );
    });

    test('ولا مديرُ إدارةٍ أخرى في المرحلة الأولى', () {
      expect(_store(UserRole.departmentManager).canApprove(_editRequest(dept: 'd-9')), isFalse);
    });

    test('ولا مديرُ المشروع ولا الموظف', () {
      expect(_store(UserRole.projectOfficer).canApprove(_editRequest()), isFalse);
      expect(_store(UserRole.employee).canApprove(_editRequest()), isFalse);
    });

    // والمستخدمُ التنفيذي يقرأ كلَّ الإدارات ولا يملك أيّاً منها.
    test('ولا المستخدمُ التنفيذي', () {
      expect(_store(UserRole.executiveViewer, dept: null).canApprove(_editRequest()), isFalse);
      expect(
        _store(UserRole.executiveViewer, dept: null)
            .canApprove(_editRequest(stage: EditStage.systemAdmin)),
        isFalse,
      );
    });
  });

  group('والحمولةُ هي المقروءة', () {
    // الوصفُ نصٌّ كتبه الطالب، والحمولةُ هي ما تُنفّذه الدالّة.
    test('الفروقُ تُقرأ من الحمولة لا من الوصف', () {
      final r = _editRequest(changes: const {
        'contractValue': {'before': 1, 'after': 2},
      });
      expect(r.editChanges.map((c) => c.field), ['contractValue']);
      expect(r.editChanges.single.before, 1);
      expect(r.editChanges.single.after, 2);
    });

    // والجوهريُّ أوّلاً: هو ما يجب أن تقع عليه العينُ قبل أن تتعب.
    test('والجوهريُّ يتصدّر ولو ورد أخيراً', () {
      final r = _editRequest(changes: const {
        'description': {'before': 'أ', 'after': 'ب'},
        'contractorName': {'before': 'ج', 'after': 'د'},
        'contractValue': {'before': 1, 'after': 2},
      });
      expect(r.editChanges.first.field, 'contractValue');
      expect(r.editChanges.first.isSensitive, isTrue);
      expect(r.hasSensitiveEdit, isTrue);
    });

    test('وطلبٌ من نوعٍ آخر لا فروقَ له', () {
      final r = ApprovalRequest(
        id: 'r-x',
        type: ApprovalType.projectCreate,
        status: DecisionStatus.pending,
        title: '',
        description: '',
        priority: PriorityLevel.medium,
        delayImpactDays: 0,
        requestedByUid: 'u',
        requestedByName: 'ف',
        requestedDate: DateTime(2026, 8, 20),
        payload: const {
          'changes': {
            'name': {'before': 'أ', 'after': 'ب'},
          },
        },
      );
      expect(r.editChanges, isEmpty);
      expect(r.hasSensitiveEdit, isFalse);
    });
  });

  group('عرضُ القيمة', () {
    test('غيرُ المسجّل يُقال ولا يُترك فراغاً', () {
      expect(showFieldValue(null), 'غير مسجّل');
      expect(showFieldValue('   '), 'غير مسجّل');
    });

    test('والقائمةُ الفارغة «لا شيء»، والمملوءةُ تُسرد', () {
      expect(showFieldValue(<String>[]), 'لا شيء');
      expect(showFieldValue(['أ', 'ب']), 'أ، ب');
    });

    test('والتاريخُ يُعرض مقروءاً لا خاماً', () {
      expect(showFieldValue(DateTime(2026, 2, 15).toIso8601String()), '15 فبراير 2026');
    });

    test('ونصٌّ فيه رقمٌ لا يُقرأ تاريخاً', () {
      expect(showFieldValue('شركة النظم 2026'), 'شركة النظم 2026');
      expect(showFieldValue(125000.5), '125000.5');
    });
  });

  group('بطاقةُ الطلب — ما يُطبَّق لا ما وُصف', () {
    testWidgets('الجدولُ يُقرأ من الحمولة: الحالية ← الجديدة', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _editRequest());
      expect(find.text('قيمة العقد'), findsOneWidget);
      expect(find.text('الوصف'), findsOneWidget);
      expect(find.textContaining('100000'), findsOneWidget);
      expect(find.textContaining('125000.5'), findsOneWidget);
      expect(find.textContaining('وصف قديم'), findsOneWidget);
      expect(find.textContaining('وصف جديد'), findsOneWidget);
    });

    testWidgets('والسببُ يُقرأ قبل الموافقة لا بعدها', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _editRequest());
      // `_ChangeLine` نصٌّ غنيّ: تسميةٌ باهتة وقيمةٌ بارزة في سطرٍ واحد.
      expect(find.textContaining('تصحيح ما ورد في العقد', findRichText: true), findsOneWidget);
    });

    // الجوهريُّ يُميَّز — وهو ما طلبتَ إبرازَه.
    //
    // والعددُ يُقاس لا الوجود: العلامةُ نفسُها في سطر التفسير كذلك، فطفرةٌ
    // تحذفها عن **الحقل** تُبقي علامةَ التفسير ويمرّ اختبارُ «توجد علامة».
    // وهو الفخُّ نفسُه الذي عضّ في `BandButton` و«غير مسجّلة».
    testWidgets('وقيمةُ العقد معلَّمةٌ جوهرية', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _editRequest());
      expect(
        find.byIcon(Icons.priority_high_rounded),
        findsNWidgets(2),
        reason: 'واحدةٌ على قيمة العقد، وواحدةٌ في سطر التفسير',
      );
      expect(tester.widget<Text>(find.text('قيمة العقد')).style?.color, AppColors.warning);
      expect(tester.widget<Text>(find.text('الوصف')).style?.color, isNot(AppColors.warning));
      expect(find.textContaining('الحقول المعلَّمة جوهرية'), findsOneWidget);
    });

    testWidgets('وطلبٌ بلا حقلٍ جوهريّ لا يُعلَّم', (tester) async {
      await _pump(
        tester,
        _store(UserRole.departmentManager),
        _editRequest(changes: const {
          'description': {'before': 'أ', 'after': 'ب'},
          'contractorName': {'before': 'شركة', 'after': 'مؤسسة'},
        }),
      );
      expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
      expect(find.textContaining('الحقول المعلَّمة جوهرية'), findsNothing);
    });

    testWidgets('ومسارُ الطلب: من طلب، ومن وافق، ومن ينتظره الآن', (tester) async {
      await _pump(
        tester,
        _store(UserRole.systemAdmin, dept: null),
        _editRequest(
          stage: EditStage.systemAdmin,
          trail: [
            StageStep(
              stage: EditStage.departmentManager,
              byUid: 'u-5',
              byName: 'صاحب الإدارة',
              at: DateTime(2026, 8, 21),
              action: 'approved',
            ),
          ],
        ),
      );
      expect(find.text('مسار الطلب'), findsOneWidget);
      expect(find.textContaining('مدير المشروع · 2026/08/20', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('صاحب الإدارة · وافق · 2026/08/21', findRichText: true),
        findsOneWidget,
      );
      // و«بانتظار» وحدها لا تكفي: هي في شريحة التصفية وفي شارة الحالة كذلك.
      expect(
        find.textContaining('بانتظار: مسؤول النظام', findRichText: true),
        findsOneWidget,
      );
    });

    // طلبٌ بُتّ فيه لا ينتظر أحداً، وقولُ «بانتظار فلان» عنه يُقرأ تعليقاً.
    testWidgets('وطلبٌ بُتّ فيه لا ينتظر أحداً', (tester) async {
      await _pump(
        tester,
        _store(UserRole.systemAdmin, dept: null),
        _editRequest(stage: EditStage.systemAdmin, status: DecisionStatus.approved),
        allStatuses: true,
      );
      expect(find.text('مسار الطلب'), findsOneWidget);
      expect(find.textContaining('بانتظار: ', findRichText: true), findsNothing);
    });

    testWidgets('و«معاد للتعديل» ليس رفضاً', (tester) async {
      await _pump(
        tester,
        _store(UserRole.systemAdmin, dept: null),
        _editRequest(status: DecisionStatus.returnedForRevision),
        allStatuses: true,
      );
      // ولونُها لونُ متابعةٍ لا لونُ انتهاء: الطلبُ حيٌّ عند مقدّمه ينتظر
      // تصحيحاً. و«مرفوض» موجودةٌ في شريحة التصفية، فلا يُقاس غيابُها بل
      // يُقاس لونُ الشارة نفسِها.
      final badge = tester.widget<Text>(find.text('معاد للتعديل'));
      expect(badge.style?.color, AppColors.info);
      expect(badge.style?.color, isNot(AppColors.danger));
    });
  });

  group('وأزرارُ المعتمِد ثلاثة', () {
    testWidgets('موافقة · رفض · إعادة للتعديل', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _editRequest());
      expect(find.text('موافقة'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
      expect(find.text('إعادة للتعديل'), findsOneWidget);
    });

    // ولا تُعرض لمن لا يبتّ: زرٌّ يُردّ عند الضغط أسوأ من زرٍّ لا يُعرض.
    testWidgets('ولا تُعرض لمسؤول النظام في مرحلةٍ ليست له', (tester) async {
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), _editRequest());
      expect(find.text('موافقة'), findsNothing);
      expect(find.text('إعادة للتعديل'), findsNothing);
    });

    // ــ ولماذا لهذا النوع وحده ــ
    //
    // الطلباتُ الأخرى لا مسارَ لتصحيحها وإعادةِ إرسالها من صفحتها، فإعادتُها
    // تترك صاحبَها بطلبٍ حيٍّ لا يعرف ماذا يفعل به.
    testWidgets('والإعادةُ لهذا النوع وحده', (tester) async {
      final r = ApprovalRequest(
        id: 'r-reg',
        type: ApprovalType.registration,
        status: DecisionStatus.pending,
        title: 'تسجيل عضو',
        description: '',
        priority: PriorityLevel.medium,
        delayImpactDays: 0,
        requestedByUid: 'u-9',
        requestedByName: 'طالب',
        requestedDate: DateTime(2026, 8, 20),
      );
      await _pump(tester, _store(UserRole.systemAdmin, dept: null), r);
      expect(find.text('موافقة'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
      expect(find.text('إعادة للتعديل'), findsNothing);
    });

    // والإعادةُ تَعِد بجولةٍ ثانية، فلتكن مبنيّةً على شيء: بلا ملاحظةٍ يقرأ
    // صاحبُ الطلب «أُعيد إليك» ولا يعرف ماذا يصحّح، فيعيده كما هو.
    testWidgets('والإعادةُ لا تقع بلا ملاحظة', (tester) async {
      await _pump(tester, _store(UserRole.departmentManager), _editRequest());
      await tester.tap(find.text('إعادة للتعديل'));
      await tester.pumpAndSettle();
      expect(find.text('إعادة الطلب للتعديل'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'إعادة للتعديل'),
      );
      expect(button.onPressed, isNull, reason: 'بلا ملاحظةٍ لا يُضغط');

      await tester.enterText(find.byType(TextField).last, 'قيمةُ العقد تخالف المستند');
      await tester.pump();
      final ready = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'إعادة للتعديل'),
      );
      expect(ready.onPressed, isNotNull);
    });
  });
}
