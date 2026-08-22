/**
 * تقرير الإدارة بالاستثناء — الحساب.
 *
 * ــــ لماذا هنا، لا في Dart؟ ــــ
 *
 * التقرير يُقرأ على الشاشة **ويُرسل بالبريد**. وكتابة سبعة أبواب ودرجةِ
 * خطورةٍ مرّتين — واحدة للشاشة وأخرى للبريد — تعني أن يفترق النصّان عند أول
 * تعديل يُنسى في أحدهما، فيقرأ المدير على الشاشة غير ما وصله في بريده.
 * ولا يصيح شيء: كلا النصّين صحيحٌ في نفسه.
 *
 * فالحساب هنا **مرة واحدة**، ويُكتب ناتجه مستنداً، ويعرضه العميل كما هو.
 *
 * وكل ما في هذا الملف **دوالّ خالصة**: تأخذ لقطةً وتُرجع تقريراً، بلا
 * Firestore ولا شبكة ولا وقتٍ حاضر تقرؤه بنفسها. فتُختبر بلقطةٍ مصنوعة
 * ويُثبت أن «متأخر» يُصنَّف حرجاً فعلاً، لا أن الشاشة تعرض شيئاً.
 */

// ============================ المدخلات ============================

/** درجة الخطورة كما طُلبت: حرج · يحتاج انتباه · طبيعي. */
export type Severity = "critical" | "needsAttention" | "normal";

export const SEVERITY_LABEL: Record<Severity, string> = {
  critical: "حرج",
  needsAttention: "يحتاج انتباه",
  normal: "طبيعي",
};

/** ترتيب الخطورة تنازلياً — به تُرتَّب «أهم الحالات». */
const SEVERITY_RANK: Record<Severity, number> = {
  critical: 3,
  needsAttention: 2,
  normal: 1,
};

export interface ReportThresholds {
  /** «قريب الاستحقاق»: الأيام المتبقية حتى الموعد. */
  dueSoonDays: number;
  /** «بلا تحديث حديث»: عمر آخر تحديث بالأيام. */
  staleUpdateDays: number;
  /**
   * هامش التسامح بين الإنجاز الفعلي والمتوقَّع من الزمن (نقاط مئوية).
   *
   * بلا هامش يصير كلُّ مشروعٍ متأخراً بنقطة واحدة «غير متناسب»، فيمتلئ
   * التقرير بما لا يحتاج قراراً — وهو نقيض ما طُلب.
   */
  lagMarginPercent: number;
}

export const DEFAULT_THRESHOLDS: ReportThresholds = {
  dueSoonDays: 3,
  staleUpdateDays: 7,
  lagMarginPercent: 15,
};

export interface ProjectRec {
  id: string;
  name: string;
  departmentId: string;
  status: string;
  progressPercent: number;
  startDate: Date;
  dueDate: Date;
  managerUids: string[];
  managerNames: string[];
}

/**
 * مهمّة مشروع أو عمل تشغيلي، بصورة واحدة.
 *
 * وحّدتُهما لأن الأبواب تعاملهما معاملةً واحدة («المهام والأعمال المتأخرة»)،
 * ويبقى `kind` مميّزاً لأن الوجهة عند الضغط تختلف.
 */
export interface ItemRec {
  id: string;
  kind: "task" | "work";
  title: string;
  departmentId: string;
  /**
   * المشروع التابع له — **null لكل عمل تشغيلي**.
   *
   * وهذا حدٌّ في نموذج البيانات لا نقصٌ في التقرير: `WorkItem` لا يحمل
   * `projectId` إطلاقاً، فالأعمال مرتبطة بإدارة لا بمشروع. فيظهر عمودا
   * «المشروع» و«مدير المشروع» فارغَين للأعمال، ويُقال ذلك في الشاشة بدل
   * أن يُختلق لهما ارتباط.
   */
  projectId: string | null;
  projectName: string | null;
  projectManagerName: string | null;
  assigneeUid: string;
  assigneeName: string;
  status: string;
  progressPercent: number;
  dueDate: Date;
  lastUpdated: Date;
  /**
   * تاريخ الإنشاء — **null لمهام المشاريع**.
   *
   * `ProjectTask` لا يحمل تاريخ إنشاء في نموذج البيانات، والعمل يحمله. فمدّة
   * الانتظار في باب «بين الإدارات» تُقال للأعمال وتُترك «غير معروفة» للمهام.
   * وأخذُ `lastUpdated` بدلاً منه يقلب المعنى رأساً على عقب: أطولُ الطلبات
   * انتظاراً هو أقدمها إنشاءً، وآخرُ تحديثٍ عليه قد يكون اليوم — فتظهر
   * المهمة المهملة منذ شهور «بانتظار يومٍ واحد».
   */
  createdAt: Date | null;
  /** سجلّ الإغلاق: من يعتمد، ومن أفاد بالإتمام ومتى. */
  approverUid: string;
  approverName: string;
  claimedByName: string;
  claimedAt: Date | null;
}

