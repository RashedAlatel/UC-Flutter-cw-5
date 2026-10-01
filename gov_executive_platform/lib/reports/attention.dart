/// **ما يحتاج تدخّلاً** — موضعٌ واحدٌ يقرّر، ويقرأ منه التقريرُ واللوحة.
///
/// ــــ لماذا وحدةٌ نقيّة ــــ
///
/// القاعدةُ التي طُلبت: «الإدارةُ بالاستثناء». والمنصّةُ تعرض اليومَ نفسَ
/// هذه القرارات في موضعين — **التقريرُ التنفيذيُّ اليوميُّ على الخادم**
/// (`functions/src/daily_report.ts`) ولوحةُ القيادة. ولوحةٌ تقول «ثلاثةُ
/// مشاريعَ متأخرة» وتقريرٌ يقول «أربعة» في الصباح نفسِه يُفقد الاثنين
/// معاً ثقتَهما.
///
/// فالقرارُ هنا، **بلا Firebase ولا واجهة**، يُقاس بالاختبار ويُستدعى من
/// حيث يُحتاج.
///
/// ــــ وما ليس هنا ــــ
///
/// العتباتُ لا تُكتب في هذا الملفّ: تُقرأ من `settings/alertRules` التي
/// يضبطها مسؤولُ النظام — «متأخرٌ بكم يوماً» و«بلا تحديثٍ منذ كم». فرقمٌ
/// مدفونٌ في الشيفرة يُجبر الوزارةَ على تعريفٍ لم تختره.
library;

import '../models/calendar_event.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/change_request.dart';
import '../models/contract.dart';
import '../models/it_asset.dart';
import '../models/ticket.dart';
import '../models/work_item.dart';
import '../itsm/sla.dart';

/// شدّةُ ما يحتاج تدخّلاً — وهي نفسُها في التقرير اليوميّ على الخادم.
enum AttentionSeverity {
  /// يوقف عملاً أو يهدّد التزاماً — يُنظر فيه اليوم.
  critical('حرج'),

  /// يحتاج متابعةً قبل أن يصير حرجاً.
  needsAttention('يحتاج انتباهاً');

  final String label;
  const AttentionSeverity(this.label);
}

/// بابُ الاهتمام — **وبه تُصفّى اللوحة**.
///
/// ولا يُجمع الكلُّ في قائمةٍ واحدةٍ طويلة: مديرُ القطاع يسأل «ما المتأخّر؟»
/// ثمّ «ما ينتظر قراري؟» — سؤالين لا سؤالاً.
enum AttentionKind {
  projectOverdue('مشروع متأخّر'),
  projectStale('مشروع بلا تحديث'),
  projectNoNextAction('مشروع بلا خطوة تالية'),
  taskOverdue('مهمّة متأخّرة'),
  workOverdue('عمل متأخّر'),
  decisionPending('قرار ينتظر'),
  contractExpiring('عقد يوشك على الانتهاء'),
  awaitingApproval('بانتظار الاعتماد'),
  ticketBreached('بلاغٌ تجاوز مدّته'),
  ticketAtRisk('بلاغٌ يوشك على تجاوز مدّته'),
  changeUnreviewed('تغييرٌ طارئٌ لم يُراجَع'),
  changeOverdue('تغييرٌ فات موعدُه ولم يُعتمد'),
  assetOverCapacity('أصلٌ تجاوز سعتَه');

  final String label;
  const AttentionKind(this.label);
}

/// بندٌ واحدٌ يحتاج تدخّلاً.
class AttentionItem {
  final AttentionKind kind;
  final AttentionSeverity severity;

  /// اسمُ الشيء — مشروعاً كان أو مهمّةً أو عقداً.
  final String title;

  /// لماذا ظهر هنا — «متأخّر ١٢ يوماً» لا «متأخّر».
  ///
  /// والعددُ لا الوصف: «متأخّر» لا تقول لمديرٍ يوازن بين عشرة بنودٍ أيُّها
  /// يبدأ به.
  final String reason;

  final String departmentId;

