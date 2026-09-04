// تصفيةُ المشاريع والأعمال — كلُّ فلترٍ وحده، ثم مجتمعة.
//
// ــــ لماذا هذا الملفّ ــــ
//
// «متأخر» كانت تُحسب في ثلاثة مواضع بثلاث طرق. وهذه الوحدةُ تجمعها، فوزنُها
// أنها **الحَكَم لثلاث شاشات**: خطأٌ فيها يظهر في المشاريع والأعمال والبحث
// معاً، وصوابٌ فيها يكفي الثلاث.
//
// وأخطرُ ما يُقاس هنا **التقاطُع**: فلترٌ يُطبَّق اتّحاداً بدل تقاطُعٍ يعرض
// أضعافَ ما طُلب، ويبدو عاملاً لمن لم يعدّ النتائج.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/record_filter.dart';
import 'package:gov_exec_platform/models/work_item.dart';

final _today = DateTime(2026, 9, 4);

Project _p(
  String id, {
  String dept = 'd-1',
  String? section,
  String name = 'مشروع',
  String description = '',
  List<String> managers = const [],
  List<String> executors = const [],
  List<String> executorNames = const [],
  List<String> categories = const [],
  ProjectStatus status = ProjectStatus.onTrack,
  DateTime? due,
  double progress = 20,
}) =>
    Project(
      id: id,
      departmentId: dept,
      name: name,
      description: description,
      startDate: DateTime(2026, 1, 1),
      dueDate: due ?? DateTime(2030, 1, 1),
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: progress,
      managerUids: managers,
      executorUids: executors,
      executorNames: executorNames,
      categoryIds: categories,
      sectionId: section,
    );

WorkItem _w(
  String id, {
  String dept = 'd-1',
  String title = 'عمل',
  String description = '',
  String assignee = 'u-a',
  String assigneeName = 'منفّذ',
  TaskStatus status = TaskStatus.inProgress,
  DateTime? due,
}) =>
    WorkItem(
      id: id,
      title: title,
      description: description,
      departmentId: dept,
      assigneeUid: assignee,
      assigneeName: assigneeName,
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      dueDate: due ?? DateTime(2030, 1, 1),
      createdByUid: 'u-1',
      createdAt: DateTime(2026, 1, 1),
    );

RecordFilterInput _input({
  List<Project> projects = const [],
  List<WorkItem> works = const [],
  Map<String, DateTime> lastProject = const {},
  Map<String, DateTime> lastWork = const {},
  Set<String> blocked = const {},
  int inactive = 7,
}) =>
    RecordFilterInput(
      projects: projects,
      works: works,
      today: _today,
      inactiveAfterDays: inactive,
      lastProjectUpdate: lastProject,
      lastWorkUpdate: lastWork,
      projectsWithOpenBlockers: blocked,
    );

List<String> _ids(List<Project> ps) => ps.map((p) => p.id).toList();