/** تحديث يومي على مشروع أو على عمل، بصورة واحدة. */
export interface UpdateRec {
  id: string;
  kind: "project" | "work";
  refId: string;
  refName: string;
  departmentId: string;
  authorName: string;
  date: Date;
  progressPercent: number;
  achievements: string;
  blockers: string[];
  newRisks: string[];
  decisionsRequired: string[];
}

export interface BlockerRec {
  id: string;
  projectId: string;
  departmentId: string;
  description: string;
  status: string;
  dateRaised: Date;
}

/** نطاق المستلم: ما يحقّ له أن يراه في تقريره. */
export interface RecipientScope {
  uid: string;
  name: string;
  /** يرى كل الإدارات (مسؤول نظام أو مسؤول تنفيذي). */
  viewsAll: boolean;
  /** الإدارات التي يديرها. */
  departmentIds: string[];
  /** المشاريع التي يقودها. */
  projectIds: string[];
  /** عبارةٌ تُكتب في رأس التقرير تقول لقارئه ما الذي يغطّيه. */
  label: string;
}

export interface Snapshot {
  /** «اليوم» يُمرَّر ولا يُقرأ من الساعة — فالدالّة خالصة وتُختبر. */
  today: Date;
  projects: ProjectRec[];
  items: ItemRec[];
  updates: UpdateRec[];
  blockers: BlockerRec[];
  thresholds: ReportThresholds;
}

// ============================ المخرجات ============================

/** حقلٌ معروض في سطر: «الموعد النهائي: ٢٠٢٦/٠٩/٠١». */
export interface ReportField {
  label: string;
  value: string;
}

/**
 * سطرٌ في التقرير.
 *
 * `link` هو ما يجعل التقرير قابلاً للتصرّف لا للقراءة وحدها: العميل يفتح به
 * صفحة العنصر، والبريد يبني منه رابطاً مباشراً.
 */
export interface ReportRow {
  key: string;
  title: string;
  severity: Severity;
  /** لماذا ظهر هذا السطر في هذا الباب — بعبارةٍ تُقرأ لا برمز. */
  reason: string;
  fields: ReportField[];
  linkProjectId: string | null;
  linkWorkId: string | null;
}

export interface ReportSection {
  key: string;
  title: string;
  /** ما يُقال حين لا سطر فيه — وهو خبرٌ جيّد لا فراغ. */
  emptyNote: string;
  rows: ReportRow[];
}

export interface DailyReport {
  /** yyyy-MM-dd بتقويم الكويت. */
  date: string;
  recipientUid: string;
  recipientName: string;
  scopeLabel: string;
  criticalCount: number;
  attentionCount: number;
  headline: string;
  top: ReportRow[];
  sections: ReportSection[];
  generatedAt: string;
}

// ============================ أدوات الزمن ============================

/** فرق الأيام الكاملة بين تاريخين، بلا ساعات — فاليوم وحدة القياس هنا. */
export function daysBetween(from: Date, to: Date): number {
  const a = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const b = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((b - a) / 86400000);
}

/** أيام التأخير عن الموعد: موجبةٌ للمتأخر، صفرٌ لمن لم يحن موعده. */
export function delayDays(dueDate: Date, today: Date): number {
  const d = daysBetween(dueDate, today);
  return d > 0 ? d : 0;
}

/** الأيام المتبقية حتى الموعد — سالبةٌ لمن تجاوزه. */
export function remainingDays(dueDate: Date, today: Date): number {
  return daysBetween(today, dueDate);
}

/**
 * النسبة المتوقَّعة من الزمن المنقضي.
 *
 * مشروعٌ مضى نصف مدّته يُتوقَّع أن يكون في نصفه. وهذا تقديرٌ خطّي ساذج
 * عمداً: التقرير يشير إلى ما يستحق النظر، ولا يدّعي جدولاً مرجّحاً.
 */
export function expectedProgress(startDate: Date, dueDate: Date, today: Date): number {
  const total = daysBetween(startDate, dueDate);
  if (total <= 0) return 100;
  const elapsed = daysBetween(startDate, today);
  if (elapsed <= 0) return 0;
  if (elapsed >= total) return 100;
  return (elapsed / total) * 100;
}

const AR_DIGITS = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];