  /// معرّفُ السجلّ وبابُه — لتُفتح تفاصيلُه بالضغط.
  final String recordId;

  /// عددُ الأيام التي يقيسها [reason] — وبه يقع الترتيب.
  final int days;

  const AttentionItem({
    required this.kind,
    required this.severity,
    required this.title,
    required this.reason,
    required this.recordId,
    this.departmentId = '',
    this.days = 0,
  });
}

/// العتباتُ كما يضبطها مسؤولُ النظام — ونظيرُها `ReportThresholds` على الخادم.
class AttentionThresholds {
  /// عمرُ آخر تحديثٍ بالأيام قبل أن يُعدّ المشروعُ مهمَلاً.
  final int staleUpdateDays;

  /// ــ كم يوماً قبل الموعد يُقال «يستحقّ قريباً» ــ
  ///
  /// وهنا لا في `record_filter.dart`: «قريباً» في شريحة الحافظة يجب أن
  /// تعني ما تعنيه في «ما يحتاج تدخّلاً»، وإلّا قال الموضعان شيئين عن
  /// المشروع نفسِه — وهو العطلُ الذي تكرّر في هذه المنصّة.
  final int dueSoonDays;

  /// كم يوماً قبل انتهاء العقد يُنبَّه عليه.
  final int contractWarningDays;

  /// تأخُّرٌ يتجاوزه يصير حرجاً لا تحذيراً.
  final int criticalDelayDays;

  /// عمرُ القرار المعلَّق قبل أن يصير حرجاً.
  final int decisionAgingDays;

  const AttentionThresholds({
    this.staleUpdateDays = 7,
    this.dueSoonDays = 7,
    this.contractWarningDays = 90,
    this.criticalDelayDays = 14,
    this.decisionAgingDays = 7,
  });
}

/// أيامُ التأخُّر عن موعدٍ بحساب لحظةٍ مُعطاة.
///
/// ــ ولماذا لا تُقرأ `Project.delayDays` ــ
///
/// لأنّها تقرأ **ساعةَ الجهاز** (`DateTime.now()`) بداخلها. فمحرّكٌ يقبل
/// `now` وسيطاً ثمّ يقرأ الساعةَ لبعض حساباته **يعطي جوابين في التقرير
/// الواحد**: بعضُه بالتاريخ المطلوب وبعضُه باليوم الجاري.
///
/// وقد قبض ذلك أوّلُ اختبارٍ كُتب لهذا المحرّك: طُلب مشروعٌ متأخّرٌ اثني
/// عشر يوماً فقال المحرّكُ أحدَ عشر — لأنّه حسبها من يومٍ آخر.
int _lateDays(DateTime due, DateTime now) {
  final d = DateTime(due.year, due.month, due.day);
  final t = DateTime(now.year, now.month, now.day);
  return t.isAfter(d) ? t.difference(d).inDays : 0;
}

