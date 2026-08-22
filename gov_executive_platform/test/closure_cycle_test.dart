// دورة الإغلاق على مرحلتين — الإدارة تُفيد، والطالب يعتمد.
//
// ثلاثة أشياء لا تكشفها القراءة:
//
// ١) **«بانتظار الاعتماد» ليست إغلاقاً**. ولو قبلتها `isDone` لعاد العدّادان
//    اللذان طُلب فصلُهما رقماً واحداً في كل شاشة، ولبدا العمل منتهياً وهو
//    واقفٌ على مكتب.
//
// ٢) **ثلاثة مسارات كانت تُغلق العمل**: قائمة الحالة في النموذج، وبلوغ ١٠٠٪
//    في التحديث اليومي، وسحبُ بطاقة كانبان إلى «منجزة». وإصلاح واحدٍ يترك
//    الاثنين الآخرين باباً مفتوحاً.
//
// ٣) **الغياب ليس خطأً**: مستندٌ بلا حقل `closure` (وهو حال كل أعمال الوزارة
//    القائمة) يجب أن يُقرأ ويُغلق كما كان، لا أن يتعطّل بعد النشر.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/closure_trail.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project_task.dart';
import 'package:gov_exec_platform/models/work_item.dart';

const _dept = 'd-exec';
const _other = 'd-other';