/** أرقام عربية — بقية المنصة تكتب بها، فلا يشذّ التقرير عنها. */
export function arabicDigits(value: number | string): string {
  return String(value).replace(/[0-9]/g, (d) => AR_DIGITS[Number(d)]);
}

export function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return arabicDigits(`${y}/${m}/${d}`);
}

export function formatPercent(value: number): string {
  return `${arabicDigits(Math.round(value))}٪`;
}

function dayLabel(n: number): string {
  if (n === 1) return "يوم واحد";
  if (n === 2) return "يومان";
  if (n <= 10) return `${arabicDigits(n)} أيام`;
  return `${arabicDigits(n)} يوماً`;
}

// ============================ النطاق ============================

function projectInScope(p: ProjectRec, scope: RecipientScope): boolean {
  if (scope.viewsAll) return true;
  if (scope.departmentIds.includes(p.departmentId)) return true;
  return scope.projectIds.includes(p.id);
}

function itemInScope(it: ItemRec, scope: RecipientScope): boolean {
  if (scope.viewsAll) return true;
  if (scope.departmentIds.includes(it.departmentId)) return true;
  if (it.projectId && scope.projectIds.includes(it.projectId)) return true;
  // ومن ينتظره اعتمادٌ يرى ما ينتظره ولو كان في إدارةٍ أخرى — وإلا لم يعلم
  // بما يقف على مكتبه، وهو نصف دورة الإغلاق بين الإدارات.
  return it.approverUid === scope.uid;
}

function updateInScope(u: UpdateRec, scope: RecipientScope): boolean {
  if (scope.viewsAll) return true;
  if (scope.departmentIds.includes(u.departmentId)) return true;
  return u.kind === "project" && scope.projectIds.includes(u.refId);
}

// ============================ حالة العنصر ============================

const CLOSED_STATUSES = new Set(["done"]);

export function isClosed(status: string): boolean {
  return CLOSED_STATUSES.has(status);
}

export function isAwaitingApproval(status: string): boolean {
  return status === "awaitingApproval";
}

/** آخر تحديثٍ سُجّل على مرجعٍ ما (مشروع أو عمل)، أو null. */
function lastUpdateOf(updates: UpdateRec[], refId: string): UpdateRec | null {
  let best: UpdateRec | null = null;
  for (const u of updates) {
    if (u.refId !== refId) continue;
    if (!best || u.date.getTime() > best.date.getTime()) best = u;
  }
  return best;
}

/**
 * انخفاض نسبة التقدّم بين آخر تحديثين.
 *
 * وهذا مقروءٌ فعلاً لا مستنتَج: كل تحديث يحمل النسبة **يوم كُتب**، فمقارنة
 * الأخيرَين تكشف تراجعاً حقيقياً — وهو إشارةٌ إدارية قويّة: إمّا أن تقديراً
 * سابقاً كان متفائلاً، وإمّا أن عملاً أُعيد.
 */
function progressDrop(updates: UpdateRec[], refId: string): number {
  const mine = updates
    .filter((u) => u.refId === refId)
    .sort((a, b) => b.date.getTime() - a.date.getTime());
  if (mine.length < 2) return 0;
  const drop = mine[1].progressPercent - mine[0].progressPercent;
  return drop > 0 ? drop : 0;
}

// ============================ أسباب المشروع ============================

interface Assessed {
  severity: Severity;
  reasons: string[];
}

function worst(a: Severity, b: Severity): Severity {
  return SEVERITY_RANK[a] >= SEVERITY_RANK[b] ? a : b;
}

/**
 * تقييم مشروع: ما الذي يستحق النظر فيه، وبأي درجة.
 *
 * الأسباب تُجمع كلها ولا يُكتفى بأوّلها: مشروعٌ متأخرٌ **ومتوقفٌ بعائق**
 * حالتُه غير مشروعٍ متأخرٍ يمضي، والفرق يُقرأ من السبب لا من الدرجة.
 */
