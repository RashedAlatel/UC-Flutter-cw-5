// تصفيةُ المشاريع والأعمال — **القرارُ الواحد**.
//
// ــــ لماذا وحدةٌ نقيّة ــــ
//
// «متأخر» كانت تُحسب في صفحة المشاريع، وفي صفحة الأعمال بحسابٍ آخر، وفي
// التقارير الدورية بثالث. وثلاثةُ تعريفاتٍ لكلمةٍ واحدة تفترق بأوّل تعديل،
// فيقرأ مديرٌ رقماً ويقرأ آخرُ غيرَه عن الشيء نفسه.
//
// فالقرارُ هنا كلُّه: بلا Firestore ولا `BuildContext`، يُقاس كلُّ فلترٍ
// وحده وتُقلب كلُّ قاعدةٍ بطفرة. وتناديه ثلاثُ شاشات — المشاريعُ والأعمالُ
// وصفحةُ البحث الموحّدة. وهو نمطٌ قائم في المنصة: `periodic_report.dart`
// و`statusForProgress` و`judgeChanges`.
library;

import 'enums.dart';
import 'project.dart';
import 'work_item.dart';

/// قيمةٌ خاصّة لفلتر المنفّذ تعني **ما لم يُسنَد بعد**.
///
/// وهي ليست حساباً: `assigneeUid` فارغٌ على العمل الذي ينتظر تكليفاً. وهو
/// فلترٌ قائمٌ في شاشة الأعمال ومحروسٌ في `tool/test/approval_gates_test.sh`
/// — فنُقل إلى الوحدة ولم يُترك في الشاشة، لئلّا يبقى للمنفّذ فلترانِ
/// يفترقان.
const String kUnassignedFilter = '__unassigned__';

/// نوعُ السجل — وبه يفصل البحثُ الموحّد.
enum RecordKind {
  project('مشروع'),
  work('عمل');

  final String label;
  const RecordKind(this.label);
}

/// حالاتٌ سريعة يُسأل عنها كثيراً، فتُختصر في شريحةٍ واحدة.
///
/// **وليست درجةَ الخطورة في التقرير اليومي.** تلك حكمٌ يُبنى على الخادم
/// بعتباتٍ خاصّة به ويكتب أسبابَه نصّاً (`functions/src/daily_report.ts`).
/// وهذه تصفيةُ شاشة. فلا يُدّعى أنهما واحدة، ويُكتب معنى كلِّ شريحةٍ تحتها
/// في الواجهة فلا يُقرأ الرقمُ على غير وجهه.
enum QuickState {
  /// تجاوز موعدَه ولم يُنجَز.
  late$('متأخر', 'تجاوز موعده النهائي ولم يُنجَز'),

  /// أُنجز.
  completed('مكتمل', 'بلغ نهايته'),

  /// مهدَّدٌ أو متوقّف — وللعمل: بانتظار اعتماد إغلاقه.
  needsFollowUp('يحتاج متابعة', 'مهدَّد بالخطر أو عليه عائق مفتوح'),

  /// مضى على آخر تحديثٍ له أكثرُ من حدّ الجمود — أو لا تحديثَ عليه إطلاقاً.
  stale('بلا تحديث حديث', 'مضى على آخر تحديث أكثر من حدّ الجمود');

  final String label;

  /// ما تعنيه الشريحةُ بالضبط — يُعرض تحتها لا يُترك يُستنتج.
  final String meaning;

  const QuickState(this.label, this.meaning);
}

/// ما اختاره المستخدم من فلاتر — قيمةٌ ثابتة تُنسخ ولا تُعدَّل في مكانها.
class RecordFilter {
  final String query;
  final String? departmentId;

  /// القسمُ داخل الإدارة. و**الأعمالُ بلا قسم** (`sectionId` على المشروع
  /// وحده)، فاختيارُه يُخرجها — ويُقال ذلك في الشاشة لا يُترك يُستنتج.
  final String? sectionId;

