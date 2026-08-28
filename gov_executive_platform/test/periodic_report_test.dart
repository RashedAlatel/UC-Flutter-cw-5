// التقرير الدوري — كلُّ عدّةٍ فيه تُقاس وحدها.
//
// ــــ لماذا هذا الملفُّ أطولُ من عادة ملفات الاختبار ــــ
//
// لأن التقرير يُقرأ عليه أداءُ موظفين. ورقمٌ خاطئٌ فيه ليس عطلاً في شاشة
// يُعاد تحميلها: هو سطرٌ يقول عن إنسانٍ إنه لم يفعل شيئاً. فكلُّ عدّةٍ
// مذكورةٍ في الطلب — المنجَز، والمُضاف، والتحديثات، والمرفقات، والمخاطر،
// والعوائق، والمتأخر، وآخر نشاط — لها اختبارٌ يخصّها، وتُقلب كلُّ واحدةٍ
// بطفرةٍ في المحرّك ليُعرف أن اختباراً يمسكها لا أنها مرّت بالصدفة.
//
// ــــ والحدُّ الذي لا يُتهاون فيه ــــ
//
// **«غير مسجّل» ليست صفراً.** المهامُّ المكتوبة قبل هذه الدورة لا تحمل
// `createdAt` ولا `completedAt`، فلو قُرئ غيابُهما صفراً لظهر موظفٌ أنجز
// عشرين مهمةً بلا إنجازٍ إطلاقاً. فتُعدّ في [PersonPerformance
// .tasksWithoutCompletionDate] ولا تُحسب متأخّرةً ولا في موعدها.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/attachment.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_task.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/models/work_update.dart';
import 'package:gov_exec_platform/reports/periodic_report.dart';

// الفترة: أسبوعٌ ينتهي الجمعة ٢٨ آب — أي من السبت ٢٢ إليه، شاملاً طرفيه.
final _range = ReportRange.weekEnding(DateTime(2026, 8, 28));

const _d1 = 'd-nizam';
const _d2 = 'd-shuoun';

const _dept1 = Department(
  id: _d1,
  name: 'إدارة النظم',
  headName: 'رئيس النظم',
  colorValue: 0xFF0B6E4F,
  iconKey: 'work',
);
const _dept2 = Department(
  id: _d2,
  name: 'إدارة الشؤون',
  headName: 'رئيس الشؤون',
  colorValue: 0xFF0B6E4F,
  iconKey: 'work',
);

AppUser _user(String id, {String? dept = _d1, UserStatus status = UserStatus.approved}) => AppUser(
      id: id,
      name: 'موظف $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: UserRole.employee,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project({
  String id = 'p1',
  String dept = _d1,
  DateTime? due,
  ProjectStatus status = ProjectStatus.onTrack,
  double progress = 40,
  List<String> managers = const ['u1'],
  List<String> executors = const ['u2'],
}) =>
    Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: due ?? DateTime(2026, 12, 31),
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: progress,
      managerUids: managers,
      executorUids: executors,
    );

WorkItem _work({String id = 'w1', String assignee = 'u1', String dept = _d1}) => WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: dept,
      assigneeUid: assignee,
      assigneeName: 'موظف $assignee',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.medium,
      progressPercent: 30,
      dueDate: DateTime(2026, 12, 31),
      createdByUid: 'u1',
      createdAt: DateTime(2026, 1, 1),
    );

ProjectTask _task({
  required String id,
  String project = 'p1',
  String dept = _d1,
  String assignee = 'u1',
  String createdBy = 'u1',
  TaskStatus status = TaskStatus.inProgress,
  DateTime? createdAt,
  DateTime? completedAt,
  DateTime? due,
}) =>
    ProjectTask(
      id: id,
      projectId: project,
      departmentId: dept,
      title: 'مهمة $id',
      assigneeUid: assignee,
      assigneeName: 'موظف $assignee',
      status: status,
      progressPercent: status == TaskStatus.done ? 100 : 30,
      lastUpdated: DateTime(2026, 8, 25),
      dueDate: due ?? DateTime(2026, 12, 31),
      priority: PriorityLevel.medium,
      createdByUid: createdBy,
      createdAt: createdAt,
      completedAt: completedAt,
    );