AppUser _user(String id, {String? dept = _dept, List<String> managed = const []}) => AppUser(
      id: id,
      name: 'صاحب $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: UserRole.projectOfficer,
      departmentId: dept,
      departmentIds: managed,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

WorkItem _work({TaskStatus status = TaskStatus.inProgress, ClosureTrail closure = ClosureTrail.none}) =>
    WorkItem(
      id: 'w1',
      title: 'جرد المستودع',
      description: '',
      departmentId: _dept,
      assigneeUid: 'u-worker',
      assigneeName: 'المنفّذ',
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: 60,
      dueDate: DateTime(2026, 12, 31),
      createdByUid: 'u-requester',
      createdAt: DateTime(2026, 1, 1),
      closure: closure,
    );

void main() {
  _dashboardCounters();

  group('الحالة تفترق عن الإغلاق', () {
    test('«بانتظار الاعتماد» ليست منجَزة', () {
      final w = _work(status: TaskStatus.awaitingApproval);
      expect(w.isDone, isFalse, reason: 'إفادةُ طرفٍ ليست إغلاقاً');
      expect(w.isAwaitingApproval, isTrue);
    });

    test('و«منجزة» وحدها إغلاق', () {
      expect(_work(status: TaskStatus.done).isDone, isTrue);
      expect(TaskStatus.done.isClosed, isTrue);
      expect(TaskStatus.awaitingApproval.isClosed, isFalse);
    });

    test('ولها اسمٌ يقرؤه المستخدم', () {
      expect(TaskStatus.awaitingApproval.label, 'بانتظار الاعتماد');
    });

    test('ومهمة المشروع مثلها حرفاً — لا صنفان بسلوكين', () {
      final t = ProjectTask(
        id: 't1',
        projectId: 'p1',
        departmentId: _dept,
        title: 'مهمة',
        assigneeName: 'فلان',
        status: TaskStatus.awaitingApproval,
        progressPercent: 100,
        lastUpdated: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 31),
        priority: PriorityLevel.medium,
      );
      expect(t.isDone, isFalse);
      expect(t.isAwaitingApproval, isTrue);
    });
  });

  group('المعتمِد المبدئي', () {
    test('طالبٌ من إدارة أخرى ⇒ يعتمد هو', () {
      expect(
        defaultApproverUid(creator: _user('u-a', dept: _other), executingDepartmentId: _dept),
        'u-a',
      );
    });

    test('وطالبٌ من الإدارة نفسها ⇒ بلا اعتماد (إغلاق مباشر كما كانت المنصة)', () {
      expect(
        defaultApproverUid(creator: _user('u-a'), executingDepartmentId: _dept),
        isNull,
      );
    });

    test('ومدير إدارةٍ يديرها ⇒ داخلها، فبلا اعتماد', () {
      expect(
        defaultApproverUid(
          creator: _user('u-a', dept: _other, managed: const [_dept]),
          executingDepartmentId: _dept,
        ),
        isNull,
      );
    });

    test('ومن لا إدارة له (مسؤول نظام/تنفيذي) ⇒ خارجها، فيعتمد', () {
      expect(
        defaultApproverUid(creator: _user('u-a', dept: null), executingDepartmentId: _dept),
        'u-a',
      );
    });

    test('وبلا إدارة منفّذة لا معنى للقاعدة', () {
      expect(defaultApproverUid(creator: _user('u-a'), executingDepartmentId: ''), isNull);
    });
  });

  group('من يعتمد', () {
    const trail = ClosureTrail(approverUid: 'u-requester', approverName: 'الطالب');

    test('المعتمِد يعتمد', () {
      expect(trail.isApprover('u-requester'), isTrue);
    });

    test('والمنفّذ لا يعتمد ولو كان مدير إدارة', () {
      expect(trail.isApprover('u-worker'), isFalse);
    });

    test('ومعرّفٌ فارغ لا يعتمد — وإلا اعتمد كلُّ زائر', () {
      expect(trail.isApprover(''), isFalse);
      expect(trail.isApprover(null), isFalse);
    });

    test('وبلا معتمِد لا مرحلةَ اعتماد أصلاً', () {
      expect(ClosureTrail.none.requiresApproval, isFalse);
      expect(trail.requiresApproval, isTrue);
    });
  });

  group('العودة إلى الخلف — مستند بلا حقل closure', () {
    test('يُقرأ بسجلٍّ فارغ لا بانهيار', () {
      expect(ClosureTrail.fromMap(null).requiresApproval, isFalse);
      expect(ClosureTrail.fromMap('نصّ غريب').requiresApproval, isFalse);
      expect(ClosureTrail.fromMap(<String, dynamic>{}).requiresApproval, isFalse);
    });

    test('والسجل الفارغ يُكتب خريطةً فارغة لا حقولاً خاوية', () {
      // مستندٌ يحمل عشرة حقول خاوية يُوهم قارئ قاعدة البيانات بدورةٍ لم تقع.
      expect(ClosureTrail.none.toMap(), isEmpty);
    });

    test('وما كُتب يُقرأ كما كُتب', () {
      final at = DateTime(2026, 8, 20, 12);
      final trail = const ClosureTrail(approverUid: 'u-r', approverName: 'الطالب').copyWith(
        claimedByUid: 'u-w',
        claimedByName: 'المنفّذ',
        claimedAt: at,
      );
      final back = ClosureTrail.fromMap(_roundTrip(trail.toMap()));
      expect(back.approverUid, 'u-r');
      expect(back.claimedByName, 'المنفّذ');
      expect(back.claimedAt, at);
      expect(back.approvedAt, isNull);
    });
  });

  group('الردّ إلى التنفيذ', () {
    test('يمسح الاعتماد — بندٌ «اعتمده فلان» وهو قيد التنفيذ يكذب', () {
      final approved = const ClosureTrail(approverUid: 'u-r').copyWith(
        approvedByUid: 'u-r',
        approvedByName: 'الطالب',
        approvedAt: DateTime(2026, 8, 1),
      );
      final sentBack = approved.copyWith(
        reworkCount: approved.reworkCount + 1,
        reworkReason: 'ينقص المرفق',
        clearApproval: true,
      );
      expect(sentBack.approvedAt, isNull);
      expect(sentBack.approvedByName, isEmpty);
      expect(sentBack.reworkCount, 1);
      // والمعتمِد يبقى: الردّ لا يُلغي الدورة بل يُعيدها خطوةً.
      expect(sentBack.approverUid, 'u-r');
    });

    test('وعددُ المرات يتراكم — ثلاثُ ردّاتٍ ليست كواحدة', () {
      var t = const ClosureTrail(approverUid: 'u-r');
      for (var i = 0; i < 3; i++) {
        t = t.copyWith(reworkCount: t.reworkCount + 1, reworkReason: 'سبب $i');
      }
      expect(t.reworkCount, 3);
      expect(t.reworkReason, 'سبب 2');
    });
  });
}