export function assessProject(
  p: ProjectRec,
  snap: Snapshot,
  openBlockers: BlockerRec[],
): Assessed {
  const reasons: string[] = [];
  let severity: Severity = "normal";
  const {today, thresholds} = snap;

  if (p.status === "completed") return {severity: "normal", reasons: []};

  const late = delayDays(p.dueDate, today);
  if (late > 0) {
    reasons.push(`تجاوز موعده النهائي بـ${dayLabel(late)}`);
    severity = worst(severity, "critical");
  }

  const blockers = openBlockers.filter((b) => b.projectId === p.id);
  if (blockers.length > 0) {
    reasons.push(
      blockers.length === 1 ?
        `متوقف بعائق: ${blockers[0].description}` :
        `متوقف بـ${arabicDigits(blockers.length)} عوائق مفتوحة`,
    );
    severity = worst(severity, "critical");
  }

  const remaining = remainingDays(p.dueDate, today);
  const last = lastUpdateOf(snap.updates, p.id);
  const staleDays = last ? daysBetween(last.date, today) : Number.MAX_SAFE_INTEGER;
  const isStale = staleDays > thresholds.staleUpdateDays;

  if (late === 0 && remaining >= 0 && remaining <= thresholds.dueSoonDays) {
    if (isStale) {
      // قرب الاستحقاق **بلا تحديث حديث** حرجٌ لا انتباه: الموعد يقترب ولا
      // أحد يعرف أين وصل العمل. وهو الباب الذي طُلب إفراده بنفسه.
      reasons.push(
        last ?
          `يستحق خلال ${dayLabel(remaining)} وآخر تحديث قبل ${dayLabel(staleDays)}` :
          `يستحق خلال ${dayLabel(remaining)} ولا تحديث مسجَّل عليه إطلاقاً`,
      );
      severity = worst(severity, "critical");
    } else {
      reasons.push(`يستحق خلال ${dayLabel(remaining)}`);
      severity = worst(severity, "needsAttention");
    }
  } else if (isStale && last) {
    reasons.push(`آخر تحديث قبل ${dayLabel(staleDays)}`);
    severity = worst(severity, "needsAttention");
  }

  const expected = expectedProgress(p.startDate, p.dueDate, today);
  const lag = expected - p.progressPercent;
  if (lag > thresholds.lagMarginPercent) {
    reasons.push(
      `الإنجاز ${formatPercent(p.progressPercent)} والمتوقَّع من الوقت المنقضي ${formatPercent(expected)}`,
    );
    severity = worst(severity, "needsAttention");
  }

  const drop = progressDrop(snap.updates, p.id);
  if (drop > 0) {
    reasons.push(`انخفضت نسبة التقدّم ${formatPercent(drop)} عن التحديث السابق`);
    severity = worst(severity, "needsAttention");
  }

  return {severity, reasons};
}

/** تقييم مهمّة أو عمل. */
export function assessItem(it: ItemRec, snap: Snapshot): Assessed {
  const reasons: string[] = [];
  let severity: Severity = "normal";
  const {today, thresholds} = snap;

  if (isClosed(it.status)) return {severity: "normal", reasons: []};

  const late = delayDays(it.dueDate, today);
  if (late > 0) {
    reasons.push(`متأخر ${dayLabel(late)}`);
    severity = worst(severity, "critical");
  }

  const staleDays = daysBetween(it.lastUpdated, today);
  const isStale = staleDays > thresholds.staleUpdateDays;
  const remaining = remainingDays(it.dueDate, today);

  if (late === 0 && remaining >= 0 && remaining <= thresholds.dueSoonDays) {
    if (isStale) {
      reasons.push(`يستحق خلال ${dayLabel(remaining)} وآخر تحديث قبل ${dayLabel(staleDays)}`);
      severity = worst(severity, "critical");
    } else {
      reasons.push(`يستحق خلال ${dayLabel(remaining)}`);
      severity = worst(severity, "needsAttention");
    }
  } else if (isStale) {
    reasons.push(`آخر تحديث قبل ${dayLabel(staleDays)}`);
    severity = worst(severity, "needsAttention");
  }

  if (isAwaitingApproval(it.status)) {
    const waited = it.claimedAt ? daysBetween(it.claimedAt, today) : 0;
    reasons.push(
      waited > 0 ?
        `أُفيد بإتمامه وينتظر الاعتماد منذ ${dayLabel(waited)}` :
        "أُفيد بإتمامه وينتظر اعتماد مدير المشروع",
    );
    severity = worst(severity, waited > thresholds.dueSoonDays ? "critical" : "needsAttention");
  }

  return {severity, reasons};
}

// ============================ بناء الأسطر ============================

function projectRow(p: ProjectRec, a: Assessed, snap: Snapshot): ReportRow {
  const last = lastUpdateOf(snap.updates, p.id);
  return {
    key: `project:${p.id}`,
    title: p.name,
    severity: a.severity,
    reason: a.reasons.join(" · "),
    fields: [
      {label: "الموعد النهائي", value: formatDate(p.dueDate)},
      {label: "أيام التأخير", value: arabicDigits(delayDays(p.dueDate, snap.today))},
      {label: "نسبة الإنجاز", value: formatPercent(p.progressPercent)},
      {label: "مدير المشروع", value: p.managerNames.join("، ")},
      {label: "آخر تحديث", value: last ? formatDate(last.date) : "لا يوجد"},
    ],
    linkProjectId: p.id,
    linkWorkId: null,
  };
}

