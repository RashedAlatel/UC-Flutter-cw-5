/**
 * التحويل بين **مشروع** و**عمل** — مقابلةُ الحقول والحالات.
 *
 * ــــ لماذا يُنشَأ نظيرٌ ويُؤرشَف الأصل، ولا يُنقل السجل؟ ــــ
 *
 * توابعُ المشروع كلُّها — المهام والتحديثات اليومية والمرفقات والمخاطر
 * والعوائق — معلّقةٌ بمعرّفه. ونقلُ السجل إلى مجموعةٍ أخرى يعني معرّفاً
 * جديداً، ومعه إعادةُ كتابة كل تابعٍ من مئاتٍ قد تكون له. وأيُّ سطرٍ يسقط
 * في المنتصف يترك تاريخاً مبتوراً لا يُعرف أين ذهب — وهو أسوأ من ألّا
 * يُحوَّل شيء.
 *
 * فالتاريخ يبقى كلُّه على الأصل المؤرشف، ويُقرأ منه، ويُوصَل الاثنان بحقلَي
 * ربطٍ في الاتجاهين.
 *
 * وهذه الوحدة **نقيّة**: لا تعرف Firestore ولا تكتب شيئاً. تأخذ مستند
 * الأصل وتُعيد مستند النظير، فتُختبر مقابلةُ كل حقلٍ بلا محاكٍ ولا شبكة —
 * كما `childMembershipPatch` و`projectMemberPatch`.
 */

export type RecordKind = "project" | "work";

/** المقابل من `ProjectStatus` و`TaskStatus` — بالأسماء كما تُكتب في المستند. */
export type ProjectStatusName = "onTrack" | "atRisk" | "delayed" | "completed";
export type TaskStatusName =
  | "todo" | "inProgress" | "review" | "awaitingApproval" | "done" | "blocked";

/**
 * حالةُ المشروع ← حالةُ العمل.
 *
 * و«متأخر» لا يُقابَل بشيء **بقصد**: تأخّرُ العمل يُحسب من موعده في كل عرض
 * (`WorkItem.delayDays`)، فنقلُه حقلاً مخزَّناً يُجمّده على يوم التحويل.
 *
 * وما لم يكتمل يُقابَل بحسب ما أُنجز منه فعلاً: صفرٌ يعني لم يبدأ، وما فوقه
 * قيد التنفيذ. وهذا أصدق من مقابلةٍ ثابتة، لأن «مهدد بالخطر» في بيانات
 * الوزارة المستوردة استُنتج من «لم يبدأ» تارةً ومن تقديرٍ بشري تارة.
 */
export function taskStatusFor(status: string, progressPercent: number): TaskStatusName {
  if (status === "completed") return "done";
  return progressPercent > 0 ? "inProgress" : "todo";
}

/**
 * حالةُ العمل ← حالةُ المشروع.
 *
 * و«معلّقة» تُقابَل بـ«مهدد بالخطر» لا بـ«على المسار»: عملٌ توقّف ليس عملاً
 * يسير. أما «بانتظار الاعتماد» فليست إغلاقاً — راجع `TaskStatus.isClosed` —
 * فتبقى على المسار حتى يعتمدها صاحبها.
 */
export function projectStatusFor(status: string): ProjectStatusName {
  if (status === "done") return "completed";
  if (status === "blocked") return "atRisk";
  return "onTrack";
}

export interface ConvertOptions {
  /** معرّف الأصل — يُكتب في حقل الربط على النظير. */
  sourceId: string;
  /** من يتولّى النظير: المسؤول إن كان عملاً، والقائد إن كان مشروعاً. */
  ownerUid: string;
  ownerName: string;
  /** طابع الوقت الذي يُكتب لما لا طابع له في الأصل. */
  now: unknown;
}

