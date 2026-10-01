// موظّفو الإدارة: من يديرهم، وماذا يملك فيهم.
//
// ــــ ما كان ناقصاً ــــ
//
// `sectionId` يُكتب عند اعتماد التسجيل ثم **يجمد**: لا سبيل إلى تعديله
// لأحد — لا لمدير الإدارة ولا لمسؤول النظام. والاسمُ كذلك: `setUserRole`
// لا تمسّه، فاسمٌ سُجّل ناقصاً يبقى ناقصاً.
//
// ــــ وما يُقاس هنا ــــ
//
// (١) **الدائرة**: مسؤولُ النظام لكلّ مستخدم، ومديرُ الإدارة لموظّفي إدارته
//     وحدهم. وهي **مرآةُ `mayEditUserProfile`** على الخادم، والحَكَم هي.
//
// (٢) **والنقلُ طلبٌ لا فعل**: يغيّر بطاقةَ دخول الموظّف وما يراه من مشاريع
//     الوزارة كلِّها، فلا يقع إلا باعتماد مسؤول النظام.
//
// (٣) **ولا يبتّ فيه مديرُ الإدارة** — ولو كان هو الطالب. فلا ينتقل إنسانٌ
//     من نطاقٍ إلى نطاق بقرار طرفٍ واحد.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-1';
const _other = 'd-2';

AppUser _user(
  UserRole role, {
  required String id,
  String? dept = _dept,
  List<String> managed = const [],
  UserStatus status = UserStatus.approved,
  String name = 'موظّف',
}) =>
    AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: managed,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store(AppUser me, {List<AppUser> others = const []}) =>
    AppStore()
      ..currentUser = me
      ..users = [me, ...others];

final _head = _user(UserRole.departmentManager, id: 'u-head', managed: const [_dept]);
final _admin = _user(UserRole.systemAdmin, id: 'u-admin', dept: null);