  /// المنفّذ: حسابُه، ومعه اسمُه للبيانات المستوردة التي تحمل الاسم بلا حساب.
  final String? executorUid;
  final String? executorName;

  /// مديرُ المشروع. و**الأعمالُ بلا مدير** — لها مُسنَدٌ إليه — فيُخرجها.
  final String? managerUid;

  final ProjectStatus? projectStatus;
  final TaskStatus? workStatus;
  final String? categoryId;

  /// أنواعُ السجلات المعروضة. الفارغةُ تعني **الكلّ** لا لا شيء: فلترٌ لم
  /// يُلمس يجب أن يُظهر كلَّ شيء.
  final Set<RecordKind> kinds;

  final QuickState? quick;

  const RecordFilter({
    this.query = '',
    this.departmentId,
    this.sectionId,
    this.executorUid,
    this.executorName,
    this.managerUid,
    this.projectStatus,
    this.workStatus,
    this.categoryId,
    this.kinds = const {},
    this.quick,
  });

  /// هل هناك ما يُعاد ضبطُه؟ — وبه يظهر زرُّ إعادة الضبط أو يُخفى.
  bool get isEmpty =>
      query.trim().isEmpty &&
      departmentId == null &&
      sectionId == null &&
      executorUid == null &&
      managerUid == null &&
      projectStatus == null &&
      workStatus == null &&
      categoryId == null &&
      kinds.isEmpty &&
      quick == null;

  bool get isNotEmpty => !isEmpty;

  /// كم فلتراً مُفعَّلاً — يُعرض على زرّ الضبط فيُعرف حجمُ ما يُزال.
  int get activeCount => [
        query.trim().isNotEmpty,
        departmentId != null,
        sectionId != null,
        executorUid != null,
        managerUid != null,
        projectStatus != null,
        workStatus != null,
        categoryId != null,
        kinds.isNotEmpty,
        quick != null,
      ].where((on) => on).length;

  /// `clear` تُفرِّغ حقلاً بعينه: `copyWith(departmentId: null)` وحدها لا
  /// تستطيع ذلك — `null` فيها تعني «لا تغيّر». وهو فخٌّ معروف في `copyWith`،
  /// ولولا هذا لَما أمكن **إزالةُ** فلترٍ إلا بإعادة بناء الكائن كلِّه.
  RecordFilter copyWith({
    String? query,
    String? departmentId,
    String? sectionId,
    String? executorUid,
    String? executorName,
    String? managerUid,
    ProjectStatus? projectStatus,
    TaskStatus? workStatus,
    String? categoryId,
    Set<RecordKind>? kinds,
    QuickState? quick,
    Set<String> clear = const {},
  }) =>
      RecordFilter(
        query: query ?? this.query,
        departmentId:
            clear.contains('departmentId') ? null : departmentId ?? this.departmentId,
        sectionId: clear.contains('sectionId') ? null : sectionId ?? this.sectionId,
        executorUid:
            clear.contains('executor') ? null : executorUid ?? this.executorUid,
        executorName:
            clear.contains('executor') ? null : executorName ?? this.executorName,
        managerUid: clear.contains('managerUid') ? null : managerUid ?? this.managerUid,
        projectStatus: clear.contains('projectStatus')
            ? null
            : projectStatus ?? this.projectStatus,
        workStatus:
            clear.contains('workStatus') ? null : workStatus ?? this.workStatus,
        categoryId: clear.contains('categoryId') ? null : categoryId ?? this.categoryId,
        kinds: kinds ?? this.kinds,
        quick: clear.contains('quick') ? null : quick ?? this.quick,
      );
}

/// ما تحتاجه التصفيةُ من المنصة — **قيمٌ لا مخزن**، فتُبنى في الاختبار.
class RecordFilterInput {
  final List<Project> projects;
  final List<WorkItem> works;

