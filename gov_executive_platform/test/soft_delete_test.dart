// المحذوف منطقياً يختفي من كل قائمة — وتوابعُه معه.
//
// ــــ لماذا يُقاس الاختفاء لا الحذف؟ ــــ
//
// وضعُ علامةٍ على مستند سهل. والصعبُ أن **يختفي فعلاً من كل موضع**:
// `projects` يقرؤها أكثر من عشرين موضعاً في المتجر والشاشات. فلو كانت
// التصفية في كل موضعٍ لَسقطت من واحدٍ منها يوماً، فظهر مشروعٌ محذوف في
// لوحة قيادةٍ أو تقرير — ولا يصيح شيء.
//
// فالقسمة تقع في `publishProjects` و`publishWorks` وحدهما. وهذا ما يُقاس:
// أن القائمة الحيّة لا تحوي المحذوف، وأن الأرشيف يحويه، وأن **توابع
// المشروع المحذوف تختفي معه** — وإلا رأى الموظف مهمّةً في «المُسنَد إليّ»
// لمشروعٍ لم يعد موجوداً.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/work_item.dart';

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

Project _project({String id = 'p1', DateTime? deletedAt, String dept = _dept}) => Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      managerUids: const ['u-1'],
      deletedAt: deletedAt,
      deletedBy: deletedAt == null ? null : 'u-head',
      deletedReason: deletedAt == null ? null : 'لم يعد مطلوباً',
    );

WorkItem _work({String id = 'w1', DateTime? deletedAt}) => WorkItem(
      id: id,
      departmentId: _dept,
      title: 'عمل $id',
      description: '',
      assigneeUid: 'u-1',
      assigneeName: 'مستخدم',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      dueDate: DateTime(2026, 6, 1),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
      deletedAt: deletedAt,
    );

void main() {
  group('علامة الحذف تُقرأ وتُكتب', () {
    test('مشروعٌ بلا علامة ليس محذوفاً', () {
      expect(_project().isDeleted, isFalse);
    });

    test('وبعلامة محذوف', () {
      expect(_project(deletedAt: DateTime(2026, 8, 1)).isDeleted, isTrue);
    });

    // `toMap` تُستعمل في تحديثٍ يكتب المستند كاملاً. فحذفُ المفتاح عند
    // الفراغ يُبقي علامةَ حذفٍ قديمة عالقة على المستند بعد استعادته.
    test('والحقول تُكتب ولو فارغة — وإلا بقيت علامةٌ قديمة عالقة', () {
      final m = _project().toMap();
      expect(m.containsKey('deletedAt'), isTrue);
      expect(m['deletedAt'], isNull);
      expect(m.containsKey('deletedBy'), isTrue);
      expect(m.containsKey('deletedReason'), isTrue);
    });

    test('وعملٌ كذلك', () {
      expect(_work().isDeleted, isFalse);
      expect(_work(deletedAt: DateTime(2026, 8, 1)).isDeleted, isTrue);
      expect(_work().toMap().containsKey('deletedAt'), isTrue);
    });
  });

  group('ومن يحذف حذفاً منطقياً — مرآةُ القاعدة', () {
    test('مسؤول النظام يحذف أيّ شيء', () {
      final store = AppStore()..currentUser = _user(UserRole.systemAdmin, dept: null);
      expect(store.canSoftDeleteProject(_project()), isTrue);
      expect(store.canSoftDeleteWork(_work()), isTrue);
    });

    test('ومدير الإدارة داخل إدارته', () {
      final store = AppStore()..currentUser = _user(UserRole.departmentManager);
      expect(store.canSoftDeleteProject(_project()), isTrue);
    });

    test('ولا يحذف في إدارةٍ ليست له', () {
      final store = AppStore()..currentUser = _user(UserRole.departmentManager);
      expect(store.canSoftDeleteProject(_project(dept: 'd-9')), isFalse);
    });

    test('ولا موظفٌ عادي — ولو كان عضواً في المشروع', () {
      final store = AppStore()..currentUser = _user(UserRole.employee);
      expect(store.canSoftDeleteProject(_project()), isFalse);
      expect(store.canSoftDeleteWork(_work()), isFalse);
    });

    // يرى كل الإدارات ولا يغيّر فيها شيئاً — قاعدةٌ قائمة في المنصة.
    test('ولا المستخدم التنفيذي', () {
      final store = AppStore()..currentUser = _user(UserRole.executiveViewer, dept: null);
      expect(store.canSoftDeleteProject(_project()), isFalse);
    });
  });

  // ــ القسمةُ نفسها: هي كلُّ ما يمنع ظهور المحذوف في عشرين موضعاً ــ
  group('القسمة تُخرج المحذوف من الحيّ', () {
    test('الحيّ لا يحوي المحذوف، والأرشيف يحويه', () {
      final split = AppStore.splitDeleted<Project>(
        [
          _project(id: 'p1'),
          _project(id: 'p2', deletedAt: DateTime(2026, 8, 1)),
          _project(id: 'p3'),
        ],
        (p) => p.isDeleted,
      );

      expect(split.live.map((p) => p.id), ['p1', 'p3']);
      expect(split.archived.map((p) => p.id), ['p2']);
    });

    test('وبلا محذوفٍ يبقى الكلُّ حيّاً', () {
      final split = AppStore.splitDeleted<Project>(
        [_project(id: 'p1'), _project(id: 'p2')],
        (p) => p.isDeleted,
      );

      expect(split.live, hasLength(2));
      expect(split.archived, isEmpty);
    });

    test('والأعمال كذلك', () {
      final split = AppStore.splitDeleted<WorkItem>(
        [_work(id: 'w1'), _work(id: 'w2', deletedAt: DateTime(2026, 8, 1))],
        (w) => w.isDeleted,
      );

      expect(split.live.map((w) => w.id), ['w1']);
      expect(split.archived.map((w) => w.id), ['w2']);
    });
  });

  // وإلا رأى الموظف مهمّةً في «المُسنَد إليّ» لمشروعٍ لم يعد موجوداً،
  // وحُسبت في مؤشّرات اللوحة كأنها قائمة.
  group('وتوابعُ المشروع المحذوف تختفي معه', () {
    final children = [
      (id: 't1', projectId: 'p1'),
      (id: 't2', projectId: 'p2'),
      (id: 't3', projectId: 'p1'),
    ];

    test('تابعُ المحذوف يسقط، وتابعُ الحيّ يبقى', () {
      final kept = AppStore.withoutArchivedParents(children, {'p2'}, (c) => c.projectId);

      expect(kept.map((c) => c.id), ['t1', 't3']);
    });

    test('وبلا أرشيفٍ لا يسقط شيء', () {
      final kept = AppStore.withoutArchivedParents(children, <String>{}, (c) => c.projectId);

      expect(kept, hasLength(3));
    });

    test('وبأرشيفٍ يشمل الكلّ لا يبقى شيء', () {
      final kept =
          AppStore.withoutArchivedParents(children, {'p1', 'p2'}, (c) => c.projectId);

      expect(kept, isEmpty);
    });
  });

  group('والاستعادة لمسؤول النظام وحده', () {
    test('مدير الإدارة يُردّ قبل أن يصل الخادم', () async {
      final store = AppStore()..currentUser = _user(UserRole.departmentManager);
      final error = await store.restoreItem(
        collection: 'projects',
        id: 'p1',
        targetType: 'project',
        targetName: 'مشروع',
      );
      expect(error, contains('لمسؤول النظام وحده'));
    });
  });
}
