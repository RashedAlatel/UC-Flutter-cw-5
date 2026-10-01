// الشكاوى والاقتراحات، والاستثناءات الفردية للصلاحيات.
//
// الاستثناء الفردي هو ما يجعل المنح «لأي مستخدم» ممكناً: مسؤول النظام يمنح
// أو يمنع شخصاً واحداً دون تغيير دوره ولا مساس بزملائه فيه. وهو يعلو على
// الدور في الاتجاهين — وغياب أحد الاتجاهين يجعل المنع مستحيلاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/feedback_item.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';

AppUser _user({
  UserRole role = UserRole.employee,
  String id = 'u1',
  Map<String, bool> overrides = const {},
}) =>
    AppUser(
      id: id,
      name: 'موظف',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: 'd1',
      permissionOverrides: overrides,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

FeedbackItem _item(String id, {required String uid, FeedbackStatus status = FeedbackStatus.submitted}) =>
    FeedbackItem(
      id: id,
      kind: FeedbackKind.complaint,
      title: 'عنوان $id',
      body: 'تفاصيل',
      submittedByUid: uid,
      submittedByName: 'فلان',
      status: status,
      createdAt: DateTime(2026, 2, 1),
    );

void main() {
  group('الاستثناء الفردي يعلو على الدور', () {
    test('يمنح ما لا يمنحه الدور', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {'sfb': true})
        ..rolePermissions = const RolePermissionsConfig({'employee': <String>{}});
      expect(store.canSubmitFeedback, isTrue);
    });

    // الاتجاه الآخر لا يقلّ أهمية: بدونه لا يستطيع مسؤول النظام منع شخص
    // بعينه إلا بسحب الصلاحية عن دوره كله — أي معاقبة الجميع بذنب واحد.
    test('ويمنع ما يمنحه الدور', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {'sfb': false})
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'sfb'},
        });
      expect(store.canSubmitFeedback, isFalse);
    });

    test('وبلا استثناء يتبع دوره', () {
      final store = AppStore()
        ..currentUser = _user()
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'sfb'},
        });
      expect(store.canSubmitFeedback, isTrue);
      expect(store.canManageFeedback, isFalse);
    });

    test('واستثناء صلاحية لا يمسّ غيرها', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {'mfb': true})
        ..rolePermissions = const RolePermissionsConfig({
          'employee': {'sap'},
        });
      expect(store.canManageFeedback, isTrue);
      expect(store.hasPermission(RolePermission.selfAssignProjects), isTrue);
      // ورفع الشكوى لم يعد حقاً مفروضاً: صار يُضبط للدور من الشبكة، وهذا
      // الإعداد يقول إن «موظف» يملك `sap` وحدها. واستثناء `mfb` لا يمنحه.
      expect(store.canSubmitFeedback, isFalse,
          reason: 'رفع الشكوى صار قرار مسؤول النظام لكل دور');
      expect(store.hasPermission(RolePermission.manageWorks), isFalse,
          reason: 'ما لم يُمنح ولم يكن حقاً أساسياً يبقى ممنوعاً');
    });

    // البوابة التي لا تُمسّ: مسؤول النظام صلاحياته كاملة، ولا استثناء يقيّده.
    test('مسؤول النظام لا يُقيَّد باستثناء', () {
      final store = AppStore()
        ..currentUser = _user(role: UserRole.systemAdmin, overrides: {'sfb': false});
      expect(store.canSubmitFeedback, isTrue);
    });

    test('والاستثناءات تُقرأ من السجل وتُكتب إليه', () {
      final map = _user(overrides: {'sfb': true, 'mfb': false}).toMap();
      expect(map['permissionOverrides'], {'sfb': true, 'mfb': false});
    });
  });

  group('نطاق الشكاوى', () {
    test('من لا يتابع الوارد يرى ما رفعه هو وحده', () {
      final store = AppStore()
        ..currentUser = _user()
        ..feedback = [_item('mine', uid: 'u1'), _item('other', uid: 'u2')];
      expect(store.myFeedback.map((f) => f.id), ['mine']);
      expect(store.incomingFeedback, isEmpty);
      expect(store.openFeedbackCount, 0);
    });

    test('ومن يتابعه يرى الكل ويُعدّ المفتوح', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {'mfb': true})
        ..feedback = [
          _item('a', uid: 'u2'),
          _item('b', uid: 'u3', status: FeedbackStatus.resolved),
          _item('c', uid: 'u4', status: FeedbackStatus.inReview),
        ];
      expect(store.incomingFeedback.length, 3);
      expect(store.openFeedbackCount, 2, reason: 'المُستلمة وقيد الدراسة مفتوحتان، والمعالَجة ليست كذلك');
    });

    // من رفع شيئاً ثم سُحبت منه صلاحية الرفع يجب أن يبقى يرى ردّه عليه.
    test('صاحبها يراها ولو سُحبت منه صلاحية الرفع', () {
      final store = AppStore()
        ..currentUser = _user(overrides: {'sfb': false})
        ..feedback = [_item('mine', uid: 'u1')];
      expect(store.canSubmitFeedback, isFalse);
      expect(store.myFeedback.map((f) => f.id), ['mine']);
    });
  });

  group('نموذج الشكوى', () {
    test('يذهب ويعود بلا فقد', () {
      final map = _item('x', uid: 'u1').toMap();
      expect(map['kind'], 'complaint');
      expect(map['status'], 'submitted');
      expect(map['submittedByUid'], 'u1');
    });

    test('المفتوح ما لم يُبتّ فيه', () {
      expect(_item('a', uid: 'u1').isOpen, isTrue);
      expect(_item('a', uid: 'u1', status: FeedbackStatus.inReview).isOpen, isTrue);
      expect(_item('a', uid: 'u1', status: FeedbackStatus.resolved).isOpen, isFalse);
      expect(_item('a', uid: 'u1', status: FeedbackStatus.dismissed).isOpen, isFalse);
    });

    test('اسم مجهول يرجع إلى قيمة آمنة لا يسقط', () {
      expect(FeedbackKind.fromName('nonsense'), FeedbackKind.suggestion);
      expect(FeedbackStatus.fromName('nonsense'), FeedbackStatus.submitted);
    });
  });
}
