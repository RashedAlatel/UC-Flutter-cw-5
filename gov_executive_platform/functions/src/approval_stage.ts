/**
 * مراحلُ اعتماد تعديل بيانات المشروع — من يبتّ في أيّها، وما التالية.
 *
 * ــــ لماذا وحدةٌ نقيّة مستقلّة ــــ
 *
 * `index.ts` ملفٌّ لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه
 * المنصة). وقرارُ «من يبتّ في هذه المرحلة» قرارُ حوكمةٍ لا تفصيلُ تنفيذ:
 * خطأٌ فيه يجعل مديرَ الإدارة يعتمد اعتماداً نهائياً ليس له، أو يجعل الطلبَ
 * يُطبَّق عند مرحلته الأولى فيسقط دورُ مسؤول النظام كلُّه.
 *
 * فأُخرج هنا ليُقاس — وهو نمطُ `approval_override.ts` و`convert_record.ts`
 * و`work_create.ts` القائم في هذا المجلد.
 *
 * ونظيرُه في العميل `lib/models/project_edit.dart`، والقاعدةُ تمنع الكتابة
 * المباشرة. **والثلاثة تُقرأ معاً.**
 */

/** مراحلُ الطلب بالترتيب. */
export type EditStage = "departmentManager" | "systemAdmin";

/** ما يعرفه الخادم عن المتصل حين يبتّ. */
export interface Actor {
  isAdmin: boolean;
  /** دورُه الأساسي كما في بطاقة الدخول. */
  role?: string;
  /** الإداراتُ التي يديرها — من `departmentIds` على البطاقة. */
  departmentIds: string[];
}

/**
 * هل يبتّ هذا المتصلُ في هذه المرحلة؟
 *
 * والمرحلةُ هي الحَكَم لا الدور: مسؤولُ النظام **لا يبتّ في مرحلة مدير
 * الإدارة** — ولو فعل لَاختصر المسار الذي طُلب أن يكون مرحلتين، وسقط رأيُ
 * صاحب الإدارة الذي هو أعلمُ بمشاريعها.
 *
 * وإدارةُ **المشروع** لا إدارةُ الطالب: المسؤوليةُ على مشروعٍ بعينه، فصاحبُ
 * ذلك المشروع هو من يقرّر.
 *
 * @param {EditStage} stage المرحلة التي عليها الطلب الآن.
 * @param {Actor} actor المتصل.
 * @param {string | null} projectDepartmentId إدارةُ المشروع.
 * @return {boolean} هل يحقّ له البتّ؟
 */
export function canActAtStage(
  stage: EditStage,
  actor: Actor,
  projectDepartmentId: string | null,
): boolean {
  if (stage === "systemAdmin") return actor.isAdmin;
  // مرحلةُ مدير الإدارة: صاحبُ إدارة المشروع وحده.
  if (actor.role !== "departmentManager") return false;
  if (!projectDepartmentId) return false;
  return actor.departmentIds.includes(projectDepartmentId);
}

/**
 * ما المرحلةُ التالية بعد موافقةٍ عند [stage]؟ و`null` تعني **انتهى المسار**
 * — وعندها وحدها يُطبَّق التغيير على المشروع.
 *
 * @param {EditStage} stage المرحلة التي وُوفق عليها.
 * @return {EditStage | null} التالية، أو `null` إن كانت الأخيرة.
 */
export function nextStage(stage: EditStage): EditStage | null {
  return stage === "departmentManager" ? "systemAdmin" : null;
}

/** هل يُطبَّق التغيير بعد الموافقة عند هذه المرحلة؟ */
export function appliesAt(stage: EditStage): boolean {
  return nextStage(stage) === null;
}

/**
 * المرحلةُ الأولى بحسب رتبة مقدّم الطلب — نظيرُ `firstStageFor` في العميل.
 *
 * ومديرُ الإدارة يبدأ عند مسؤول النظام مباشرةً: لا يعتمد أحدٌ طلبَ نفسه.
 *
 * @param {string | undefined} requesterRole دورُ مقدّم الطلب.
 * @return {EditStage} المرحلة الأولى.
 */
export function firstStageFor(requesterRole: string | undefined): EditStage {
  return requesterRole === "departmentManager" || requesterRole === "systemAdmin" ?
    "systemAdmin" :
    "departmentManager";
}

/** قيمةٌ في حمولة الطلب: ما كان، وما سيصير. */
export interface FieldChange {
  before: unknown;
  after: unknown;
}