void main() {
  group('بلا فلترٍ يُعرض الكلّ', () {
    test('المشاريعُ والأعمالُ معاً', () {
      final out = applyRecordFilter(
        const RecordFilter(),
        _input(projects: [_p('a'), _p('b')], works: [_w('w1')]),
      );
      expect(out.projects, hasLength(2));
      expect(out.works, hasLength(1));
    });

    // ــ والفارغةُ تعني الكلّ لا لا شيء ــ
    //
    // فلترٌ لم يُلمس يجب أن يُظهر كلَّ شيء. ولو قُرئت المجموعةُ الفارغة
    // «لا نوع» لَظهرت الشاشةُ خاليةً قبل أن يلمسها أحد.
    test('ومجموعةُ الأنواع الفارغة تعني الكلّ', () {
      final out = applyRecordFilter(
        const RecordFilter(kinds: {}),
        _input(projects: [_p('a')], works: [_w('w1')]),
      );
      expect(out.projects, hasLength(1));
      expect(out.works, hasLength(1));
    });

    test('و«ليس فيه ما يُضبط» يُعرف', () {
      expect(const RecordFilter().isEmpty, isTrue);
      expect(const RecordFilter(departmentId: 'd-1').isEmpty, isFalse);
      expect(const RecordFilter(query: '   ').isEmpty, isTrue,
          reason: 'فراغٌ ليس بحثاً');
    });

    test('وعددُ المُفعَّل يُقال', () {
      expect(const RecordFilter().activeCount, 0);
      expect(
        const RecordFilter(departmentId: 'd-1', quick: QuickState.late$).activeCount,
        2,
      );
    });
  });

  group('نوعُ السجل يفصل', () {
    test('المشاريعُ وحدها', () {
      final out = applyRecordFilter(
        const RecordFilter(kinds: {RecordKind.project}),
        _input(projects: [_p('a')], works: [_w('w1')]),
      );
      expect(out.projects, hasLength(1));
      expect(out.works, isEmpty);
    });

    test('والأعمالُ وحدها', () {
      final out = applyRecordFilter(
        const RecordFilter(kinds: {RecordKind.work}),
        _input(projects: [_p('a')], works: [_w('w1')]),
      );
      expect(out.projects, isEmpty);
      expect(out.works, hasLength(1));
    });
  });

  group('البحثُ النصّي', () {
    test('بالاسم', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'رقمنة'),
        _input(projects: [_p('a', name: 'رقمنة الدعوى'), _p('b', name: 'تجديد تراخيص')]),
      );
      expect(_ids(out.projects), ['a']);
    });

    test('وبكلمةٍ من الوصف', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'الداخلية'),
        _input(projects: [
          _p('a', description: 'الربط مع وزارة الداخلية'),
          _p('b', description: 'أخرى'),
        ]),
      );
      expect(_ids(out.projects), ['a']);
    });

    // المعرّفُ لا يُعرض في شاشة، لكنه يظهر في الروابط ورسائل الأخطاء.
    test('وبالمعرّف لمن نسخه من رابطٍ أو رسالة', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'dept_support_p8'),
        _input(projects: [_p('dept_support_p8'), _p('other')]),
      );
      expect(_ids(out.projects), ['dept_support_p8']);
    });

    test('ويشمل الأعمالَ بعنوانها', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'صيانة'),
        _input(works: [_w('w1', title: 'صيانة الخوادم'), _w('w2', title: 'أخرى')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['w1']);
    });

    test('ولا يفرّق بين حالة الأحرف', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'mimix'),
        _input(projects: [_p('a', name: 'تطبيقات MIMIX')]),
      );
      expect(out.projects, hasLength(1));
    });
  });

  group('الإدارةُ والقسم', () {
    test('الإدارةُ تضيّق الاثنين', () {
      final out = applyRecordFilter(
        const RecordFilter(departmentId: 'd-1'),
        _input(
          projects: [_p('a'), _p('b', dept: 'd-2')],
          works: [_w('w1'), _w('w2', dept: 'd-2')],
        ),
      );
      expect(_ids(out.projects), ['a']);
      expect(out.works.map((w) => w.id).toList(), ['w1']);
    });

    test('والقسمُ يضيّق المشاريع', () {
      final out = applyRecordFilter(
        const RecordFilter(sectionId: 's-1'),
        _input(projects: [_p('a', section: 's-1'), _p('b', section: 's-2'), _p('c')]),
      );
      expect(_ids(out.projects), ['a']);
    });

    // ــ وحدُّ البيانات يُقال لا يُخفى ــ
    //
    // `WorkItem` بلا قسم. فاختيارُ قسمٍ يُخرج الأعمالَ كلَّها — وهو صحيح،
    // ويجب أن تقوله الشاشة لا أن يستنتجه القارئ من فراغٍ صامت.
    test('والأعمالُ بلا قسمٍ فتخرج باختياره', () {
      final out = applyRecordFilter(
        const RecordFilter(sectionId: 's-1'),
        _input(works: [_w('w1'), _w('w2')]),
      );
      expect(out.works, isEmpty);
    });
  });

  group('المنفّذُ ومديرُ المشروع — منفصلين', () {
    test('المنفّذُ بحسابه', () {
      final out = applyRecordFilter(
        const RecordFilter(executorUid: 'u-x'),
        _input(projects: [_p('a', executors: ['u-x']), _p('b', executors: ['u-y'])]),
      );
      expect(_ids(out.projects), ['a']);
    });

    // ــ ومشاريعُ الوزارة المستوردة تحمل الاسمَ نصّاً بلا حساب ــ
    //
    // فمقارنةُ الحساب وحدها تُسقطها كلَّها من فلتر المنفّذ، وهي أكثرُ ما في
    // المنصة. والقاعدةُ نفسُها في `AppStore.projectsOf`.
    test('وبالاسم النصّي للبيانات المستوردة', () {
      final out = applyRecordFilter(
        const RecordFilter(executorUid: 'u-x', executorName: 'ابرار المنصوري'),
        _input(projects: [
          _p('a', executorNames: ['ابرار المنصوري']),
          _p('b', executorNames: ['غيرها']),
        ]),
      );
      expect(_ids(out.projects), ['a']);
    });

    test('ومديرُ المشروع فلترٌ آخر لا هو', () {
      final out = applyRecordFilter(
        const RecordFilter(managerUid: 'u-m'),
        _input(projects: [
          _p('a', managers: ['u-m']),
          _p('b', executors: ['u-m']),
        ]),
      );
      expect(_ids(out.projects), ['a'], reason: 'منفّذاً لا مديراً — فلا يُطابق');
    });

    test('والمنفّذُ على الأعمال هو المُسنَد إليه', () {
      final out = applyRecordFilter(
        const RecordFilter(executorUid: 'u-x'),
        _input(works: [_w('w1', assignee: 'u-x'), _w('w2', assignee: 'u-y')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['w1']);
    });

    // ــ «بانتظار التكليف» فلترٌ قائمٌ نُقل إلى الوحدة ــ
    //
    // وهو محروسٌ في `approval_gates_test.sh`. ولو تُرك في الشاشة لبقي
    // للمنفّذ فلترانِ يفترقان.
    test('و«بانتظار التكليف» تعرض ما لم يُسنَد', () {
      final out = applyRecordFilter(
        const RecordFilter(executorUid: kUnassignedFilter),
        _input(works: [_w('open', assignee: ''), _w('taken', assignee: 'u-x')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['open']);
    });

    test('وهي وصفُ عملٍ لا مشروع — فتُخرج المشاريع', () {
      final out = applyRecordFilter(
        const RecordFilter(executorUid: kUnassignedFilter),
        _input(projects: [_p('a'), _p('b', executors: [])]),
      );
      expect(out.projects, isEmpty);
    });

    test('والأعمالُ بلا مديرٍ فتخرج باختياره', () {
      final out = applyRecordFilter(
        const RecordFilter(managerUid: 'u-m'),
        _input(works: [_w('w1')]),
      );
      expect(out.works, isEmpty);
    });
  });

  // ــ الحالةُ المختارة من القائمة، غيرُ الشريحة السريعة ــ
  //
  // فلترانِ مختلفان يعملان معاً: هذا يختار حالةً بعينها، وتلك تجمع وصفاً.
  // ولم يكن يقيسهما شيءٌ أوّل مرّة — نجت عليهما ثلاثُ طفرات.
  group('حالةُ المشروع وحالةُ العمل والتصنيف', () {
    test('حالةُ المشروع تُصفّي بالحالة الفعلية', () {
      final out = applyRecordFilter(
        const RecordFilter(projectStatus: ProjectStatus.delayed),
        _input(projects: [
          _p('late', due: DateTime(2026, 1, 1)),
          _p('fine'),
        ]),
      );
      expect(_ids(out.projects), ['late']);
    });

    // ــ والفعليةُ لا المخزَّنة ــ
    //
    // مشروعٌ مكتوبٌ عليه «على المسار» وقد تجاوز موعدَه يُقرأ متأخراً — وهي
    // القاعدةُ القائمة في `effectiveStatus`، ومصدرُ الحقيقة الوحيد. ولولا
    // ذلك لَاختلفت التصفيةُ عن الشارة المعروضة على البطاقة نفسها.
    test('ولا تُصفّي بالمخزَّن حين يخالفه الموعد', () {
      final out = applyRecordFilter(
        const RecordFilter(projectStatus: ProjectStatus.onTrack),
        _input(projects: [_p('late', status: ProjectStatus.onTrack, due: DateTime(2026, 1, 1))]),
      );
      expect(out.projects, isEmpty, reason: 'تجاوز موعدَه فهو متأخّر مهما كُتب عليه');
    });

    test('وحالةُ التنفيذ تُصفّي الأعمال', () {
      final out = applyRecordFilter(
        const RecordFilter(workStatus: TaskStatus.todo),
        _input(works: [_w('a', status: TaskStatus.todo), _w('b')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['a']);
    });

    test('والتصنيفُ يُصفّي المشاريع', () {
      final out = applyRecordFilter(
        const RecordFilter(categoryId: 'c-1'),
        _input(projects: [
          _p('a', categories: ['c-1', 'c-2']),
          _p('b', categories: ['c-2']),
          _p('c'),
        ]),
      );
      expect(_ids(out.projects), ['a']);
    });

    // العملُ بلا تصنيف — فاختيارُه يُخرجه، كالقسم والمدير.
    test('والأعمالُ بلا تصنيفٍ فتخرج باختياره', () {
      final out = applyRecordFilter(
        const RecordFilter(categoryId: 'c-1'),
        _input(works: [_w('w1')]),
      );
      expect(out.works, isEmpty);
    });
  });

  group('الحالاتُ الأربع — المشاريع', () {
    final late$ = _p('late', due: DateTime(2026, 1, 1));
    final done = _p('done', status: ProjectStatus.completed, progress: 100);
    final risk = _p('risk', status: ProjectStatus.atRisk);
    final blocked = _p('blocked');
    final fine = _p('fine');

    RecordFilterInput four() => _input(
          projects: [late$, done, risk, blocked, fine],
          blocked: {'blocked'},
          lastProject: {
            'late': _today,
            'done': _today,
            'risk': _today,
            'blocked': _today,
            'fine': _today,
          },
        );

    test('متأخّر', () {
      final out = applyRecordFilter(const RecordFilter(quick: QuickState.late$), four());
      expect(_ids(out.projects), ['late']);
    });

    test('ومكتمل', () {
      final out =
          applyRecordFilter(const RecordFilter(quick: QuickState.completed), four());
      expect(_ids(out.projects), ['done']);
    });

    test('ويحتاج متابعة: المهدَّد والمتوقّف معاً', () {
      final out =
          applyRecordFilter(const RecordFilter(quick: QuickState.needsFollowUp), four());
      expect(_ids(out.projects)..sort(), ['blocked', 'risk']);
    });

    test('وبلا تحديثٍ حديث', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.stale),
        _input(
          projects: [_p('old'), _p('fresh')],
          lastProject: {
            'old': DateTime(2026, 8, 1),
            'fresh': DateTime(2026, 9, 3),
          },
        ),
      );
      expect(_ids(out.projects), ['old']);
    });

    // ــ وغيابُ التحديث أشدُّ الجمود لا استثناءٌ منه ــ
    //
    // سجلٌّ لم يُكتب عليه شيء منذ أُنشئ هو أولى ما يُرى في هذه القائمة.
    test('ومن لا تحديثَ عليه إطلاقاً جامدٌ لا مجهول', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.stale),
        _input(projects: [_p('never')]),
      );
      expect(_ids(out.projects), ['never']);
    });

    // ــ والحدُّ هو حدُّ الوزارة لا رقمٌ مخترع ــ
    test('والحدُّ يتبع إعداد التقارير الدورية', () {
      final input = _input(
        projects: [_p('p')],
        lastProject: {'p': DateTime(2026, 8, 28)},
        inactive: 30,
      );
      expect(
        applyRecordFilter(const RecordFilter(quick: QuickState.stale), input).projects,
        isEmpty,
        reason: 'سبعةُ أيامٍ دون حدّ الثلاثين',
      );
    });

    // ــ وهذه هي الحالُ التي يحرسها شرطُ الاكتمال فعلاً ــ
    //
    // مشروعٌ بلغ المئة **وعليه عائقٌ لم يُغلق** — وهو يقع في العمل: يُنجَز
    // العملُ ويبقى العائقُ مفتوحاً في السجل. ولولا الشرط لَظهر في «يحتاج
    // متابعة» أبداً. والاختبارُ السابق لا يقيس ذلك: مشروعٌ مكتملٌ بلا عائقٍ
    // ولا خطر يخرج على أي حال — وقد نجت عليه طفرة.
    test('ومكتملٌ عليه عائقٌ مفتوح لا يُطلب متابعةً', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.needsFollowUp),
        _input(
          projects: [_p('done', status: ProjectStatus.completed, progress: 100)],
          blocked: {'done'},
        ),
      );
      expect(out.projects, isEmpty, reason: 'بلغ نهايته — والعائقُ أثرٌ لا مطلب');
    });

    // المكتملُ بلغ نهايته: لا متابعةَ تُطلب ولا جمودَ يُلام عليه.
    test('والمكتملُ خارج «يحتاج متابعة» و«بلا تحديث»', () {
      final input = _input(projects: [
        _p('done', status: ProjectStatus.completed, progress: 100),
      ]);
      expect(
        applyRecordFilter(const RecordFilter(quick: QuickState.stale), input).projects,
        isEmpty,
      );
      expect(
        applyRecordFilter(const RecordFilter(quick: QuickState.needsFollowUp), input)
            .projects,
        isEmpty,
      );
    });
  });

  group('والحالاتُ الأربع — الأعمال', () {
    test('متأخّر: موعدُه مضى ولم يُنجَز', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.late$),
        _input(works: [
          _w('late', due: DateTime(2026, 8, 1)),
          _w('doneLate', due: DateTime(2026, 8, 1), status: TaskStatus.done),
          _w('soon'),
        ]),
      );
      expect(out.works.map((w) => w.id).toList(), ['late']);
    });

    test('ومكتمل', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.completed),
        _input(works: [_w('a', status: TaskStatus.done), _w('b')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['a']);
    });

    test('ويحتاج متابعة: ما ينتظر اعتماد إغلاقه', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.needsFollowUp),
        _input(works: [_w('a', status: TaskStatus.awaitingApproval), _w('b')]),
      );
      expect(out.works.map((w) => w.id).toList(), ['a']);
    });

    test('وبلا تحديثٍ حديث', () {
      final out = applyRecordFilter(
        const RecordFilter(quick: QuickState.stale),
        _input(
          works: [_w('old'), _w('fresh')],
          lastWork: {'old': DateTime(2026, 8, 1), 'fresh': DateTime(2026, 9, 3)},
        ),
      );
      expect(out.works.map((w) => w.id).toList(), ['old']);
    });
  });

  // ــــ وهذا أخطرُ ما في الملفّ ــــ
  //
  // هو المثالُ الذي كتبتَه بنفسك. وفلترٌ يُطبَّق اتّحاداً بدل تقاطُعٍ يعرض
  // أضعافَ ما طُلب ويبدو عاملاً لمن لم يعدّ النتائج.
  group('والفلاترُ تتقاطع لا تتّحد', () {
    test('إدارة + قسم + حالة + منفّذ — الأربعةُ معاً', () {
      final wanted = _p('wanted',
          dept: 'd-it',
          section: 's-sys',
          executors: ['u-ahmad'],
          due: DateTime(2026, 1, 1));
      final input = _input(projects: [
        wanted,
        _p('wrongDept', dept: 'd-x', section: 's-sys', executors: ['u-ahmad'], due: DateTime(2026, 1, 1)),
        _p('wrongSection', dept: 'd-it', section: 's-net', executors: ['u-ahmad'], due: DateTime(2026, 1, 1)),
        _p('wrongUser', dept: 'd-it', section: 's-sys', executors: ['u-other'], due: DateTime(2026, 1, 1)),
        _p('notLate', dept: 'd-it', section: 's-sys', executors: ['u-ahmad']),
      ]);
      final out = applyRecordFilter(
        const RecordFilter(
          departmentId: 'd-it',
          sectionId: 's-sys',
          executorUid: 'u-ahmad',
          quick: QuickState.late$,
        ),
        input,
      );
      expect(_ids(out.projects), ['wanted']);
    });

    test('وبحثٌ نصّي مع إدارة', () {
      final out = applyRecordFilter(
        const RecordFilter(query: 'رقمنة', departmentId: 'd-1'),
        _input(projects: [
          _p('a', name: 'رقمنة الدعوى'),
          _p('b', name: 'رقمنة الأرشيف', dept: 'd-2'),
        ]),
      );
      expect(_ids(out.projects), ['a']);
    });
  });

  group('ونسخُ الفلتر', () {
    test('copyWith تُبدّل ما ذُكر وتُبقي ما سواه', () {
      const f = RecordFilter(departmentId: 'd-1', query: 'رقمنة');
      final next = f.copyWith(departmentId: 'd-2');
      expect(next.departmentId, 'd-2');
      expect(next.query, 'رقمنة');
    });

    // ــ وهذا هو الفخُّ المعروف في copyWith ــ
    //
    // `copyWith(departmentId: null)` تعني «لا تغيّر» لا «امسح». ولولا
    // `clear` لَما أمكن **إزالةُ** فلترٍ إلا بإعادة بناء الكائن كلِّه.
    test('و`clear` تمسح حقلاً بعينه', () {
      const f = RecordFilter(departmentId: 'd-1', query: 'رقمنة');
      final next = f.copyWith(clear: {'departmentId'});
      expect(next.departmentId, isNull);
      expect(next.query, 'رقمنة', reason: 'ولا تمسّ ما لم يُذكر');
    });
  });
}