DailyUpdate _update({
  required String id,
  String project = 'p1',
  String author = 'u1',
  DateTime? date,
  String achievements = 'أُنجز الربط',
  List<String> risks = const [],
  List<String> blockers = const [],
  List<Attachment> attachments = const [],
  double progress = 40,
}) =>
    DailyUpdate(
      id: id,
      projectId: project,
      departmentId: _d1,
      authorUid: author,
      authorName: 'موظف $author',
      date: date ?? DateTime(2026, 8, 24),
      achievements: achievements,
      completedTasks: const [],
      newRisks: risks,
      blockers: blockers,
      decisionsRequired: const [],
      progressPercent: progress,
      attachments: attachments,
    );

WorkUpdate _workUpdate({
  required String id,
  String author = 'u1',
  DateTime? date,
  List<Attachment> attachments = const [],
}) =>
    WorkUpdate(
      id: id,
      workId: 'w1',
      departmentId: _d1,
      assigneeUid: 'u1',
      authorUid: author,
      authorName: 'موظف $author',
      date: date ?? DateTime(2026, 8, 25),
      summary: 'تقدّمٌ في العمل',
      progressPercent: 30,
      attachments: attachments,
    );

const _file = Attachment(name: 'ملف.pdf', url: 'https://x/1', kind: AttachmentKind.upload);

/// مدخلاتٌ افتراضية: `u1` نشِط، و`u2` بلا أثر إطلاقاً.
ReportInput _input({
  List<Project>? projects,
  List<WorkItem>? works,
  List<ProjectTask>? tasks,
  List<DailyUpdate>? updates,
  List<WorkUpdate>? workUpdates,
  List<AppUser>? users,
  List<Department>? departments,
}) =>
    ReportInput(
      projects: projects ?? [_project()],
      works: works ?? [_work()],
      tasks: tasks ?? const [],
      dailyUpdates: updates ?? const [],
      workUpdates: workUpdates ?? const [],
      users: users ?? [_user('u1'), _user('u2')],
      departments: departments ?? const [_dept1],
    );

PersonPerformance _person(PeriodicReport r, String uid) =>
    r.people.firstWhere((p) => p.uid == uid);

DepartmentPerformance _department(PeriodicReport r, String id) =>
    r.departments.firstWhere((d) => d.departmentId == id);