  /// آخرُ تحديثٍ لكل مشروع ولكل عمل — للحالة «بلا تحديثٍ حديث».
  /// والغيابُ من الخريطة يعني **لا تحديثَ إطلاقاً**، وهو أشدُّ جموداً لا أقلّ.
  final Map<String, DateTime> lastProjectUpdate;
  final Map<String, DateTime> lastWorkUpdate;

  /// المشاريعُ التي عليها عائقٌ مفتوح — للحالة «يحتاج متابعة».
  final Set<String> projectsWithOpenBlockers;

  /// حدُّ الجمود بالأيام — وهو `inactiveAfterDays` القائم في إعدادات
  /// التقارير الدورية، لا رقمٌ ثانٍ يُخترع هنا.
  final int inactiveAfterDays;

  /// اليومُ — يُحقن ليكون الاختبارُ ثابتاً لا يتبدّل بمرور الوقت.
  final DateTime today;

  const RecordFilterInput({
    required this.projects,
    required this.works,
    required this.today,
    required this.inactiveAfterDays,
    this.lastProjectUpdate = const {},
    this.lastWorkUpdate = const {},
    this.projectsWithOpenBlockers = const {},
  });

  /// نسخةٌ بأعمالٍ أخرى — لشاشة الأعمال حين تبدّل مصدرَ قائمتها.
  ///
  /// و«سجلُّ المنجَز» مصدرٌ لا فلتر: زرٌّ يبدّل ما يُصفَّى لا شرطاً يُضاف.
  RecordFilterInput copyWithWorks(List<WorkItem> works) => RecordFilterInput(
        projects: projects,
        works: works,
        today: today,
        inactiveAfterDays: inactiveAfterDays,
        lastProjectUpdate: lastProjectUpdate,
        lastWorkUpdate: lastWorkUpdate,
        projectsWithOpenBlockers: projectsWithOpenBlockers,
      );
}

/// يُطبّق الفلاتر **كلَّها معاً** — تقاطُعاً لا اتّحاداً.
///
/// وهذا هو ما طلبتَه صراحةً: «الإدارة: تقنية المعلومات، القسم: الأنظمة،
/// الحالة: متأخر، المنفذ: أحمد» تُعيد ما طابق **الأربعة**.
({List<Project> projects, List<WorkItem> works}) applyRecordFilter(
  RecordFilter f,
  RecordFilterInput input,
) {
  final showProjects = f.kinds.isEmpty || f.kinds.contains(RecordKind.project);
  final showWorks = f.kinds.isEmpty || f.kinds.contains(RecordKind.work);
  final q = f.query.trim().toLowerCase();

  bool matchesText(String name, String description, String extra) =>
      q.isEmpty ||
      name.toLowerCase().contains(q) ||
      description.toLowerCase().contains(q) ||
      extra.toLowerCase().contains(q);

  final projects = !showProjects
      ? const <Project>[]
      : input.projects.where((p) {
          // ــ والمعرّفُ مقروءٌ لمن يعرفه ــ
          //
          // لا يُعرض في شاشةٍ، لكنه يظهر في الروابط وفي رسائل الأخطاء —
          // فمن نسخه من هناك يجد مشروعَه بلا أن نُضيف حقلاً ونُرقّم ١٨٤
          // مشروعاً قائماً.
          if (!matchesText(p.name, p.description, '${p.id} ${p.executorNames.join(' ')}')) {
            return false;
          }
          if (f.departmentId != null && p.departmentId != f.departmentId) return false;
          if (f.sectionId != null && p.sectionId != f.sectionId) return false;
          if (f.categoryId != null && !p.categoryIds.contains(f.categoryId)) return false;
          if (f.managerUid != null && !p.managerUids.contains(f.managerUid)) return false;
          // و«بانتظار التكليف» وصفُ عملٍ لا مشروع — فيُخرج المشاريع كلَّها.
          if (f.executorUid == kUnassignedFilter) return false;
          if (f.executorUid != null && !_isExecutor(p, f)) return false;
          if (f.projectStatus != null && p.effectiveStatus != f.projectStatus) return false;
          if (f.quick != null && !_projectMatchesQuick(p, f.quick!, input)) return false;
          return true;
        }).toList();

  final works = !showWorks
      ? const <WorkItem>[]
      : input.works.where((w) {
          if (!matchesText(w.title, w.description, w.assigneeName)) return false;
          if (f.departmentId != null && w.departmentId != f.departmentId) return false;
          // العملُ بلا قسمٍ وبلا مديرِ مشروع — فأيُّ اختيارٍ لهما يُخرجه.
          if (f.sectionId != null) return false;
          if (f.managerUid != null) return false;
          if (f.categoryId != null) return false;
          if (f.executorUid == kUnassignedFilter) {
            if (w.assigneeUid.isNotEmpty) return false;
          } else if (f.executorUid != null && w.assigneeUid != f.executorUid) {
            return false;
          }
          if (f.workStatus != null && w.status != f.workStatus) return false;
          if (f.quick != null && !_workMatchesQuick(w, f.quick!, input)) return false;
          return true;
        }).toList();

  return (projects: projects, works: works);
}