/**
 * الحقولُ التي يقبلها هذا المسار — نظيرُ `kEditableProjectFields` في العميل
 * و`hasAny` في القاعدة.
 *
 * وقائمةٌ **مغلقة** هنا بخلاف القاعدة: هذه تُطبّق بصلاحية المدير، فتتجاوز
 * كلَّ قاعدة. فحقلٌ غريبٌ يُدسّ في الحمولة يُكتب على المشروع بلا مانع لو لم
 * تُغلق. والقاعدةُ قائمةُ منعٍ لأن غرضها آخر: ألّا تُردّ حقولٌ تُضاف مستقبلاً.
 */
export const EDITABLE_FIELDS: readonly string[] = [
  "name",
  "description",
  "priority",
  "categoryIds",
  "contractDate",
  "contractStartDate",
  "contractEndDate",
  "invoiceDueDate",
  "durationDays",
  "contractValue",
  "contractorName",
];

/**
 * حقولُ المسار التي تُخزَّن **ختماً زمنياً** لا نصّاً.
 *
 * ــــ الحادثةُ التي أوجبت هذه القائمة ــــ
 *
 * الحمولةُ تحمل التواريخ نصّاً (ISO) بقصد: تُخزَّن في Firestore وتُقارن
 * على الخادم، والنصُّ الموحّد يُقارن بلا التباس منطقةٍ زمنية. لكنّ
 * [judgeChanges] كانت تكتب ما وصلها كما وصلها، فدخل النصُّ حقلَ الختم.
 *
 * فاختفت مشاريعُ وزارة العدل كلُّها — مئةٌ وأربعةٌ وثمانون — يوماً كاملاً:
 * قارئُ المشروع في العميل ينتظر ختماً فرمى، والقراءةُ يومَها ذرّية، فأسقط
 * المستندُ الواحدُ الباقين معه.
 *
 * وهي هنا بجوار [EDITABLE_FIELDS] **لتُقرأ معها**: من زاد حقلَ تاريخٍ إلى
 * تلك ولم يزده إلى هذه أعاد الحادثةَ بحرفها.
 */
export const DATE_FIELDS: readonly string[] = [
  "contractDate",
  "contractStartDate",
  "contractEndDate",
  "invoiceDueDate",
];

/**
 * الحقولُ **الجوهرية** — نظيرُ `kSensitiveProjectFields` في العميل.
 *
 * وليست كلُّ حقول المسار جوهرية: تصحيحُ وصفٍ ليس كتغيير قيمة عقد. فما
 * يُعدّ جوهرياً هو ما يُغيّر التزاماً أو مسؤوليةً أو موعداً — وهو ما
 * يُميَّز للمعتمِد في البطاقة، **وما يُشعَر به بعد الاعتماد**.
 *
 * وفيها ما لا يمرّ بهذا المسار أصلاً (`departmentId` و`managerUids`
 * و`startDate` و`dueDate`): لها بواباتُها، وتُذكر هنا لأن الجوهرية وصفٌ
 * للحقل لا إذنٌ به. راجع `EDITABLE_FIELDS` — تلك تقرّر ما يُقبل.
 */
export const SENSITIVE_FIELDS: readonly string[] = [
  "name",
  "departmentId",
  "managerUids",
  "startDate",
  "dueDate",
  "contractStartDate",
  "contractEndDate",
  "invoiceDueDate",
  "contractValue",
  "durationDays",
];

/**
 * أيُّ حقولِ هذا التغيير جوهريّ — مرتَّبةً كما وردت في [SENSITIVE_FIELDS].
 *
 * والترتيبُ من القائمة لا من الحمولة: مفاتيحُ الكائن ترتيبُها ترتيبُ
 * إدخالها، فرسالتان عن التغيير نفسه تخرجان بترتيبين. ونصُّ إشعارٍ يتبدّل
 * بلا سببٍ يُقرأ تبدُّلاً في الأمر لا في العرض.
 *
 * @param {Record<string, unknown>} patch ما طُبّق على المشروع.
 * @return {string[]} الجوهريُّ منه.
 */
export function sensitiveOf(patch: Record<string, unknown>): string[] {
  return SENSITIVE_FIELDS.filter((field) =>
    Object.prototype.hasOwnProperty.call(patch, field));
}

/**
 * يفحص حمولةَ التغييرات: أيُّها مقبول، وهل تبدّلت القيمةُ المخزَّنة منذ
 * تقديم الطلب.
 *
 * ــــ ولماذا يُفحص التبدُّل ــــ
 *
 * الطلبُ يُعتمد بعد يومٍ أو يومين. ولو صحّح أحدٌ الاسمَ في تلك المدّة، ثم
 * طُبّق الطلبُ بما سُجّل فيه، لَمحا التصحيحَ **بلا أن يعلم أحد** — لا
 * المعتمِد ولا من صحّح. فيُردّ الطلب ويُقال أيُّ حقلٍ تبدّل.
 *
 * @param {Record<string, unknown>} changes حمولةُ التغييرات.
 * @param {Record<string, unknown>} currentDoc مستندُ المشروع كما هو الآن.
 * @return {{patch: Record<string, unknown>, stale: string[], rejected: string[]}}
 *   ما يُكتب، وما تبدّل، وما رُفض لأنه ليس من القائمة.
 */