void main() {
  group('الفترة تُحدَّد بطرفيها', () {
    test('الأسبوع سبعة أيامٍ شاملةً طرفيه', () {
      expect(_range.start, DateTime(2026, 8, 22));
      expect(_range.end, DateTime(2026, 8, 28));
      expect(_range.days, 7);
    });

    // الحدُّ الأخير بعينه: تحديثٌ كُتب مساء آخر يومٍ داخل الفترة لا خارجها.
    test('آخرُ يومٍ داخلها ولو في آخر ساعة', () {
      expect(_range.contains(DateTime(2026, 8, 28, 23, 59)), isTrue);
      expect(_range.contains(DateTime(2026, 8, 22, 0, 1)), isTrue);
      expect(_range.contains(DateTime(2026, 8, 29)), isFalse);
      expect(_range.contains(DateTime(2026, 8, 21, 23, 59)), isFalse);
    });

    // شباطُ ثمانيةٌ وعشرون لا ثلاثون: آخرُ الشهر يُحسب لا يُفترض.
    test('والشهر يعرف طولَ شهره', () {
      expect(ReportRange.monthOf(DateTime(2026, 2, 10)).end, DateTime(2026, 2, 28));
      expect(ReportRange.monthOf(DateTime(2026, 7, 10)).end, DateTime(2026, 7, 31));
      expect(ReportRange.monthOf(DateTime(2026, 12, 5)).end, DateTime(2026, 12, 31));
    });
  });

  group('أداءُ الشخص — كلُّ عدّةٍ على حدة', () {
    test('المهامُّ المنجَزة داخل الفترة تُعدّ، وما خارجها لا يُعدّ', () {
      final r = buildPeriodicReport(
        _input(tasks: [
          _task(id: 't1', status: TaskStatus.done, completedAt: DateTime(2026, 8, 24)),
          _task(id: 't2', status: TaskStatus.done, completedAt: DateTime(2026, 8, 26)),
          // قبل الفترة — لا يُحسب لها.
          _task(id: 't3', status: TaskStatus.done, completedAt: DateTime(2026, 8, 1)),
        ]),
        _range,
      );
      expect(_person(r, 'u1').tasksCompleted, 2);
    });

    test('والمهامُّ المُضافة تُنسب إلى من أضافها لا إلى المُسنَد إليه', () {
      final r = buildPeriodicReport(
        _input(tasks: [
          _task(id: 't1', createdBy: 'u1', assignee: 'u2', createdAt: DateTime(2026, 8, 23)),
          _task(id: 't2', createdBy: 'u1', assignee: 'u2', createdAt: DateTime(2026, 8, 25)),
          _task(id: 't3', createdBy: 'u1', assignee: 'u2', createdAt: DateTime(2026, 7, 1)),
        ]),
        _range,
      );
      expect(_person(r, 'u1').tasksAdded, 2);
      expect(_person(r, 'u2').tasksAdded, 0);
    });

    test('والتحديثات اليومية تُعدّ لكاتبها', () {
      final r = buildPeriodicReport(
        _input(updates: [
          _update(id: 'a'),
          _update(id: 'b', date: DateTime(2026, 8, 26)),
          _update(id: 'c', author: 'u2'),
          _update(id: 'd', date: DateTime(2026, 8, 1)),
        ]),
        _range,
      );
      expect(_person(r, 'u1').dailyUpdates, 2);
      expect(_person(r, 'u2').dailyUpdates, 1);
    });

    test('وتحديثاتُ الأعمال عدّةٌ مستقلّة', () {
      final r = buildPeriodicReport(
        _input(workUpdates: [
          _workUpdate(id: 'wu1'),
          _workUpdate(id: 'wu2', date: DateTime(2026, 8, 1)),
        ]),
        _range,
      );
      expect(_person(r, 'u1').workUpdates, 1);
    });

    // المرفق لا يحمل رافعاً — يُنسب إلى كاتب التحديث الذي وُلد فيه.
    test('والمرفقات تُنسب عبر التحديث الذي حملها', () {
      final r = buildPeriodicReport(
        _input(
          updates: [
            _update(id: 'a', attachments: const [_file, _file]),
            _update(id: 'b', author: 'u2', attachments: const [_file]),
          ],
          workUpdates: [_workUpdate(id: 'wu1', attachments: const [_file])],
        ),
        _range,
      );
      expect(_person(r, 'u1').attachmentsUploaded, 3);
      expect(_person(r, 'u2').attachmentsUploaded, 1);
    });

    test('والمخاطر والعوائق عدّتان لا واحدة', () {
      final r = buildPeriodicReport(
        _input(updates: [
          _update(id: 'a', risks: const ['خطر أول', 'خطر ثانٍ'], blockers: const ['عائق']),
        ]),
        _range,
      );
      expect(_person(r, 'u1').risksRaised, 2);
      expect(_person(r, 'u1').blockersRaised, 1);
    });

    test('والمتأخّرة المُسنَدة إليه تُقاس بنهاية الفترة لا بيوم القراءة', () {
      final r = buildPeriodicReport(
        _input(tasks: [
          // استُحقّت داخل الفترة ولم تُنجَز ⇒ متأخّرة.
          _task(id: 't1', due: DateTime(2026, 8, 25)),
          // تستحقّ بعد نهاية الفترة ⇒ ليست متأخّرةً في تقريرها ولو تأخّرت بعده.
          _task(id: 't2', due: DateTime(2026, 9, 30)),
          // منجَزةٌ متأخّرةً: تأخّرُها يُقال في `finishedLate` لا هنا.
          _task(
            id: 't3',
            status: TaskStatus.done,
            due: DateTime(2026, 8, 20),
            completedAt: DateTime(2026, 8, 26),
          ),
        ]),
        _range,
      );
      expect(_person(r, 'u1').lateTasksAssigned, 1);
    });

    // اليومُ الذي تستحقّ فيه ليس يومَ تأخّرها: من استُحقّت مهمتُه اليوم
    // أمامه يومُه كلُّه. وطفرةٌ تجعلها متأخّرةً يومَ استحقاقها تعضّ هنا.
    test('والمستحقّةُ في آخر يومٍ من الفترة ليست متأخّرةً فيه', () {
      final r = buildPeriodicReport(
        _input(tasks: [_task(id: 't1', due: DateTime(2026, 8, 28))]),
        _range,
      );
      expect(_person(r, 'u1').lateTasksAssigned, 0);
    });

    test('والمنجَز في موعده يفترق عن المنجَز متأخراً', () {
      final r = buildPeriodicReport(
        _input(tasks: [
          _task(
            id: 't1',
            status: TaskStatus.done,
            due: DateTime(2026, 8, 27),
            completedAt: DateTime(2026, 8, 26),
          ),
          _task(
            id: 't2',
            status: TaskStatus.done,
            due: DateTime(2026, 8, 20),
            completedAt: DateTime(2026, 8, 26),
          ),
        ]),
        _range,
      );
      expect(_person(r, 'u1').finishedOnTime, 1);
      expect(_person(r, 'u1').finishedLate, 1);
    });

    test('وما شارك فيه: مشاريعُ عضويتِه وأعمالُ إسنادِه', () {
      final r = buildPeriodicReport(
        _input(
          projects: [_project(id: 'p1', managers: ['u1']), _project(id: 'p2', managers: ['u9'])],
          works: [_work(id: 'w1', assignee: 'u1'), _work(id: 'w2', assignee: 'u9')],
        ),
        _range,
      );
      expect(_person(r, 'u1').projectNames, ['مشروع p1']);
      expect(_person(r, 'u1').workTitles, ['عمل w1']);
    });

    test('وآخرُ نشاطٍ أحدثُ أثرٍ له أيّاً كان نوعه', () {
      final r = buildPeriodicReport(
        _input(
          tasks: [_task(id: 't1', status: TaskStatus.done, completedAt: DateTime(2026, 8, 23))],
          updates: [_update(id: 'a', date: DateTime(2026, 8, 20))],
          workUpdates: [_workUpdate(id: 'wu1', date: DateTime(2026, 8, 27))],
        ),
        _range,
      );
      expect(_person(r, 'u1').lastActivity, DateTime(2026, 8, 27));
    });

    // آخرُ نشاطٍ سؤالٌ عن الشخص لا عن الفترة: «متى تحرّك آخر مرّة».
    test('وآخرُ نشاطٍ يُقال ولو وقع خارج الفترة', () {
      final r = buildPeriodicReport(
        _input(updates: [_update(id: 'a', date: DateTime(2026, 5, 3))]),
        _range,
      );
      expect(_person(r, 'u1').lastActivity, DateTime(2026, 5, 3));
      expect(_person(r, 'u1').dailyUpdates, 0);
    });
  });

  group('من له نشاطٌ ومن لا نشاط له — يُقالان صراحةً', () {
    test('من لا أثر له إطلاقاً يُدرَج بلا نشاط، ولا يُحذف من التقرير', () {
      final r = buildPeriodicReport(_input(updates: [_update(id: 'a')]), _range);
      final idle = _person(r, 'u2');
      expect(idle.hasNoActivity, isTrue);
      expect(idle.totalActivities, 0);
      expect(idle.lastActivity, isNull);
      expect(idle.activity, ActivityLevel.none);
      expect(r.digest.idlePeople, contains('موظف u2'));
    });

    test('والأنشطُ أوّلاً في الترتيب', () {
      final r = buildPeriodicReport(
        _input(updates: [_update(id: 'a'), _update(id: 'b', date: DateTime(2026, 8, 25))]),
        _range,
      );
      expect(r.people.first.uid, 'u1');
      expect(r.people.last.uid, 'u2');
    });

    // من ينتظر الاعتماد ليس مقصّراً — إدراجُه «بلا نشاط» يُحصي عليه غيابَ
    // صلاحيةٍ لا غيابَ عمل.
    test('وغيرُ المعتمَد لا يُدرَج أصلاً', () {
      final r = buildPeriodicReport(
        _input(users: [_user('u1'), _user('u7', status: UserStatus.pending)]),
        _range,
      );
      expect(r.people.map((p) => p.uid), isNot(contains('u7')));
    });

    test('ومستوى النشاط يتدرّج بما فُعل', () {
      expect(activityLevelFor(0, ReportPeriod.weekly), ActivityLevel.none);
      expect(activityLevelFor(1, ReportPeriod.weekly), ActivityLevel.low);
      expect(activityLevelFor(4, ReportPeriod.weekly), ActivityLevel.medium);
      expect(activityLevelFor(10, ReportPeriod.weekly), ActivityLevel.high);
    });

    // شهرٌ كامل لا يُصنَّف بمعيار أسبوع: أربعُ تحديثاتٍ في شهرٍ ليست
    // «متوسطاً» كما هي في أسبوع.
    test('والشهر يُقاس بمعيار شهر لا بمعيار أسبوع', () {
      expect(activityLevelFor(4, ReportPeriod.monthly), ActivityLevel.low);
      expect(activityLevelFor(16, ReportPeriod.monthly), ActivityLevel.medium);
      expect(activityLevelFor(40, ReportPeriod.monthly), ActivityLevel.high);
    });
  });

  group('«غير مسجّل» ليست صفراً', () {
    // العطلُ الذي يُخشى: مهمةٌ أُنجزت قبل وجود الحقل تُقرأ «لم تُنجز في
    // موعدها» فيظهر الموظف متأخراً بسبب نقصٍ في البيان لا في عمله.
    test('المنجَزة بلا تاريخٍ تُعدّ على حدة ولا تُحسب متأخّرةً ولا في موعدها', () {
      final r = buildPeriodicReport(
        _input(tasks: [
          _task(id: 't1', status: TaskStatus.done, due: DateTime(2026, 1, 1)),
          _task(id: 't2', status: TaskStatus.done, due: DateTime(2026, 1, 1)),
        ]),
        _range,
      );
      final p = _person(r, 'u1');
      expect(p.tasksWithoutCompletionDate, 2);
      expect(p.finishedLate, 0);
      expect(p.finishedOnTime, 0);
      expect(p.tasksCompleted, 0);
    });

    test('والمهمة نفسُها تقول إنها لا تعرف', () {
      final undated = _task(id: 't1', status: TaskStatus.done, due: DateTime(2026, 1, 1));
      expect(undated.hasCompletionDate, isFalse);
      expect(undated.finishedOnTime, isNull);

      final dated = _task(
        id: 't2',
        status: TaskStatus.done,
        due: DateTime(2026, 8, 27),
        completedAt: DateTime(2026, 8, 26),
      );
      expect(dated.hasCompletionDate, isTrue);
      expect(dated.finishedOnTime, isTrue);
    });

    test('والمُضافة بلا تاريخِ إضافةٍ لا تُحتسب إضافةً في الفترة', () {
      final r = buildPeriodicReport(
        _input(tasks: [_task(id: 't1', createdBy: 'u1')]),
        _range,
      );
      expect(_person(r, 'u1').tasksAdded, 0);
    });
  });

  group('أداءُ الإدارة', () {
    ReportInput twoDepartments() => _input(
          projects: [
            _project(id: 'p1', dept: _d1, progress: 80),
            // متأخّر: موعدُه مضى ولم يكتمل.
            _project(id: 'p2', dept: _d1, due: DateTime(2026, 1, 1), progress: 20),
            _project(id: 'p3', dept: _d2, progress: 50, managers: ['u3']),
          ],
          works: [_work(id: 'w1', dept: _d1), _work(id: 'w2', dept: _d2)],
          tasks: [
            _task(id: 't1', project: 'p1', status: TaskStatus.done, completedAt: DateTime(2026, 8, 24)),
            _task(id: 't2', project: 'p1', createdAt: DateTime(2026, 8, 23)),
            _task(id: 't3', project: 'p1', due: DateTime(2026, 8, 20)),
            _task(id: 't4', project: 'p3', dept: _d2, status: TaskStatus.done, completedAt: DateTime(2026, 8, 24)),
          ],
          updates: [
            _update(id: 'a', project: 'p1', blockers: const ['نقص كوادر']),
            _update(id: 'b', project: 'p1', date: DateTime(2026, 8, 26)),
          ],
          users: [_user('u1'), _user('u2'), _user('u3', dept: _d2)],
          departments: const [_dept1, _dept2],
        );

    test('تعدّ مشاريعَها وأعمالَها', () {
      final r = buildPeriodicReport(twoDepartments(), _range);
      expect(_department(r, _d1).projectCount, 2);
      expect(_department(r, _d1).workCount, 1);
      expect(_department(r, _d2).projectCount, 1);
    });

    test('ومهامَّها المنجَزة والمُضافة والمتأخّرة', () {
      final d = _department(buildPeriodicReport(twoDepartments(), _range), _d1);
      expect(d.tasksCompleted, 1);
      expect(d.tasksAdded, 1);
      expect(d.lateTasks, 1);
    });

    test('والمتأخّرَ من مشاريعها بحالته الفعلية لا المخزَّنة', () {
      final d = _department(buildPeriodicReport(twoDepartments(), _range), _d1);
      expect(d.lateProjects, 1);
    });

    // العددان يجب أن يفترقا: لو تساوى المحدَّث وغيرُ المحدَّث لَمرّ انقلابُ
    // الشرط بلا أن يمسكه اختبار. فثلاثةٌ، واحدٌ منها حُدِّث.
    test('وما لم يُحدَّث في الفترة', () {
      final r = buildPeriodicReport(
        _input(
          projects: [_project(id: 'p1'), _project(id: 'p2'), _project(id: 'p3')],
          updates: [
            _update(id: 'a', project: 'p1'),
            // خارج الفترة: لا يجعل p2 محدَّثاً.
            _update(id: 'b', project: 'p2', date: DateTime(2026, 7, 1)),
          ],
        ),
        _range,
      );
      expect(_department(r, _d1).projectsWithoutRecentUpdate, 2);
    });

    // مشروعٌ متأخّرٌ وعليه عائقٌ واحدٌ لا اثنان: المجموعة لا الجمع.
    test('وما يحتاج تدخّلاً لا يُحصى مرّتين', () {
      final r = buildPeriodicReport(
        _input(
          projects: [_project(id: 'p1', due: DateTime(2026, 1, 1))],
          updates: [_update(id: 'a', project: 'p1', blockers: const ['عائق'])],
        ),
        _range,
      );
      expect(_department(r, _d1).projectsNeedingIntervention, 1);
    });

    test('ومتوسّطُ الإنجاز ومتوسّطُ التحديثات', () {
      final d = _department(buildPeriodicReport(twoDepartments(), _range), _d1);
      expect(d.avgProgress, 50); // (٨٠ + ٢٠) ÷ ٢
      expect(d.avgUpdatesPerProject, 1); // تحديثان على مشروعين
    });

    // القسمة على صفر تُخرج NaN فيُطبع «NaN%» في تقريرٍ رسمي.
    test('وإدارةٌ بلا مشاريع لا تُقسَم على صفر', () {
      final r = buildPeriodicReport(
        _input(projects: const [], works: const [], departments: const [_dept1]),
        _range,
      );
      final d = _department(r, _d1);
      expect(d.avgProgress, 0);
      expect(d.avgUpdatesPerProject, 0);
    });

    test('والنشِطُ من موظفيها يفترق عن الخامل', () {
      final r = buildPeriodicReport(
        _input(updates: [_update(id: 'a', author: 'u1')]),
        _range,
      );
      final d = _department(r, _d1);
      expect(d.activePeople, 1);
      expect(d.idlePeople, 1);
    });

    test('وأبرزُ الإنجازات والعوائق بلا تكرار', () {
      final r = buildPeriodicReport(
        _input(updates: [
          _update(id: 'a', achievements: 'ربط المحاكم', blockers: const ['نقص كوادر']),
          _update(id: 'b', achievements: 'ربط المحاكم', blockers: const ['نقص كوادر', 'تأخر التوريد']),
        ]),
        _range,
      );
      final d = _department(r, _d1);
      expect(d.topAchievements, ['ربط المحاكم']);
      expect(d.topBlockers, ['نقص كوادر', 'تأخر التوريد']);
    });

    // المقارنة بين الإدارات هي ما طُلب: تُرتَّب بمتوسّط إنجازها نازلاً،
    // فأعلاها أوّلاً بلا أن يقلّب القارئ الجدول.
    test('والمقارنة ممكنة: الإدارات مرتّبةٌ بإنجازها نازلاً', () {
      final r = buildPeriodicReport(
        _input(
          projects: [
            _project(id: 'p1', dept: _d1, progress: 30),
            _project(id: 'p3', dept: _d2, progress: 90, managers: ['u3']),
          ],
          users: [_user('u1'), _user('u3', dept: _d2)],
          departments: const [_dept1, _dept2],
        ),
        _range,
      );
      expect(r.departments.map((d) => d.departmentId), [_d2, _d1]);
      expect(_department(r, _d2).avgProgress, 90);
      expect(_department(r, _d1).avgProgress, 30);
    });
  });

  group('الملخّص التنفيذي', () {
    test('يجمع ما تفرّق: المشاريع والمتأخر وما لم يُحدَّث', () {
      final r = buildPeriodicReport(
        _input(
          projects: [
            _project(id: 'p1'),
            _project(id: 'p2', due: DateTime(2026, 1, 1)),
          ],
          updates: [_update(id: 'a', project: 'p1')],
        ),
        _range,
      );
      expect(r.digest.totalProjects, 2);
      expect(r.digest.lateProjects, 1);
      expect(r.digest.projectsNotUpdated, 1);
    });

    test('ويعدّ المهامّ المنجَزة والمتأخرة عبر الإدارات كلِّها', () {
      final r = buildPeriodicReport(
        _input(
          tasks: [
            _task(id: 't1', status: TaskStatus.done, completedAt: DateTime(2026, 8, 24)),
            _task(id: 't2', due: DateTime(2026, 8, 20)),
          ],
        ),
        _range,
      );
      expect(r.digest.tasksCompleted, 1);
      expect(r.digest.lateTasks, 1);
    });

    test('ويسمّي من لا نشاط له بالاسم', () {
      final r = buildPeriodicReport(_input(updates: [_update(id: 'a')]), _range);
      expect(r.digest.mostActivePeople, ['موظف u1']);
      expect(r.digest.idlePeople, ['موظف u2']);
    });
  });

  group('الحدود', () {
    test('فترةٌ بلا نشاطٍ إطلاقاً تُنتج تقريراً لا انهياراً', () {
      final r = buildPeriodicReport(_input(), _range);
      expect(r.people.length, 2);
      expect(r.people.every((p) => p.hasNoActivity), isTrue);
      expect(r.digest.tasksCompleted, 0);
      expect(r.digest.topAchievements, isEmpty);
      expect(r.digest.mostActivePeople, isEmpty);
    });

    test('ومنصّةٌ بلا مستخدمين ولا إدارات لا تكسر التقرير', () {
      final r = buildPeriodicReport(
        _input(projects: const [], works: const [], users: const [], departments: const []),
        _range,
      );
      expect(r.people, isEmpty);
      expect(r.departments, isEmpty);
      expect(r.digest.totalProjects, 0);
    });

    // قوائمُ النصّ الحرّ تُقصّ: سطرٌ من عشرين بنداً لا يُقرأ في تقريرٍ رسمي.
    test('وقوائمُ الأبرز محدودةُ الطول', () {
      final r = buildPeriodicReport(
        _input(
          updates: [
            for (var i = 0; i < 12; i++)
              _update(id: 'u$i', achievements: 'إنجاز رقم $i'),
          ],
        ),
        _range,
      );
      expect(_department(r, _d1).topAchievements.length, kTopListSize);
    });
  });
}
