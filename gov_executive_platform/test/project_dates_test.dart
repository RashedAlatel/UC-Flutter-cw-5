// تعديلُ تواريخ المشروع — مسارُها ومن يبتّ فيها.
//
// ــــ ما كان ناقصاً ــــ
//
// (١) **تاريخُ بدء المشروع بلا مسارٍ إطلاقاً.** لا يظهر في نموذج التعديل،
//     ولا يقبله مسارُ الاعتماد. وقاعدةُ `projects` **لا تمنعه** — فهو
//     الحقلُ الوحيد من بيانات الخطة الذي يُكتب مباشرةً بلا اعتمادٍ ولا
//     سطرٍ في سجل التدقيق، لو وُجدت شاشةٌ تكتبه.
//
// (٢) **وتعديلُ الموعد النهائي مرحلةٌ واحدة.** يُرفع الطلبُ ويبتّ فيه
//     مسؤولُ النظام مباشرةً، ولا يُستشار مديرُ الإدارة في موعد مشروع
//     إدارته — وهو أعلمُ الناس بسببه.
//
// ــــ والبوابةُ محفوظة ــــ
//
// الموعدُ النهائي يبقى **لا يُطبَّق إلا بمسؤول النظام**: مرحلةُ مدير
// الإدارة تُحيل ولا تُنفّذ (`appliesAt` تُرجع `false` عندها). فالمرحلتان
// توسيعُ **مشورة** لا توسيعُ إذن.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project_edit.dart';

const _dept = 'd-1';
const _other = 'd-2';

AppUser _user(UserRole role, {String id = 'u-1', List<String> managed = const []}) => AppUser(
      id: id,
      name: 'مستخدم',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: managed.isEmpty ? null : managed.first,
      departmentIds: managed,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store(UserRole role, {List<String> managed = const []}) =>
    AppStore()..currentUser = _user(role, managed: managed);

ApprovalRequest _deadline({
  EditStage stage = EditStage.systemAdmin,
  String dept = _dept,
}) =>
    ApprovalRequest(
      id: 'r1',
      type: ApprovalType.deadlineChange,
      status: DecisionStatus.pending,
      title: 'طلب تعديل الموعد النهائي',
      description: 'تأخّر المورّد',
      priority: PriorityLevel.medium,
      delayImpactDays: 30,
      departmentId: dept,
      projectId: 'p1',
      requestedByUid: 'u-9',
      requestedByName: 'طالب',
      requestedDate: DateTime(2026, 9, 1),
      stage: stage,
    );

void main() {
  group('تاريخُ البدء يمرّ بمسار الاعتماد', () {
    test('وهو من الحقول التي يقبلها المسار', () {
      expect(kEditableProjectFields, contains('startDate'));
    });

    test('وجوهريٌّ يُميَّز للمعتمِد', () {
      expect(isSensitiveField('startDate'), isTrue);
    });

    test('واسمُه يُقرأ بالعربية لا بمعرّفه', () {
      expect(projectFieldLabel('startDate'), 'تاريخ بدء المشروع');
    });

    // ــ ولا يدخل الاستحقاقُ هذا المسار ــ
    //
    // له بوابتُه: طلبُ تعديل الموعد النهائي. ولو قَبِلَه المساران معاً
    // لَصار للحقل الواحد طريقان يفترقان — وأحدُهما يتجاوز البوابة.
    test('ولا يدخل تاريخُ الاستحقاق معه — بوابتُه غيرُها', () {
      expect(kEditableProjectFields, isNot(contains('dueDate')));
    });
  });

  group('والموعدُ النهائي مرحلتان', () {
    test('مديرُ الإدارة يبتّ في المرحلة الأولى', () {
      expect(
        _store(UserRole.departmentManager, managed: const [_dept])
            .canApprove(_deadline(stage: EditStage.departmentManager)),
        isTrue,
      );
    });

    test('ولا مديرُ إدارةٍ أخرى', () {
      expect(
        _store(UserRole.departmentManager, managed: const [_other])
            .canApprove(_deadline(stage: EditStage.departmentManager)),
        isFalse,
      );
    });

    // ــ وهذا هو حفظُ البوابة ــ
    //
    // مسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة — لا لأنه أضعف، بل لئلّا
    // يُختصر مسارٌ طُلب أن يكون مرحلتين. وهي القاعدةُ نفسُها في `projectEdit`.
    test('ومسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة', () {
      expect(
        _store(UserRole.systemAdmin).canApprove(_deadline(stage: EditStage.departmentManager)),
        isFalse,
      );
    });

    test('ويبتّ في المرحلة الأخيرة وحدَه', () {
      expect(
        _store(UserRole.systemAdmin).canApprove(_deadline()),
        isTrue,
      );
    });

    // **البوابةُ محفوظة**: الاعتمادُ النهائي لمسؤول النظام، ولا يفتحه دورٌ
    // ولا مفتاحٌ مفوَّض.
    test('ولا مديرُ الإدارة في المرحلة الأخيرة', () {
      expect(
        _store(UserRole.departmentManager, managed: const [_dept]).canApprove(_deadline()),
        isFalse,
      );
    });

    test('ولا المستخدمُ التنفيذي في أيّ مرحلة', () {
      final store = _store(UserRole.executiveViewer);
      expect(store.canApprove(_deadline()), isFalse);
      expect(store.canApprove(_deadline(stage: EditStage.departmentManager)), isFalse);
    });

    test('ولا الموظف', () {
      expect(_store(UserRole.employee).canApprove(_deadline()), isFalse);
    });
  });

  // ــ ومن يبدأ عند أيّ مرحلة ــ
  //
  // ومديرُ الإدارة يبدأ عند مسؤول النظام مباشرةً: لا يعتمد أحدٌ طلبَ نفسه.
  group('والمرحلةُ الأولى بحسب رافع الطلب', () {
    test('موظّفٌ أو مديرُ مشروع يبدأ عند مدير الإدارة', () {
      expect(firstStageFor(requesterIsDepartmentManager: false),
          EditStage.departmentManager);
    });

    test('ومديرُ الإدارة يبدأ عند مسؤول النظام', () {
      expect(firstStageFor(requesterIsDepartmentManager: true), EditStage.systemAdmin);
    });
  });
}