/// ما يحتاج تدخّلاً في هذا النطاق — **مرتَّباً بالأشدّ**.
class AttentionEngine {
  /// يبني القائمة.
  ///
  /// و[projects] و[tasks] و[works] **مصفّاةٌ بالنطاق قبل الدخول**: هذه
  /// الوحدةُ لا تعرف من يقرأ ولا تفحص صلاحية. والتصفيةُ في المتجر حيث
  /// تُقرأ البياناتُ أصلاً، فلا يوجد تعريفان لـ«ما أراه».
  static List<AttentionItem> build({
    required List<Project> projects,
    required List<ProjectTask> tasks,
    required List<WorkItem> works,
    required Map<String, DateTime> lastUpdateByProject,
    required int pendingDecisions,
    // ــ والبلاغاتُ بقيمةٍ مبدئيّةٍ لا مطلوبة ــ
    //
    // فالمحرّكُ يُنادى من لوحة القيادة ومن التقرير ومن اثني عشر اختباراً.
    // ووسيطٌ مطلوبٌ يكسرها كلَّها في سطرٍ واحد — وهو ما نُهي عنه صراحةً:
    // «أي تعديل يجب ألا يكسر الميزات الحالية».
    List<Ticket> tickets = const [],
    List<ChangeRequest> changes = const [],
    List<ITAsset> assets = const [],
    List<Contract> contracts = const [],
    SlaPolicy slaPolicy = SlaPolicy.standard,
    DateTime? now,
    AttentionThresholds thresholds = const AttentionThresholds(),
  }) {
    final today = now ?? DateTime.now();
    final items = <AttentionItem>[];

    for (final p in projects) {
      // والمكتملُ لا يُنبَّه عليه: تأخُّرُه خبرٌ للتقرير لا نداءٌ للتصرّف.
      if (p.effectiveStatus == ProjectStatus.completed) continue;

      final projectLate = _lateDays(p.dueDate, today);
      if (projectLate > 0) {
        items.add(AttentionItem(
          kind: AttentionKind.projectOverdue,
          severity: projectLate >= thresholds.criticalDelayDays
              ? AttentionSeverity.critical
              : AttentionSeverity.needsAttention,
          title: p.name,
          reason: 'متأخّر $projectLate يوماً عن موعده',
          departmentId: p.departmentId,
          recordId: p.id,
          days: projectLate,
        ));
      }

      final last = lastUpdateByProject[p.id];
      final age = last == null ? null : today.difference(last).inDays;
      if (age == null || age >= thresholds.staleUpdateDays) {
        items.add(AttentionItem(
          kind: AttentionKind.projectStale,
          severity: AttentionSeverity.needsAttention,
          title: p.name,
          // و«لم يُحدَّث قطّ» غيرُ «مضى عليه ١٢ يوماً»: الأوّلُ مشروعٌ لم
          // يبدأ أحدٌ يتابعه، والثاني متابعةٌ انقطعت.
          reason: age == null ? 'لم يُسجَّل له تحديثٌ قطّ' : 'بلا تحديثٍ منذ $age يوماً',
          departmentId: p.departmentId,
          recordId: p.id,
          days: age ?? 999,
        ));
      }

      // ــ وبلا خطوةٍ تالية ــ
      //
      // مشروعٌ جارٍ لا يعرف أحدٌ ما التالي فيه يتوقّف بلا أن يعلن توقّفه.
      if (p.nextAction.trim().isEmpty && p.progressPercent > 0 && p.progressPercent < 100) {
        items.add(AttentionItem(
          kind: AttentionKind.projectNoNextAction,
          severity: AttentionSeverity.needsAttention,
          title: p.name,
          reason: 'لا خطوةَ تاليةً مسجّلة',
          departmentId: p.departmentId,
          recordId: p.id,
        ));
      }

      final end = p.contractEndDate;
      if (end != null) {
        final left = end.difference(today).inDays;
        if (left >= 0 && left <= thresholds.contractWarningDays) {
          items.add(AttentionItem(
            kind: AttentionKind.contractExpiring,
            severity: left <= 30 ? AttentionSeverity.critical : AttentionSeverity.needsAttention,
            title: p.name,
            reason: 'ينتهي عقدُه بعد $left يوماً',
            departmentId: p.departmentId,
            recordId: p.id,
            days: left,
          ));
        }
      }
    }

    for (final t in tasks) {
      if (t.isDone) continue;
      final late = today.difference(t.dueDate).inDays;
      if (late <= 0) continue;
      items.add(AttentionItem(
        kind: AttentionKind.taskOverdue,
        severity: t.priority == PriorityLevel.critical || late >= thresholds.criticalDelayDays
            ? AttentionSeverity.critical
            : AttentionSeverity.needsAttention,
        title: t.title,
        reason: 'متأخّرة $late يوماً',
        departmentId: t.departmentId,
        recordId: t.id,
        days: late,
      ));
    }

    for (final w in works) {
      if (w.isDone) continue;
      if (w.isAwaitingApproval) {
        items.add(AttentionItem(
          kind: AttentionKind.awaitingApproval,
          severity: AttentionSeverity.needsAttention,
          title: w.title,
          reason: 'أُفيد بإتمامه وينتظر اعتماداً',
          departmentId: w.departmentId,
          recordId: w.id,
        ));
        continue;
      }
      final late = _lateDays(w.dueDate, today);
      if (late <= 0) continue;
      items.add(AttentionItem(
        kind: AttentionKind.workOverdue,
        severity: w.priority == PriorityLevel.critical || late >= thresholds.criticalDelayDays
            ? AttentionSeverity.critical
            : AttentionSeverity.needsAttention,
        title: w.title,
        reason: 'متأخّر $late يوماً',
        departmentId: w.departmentId,
        recordId: w.id,
        days: late,
      ));
    }

    if (pendingDecisions > 0) {
      items.add(AttentionItem(
        kind: AttentionKind.decisionPending,
        severity: AttentionSeverity.critical,
        title: 'قرارات تنتظر القيادة',
        reason: '$pendingDecisions بنداً واقفٌ على مكتب',
        recordId: '',
        days: pendingDecisions,
      ));
    }

    // الأشدُّ أوّلاً، ثمّ الأطولُ تأخُّراً: من يفتح اللوحةَ لدقيقةٍ يقرأ
    // أعلاها ويكفيه.
    // ــ البلاغاتُ تدخل من البابِ الذي تدخل منه المشاريعُ المتأخّرة ــ
    //
    // ولا شاشةَ ثالثةٌ لها حسابُها الخاصّ: مسؤولٌ يقرأ «ما يحتاج تدخّلاً»
    // يجب أن يرى فيه البلاغَ المتجاوزَ إلى جانب المشروع المتأخّر، لا أن
    // يفتح موضعين ليجمع بينهما بنفسه.
    for (final t in tickets) {
      // والمحلولُ والمغلقُ خارجَه: تجاوزُه خبرٌ للتقرير لا نداءٌ للتصرّف —
      // كما أنّ المشروعَ المكتملَ لا يُنبَّه على تأخّره.
      if (t.isDeleted || !t.status.isActive) continue;
      final clock = SlaEngine.resolve(t, slaPolicy, today);
      if (clock.outcome != SlaOutcome.breached && clock.outcome != SlaOutcome.atRisk) continue;
      final breached = clock.outcome == SlaOutcome.breached;
      // والأيّامُ هي ما يقع به الترتيب، فتُقاس من الموعد لا من الفتح.
      final lateDays = breached ? (-clock.remaining.inHours / 24).ceil() : 0;
      items.add(AttentionItem(
        kind: breached ? AttentionKind.ticketBreached : AttentionKind.ticketAtRisk,
        // و«يوشك» ليس حرجاً: الحرجُ ما وقع، وهذا ما يُتّقى قبل أن يقع.
        severity: breached ? AttentionSeverity.critical : AttentionSeverity.needsAttention,
        title: t.title,
        reason: breached
            ? 'تجاوز مهلةَ الحلّ — ${t.priority.label}'
            : 'يوشك على تجاوز مهلةِ الحلّ — ${t.priority.label}',
        departmentId: t.reporterDepartmentId,
        recordId: t.id,
        days: lateDays,
      ));
    }

    // ــ التغييراتُ: تغييرٌ في الإنتاج بلا اعتمادٍ لا يُنسى ــ
    for (final c in changes) {
      if (c.isDeleted) continue;
      // **وهذا هو ما يمنع أن يصير الطارئُ باباً خلفيّاً**: «يُنفَّذ ثمّ
      // يُراجَع» رخصةٌ للسرعة لا للإفلات. فما نُفِّذ ولم يُراجَع يبقى
      // ظاهراً حتّى يبتّ فيه أحد.
      if (c.awaitingReview) {
        final age = _lateDays(c.implementedAt ?? c.createdAt, today);
        items.add(AttentionItem(
          kind: AttentionKind.changeUnreviewed,
          severity: AttentionSeverity.critical,
          title: c.title,
          reason: age > 0 ? 'نُفِّذ طارئاً منذ $age يوماً ولم يُراجَع' : 'نُفِّذ طارئاً ولم يُراجَع',
          recordId: c.id,
          days: age,
        ));
        continue;
      }
      // وتغييرٌ فات موعدُ تنفيذه وما زال ينتظر البتّ: لا هو نُفِّذ ولا
      // هو سقط — وهذا أسوأُ من الرفض، إذ لا يعرف أحدٌ ما يفعل.
      final start = c.plannedStart;
      if (c.status == ChangeStatus.awaitingApproval && start != null) {
        final late = _lateDays(start, today);
        if (late > 0) {
          items.add(AttentionItem(
            kind: AttentionKind.changeOverdue,
            severity: AttentionSeverity.needsAttention,
            title: c.title,
            reason: 'فات موعدُ تنفيذه بـ$late يوماً وما زال ينتظر الاعتماد',
            recordId: c.id,
            days: late,
          ));
        }
      }
    }

    // ــ العقودُ المستقلّة: مصدرٌ ثانٍ لخبرٍ **لا يُعدّ مرّتين** ــ
    //
    // `Project` يحمل عقدَه أصلاً، وقد نُبِّه عليه أعلاه من `contractEndDate`.
    // فعقدٌ هنا يحمل `relatedProjectId` هو **الوثيقةُ نفسُها** مسجَّلةً
    // للتصفّح — ولو نُبِّه عليه لظهر العقدُ الواحد مرّتين في «ما يحتاج
    // تدخّلاً»، والرقمُ الذي يُعدّ مرّتين لا يُصدَّق مرّة.
    for (final c in contracts) {
      if (c.isDeleted || c.relatedProjectId.isNotEmpty) continue;
      final end = c.endDate;
      if (end == null) continue;
      final left = end.difference(today).inDays;
      // ومهلةُ التنبيه من العقد نفسِه: ترخيصٌ يُجدَّد في أسبوعٍ غيرُ عقدِ
      // دعمٍ تستغرق مناقصتُه ثلاثة أشهر.
      if (left < 0 || left > c.renewalNoticeDays) continue;
      items.add(AttentionItem(
        kind: AttentionKind.contractExpiring,
        severity: left <= 30 ? AttentionSeverity.critical : AttentionSeverity.needsAttention,
        title: c.title,
        reason: 'ينتهي بعد $left يوماً — ${c.vendorName.isEmpty ? c.kind.label : c.vendorName}',
        recordId: c.id,
        days: left,
      ));
    }

    // ــ والأصلُ الذي تجاوز سعتَه ــ
    //
    // و**غيرُ المقيس ليس متجاوزاً**: `capacityUsedPercent` الغائبةُ تُقرأ
    // «لم تُقَس» لا صفراً — يفرضه `ITAsset.isOverCapacity`.
    for (final a in assets) {
      if (a.isDeleted || !a.isOverCapacity) continue;
      items.add(AttentionItem(
        kind: AttentionKind.assetOverCapacity,
        // والحَرِجيّةُ من تصنيف الأصل لا من النسبة: خادمُ `tier1` عند ٩٠٪
        // خطرٌ، وطابعةُ `tier3` عنده خبر.
        severity: a.criticality == 'tier1'
            ? AttentionSeverity.critical
            : AttentionSeverity.needsAttention,
        title: a.name,
        reason: 'استهلك ${a.capacityUsedPercent}% من سعته (الحدّ ${a.capacityThreshold}%)',
        departmentId: a.departmentServed,
        recordId: a.id,
      ));
    }

    items.sort((a, b) {
      if (a.severity != b.severity) {
        return a.severity == AttentionSeverity.critical ? -1 : 1;
      }
      return b.days.compareTo(a.days);
    });
    return items;
  }

