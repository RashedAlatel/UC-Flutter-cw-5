// من يعدّل، ومن يحوّل — ومَن لا يفعل أيّاً منهما.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **تعديلُ العمل حقُّ الدور لا علَمٌ يُطفأ.** كان الطريق الوحيد صلاحية
//     «إدارة الأعمال» (`mw`)، وهي **تُطفأ** من شاشة صلاحيات الأدوار
//     والمستندُ المخزَّن يُقدَّم على المبدئي. فكان مديرُ الإدارة يملك **حذف**
//     العمل من إدارته ولا يملك تصحيح سطرٍ فيه.
//
// (٢) **والتحويل ليس تعديلاً.** يُنشئ سجلاً ويؤرشف آخر ويغيّر من يظهر له في
//     القوائم. فلا يفتحه علَمٌ مفوَّض، ولا من يقرأ كل الإدارات ولا يملك
//     أيّاً منها.
//
// (٣) **ونموذجُ المشروع لا يَعِد بما يُردّ.** الموعد النهائي بوابةُ اعتماد،
//     والقاعدة تردّه — فلا يُعرض له حقل.
//
// وهذه مرايا للقواعد لا حكماً: `test_rules/convert.rules.test.mjs` هو
// الحَكَم، وما هنا ترتيبٌ للواجهة فلا يُعرض زرٌّ يُردّ عند الضغط.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/project_form_dialog.dart';

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

Project _project({String dept = _dept, List<String> managers = const []}) => Project(
      id: 'p1',
      departmentId: dept,
      name: 'رقمنة صحيفة الدعوى',
      description: 'وصف',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      managerUids: managers,
    );

WorkItem _work({String dept = _dept, String assignee = 'u-9'}) => WorkItem(
      id: 'w1',
      departmentId: dept,
      title: 'جرد الأرشيف',
      description: '',
      assigneeUid: assignee,
      assigneeName: 'موظف',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      dueDate: DateTime(2026, 6, 1),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    );

/// متجرٌ بصلاحيات أدوارٍ **مخزَّنة** أُطفئت فيها «إدارة الأعمال» — وهي الحالة
/// التي كُسرت: المستند المخزَّن يُقدَّم على المبدئي.
AppStore _storeWithoutManageWorks(UserRole role, {String? dept = _dept}) {
  final store = AppStore()..currentUser = _user(role, dept: dept);
  store.rolePermissions = const RolePermissionsConfig({
    'executiveViewer': <String>{},
    'departmentManager': <String>{},
    'projectOfficer': <String>{},
    'employee': <String>{},
  });
  return store;
}

