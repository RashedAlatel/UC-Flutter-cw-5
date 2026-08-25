// نافذة اليوم: من يرى فيها ماذا، ومن يملك زرّ الحذف.
//
// ــــ عطلان يقيسهما هذا الملف ــــ
//
// **الأول**: الضغط على يومٍ في التقويم كان يقذف من يملك التحرير — أي مدير
// المشروع نفسه — إلى نموذج إضافةٍ فارغ، ولا يريه ما كُتب في ذلك اليوم
// إطلاقاً. ومن لا يملك التحرير كان يرى السرد. فصاحبُ المشروع وحده هو
// المحروم من سجلّه. وهذا نصُّ ما اشتُكي منه: «يجب أن يظهر له التحديث الذي
// قام بإضافته ويكون قادراً على عرضه وحذفه».
//
// **والثاني**: لم يكن للتحديث حذفٌ إطلاقاً — لا دالّة ولا زرّ، والقاعدة
// `allow delete: if isAdmin()`. فمن كتب تحديثاً بالخطأ لا سبيل له إلى محوه.
//
// وحدُّ الحذف هو ما يُقاس أكثر من الحذف نفسه: **المنفّذ لا يمحو تحديث
// مديره**، ولا يمحوه زميلٌ في الإدارة. راجع نظيره على المحاكي في
// `test_rules/daily_update.rules.test.mjs` — القاعدة هي الحَكَم، وهذه
// الواجهة مرآتُها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/attachment.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/day_updates_dialog.dart';

const _dept = 'd-1';
final _day = DateTime(2026, 6, 15);

AppUser _user(String id, UserRole role, {String? dept = _dept}) => AppUser(
      id: id,
      name: 'مستخدم $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project() => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'مشروع العدالة الرقمية',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 20,
      managerUids: const ['m1', 'm2'],
      executorUids: const ['e1'],
    );

DailyUpdate _update({
  String id = 'u1',
  String authorUid = 'm1',
  String authorName = 'المدير الأول',
  List<Attachment> attachments = const [],
}) =>
    DailyUpdate(
      id: id,
      projectId: 'p1',
      departmentId: _dept,
      authorUid: authorUid,
      authorName: authorName,
      date: _day,
      achievements: 'أُنجز ربط النظام بالمحاكم',
      completedTasks: const [],
      newRisks: const [],
      blockers: const [],
      decisionsRequired: const [],
      progressPercent: 40,
      attachments: attachments,
    );