  /// عددُ البنود لكلّ باب — لبطاقات اللوحة.
  static Map<AttentionKind, int> countByKind(List<AttentionItem> items) {
    final counts = <AttentionKind, int>{};
    for (final i in items) {
      counts[i.kind] = (counts[i.kind] ?? 0) + 1;
    }
    return counts;
  }
}

/// أحداثُ التقويم — **مُشتقّةٌ من بيانات المنصّة لا مخزَّنة**.
///
/// راجع `CalendarEvent`: مجموعةٌ ثانيةٌ تحمل نسخةً من هذه التواريخ كانت
/// ستنحرف عنها بأوّل تأجيلِ موعد.
class CalendarBuilder {
  /// يبني أحداثَ مدىً زمنيّ من المشاريع والمهامّ والأعمال والعطل.
  ///
  /// والمدخلاتُ مصفّاةٌ بالنطاق قبل الدخول، كما في `AttentionEngine`.
  static List<CalendarEvent> build({
    required List<Project> projects,
    required List<ProjectTask> tasks,
    required List<WorkItem> works,
    required Map<String, String> holidayNames,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final events = <CalendarEvent>[];

    for (final p in projects) {
      final done = p.effectiveStatus == ProjectStatus.completed;
      events.add(CalendarEvent(
        day: p.startDate,
        kind: EventKind.projectStart,
        title: p.name,
        departmentId: p.departmentId,
        recordId: p.id,
      ));
      events.add(CalendarEvent(
        day: p.dueDate,
        kind: EventKind.projectDue,
        title: p.name,
        departmentId: p.departmentId,
        recordId: p.id,
        isOverdue: !done && _lateDays(p.dueDate, today) > 0,
      ));
      final end = p.contractEndDate;
      if (end != null) {
        events.add(CalendarEvent(
          day: end,
          kind: EventKind.contractEnd,
          title: p.contractorName.isEmpty ? p.name : '${p.name} — ${p.contractorName}',
          departmentId: p.departmentId,
          recordId: p.id,
          isOverdue: _lateDays(end, today) > 0,
        ));
      }
      final invoice = p.invoiceDueDate;
      if (invoice != null) {
        events.add(CalendarEvent(
          day: invoice,
          kind: EventKind.invoiceDue,
          title: p.name,
          departmentId: p.departmentId,
          recordId: p.id,
          isOverdue: _lateDays(invoice, today) > 0,
        ));
      }
      final next = p.nextActionDate;
      if (next != null && p.nextAction.trim().isNotEmpty) {
        events.add(CalendarEvent(
          day: next,
          kind: EventKind.nextAction,
          title: '${p.name}: ${p.nextAction}',
          departmentId: p.departmentId,
          recordId: p.id,
          isOverdue: !done && _lateDays(next, today) > 0,
        ));
      }
    }

    for (final t in tasks) {
      if (t.isDone) continue;
      events.add(CalendarEvent(
        day: t.dueDate,
        kind: EventKind.taskDue,
        title: t.title,
        departmentId: t.departmentId,
        recordId: t.id,
        isOverdue: _lateDays(t.dueDate, today) > 0,
      ));
    }

    for (final w in works) {
      if (w.isDone) continue;
      events.add(CalendarEvent(
        day: w.dueDate,
        kind: EventKind.workDue,
        title: w.title,
        departmentId: w.departmentId,
        recordId: w.id,
        isOverdue: _lateDays(w.dueDate, today) > 0,
      ));
    }

    // والعطلُ للوزارة كلِّها: بلا إدارةٍ تُصفّى بها.
    for (final entry in holidayNames.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null) continue;
      events.add(CalendarEvent(
        day: day,
        kind: EventKind.holiday,
        title: entry.value,
      ));
    }

    events.sort((a, b) => a.day.compareTo(b.day));
    return events;
  }

  /// أحداثُ يومٍ بعينه.
  static List<CalendarEvent> onDay(List<CalendarEvent> events, DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return events.where((e) => e.dayOnly == key).toList();
  }

  /// أحداثُ شهرٍ مجموعةً بأيامها — لصبغ مربّعات التقويم.
  static Map<DateTime, List<CalendarEvent>> byDay(List<CalendarEvent> events) {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      map.putIfAbsent(e.dayOnly, () => []).add(e);
    }
    return map;
  }
}