/// عضويةُ المنفّذ: بالحساب، **وبالاسم النصّي** للبيانات المستوردة.
///
/// ومشاريعُ الوزارة المستوردة تحمل أسماءَ منفّذيها نصّاً بلا حسابات تقابلها.
/// فمقارنةُ الحساب وحدها تُسقطها كلَّها من فلتر المنفّذ — وهي أكثرُ ما في
/// المنصة. والقاعدةُ نفسُها في `AppStore.projectsOf`.
bool _isExecutor(Project p, RecordFilter f) {
  if (p.executorUids.contains(f.executorUid)) return true;
  final name = f.executorName?.trim();
  if (name == null || name.isEmpty) return false;
  return p.executorNames.any((e) => e.trim() == name);
}

bool _projectMatchesQuick(Project p, QuickState quick, RecordFilterInput input) =>
    switch (quick) {
      QuickState.late$ => p.effectiveStatus == ProjectStatus.delayed,
      QuickState.completed => p.effectiveStatus == ProjectStatus.completed,
      // مهدَّدٌ أو متوقّف. والمكتملُ خارجُها مهما كان مخزَّناً عليه: بلغ
      // نهايتَه فلا متابعةَ تُطلب.
      QuickState.needsFollowUp => p.effectiveStatus != ProjectStatus.completed &&
          (p.effectiveStatus == ProjectStatus.atRisk ||
              input.projectsWithOpenBlockers.contains(p.id)),
      QuickState.stale =>
        _isStale(input.lastProjectUpdate[p.id], input) &&
            p.effectiveStatus != ProjectStatus.completed,
    };

bool _workMatchesQuick(WorkItem w, QuickState quick, RecordFilterInput input) =>
    switch (quick) {
      QuickState.late$ =>
        w.status != TaskStatus.done && w.dueDate.isBefore(_startOfDay(input.today)),
      QuickState.completed => w.status == TaskStatus.done,
      // وللعمل: ما ينتظر اعتماد إغلاقه — هو ما يقف على مكتب أحدٍ فعلاً.
      QuickState.needsFollowUp => w.status == TaskStatus.awaitingApproval,
      QuickState.stale =>
        _isStale(input.lastWorkUpdate[w.id], input) && w.status != TaskStatus.done,
    };

/// جامدٌ: مضى على آخر تحديثٍ أكثرُ من الحدّ — **أو لا تحديثَ عليه إطلاقاً**.
///
/// وغيابُ التحديث ليس «غيرَ معروف» بل أشدُّ الجمود: سجلٌّ لم يُكتب عليه شيء
/// منذ أُنشئ. ولو استُثني لَاختفى من القائمة أكثرُ ما يستحق أن يُرى فيها.
bool _isStale(DateTime? last, RecordFilterInput input) {
  if (last == null) return true;
  final days = _startOfDay(input.today).difference(_startOfDay(last)).inDays;
  return days > input.inactiveAfterDays;
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
