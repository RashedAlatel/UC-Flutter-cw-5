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

import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/work_item.dart';

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
  awaitingApproval('بانتظار الاعتماد');

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

  /// كم يوماً قبل انتهاء العقد يُنبَّه عليه.
  final int contractWarningDays;

  /// تأخُّرٌ يتجاوزه يصير حرجاً لا تحذيراً.
  final int criticalDelayDays;

  /// عمرُ القرار المعلَّق قبل أن يصير حرجاً.
  final int decisionAgingDays;

  const AttentionThresholds({
    this.staleUpdateDays = 7,
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