AppStore _store(AppUser me, {List<DailyUpdate>? updates}) => AppStore()
  ..currentUser = me
  ..projects = [_project()]
  ..dailyUpdates = updates ?? [_update()];

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: DayUpdatesDialog(project: _project(), day: _day),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('نافذة اليوم تعرض ما جرى فيه', () {
    // العطل الأول بعينه: من يملك التحرير كان لا يرى شيئاً.
    testWidgets('لمدير المشروع — لا نموذج إضافةٍ فارغ', (tester) async {
      await _pump(tester, _store(_user('m1', UserRole.projectOfficer)));
      expect(tester.takeException(), isNull);

      expect(find.text('أُنجز ربط النظام بالمحاكم'), findsOneWidget);
      expect(find.text('المدير الأول'), findsOneWidget);
      // وزرُّ الإضافة موجودٌ مع ذلك — عرضٌ **ثم** إضافة، لا إحداهما بدل الأخرى.
      expect(find.text('أضِف تحديثاً لهذا اليوم'), findsOneWidget);
    });

    testWidgets('وللمدير الثاني كذلك', (tester) async {
      await _pump(tester, _store(_user('m2', UserRole.projectOfficer)));
      expect(find.text('أُنجز ربط النظام بالمحاكم'), findsOneWidget);
    });

    testWidgets('ومن لا يكتب يقرأ بلا زرّ إضافة', (tester) async {
      await _pump(tester, _store(_user('x', UserRole.executiveViewer, dept: null)));
      expect(find.text('أُنجز ربط النظام بالمحاكم'), findsOneWidget);
      expect(find.text('أضِف تحديثاً لهذا اليوم'), findsNothing);
    });

    testWidgets('ويومٌ فارغ يُقال إنه فارغ', (tester) async {
      await _pump(tester, _store(_user('m1', UserRole.projectOfficer), updates: []));
      expect(find.text('لا يوجد تحديث مسجَّل لهذا اليوم.'), findsOneWidget);
    });

    testWidgets('والمرفقات تُعرض ليُفتح منها', (tester) async {
      final store = _store(
        _user('m1', UserRole.projectOfficer),
        updates: [
          _update(attachments: const [
            Attachment(name: 'محضر.pdf', url: 'https://x/1', kind: AttachmentKind.upload),
          ])
        ],
      );
      await _pump(tester, store);
      expect(find.text('محضر.pdf'), findsOneWidget);
    });
  });

  group('وزرّ الحذف لمن يملكه', () {
    testWidgets('كاتبُ التحديث يراه', (tester) async {
      await _pump(
        tester,
        _store(_user('e1', UserRole.employee), updates: [_update(authorUid: 'e1')]),
      );
      expect(find.byTooltip('حذف هذا التحديث'), findsOneWidget);
    });

    testWidgets('ومديرُ المشروع يراه على تحديثٍ لم يكتبه', (tester) async {
      await _pump(tester, _store(_user('m2', UserRole.projectOfficer)));
      expect(find.byTooltip('حذف هذا التحديث'), findsOneWidget);
    });

    testWidgets('ومديرُ الإدارة كذلك', (tester) async {
      await _pump(tester, _store(_user('h', UserRole.departmentManager)));
      expect(find.byTooltip('حذف هذا التحديث'), findsOneWidget);
    });

    // حدُّ الفتح: المنفّذ **يكتب** التحديث اليومي ولا يمحو تحديث مديره.
    testWidgets('ولا يراه المنفّذ على تحديث مديره', (tester) async {
      await _pump(tester, _store(_user('e1', UserRole.employee)));
      expect(find.text('أُنجز ربط النظام بالمحاكم'), findsOneWidget);
      expect(find.byTooltip('حذف هذا التحديث'), findsNothing);
    });

    testWidgets('ولا زميلٌ في الإدارة ليس عضواً', (tester) async {
      await _pump(tester, _store(_user('z', UserRole.employee)));
      expect(find.byTooltip('حذف هذا التحديث'), findsNothing);
    });

    // المستخدم التنفيذي يرى كل شيء ولا يغيّر شيئاً — قاعدةٌ قائمة في المنصة.
    testWidgets('ولا المستخدم التنفيذي وإن رأى كل الإدارات', (tester) async {
      await _pump(tester, _store(_user('v', UserRole.executiveViewer, dept: null)));
      expect(find.byTooltip('حذف هذا التحديث'), findsNothing);
    });
  });

  // نفس القرار بلا واجهة — فهو ما تقرؤه الشاشة، وما يُقارَن بالقاعدة.
  group('canDeleteDailyUpdate', () {
    test('مسؤول النظام يحذف أيّ تحديث', () {
      final store = _store(_user('a', UserRole.systemAdmin, dept: null));
      expect(store.canDeleteDailyUpdate(_update(), _project()), isTrue);
    });

    test('وبلا مشروعٍ محمَّل يبقى للكاتب حقُّه', () {
      final store = _store(_user('e1', UserRole.employee));
      expect(store.canDeleteDailyUpdate(_update(authorUid: 'e1'), null), isTrue);
      expect(store.canDeleteDailyUpdate(_update(authorUid: 'm1'), null), isFalse);
    });

    test('ومديرُ إدارةٍ أخرى لا يحذف', () {
      final store = _store(_user('h', UserRole.departmentManager, dept: 'd-9'));
      expect(store.canDeleteDailyUpdate(_update(), _project()), isFalse);
    });
  });
}