function itemRow(it: ItemRec, a: Assessed, snap: Snapshot): ReportRow {
  return {
    key: `${it.kind}:${it.id}`,
    title: it.title,
    severity: a.severity,
    reason: a.reasons.join(" · "),
    fields: [
      // المشروع ومديره فارغان للأعمال — راجع تعليق `ItemRec.projectId`.
      {label: "المشروع", value: it.projectName ?? "عمل تشغيلي (غير مرتبط بمشروع)"},
      {label: "المُسنَد إليه", value: it.assigneeName},
      {label: "مدير المشروع", value: it.projectManagerName ?? "—"},
      {label: "الموعد النهائي", value: formatDate(it.dueDate)},
      {label: "أيام التأخير", value: arabicDigits(delayDays(it.dueDate, snap.today))},
      {label: "آخر تحديث", value: formatDate(it.lastUpdated)},
    ],
    linkProjectId: it.kind === "task" ? it.projectId : null,
    linkWorkId: it.kind === "work" ? it.id : null,
  };
}

function updateRow(u: UpdateRec, previous: number | null): ReportRow {
  const fields: ReportField[] = [
    {label: "الجهة", value: u.refName},
    {label: "كاتب التحديث", value: u.authorName},
    {
      label: "نسبة التقدّم",
      value: previous === null ?
        formatPercent(u.progressPercent) :
        `${formatPercent(previous)} ← ${formatPercent(u.progressPercent)}`,
    },
  ];
  if (u.achievements.trim()) fields.push({label: "الإنجازات", value: u.achievements.trim()});
  if (u.blockers.length) fields.push({label: "عوائق جديدة", value: u.blockers.join("، ")});
  if (u.newRisks.length) fields.push({label: "مخاطر جديدة", value: u.newRisks.join("، ")});
  if (u.decisionsRequired.length) {
    fields.push({label: "قرارات مطلوبة", value: u.decisionsRequired.join("، ")});
  }

  // القرار المطلوب من القيادة هو ما يجعل التحديث بنداً تنفيذياً لا خبراً.
  const severity: Severity = u.decisionsRequired.length ?
    "critical" :
    (u.blockers.length || u.newRisks.length ? "needsAttention" : "normal");

  return {
    key: `update:${u.id}`,
    title: u.refName,
    severity,
    reason: u.decisionsRequired.length ?
      "يطلب قراراً من القيادة" :
      (u.blockers.length ? "سجّل عائقاً جديداً" : "تحديث خلال ٢٤ ساعة"),
    fields,
    linkProjectId: u.kind === "project" ? u.refId : null,
    linkWorkId: u.kind === "work" ? u.refId : null,
  };
}

// ============================ الأبواب السبعة ============================

/**
 * الترتيب المطلوب: بالخطورة ثم بأيام التأخير.
 *
 * وأيام التأخير تُقرأ من الحقل المعروض نفسه لا تُعاد حسابها: لو حُسبت هنا
 * مرةً أخرى لأمكن أن يختلف ما يُرتَّب به عمّا يُقرأ في السطر.
 */
function bySeverityThenDelay(a: ReportRow, b: ReportRow): number {
  const s = SEVERITY_RANK[b.severity] - SEVERITY_RANK[a.severity];
  if (s !== 0) return s;
  return delayFieldOf(b) - delayFieldOf(a);
}

function delayFieldOf(row: ReportRow): number {
  const f = row.fields.find((x) => x.label === "أيام التأخير");
  if (!f) return 0;
  return Number(f.value.replace(/[٠-٩]/g, (d) => String(AR_DIGITS.indexOf(d)))) || 0;
}

/**
 * يبني التقرير كاملاً لمستلمٍ واحد ضمن نطاقه.
 *
 * الترتيب هو الترتيب المطلوب حرفاً: ما يحتاج قراراً أولاً، والقراءة العامة
 * آخراً. ولا يُحذف بابٌ لأنه فارغ — الفراغ فيه خبرٌ يُقال («لا مشروع يحتاج
 * تدخلاً اليوم»)، وحذفُه يجعل القارئ لا يدري أفُحص الباب أم أُسقط.
 */
