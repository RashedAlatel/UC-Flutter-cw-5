// من يصحّح نسبة الإنجاز — وما يُقال له قبل أن يحفظ.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **الدائرة**: مديرُ الإدارة صاحبةِ المشروع، ومديرو المشروع، ومسؤولُ
//     النظام. **ولا الموظفُ في الإدارة** — وهو الفرقُ عن `canEditProject`
//     التي تفتح للجميع: تصحيحُ رقمٍ رسميّ ليس حقَّ كلِّ زميل.
//
// (٢) **والحالُ**: المكتملُ وحده. ما دام المشروعُ جارياً فطريقُ نسبته
//     التحديثُ اليومي، وهو سجلُّ العمل.
//
// (٣) **وما يُقال قبل الحفظ**: نزولُ النسبة عن ١٠٠٪ يُخرج المشروع من
//     المكتملة ويعيده إلى قوائم المتابعة. وذلك أوسعُ من تغيير رقم، فيُقال
//     في النافذة لا يُكتشف بعدها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/project_progress_dialog.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

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

Project _project({
  ProjectStatus status = ProjectStatus.completed,
  double progress = 100,
  List<String> managers = const [],
  DateTime? due,
}) =>
    Project(
      id: 'p1',
      departmentId: _dept,
      name: 'رقمنة صحيفة الدعوى',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: due ?? DateTime(2030, 12, 31),
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: progress,
      managerUids: managers,
    );

AppStore _store(UserRole role, {String id = 'u-1', String? dept = _dept}) =>
    AppStore()..currentUser = _user(role, id: id, dept: dept);

Future<void> _pumpDialog(WidgetTester tester, AppStore store, Project project) async {
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: ProjectProgressDialog(project: project)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('من يصحّح النسبة', () {
    test('مديرُ إدارة المشروع', () {
      expect(
        _store(UserRole.departmentManager).canEditProjectProgress(_project()),
        isTrue,
      );
    });

    test('ومديرُ المشروع نفسُه', () {
      expect(
        _store(UserRole.employee, id: 'u-9')
            .canEditProjectProgress(_project(managers: ['u-9'])),
        isTrue,
      );
    });

    test('ومسؤولُ النظام', () {
      expect(
        _store(UserRole.systemAdmin, dept: null).canEditProjectProgress(_project()),
        isTrue,
      );
    });

    // ــ وهذا التعليقُ كان يصف عطلاً ويُسمّيه صواباً ــ
    //
    // كان مكتوباً هنا: «`canEditProject` تُرجع `true` لكل موظّفٍ في الإدارة
    // — وهو الصواب للتحديث اليومي». ولم يكن صواباً: قاعدةُ الخادم لا تقبل
    // إلا عضواً في المشروع أو مديرَ الإدارة أو مسؤولَ النظام، فكان الموظفُ
    // يكتب تحديثَ يومه ثم يُردّ ويفقده.
    //
    // والدائرتان الآن واحدةٌ في هذا الطرف: **الموظفُ في الإدارة لا يكتب
    // تحديثاً ولا يصحّح نسبة**. وتبقى `canEditProjectProgress` أضيقَ من
    // `canEditProject` في طرفٍ آخر — راجع اختبارَي المنفّذ أدناه.
    test('ولا الموظفُ في الإدارة — لا تحديثاً ولا تصحيحاً', () {
      final store = _store(UserRole.employee, id: 'u-2');
      expect(store.canEditProject(_project()), isFalse, reason: 'ليس عضواً في المشروع');
      expect(store.canEditProjectProgress(_project()), isFalse, reason: 'ولا يصحّح الرقم');
    });

    // ــ والفرقُ بين الدائرتين يبقى مقيساً ــ
    //
    // المنفّذُ المسجَّل يكتب التحديثَ اليومي (فهو عضو)، ولا يصحّح النسبة
    // الرسمية (فتلك لمديري المشروع ومدير الإدارة). ولولا هذا الاختبار
    // لَجاز أن تُدمج الدائرتان بعد ما تقاربتا.
    test('والمنفّذُ يكتب التحديث ولا يصحّح النسبة', () {
      final store = _store(UserRole.employee, id: 'u-x');
      final p = Project(
        id: 'p1',
        departmentId: _dept,
        name: 'رقمنة صحيفة الدعوى',
        description: '',
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2030, 12, 31),
        status: ProjectStatus.completed,
        priority: PriorityLevel.medium,
        progressPercent: 100,
        executorUids: const ['u-x'],
      );
      expect(store.canEditProject(p), isTrue, reason: 'عضوٌ منفّذاً');
      expect(store.canEditProjectProgress(p), isFalse, reason: 'ولا يصحّح الرقم الرسمي');
    });

    test('ولا مديرُ إدارةٍ أخرى', () {
      expect(
        _store(UserRole.departmentManager, dept: 'd-9').canEditProjectProgress(_project()),
        isFalse,
      );
    });

    // التنفيذي يقرأ كلَّ الإدارات ولا يملك أيّاً منها.
    test('ولا المستخدمُ التنفيذي', () {
      expect(
        _store(UserRole.executiveViewer, dept: null).canEditProjectProgress(_project()),
        isFalse,
      );
    });
  });

  group('وعلى المكتمل وحده', () {
    test('مشروعٌ جارٍ لا يُصحَّح من هنا', () {
      expect(
        _store(UserRole.departmentManager).canEditProjectProgress(
          _project(status: ProjectStatus.onTrack, progress: 60),
        ),
        isFalse,
      );
    });

    test('ولا متأخّر', () {
      expect(
        _store(UserRole.departmentManager).canEditProjectProgress(
          _project(status: ProjectStatus.delayed, progress: 60, due: DateTime(2020, 1, 1)),
        ),
        isFalse,
      );
    });
  });

  group('والنافذةُ تقول ما ستفعل', () {
    testWidgets('تعرض النسبة المسجّلة', (tester) async {
      await _pumpDialog(tester, _store(UserRole.departmentManager), _project());
      expect(find.textContaining('النسبة المسجّلة الآن: 100٪'), findsOneWidget);
    });

    // بلا تغييرٍ لا معنى للحفظ.
    testWidgets('والحفظُ مغلقٌ قبل أي تغيير', (tester) async {
      await _pumpDialog(tester, _store(UserRole.departmentManager), _project());
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'حفظ'));
      expect(button.onPressed, isNull);
    });

    testWidgets('وتقول إن المشروع يبقى مكتملاً بمئةٍ كاملة', (tester) async {
      await _pumpDialog(tester, _store(UserRole.departmentManager), _project());
      expect(find.textContaining('يبقى مكتملاً'), findsOneWidget);
    });

    // ــ وهذا هو الأثرُ الذي يجب أن يُقرأ قبل الضغط ــ
    testWidgets('وتُنذر بخروجه من المكتملة عند النزول', (tester) async {
      await _pumpDialog(tester, _store(UserRole.departmentManager), _project());
      await tester.drag(find.byType(Slider), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('يخرج المشروع من المشاريع المكتملة'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'حفظ'));
      expect(button.onPressed, isNotNull, reason: 'صار هناك ما يُحفظ');
    });
  });
}