/// عدّادا لوحة المدير التنفيذي — وهما أصل الطلب.
void _dashboardCounters() {
  group('لوحة المدير التنفيذي تفرّق بين الحالتين', () {
    AppStore storeWith(List<TaskStatus> statuses) => AppStore()
      ..currentUser = AppUser(
        id: _adminId,
        name: 'مسؤول',
        email: '',
        phone: '',
        role: UserRole.systemAdmin,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      )
      ..works = [
        for (var i = 0; i < statuses.length; i++)
          WorkItem(
            id: 'w$i',
            title: 'عمل $i',
            description: '',
            departmentId: _dept,
            assigneeUid: 'u-worker',
            assigneeName: 'المنفّذ',
            status: statuses[i],
            priority: PriorityLevel.medium,
            progressPercent: 100,
            dueDate: DateTime(2026, 12, 31),
            createdByUid: 'u-requester',
            createdAt: DateTime(2026, 1, 1),
          ),
      ];

    test('«أفادت الإدارات بإتمامه» يعدّ المنتظِر وحده', () {
      final store = storeWith([
        TaskStatus.awaitingApproval,
        TaskStatus.awaitingApproval,
        TaskStatus.done,
        TaskStatus.inProgress,
      ]);
      expect(store.claimedDoneCount, 2);
    });

    test('و«مُعتمَد ومغلَق» يعدّ المغلَق وحده', () {
      final store = storeWith([
        TaskStatus.awaitingApproval,
        TaskStatus.done,
        TaskStatus.done,
        TaskStatus.todo,
      ]);
      expect(store.closedApprovedCount, 2);
    });

    // الحارس الحقيقي: لو عُدّ المنتظِر مغلقاً لعاد الرقمان واحداً — وهو
    // بالضبط ما طُلب فصلُه.
    test('ولا يتداخل العدّادان', () {
      final store = storeWith([TaskStatus.awaitingApproval, TaskStatus.done]);
      expect(store.claimedDoneCount, 1);
      expect(store.closedApprovedCount, 1);
    });
  });

  group('من ينتظر اعتمادي', () {
    test('يظهر ما أنا معتمِده وحده', () {
      final me = _user('u-me');
      final store = AppStore()
        ..currentUser = me
        ..works = [
          _work(
            status: TaskStatus.awaitingApproval,
            closure: const ClosureTrail(approverUid: 'u-me', approverName: 'أنا'),
          ),
          WorkItem(
            id: 'w2',
            title: 'عمل غيري',
            description: '',
            departmentId: _dept,
            assigneeUid: 'x',
            assigneeName: 'x',
            status: TaskStatus.awaitingApproval,
            priority: PriorityLevel.medium,
            progressPercent: 100,
            dueDate: DateTime(2026, 12, 31),
            createdByUid: 'y',
            createdAt: DateTime(2026, 1, 1),
            closure: const ClosureTrail(approverUid: 'u-other'),
          ),
        ];
      expect(store.worksAwaitingMyApproval.map((w) => w.id), ['w1']);
      expect(store.pendingClosureApprovals, 1);
    });

    test('وما لم يُفَد بإتمامه بعد لا يظهر', () {
      final store = AppStore()
        ..currentUser = _user('u-me')
        ..works = [
          _work(
            status: TaskStatus.inProgress,
            closure: const ClosureTrail(approverUid: 'u-me'),
          ),
        ];
      expect(store.worksAwaitingMyApproval, isEmpty);
    });
  });
}

const _adminId = 'u-admin';

/// يحاكي رحلة الخريطة إلى Firestore ومنها: `Timestamp` يبقى `Timestamp`.
Map<String, dynamic> _roundTrip(Map<String, dynamic> map) => {
      for (final e in map.entries)
        e.key: e.value is Timestamp ? e.value : e.value,
    };