export function buildReport(
  snap: Snapshot,
  scope: RecipientScope,
  dateKey: string,
  generatedAt: string,
): DailyReport {
  const {today, thresholds} = snap;

  const projects = snap.projects.filter((p) => projectInScope(p, scope));
  const items = snap.items.filter((it) => itemInScope(it, scope));
  const updates = snap.updates.filter((u) => updateInScope(u, scope));
  const openBlockers = snap.blockers.filter(
    (b) => b.status !== "closed" && b.status !== "resolved",
  );

  const projectAssessment = new Map<string, Assessed>();
  for (const p of projects) projectAssessment.set(p.id, assessProject(p, snap, openBlockers));
  const itemAssessment = new Map<string, Assessed>();
  for (const it of items) itemAssessment.set(it.id, assessItem(it, snap));

  const sort = bySeverityThenDelay;
  const openItems = items.filter((it) => !isClosed(it.status));

  // ١) مشاريع تحتاج تدخلاً عاجلاً
  const urgent = projects
    .filter((p) => (projectAssessment.get(p.id)?.severity ?? "normal") !== "normal")
    .map((p) => projectRow(p, projectAssessment.get(p.id)!, snap))
    .sort(sort);

  // ٢) مهام وأعمال متأخرة
  const late = openItems
    .filter((it) => delayDays(it.dueDate, today) > 0)
    .map((it) => itemRow(it, itemAssessment.get(it.id)!, snap))
    .sort(sort);

  // ٣) قريبة الاستحقاق — الأقرب أولاً، لا الأخطر: القارئ يخطّط أسبوعه بها.
  const dueSoon = openItems
    .filter((it) => {
      const r = remainingDays(it.dueDate, today);
      return r >= 0 && r <= thresholds.dueSoonDays;
    })
    .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime())
    .map((it) => itemRow(it, itemAssessment.get(it.id)!, snap));

  // ٤) قريبة الاستحقاق **بلا تحديث حديث** — بابٌ مستقل بطلبٍ صريح
  const dueSoonStale = openItems
    .filter((it) => {
      const r = remainingDays(it.dueDate, today);
      if (r < 0 || r > thresholds.dueSoonDays) return false;
      return daysBetween(it.lastUpdated, today) > thresholds.staleUpdateDays;
    })
    .sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime())
    .map((it) => itemRow(it, itemAssessment.get(it.id)!, snap));

  // ٥) تحديثات آخر ٢٤ ساعة
  const cutoff = new Date(today.getTime() - 24 * 3600 * 1000);
  const recent = updates
    .filter((u) => u.date.getTime() >= cutoff.getTime())
    .sort((a, b) => b.date.getTime() - a.date.getTime())
    .map((u) => {
      const history = updates
        .filter((x) => x.refId === u.refId && x.date.getTime() < u.date.getTime())
        .sort((a, b) => b.date.getTime() - a.date.getTime());
      return updateRow(u, history.length ? history[0].progressPercent : null);
    });

  // ٦) طلبات ومعوقات بين الإدارات
  //
  // «بين الإدارات» يُقرأ من سجلّ الإغلاق نفسه: وجودُ معتمِدٍ يعني أن الطالب
  // خارج الإدارة المنفّذة — وهي القاعدة التي بُنيت عليها دورة الإغلاق من
  // مرحلتين. فلا يُختلق له تعريفٌ ثانٍ قد يفترق عنها.
  const crossDept = openItems
    .filter((it) => it.approverUid !== "")
    .map((it) => {
      const waited = it.createdAt === null ? null : daysBetween(it.createdAt, today);
      const a = itemAssessment.get(it.id)!;
      const row = itemRow(it, a, snap);
      const from = it.approverName || "جهة أخرى";
      return {
        ...row,
        key: `cross:${it.kind}:${it.id}`,
        reason: waited === null ?
          `مطلوب من ${from}` :
          `مطلوب من ${from} · بانتظار ${dayLabel(waited)}`,
        fields: [
          {label: "الجهة الطالبة", value: it.approverName || "—"},
          {label: "المسؤول عن التنفيذ", value: it.assigneeName},
          // «غير معروفة» لا صفر: المهمة لا تحمل تاريخ إنشاء — راجع
          // `ItemRec.createdAt`. والصفرُ هنا كذبٌ يُقرأ «طُلبت اليوم».
          {label: "مدّة الانتظار", value: waited === null ? "غير معروفة" : dayLabel(waited)},
          {label: "الحالة", value: statusLabel(it.status)},
          {label: "أيام التأخير", value: arabicDigits(delayDays(it.dueDate, today))},
        ],
      };
    })
    .sort(sort);

  // ٧) بانتظار اعتماد مدير المشروع
  const awaiting = openItems
    .filter((it) => isAwaitingApproval(it.status))
    .map((it) => {
      const a = itemAssessment.get(it.id)!;
      const row = itemRow(it, a, snap);
      return {
        ...row,
        key: `approval:${it.kind}:${it.id}`,
        fields: [
          {label: "أفاد بالإتمام", value: it.claimedByName || it.assigneeName},
          {label: "تاريخ الإفادة", value: it.claimedAt ? formatDate(it.claimedAt) : "—"},
          {label: "المعتمِد", value: it.approverName || "—"},
          {
            label: "مدّة الانتظار",
            value: it.claimedAt ? dayLabel(daysBetween(it.claimedAt, today)) : "—",
          },
          {label: "أيام التأخير", value: arabicDigits(delayDays(it.dueDate, today))},
        ],
      };
    })
    .sort(sort);

  const sections: ReportSection[] = [
    {
      key: "urgentProjects",
      title: "مشاريع تحتاج تدخلاً عاجلاً",
      emptyNote: "لا مشروع يحتاج تدخلاً اليوم.",
      rows: urgent,
    },
    {
      key: "lateItems",
      title: "مهام وأعمال متأخرة",
      emptyNote: "لا مهمة ولا عمل متأخر.",
      rows: late,
    },
    {
      key: "dueSoon",
      title: `قريبة الاستحقاق خلال ${dayLabel(thresholds.dueSoonDays)}`,
      emptyNote: "لا شيء يستحق خلال المدة القريبة.",
      rows: dueSoon,
    },
    {
      key: "dueSoonStale",
      title: "قريبة الاستحقاق بلا تحديث حديث",
      emptyNote: "كل ما يقترب موعده عليه تحديث حديث.",
      rows: dueSoonStale,
    },
    {
      key: "recentUpdates",
      title: "تحديثات آخر ٢٤ ساعة",
      emptyNote: "لم يُسجَّل تحديث خلال ٢٤ ساعة.",
      rows: recent,
    },
    {
      key: "crossDepartment",
      title: "طلبات ومعوقات بين الإدارات",
      emptyNote: "لا طلب معلّق بين الإدارات.",
      rows: crossDept,
    },
    {
      key: "awaitingApproval",
      title: "بانتظار اعتماد مدير المشروع",
      emptyNote: "لا شيء ينتظر اعتماداً.",
      rows: awaiting,
    },
  ];

  // «أهم خمس حالات»: من الأبواب الأربعة التي تحتاج قراراً، بلا تكرار.
  const seen = new Set<string>();
  const top: ReportRow[] = [];
  for (const row of [...urgent, ...late, ...crossDept, ...awaiting].sort(sort)) {
    const id = row.key.replace(/^(cross|approval):/, "");
    if (seen.has(id)) continue;
    seen.add(id);
    top.push(row);
    if (top.length === 5) break;
  }

  const decisive = [...urgent, ...late, ...crossDept, ...awaiting, ...dueSoonStale];
  const criticalCount = countDistinct(decisive, "critical");
  const attentionCount = countDistinct(decisive, "needsAttention");

  return {
    date: dateKey,
    recipientUid: scope.uid,
    recipientName: scope.name,
    scopeLabel: scope.label,
    criticalCount,
    attentionCount,
    headline: headlineOf(criticalCount, attentionCount, urgent.length, late.length),
    top,
    sections,
    generatedAt,
  };
}