function str(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

function num(v: unknown, fallback = 0): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function strList(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((v): v is string => typeof v === "string") : [];
}

/**
 * مشروعٌ ← مستندُ عمل.
 *
 * وحقول الحذف تُكتب فارغةً صراحةً: النظير يُولد حيّاً ولو وُلد من أصلٍ
 * سيُؤرشَف بعد سطر، وتركُ المفاتيح غائبة يجعل قراءتها تختلف بين عميلٍ
 * وقاعدة.
 */
export function projectToWork(
  project: Record<string, unknown>,
  o: ConvertOptions,
): Record<string, unknown> {
  const progress = num(project.progressPercent);
  const status = taskStatusFor(str(project.status, "onTrack"), progress);
  return {
    title: str(project.name),
    description: str(project.description),
    departmentId: str(project.departmentId),
    assigneeUid: o.ownerUid,
    assigneeName: o.ownerName,
    status,
    priority: str(project.priority, "medium"),
    progressPercent: progress,
    dueDate: project.dueDate ?? o.now,
    completedDate: status === "done" ? o.now : null,
    isRecurring: false,
    // المنشئ يبقى المنشئ: التحويل تغييرُ شكلٍ لا نسبةٍ إلى صاحبٍ جديد.
    createdByUid: str(project.createdByUid),
    createdAt: project.createdAt ?? o.now,
    closure: {},
    deletedAt: null,
    deletedBy: null,
    deletedReason: null,
    convertedFromType: "project",
    convertedFromId: o.sourceId,
    convertedToType: null,
    convertedToId: null,
  };
}

/** عملٌ ← مستندُ مشروع. */
export function workToProject(
  work: Record<string, unknown>,
  o: ConvertOptions,
): Record<string, unknown> {
  // المُسنَد إليه الأصلي يُدرَج منفّذاً إن لم يكن هو القائد المختار — فلا
  // يخرج من سجلٍّ كان على مكتبه بلا أثر.
  const assignee = str(work.assigneeUid);
  const executorUids = assignee && assignee !== o.ownerUid ? [assignee] : [];
  const assigneeName = str(work.assigneeName);
  return {
    name: str(work.title),
    description: str(work.description),
    departmentId: str(work.departmentId),
    // العمل بلا تاريخ بدء، فتاريخُ إنشائه هو بدؤه — لا اليوم: مشروعٌ بدأ
    // قبل شهور لا يُكتب أنه بدأ لحظةَ تحويله.
    startDate: work.createdAt ?? o.now,
    dueDate: work.dueDate ?? o.now,
    status: projectStatusFor(str(work.status, "todo")),
    priority: str(work.priority, "medium"),
    progressPercent: num(work.progressPercent),
    executorNames: assigneeName ? [assigneeName] : [],
    createdByUid: str(work.createdByUid),
    managerUids: [o.ownerUid],
    managerUid: o.ownerUid,
    executorUids,
    sectionId: null,
    categoryIds: [],
    createdAt: work.createdAt ?? o.now,
    deletedAt: null,
    deletedBy: null,
    deletedReason: null,
    convertedFromType: "work",
    convertedFromId: o.sourceId,
    convertedToType: null,
    convertedToId: null,
  };
}

/** الاسم المعروض للأصل — لسطر التدقيق ولرسالة الخطأ. */
export function titleOf(kind: RecordKind, data: Record<string, unknown>): string {
  return kind === "project" ? str(data.name) : str(data.title);
}

/** المجموعة التي يُكتب فيها نظيرُ هذا النوع. */
export function targetCollection(kind: RecordKind): string {
  return kind === "project" ? "works" : "projects";
}

/** والنوع المقابل. */
export function targetKind(kind: RecordKind): RecordKind {
  return kind === "project" ? "work" : "project";
}

/**
 * من يملك تحويل سجلٍّ في هذه الإدارة؟
 *
 * **مسؤول النظام، ومديرُ الإدارة صاحبتِها وحدها.** والتحويل ليس تعديلاً
 * عادياً: يُنشئ سجلاً ويؤرشف آخر ويغيّر من يظهر له في القوائم — فلا يُفتح
 * بعلَمٍ مفوَّض، ولا لمن يقرأ كل الإدارات ولا يملك أيّاً منها.
 */
export function mayConvertIn(
  role: string | undefined,
  myDepartmentIds: readonly string[],
  departmentId: string,
): boolean {
  if (role === "systemAdmin") return true;
  if (role !== "departmentManager") return false;
  return departmentId !== "" && myDepartmentIds.includes(departmentId);
}

/** قائمةُ الإدارات على بطاقة الدخول، أيّاً كان شكلُها. */
export function claimDepartments(token: Record<string, unknown> | undefined): string[] {
  if (!token) return [];
  const many = strList(token.departmentIds);
  if (many.length > 0) return many;
  const one = str(token.departmentId);
  return one ? [one] : [];
}