void main() {
  group('تعديل بيانات العمل — حقُّ الدور لا علَمٌ', () {
    test('مديرُ الإدارة يعدّل عملاً في إدارته ولو أُطفئت «إدارة الأعمال»', () {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      expect(store.canManageWorks, isFalse, reason: 'العلَم مُطفأ فعلاً في هذا المتجر');
      expect(store.canEditWorkDetails(_work()), isTrue);
    });

    test('ولا يعدّل عمل إدارةٍ ليست له', () {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      expect(store.canEditWorkDetails(_work(dept: 'd-9')), isFalse);
    });

    test('ومسؤول النظام في كل إدارة', () {
      final store = _storeWithoutManageWorks(UserRole.systemAdmin, dept: null);
      expect(store.canEditWorkDetails(_work(dept: 'd-9')), isTrue);
    });

    test('والمستخدم التنفيذي يقرأ ولا يعدّل', () {
      final store = _storeWithoutManageWorks(UserRole.executiveViewer, dept: null);
      expect(store.canEditWorkDetails(_work()), isFalse);
    });

    // أضيقُ من `canEditWork`: تلك تُدخل المُسنَد إليه ليحرّك تقدّمه.
    test('والمُسنَد إليه يحرّك تقدّمه ولا يعدّل بياناته', () {
      final store = _storeWithoutManageWorks(UserRole.employee);
      final mine = _work(assignee: 'u-1');
      expect(store.canEditWork(mine), isTrue);
      expect(store.canEditWorkDetails(mine), isFalse);
    });
  });

  group('تعديل بيانات المشروع', () {
    test('مديرُ الإدارة في إدارته', () {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      expect(store.canEditProjectDetails(_project()), isTrue);
    });

    test('وقائدُ المشروع ولو لم يكن مديرَ إدارة', () {
      final store = _storeWithoutManageWorks(UserRole.employee);
      expect(store.canEditProjectDetails(_project(managers: const ['u-1'])), isTrue);
    });

    // المنفّذ يكتب التحديث اليومي ولا يعدّل السجل نفسه.
    test('ولا موظفُ الإدارة الذي ليس عضواً فيه', () {
      final store = _storeWithoutManageWorks(UserRole.employee);
      expect(store.canEditProjectDetails(_project()), isFalse);
    });

    test('ولا المستخدم التنفيذي', () {
      final store = _storeWithoutManageWorks(UserRole.executiveViewer, dept: null);
      expect(store.canEditProjectDetails(_project()), isFalse);
    });
  });

  group('من يحوّل', () {
    test('مديرُ الإدارة في إدارته', () {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      expect(store.canConvertIn(_dept), isTrue);
    });

    test('ولا في غيرها', () {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      expect(store.canConvertIn('d-9'), isFalse);
    });

    test('ومسؤول النظام في كل إدارة', () {
      final store = _storeWithoutManageWorks(UserRole.systemAdmin, dept: null);
      expect(store.canConvertIn('d-9'), isTrue);
    });

    // التحويل يُنشئ سجلاً ويؤرشف آخر — فلا يفتحه أن يقرأ المرء كل الإدارات.
    test('والمستخدم التنفيذي يقرأ كل الإدارات ولا يحوّل شيئاً', () {
      final store = _storeWithoutManageWorks(UserRole.executiveViewer, dept: null);
      expect(store.canConvertIn(_dept), isFalse);
    });

    test('وقائدُ المشروع لا يحوّل مشروعه', () {
      final store = _storeWithoutManageWorks(UserRole.employee);
      expect(store.canConvertIn(_dept), isFalse);
    });
  });

  group('نموذج تعديل المشروع لا يَعِد بما يُردّ', () {
    testWidgets('يعرض الاسم والوصف ولا يعرض الموعد النهائي', (tester) async {
      final store = _storeWithoutManageWorks(UserRole.departmentManager);
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ProjectFormDialog(project: _project()),
          ),
        ),
      ));
      await tester.pump();

      // ــ الترويسةُ تقول ما يقع: مديرُ الإدارة **يطلب** لا يكتب ــ
      //
      // وكانت «تعديل بيانات المشروع» حين كان يكتب مباشرةً. ثم صار التعديلُ
      // يمرّ بالاعتماد بقرارٍ صريح، فلو بقيت الترويسةُ على حالها لَوعدت
      // بحفظٍ لا يقع.
      expect(find.text('طلب تعديل بيانات المشروع'), findsOneWidget);
      expect(find.text('تعديل بيانات المشروع'), findsNothing);
      expect(find.text('اسم المشروع'), findsOneWidget);
      expect(find.text('الوصف'), findsOneWidget);
      expect(find.text('الأولوية'), findsOneWidget);
      // البوابة التي لا تُفتح: لا حقلَ للموعد النهائي، ولا زرَّ تقويم.
      expect(find.text('الموعد النهائي'), findsNothing);
      expect(find.byIcon(Icons.calendar_today), findsNothing);
      expect(find.byIcon(Icons.calendar_month), findsNothing);
      // ويُقال أين يُعدَّل بدل أن يُترك القارئ يبحث في كل شاشة.
      expect(find.textContaining('الموعد النهائي يُعدَّل بطلبٍ'), findsOneWidget);
      // والزرُّ يقول ما يفعل: «حفظ» على فعلٍ ينتظر اعتماداً وعدٌ لا يُوفى.
      expect(find.text('إرسال للاعتماد'), findsOneWidget);
      expect(find.text('حفظ'), findsNothing);
      // وحقلُ السبب يُعرض لمن يرفع طلباً — يُقرأ عند الاعتماد ويُحفظ.
      expect(find.textContaining('سبب التعديل'), findsOneWidget);
    });

    // ومسؤولُ النظام يكتب مباشرةً — هو المعتمِد النهائي، فلا يطلب من نفسه.
    testWidgets('ومسؤولُ النظام يحفظ مباشرةً بلا طلب', (tester) async {
      final store = _storeWithoutManageWorks(UserRole.systemAdmin);
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ProjectFormDialog(project: _project()),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('تعديل بيانات المشروع'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(find.text('إرسال للاعتماد'), findsNothing);
      // ولا جدولَ فروقٍ ولا سبب: يكتب فيرى الأثر فوراً.
      expect(find.textContaining('سبب التعديل'), findsNothing);
    });
  });
}