function countDistinct(rows: ReportRow[], severity: Severity): number {
  const seen = new Set<string>();
  for (const r of rows) {
    if (r.severity !== severity) continue;
    seen.add(r.key.replace(/^(cross|approval):/, ""));
  }
  return seen.size;
}

function headlineOf(
  critical: number,
  attention: number,
  urgentProjects: number,
  lateItems: number,
): string {
  if (critical === 0 && attention === 0) {
    return "لا يوجد ما يستدعي تدخلاً اليوم — كل ما في نطاقك ضمن الطبيعي.";
  }
  const parts: string[] = [];
  if (critical > 0) parts.push(`${arabicDigits(critical)} حالة حرجة`);
  if (attention > 0) parts.push(`${arabicDigits(attention)} تحتاج انتباهاً`);
  const detail: string[] = [];
  if (urgentProjects > 0) detail.push(`${arabicDigits(urgentProjects)} مشروعاً يحتاج تدخلاً`);
  if (lateItems > 0) detail.push(`${arabicDigits(lateItems)} بنداً متأخراً`);
  const tail = detail.length ? ` (${detail.join("، ")})` : "";
  return `${parts.join(" و")}${tail}.`;
}

const STATUS_LABELS: Record<string, string> = {
  todo: "لم تبدأ",
  inProgress: "قيد التنفيذ",
  review: "قيد المراجعة",
  awaitingApproval: "بانتظار اعتماد مدير المشروع",
  done: "منجزة",
};

export function statusLabel(status: string): string {
  return STATUS_LABELS[status] ?? status;
}

// ============================ البريد ============================

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const SEVERITY_COLOR: Record<Severity, string> = {
  critical: "#B3261E",
  needsAttention: "#8A6100",
  normal: "#2E6B4F",
};