void main() {
  group('من يرى شاشة موظّفي إدارته', () {
    test('مديرُ الإدارة', () {
      expect(_store(_head).canManageDepartmentUsers, isTrue);
    });

    // ــ ومسؤولُ النظام خارجها بقصد ــ
    //
    // له شاشةُ «المستخدمون» وفيها ما هو أوسع، ومدخلان لعملٍ واحد يُربكان.
    test('ولا مسؤولُ النظام — له شاشتُه الأوسع', () {
      expect(_store(_admin).canManageDepartmentUsers, isFalse);
    });

    test('ولا الموظف ولا التنفيذي', () {
      expect(
        _store(_user(UserRole.employee, id: 'u-e')).canManageDepartmentUsers,
        isFalse,
      );
      expect(
        _store(_user(UserRole.executiveViewer, id: 'u-v', dept: null))
            .canManageDepartmentUsers,
        isFalse,
      );
    });

    // مديرُ إدارةٍ بلا إدارةٍ مسجَّلة لا يدير أحداً — ولا تُعرض له شاشةٌ
    // فارغةٌ يظنّها عطلاً.
    test('ولا مديرُ إدارةٍ بلا إداراتٍ على بطاقته', () {
      final orphan =
          _user(UserRole.departmentManager, id: 'u-x', dept: null, managed: const []);
      expect(_store(orphan).canManageDepartmentUsers, isFalse);
    });
  });

  // ــ والمدخلُ يتبع الصلاحية لا الدور ــ
  //
  // ولم أكن كتبتُ لهذا اختباراً، فنجت طفرةُ حذفِ السطر كلِّه: تختفي الشاشةُ
  // من القائمة الجانبية ولا يشكو أحدٌ إلا المستخدم.
  group('ومدخلُ الشاشة في القائمة الجانبية', () {
    test('يظهر لمدير الإدارة', () {
      expect(navKeysFor(_store(_head)), contains(NavKey.departmentUsers));
    });

    test('ولا يظهر لمسؤول النظام — له «المستخدمون»', () {
      final keys = navKeysFor(_store(_admin));
      expect(keys, isNot(contains(NavKey.departmentUsers)));
      expect(keys, contains(NavKey.users));
    });

    test('ولا للموظف ولا للتنفيذي', () {
      expect(navKeysFor(_store(_user(UserRole.employee, id: 'u-e'))),
          isNot(contains(NavKey.departmentUsers)));
      expect(
          navKeysFor(
              _store(_user(UserRole.executiveViewer, id: 'u-v', dept: null))),
          isNot(contains(NavKey.departmentUsers)));
    });
  });

  group('ومن يظهر في قائمته', () {
    test('موظّفو إدارته المعتمَدون', () {
      final store = _store(_head, others: [
        _user(UserRole.employee, id: 'u-1', name: 'أحمد'),
        _user(UserRole.employee, id: 'u-2', dept: _other, name: 'خالد'),
      ]);
      expect(store.myDepartmentMembers.map((u) => u.id).toList(), ['u-1']);
    });

    // ــ ولا من لم يُعتمد ــ
    //
    // طلبُ التسجيل بوابةٌ لمسؤول النظام. وعرضُ المنتظرين هنا يُوهم بأنّ
    // لمدير الإدارة فيهم قراراً.
    test('ولا من ينتظر اعتماد تسجيله', () {
      final store = _store(_head, others: [
        _user(UserRole.employee, id: 'u-p', status: UserStatus.pending),
      ]);
      expect(store.myDepartmentMembers, isEmpty);
    });

    test('ولا نفسُه في قائمة موظّفيه', () {
      expect(_store(_head).myDepartmentMembers, isEmpty);
    });
  });

  group('وماذا يملك فيهم', () {
    test('يعدّل بيانات موظّف إدارته', () {
      final target = _user(UserRole.employee, id: 'u-1');
      expect(_store(_head, others: [target]).canEditUserProfile(target), isTrue);
    });

    test('ولا موظّف إدارةٍ أخرى', () {
      final target = _user(UserRole.employee, id: 'u-2', dept: _other);
      expect(_store(_head, others: [target]).canEditUserProfile(target), isFalse);
    });

    // ــ ومن لا إدارةَ له لمسؤول النظام وحده ــ
    //
    // ولو فُتح لمدير إدارةٍ لَادّعى كلُّ مديرٍ من لا إدارة له.
    test('ولا من لا إدارةَ له', () {
      final target = _user(UserRole.employee, id: 'u-3', dept: null);
      expect(_store(_head, others: [target]).canEditUserProfile(target), isFalse);
      expect(_store(_admin, others: [target]).canEditUserProfile(target), isTrue);
    });

    test('ومسؤولُ النظام يعدّل كلَّ مستخدم', () {
      final target = _user(UserRole.employee, id: 'u-2', dept: _other);
      expect(_store(_admin, others: [target]).canEditUserProfile(target), isTrue);
    });

    // ــ وبطاقةُ مديرٍ فيها إدارةٌ فارغة لا تفتح من لا إدارةَ له ــ
    //
    // وهذه هي الحالةُ التي يقيسها حارسُ الإدارة الفارغة وحدَه: بدونه يلتقي
    // الفراغُ بالفراغ في `contains` فيمرّ. نجت طفرتُه في أوّل جولةٍ لأنّ
    // `contains` كانت تحرسها — وهي مرآةُ ما وقع في `mayEditUserProfile`.
    test('ولا مديرٌ في بطاقته إدارةٌ فارغة يعدّل من لا إدارةَ له', () {
      final stray = _user(UserRole.departmentManager,
          id: 'u-stray', dept: null, managed: const ['']);
      final target = _user(UserRole.employee, id: 'u-4', dept: '');
      expect(_store(stray, others: [target]).canEditUserProfile(target), isFalse);
    });

    test('ولا الموظفُ يعدّل زميلَه', () {
      final me = _user(UserRole.employee, id: 'u-me');
      final target = _user(UserRole.employee, id: 'u-1');
      expect(_store(me, others: [target]).canEditUserProfile(target), isFalse);
    });
  });

  // ــ والبوابةُ تُردّ قبل أن يُمَسّ الخادم ــ
  //
  // ولم أكن كتبتُ لهذا اختباراً، فنجت طفراتُه كلُّها. والدالّتان تردّان
  // نصَّ الردّ قبل أيّ اتصال — فتُقاسان بلا فايربيس.
  group('وما يُردّ قبل الوصول إلى الخادم', () {
    test('تعديلُ من ليس من موظّفيه يُردّ بنصّ يقول من يملكه', () async {
      final target = _user(UserRole.employee, id: 'u-2', dept: _other);
      final message = await _store(_head, others: [target])
          .updateUserProfile(target, name: 'اسم جديد');
      expect(message, contains('مسؤول النظام'));
    });

    test('وطلبُ نقلِ من ليس من موظّفيه يُردّ كذلك', () async {
      final target = _user(UserRole.employee, id: 'u-2', dept: _other);
      final message = await _store(_head, others: [target]).submitUserTransferRequest(
        user: target,
        toDepartmentId: _dept,
        reason: 'سبب',
      );
      expect(message, contains('مدير إدارته'));
    });

    // نقلٌ إلى الإدارة نفسِها ليس نقلاً — ولا يُشغَل به مركزُ القرارات.
    test('ولا نقلَ إلى الإدارة التي هو فيها', () async {
      final target = _user(UserRole.employee, id: 'u-1');
      final message = await _store(_head, others: [target]).submitUserTransferRequest(
        user: target,
        toDepartmentId: _dept,
        reason: 'سبب',
      );
      expect(message, contains('أصلاً'));
    });

    // ــ والسببُ مكتوب ــ
    //
    // فمسؤولُ النظام يبتّ في نقل إنسانٍ بين نطاقين، ولا يبتّ في فراغ.
    test('ولا طلبَ بلا سببٍ مكتوب', () async {
      final target = _user(UserRole.employee, id: 'u-1');
      final message = await _store(_head, others: [target]).submitUserTransferRequest(
        user: target,
        toDepartmentId: _other,
        reason: '   ',
      );
      expect(message, contains('سبب'));
    });
  });

  // ــ والحمولةُ تقول «تحت الإدارة مباشرةً» ولا تسكت عنها ــ
  //
  // ومفتاحٌ غائب يعني «لا تمسّ»: `profilePatch` على الخادم لا تكتب إلا ما
  // ورد. فالفرقُ بين الاثنين هو الفرقُ بين محوٍ مقصودٍ ومحوٍ صامت.
  group('وحمولةُ التعديل', () {
    test('الاسمُ وحده حين لا يُمسّ القسم', () {
      expect(userProfilePayload(uid: 'u-1', name: 'أحمد'),
          {'uid': 'u-1', 'name': 'أحمد'});
    });

    test('والقسمُ يُرسَل حين يُختار', () {
      expect(userProfilePayload(uid: 'u-1', sectionId: 's-1'),
          {'uid': 'u-1', 'sectionId': 's-1'});
    });

    test('و«تحت الإدارة مباشرةً» تُقال بـ`null` صريحة لا بصمت', () {
      expect(userProfilePayload(uid: 'u-1', clearSection: true),
          {'uid': 'u-1', 'sectionId': null});
    });

    test('ولا شيءَ يُرسَل عمّا لم يُطلب تغييرُه', () {
      expect(userProfilePayload(uid: 'u-1'), {'uid': 'u-1'});
    });

    // والمحوُ يغلب القيمةَ المختارة: نافذةٌ اختير فيها قسمٌ ثم رُجع عنه.
    test('والمحوُ يغلب قسماً اختير قبله', () {
      expect(userProfilePayload(uid: 'u-1', sectionId: 's-1', clearSection: true),
          {'uid': 'u-1', 'sectionId': null});
    });
  });

  group('والنقلُ طلبٌ لا فعل', () {
    ApprovalRequest transfer({String dept = _dept}) => ApprovalRequest(
          id: 'r1',
          type: ApprovalType.userTransfer,
          status: DecisionStatus.pending,
          title: 'طلب نقل موظّف: أحمد',
          description: 'إعادة توزيع',
          priority: PriorityLevel.medium,
          delayImpactDays: 0,
          departmentId: dept,
          requestedByUid: 'u-head',
          requestedByName: 'مدير',
          requestedDate: DateTime(2026, 9, 1),
          payload: const {'uid': 'u-1', 'toDepartmentId': _other},
        );

    test('مسؤولُ النظام وحده يبتّ فيه', () {
      expect(_store(_admin).canApprove(transfer()), isTrue);
    });

    // ــ ولا الطالبُ نفسُه ــ
    //
    // فلا ينتقل إنسانٌ من نطاقٍ إلى نطاق بقرار طرفٍ واحد.
    test('ولا مديرُ الإدارة ولو كان هو الطالب', () {
      expect(_store(_head).canApprove(transfer()), isFalse);
    });

    test('ولا التنفيذيُّ ولا الموظف', () {
      expect(
        _store(_user(UserRole.executiveViewer, id: 'u-v', dept: null))
            .canApprove(transfer()),
        isFalse,
      );
      expect(_store(_user(UserRole.employee, id: 'u-e')).canApprove(transfer()), isFalse);
    });

    test('وطلبٌ معلّقٌ يُعرف فلا يُقدَّم طلبان', () {
      final target = _user(UserRole.employee, id: 'u-1');
      final store = _store(_head, others: [target])
        ..approvalRequests = [transfer()];
      expect(store.pendingUserTransferFor(target), isNotNull);
    });

    // ــ وطلبُ زميلِه ليس طلبَه ــ
    //
    // ولو خُلطا لَظنّ المديرُ أنّ طلبَه قُدّم وهو لم يُقدَّم — أو لَمُنع من
    // تقديمه لأنّ لزميلٍ آخر طلباً معلّقاً.
    test('وطلبُ موظّفٍ آخر لا يُحسب له', () {
      final target = _user(UserRole.employee, id: 'u-9');
      final store = _store(_head, others: [target])
        ..approvalRequests = [transfer()];
      expect(store.pendingUserTransferFor(target), isNull);
    });

    // ــ وما بُتّ فيه ليس معلّقاً ــ
    //
    // فطلبٌ رُدّ لا يمنع تقديمَ غيره، وإلا لَقُفل البابُ على الموظّف بردٍّ
    // واحد.
    test('وطلبٌ بُتَّ فيه لا يُعدّ معلّقاً', () {
      final target = _user(UserRole.employee, id: 'u-1');
      final decided = ApprovalRequest(
        id: 'r3',
        type: ApprovalType.userTransfer,
        status: DecisionStatus.rejected,
        title: 'طلب نقل موظّف: أحمد',
        description: 'إعادة توزيع',
        priority: PriorityLevel.medium,
        delayImpactDays: 0,
        departmentId: _dept,
        requestedByUid: 'u-head',
        requestedByName: 'مدير',
        requestedDate: DateTime(2026, 9, 1),
        payload: const {'uid': 'u-1', 'toDepartmentId': _other},
      );
      final store = _store(_head, others: [target])..approvalRequests = [decided];
      expect(store.pendingUserTransferFor(target), isNull);
    });

    test('ولا يُخلط بطلبِ نقلِ مشروع', () {
      final target = _user(UserRole.employee, id: 'u-1');
      final store = _store(_head, others: [target])
        ..approvalRequests = [
          ApprovalRequest(
            id: 'r2',
            type: ApprovalType.departmentTransfer,
            status: DecisionStatus.pending,
            title: 'نقل مشروع',
            description: '',
            priority: PriorityLevel.medium,
            delayImpactDays: 0,
            departmentId: _dept,
            projectId: 'p1',
            requestedByUid: 'u-head',
            requestedByName: 'مدير',
            requestedDate: DateTime(2026, 9, 1),
            payload: const {'uid': 'u-1'},
          ),
        ];
      expect(store.pendingUserTransferFor(target), isNull,
          reason: 'نقلُ المشروع غيرُ نقل الموظّف — واسماهما متقاربان');
    });
  });

  // ــ واسمُ النوع يُقرأ بالعربية ــ
  test('و«نقل موظّف بين الإدارات» يُميَّز عن نقل المشروع في العرض', () {
    expect(ApprovalType.userTransfer.label, 'نقل موظّف بين الإدارات');
    expect(ApprovalType.userTransfer.label,
        isNot(ApprovalType.departmentTransfer.label));
  });
}