export function judgeChanges(
  changes: Record<string, unknown>,
  currentDoc: Record<string, unknown>,
): {patch: Record<string, unknown>; stale: string[]; rejected: string[]} {
  const patch: Record<string, unknown> = {};
  const stale: string[] = [];
  const rejected: string[] = [];

  for (const [field, raw] of Object.entries(changes)) {
    if (!EDITABLE_FIELDS.includes(field)) {
      rejected.push(field);
      continue;
    }
    if (!raw || typeof raw !== "object") {
      rejected.push(field);
      continue;
    }
    const change = raw as FieldChange;
    if (!sameStoredValue(currentDoc[field], change.before)) {
      stale.push(field);
      continue;
    }

    // ــ حقلُ التاريخ يُكتب ختماً، ونصُّه لا يُدسّ في المستند ــ
    //
    // و`Date` تخزّنها Firestore ختماً من نفسها، فتبقى هذه الوحدةُ نقيّةً
    // بلا `admin` — كما هي منذ كُتبت. راجع [DATE_FIELDS].
    if (DATE_FIELDS.includes(field)) {
      const parsed = asDate(change.after);
      if (parsed === undefined) {
        // نصٌّ لا يُقرأ تاريخاً: **يُردّ ويُسمّى**. وحقلٌ مشوَّهٌ يُكتب
        // بصمتٍ هو ما أخفى المنصّة يوماً كاملاً.
        rejected.push(field);
        continue;
      }
      patch[field] = parsed;
      continue;
    }

    patch[field] = change.after ?? null;
  }
  return {patch, stale, rejected};
}

/**
 * يقرأ قيمةَ حقل تاريخ: `null` مسحٌ، ونصُّ ISO تاريخٌ، وما عداه **مرفوض**.
 *
 * و`undefined` هنا تعني «لا يُقرأ تاريخاً» — وهي غير `null` التي تعني
 * «مسحٌ مقصود». والتفريقُ مقصود: الأولى تُردّ على صاحبها، والثانية تُكتب.
 *
 * @param {unknown} raw ما وصل في الحمولة.
 * @return {Date | null | undefined} التاريخ، أو المسح، أو الرفض.
 */
function asDate(raw: unknown): Date | null | undefined {
  if (raw === null || raw === undefined) return null;
  if (raw instanceof Date) return raw;
  if (typeof raw !== "string") return undefined;
  const text = raw.trim();
  // النصُّ الفارغ «غير مسجّل» — يُكتب عدماً لا يُردّ.
  if (text === "") return null;
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

/**
 * هل القيمةُ المخزَّنة هي ما سُجّل وقت الطلب؟
 *
 * والمقارنةُ متسامحةٌ في موضعٍ واحد: `null` والنصُّ الفارغ شيءٌ واحد، لأن
 * «غير مسجّل» تُكتب فارغةً في حقلٍ نصّي وتُقرأ عدماً. وما عدا ذلك يُقارن
 * بالقيمة.
 *
 * والتواريخُ تصل نصّاً في الحمولة (ISO) وتُخزَّن ختماً، فتُقارن بنصّها.
 *
 * @param {unknown} stored المخزَّن الآن.
 * @param {unknown} recorded ما سُجّل وقت الطلب.
 * @return {boolean} هل هما سواء؟
 */
export function sameStoredValue(stored: unknown, recorded: unknown): boolean {
  const a = normalize(stored);
  const b = normalize(recorded);
  if (a === null && b === null) return true;
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((v, i) => v === b[i]);
  }
  return a === b;
}

/**
 * يُسوّي القيمةَ للمقارنة: الفراغُ عدمٌ، والختمُ نصُّه.
 *
 * @param {unknown} v القيمة.
 * @return {unknown} المُسوّاة.
 */
function normalize(v: unknown): unknown {
  if (v === undefined || v === null) return null;
  if (typeof v === "string") return v.trim() === "" ? null : v.trim();
  // ختمُ Firestore يحمل `toDate`؛ يُقارن بنصٍّ زمنيّ موحّد.
  if (typeof v === "object" && v !== null && typeof (v as {toDate?: unknown}).toDate === "function") {
    return (v as {toDate: () => Date}).toDate().toISOString();
  }
  if (v instanceof Date) return v.toISOString();
  return v;
}