function rowHtml(row: ReportRow, baseUrl: string): string {
  const href = linkFor(row, baseUrl);
  const title = href ?
    `<a href="${escapeHtml(href)}" style="color:#0B5C3B;font-weight:700;text-decoration:none">${escapeHtml(row.title)}</a>` :
    `<strong>${escapeHtml(row.title)}</strong>`;
  const fields = row.fields
    .filter((f) => f.value && f.value !== "—")
    .map((f) => `<span style="color:#5B6B79">${escapeHtml(f.label)}:</span> ${escapeHtml(f.value)}`)
    .join(" &nbsp;·&nbsp; ");
  return `
    <div style="border-right:3px solid ${SEVERITY_COLOR[row.severity]};padding:8px 12px;margin:8px 0;background:#F7F9FA">
      <div>${title}
        <span style="color:${SEVERITY_COLOR[row.severity]};font-size:12px">— ${SEVERITY_LABEL[row.severity]}</span>
      </div>
      <div style="font-size:13px;color:#1C2733;margin-top:4px">${escapeHtml(row.reason)}</div>
      <div style="font-size:12px;color:#1C2733;margin-top:4px">${fields}</div>
    </div>`;
}

/** الرابط المباشر إلى العنصر — وهو ما يجعل البريد بابَ إجراء لا نصَّ قراءة. */
export function linkFor(row: ReportRow, baseUrl: string): string | null {
  if (!baseUrl) return null;
  if (row.linkProjectId) return `${baseUrl}/?project=${encodeURIComponent(row.linkProjectId)}`;
  if (row.linkWorkId) return `${baseUrl}/?work=${encodeURIComponent(row.linkWorkId)}`;
  return null;
}

/**
 * نصّ البريد — مبنيٌّ من التقرير نفسه الذي يُعرض على الشاشة.
 *
 * ولا يقبل نصّاً من أحد: لا موضوعاً ولا جسماً ولا مستلماً إضافياً. وهذا
 * حدُّ الاستثناء من بوابة البريد: التقرير المولَّد يخرج بلا اعتماد، وكل
 * بريدٍ يكتبه إنسان يبقى باعتماد مسؤول النظام عبر `sendUserNotification`.
 */
export function renderReportHtml(report: DailyReport, baseUrl: string): string {
  const sections = report.sections
    .map((s) => {
      const body = s.rows.length ?
        s.rows.map((r) => rowHtml(r, baseUrl)).join("") :
        `<div style="color:#5B6B79;font-size:13px;padding:4px 12px">${escapeHtml(s.emptyNote)}</div>`;
      return `
        <h3 style="margin:20px 0 4px;font-size:15px;color:#0B5C3B;border-bottom:1px solid #E1E6EB;padding-bottom:4px">
          ${escapeHtml(s.title)} (${arabicDigits(s.rows.length)})
        </h3>${body}`;
    })
    .join("");

  const top = report.top.length ?
    `<h3 style="margin:20px 0 4px;font-size:15px;color:#0B5C3B">أهم ${arabicDigits(report.top.length)} حالات</h3>
     ${report.top.map((r) => rowHtml(r, baseUrl)).join("")}` :
    "";

  return `
    <div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;text-align:right;line-height:1.8;color:#1C2733">
      <h2 style="margin:0 0 4px;font-size:18px;color:#0B5C3B">التقرير التنفيذي اليومي</h2>
      <div style="color:#5B6B79;font-size:13px">${escapeHtml(report.date)} — ${escapeHtml(report.scopeLabel)}</div>
      <p style="background:#EFF4F1;padding:10px 12px;border-radius:6px;margin:12px 0">
        ${escapeHtml(report.headline)}
      </p>
      ${top}
      ${sections}
      <hr style="border:none;border-top:1px solid #E1E6EB;margin:16px 0"/>
      <p style="color:#5B6B79;font-size:12px">
        تقرير آلي من المنصة التنفيذية — وزارة العدل. يُرسل الساعة السابعة صباحاً، ولا يُرد عليه.
      </p>
    </div>`;
}

/** موضوع الرسالة — يحمل الخلاصة، فيُقرأ من قائمة البريد بلا فتح. */
export function reportSubject(report: DailyReport): string {
  if (report.criticalCount > 0) {
    return `التقرير التنفيذي ${report.date} — ${arabicDigits(report.criticalCount)} حالة حرجة`;
  }
  if (report.attentionCount > 0) {
    return `التقرير التنفيذي ${report.date} — ${arabicDigits(report.attentionCount)} تحتاج انتباهاً`;
  }
  return `التقرير التنفيذي ${report.date} — لا حالات حرجة`;
}
