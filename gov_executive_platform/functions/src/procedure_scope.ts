/**
 * دليلُ الإجراءات: **من يحرّر، وما يُكتب، وأيَّ رقمٍ تحمل النسخة**.
 *
 * ــــ لماذا وحدةٌ نقيّة ــــ
 *
 * `index.ts` لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه المنصة).
 * وهذا قرارُ **حوكمة** لا تفصيلُ تنفيذ: خطأٌ فيه يجعل من لا يملك التحريرَ
 * يحرّر، أو يجعل حقلاً لم يُقصد فتحُه يُكتب من حمولةٍ مدسوسة، أو — وهو
 * الأخطر — يجعل نسخةً تُكتب فوق نسخة فيضيع ما وُعد بحفظه.
 *
 * وهو نمطُ `user_scope.ts` و`approval_stage.ts` و`claims_stamp.ts`.
 *
 * ــــ والكتابةُ من هنا وحدَها ــــ
 *
 * `procedures` و`procedureVersions` **مغلقتان للكتابة في القواعد**
 * (`allow write: if false`) ولو كان الكاتبُ مسؤولَ النظام. فحفظُ صورة
 * النسخة السابقة لا يجوز أن يكون خطوةً يستطيع عميلٌ تخطّيها: لو كُتب
 * الجديدُ بلا صورة لَضاع ما وُعد بحفظه، ولا سبيل إلى استرجاعه.
 */

/** ما تعرفه بطاقةُ الدخول عن المتصل. */
export interface Editor {
  isAdmin: boolean;
  perms?: Record<string, boolean>;
}

/** خطوةٌ كما تُكتب في المستند. */
export interface Step {
  title: string;
  description: string;
  ownerTitle: string;
  departmentId: string | null;
  durationDays: number | null;
  notes: string;
  attachments: unknown[];
}

/**
 * الحقولُ التي يقبلها هذا الطريق على الإجراء — **قائمةٌ مغلقة**.
 *
 * ومغلقةٌ لا قائمةَ منع: الدالّةُ تُطبَّق بصلاحية المدير فتتجاوز كلَّ
 * قاعدة، فحقلٌ غريبٌ يُدسّ في الحمولة يُكتب بلا مانع لو لم تُغلق. ووقع
 * ذلك في المنصة من قبل — في تعديل العمل وفي تسمية المشروع.
 */
export const PROCEDURE_FIELDS: readonly string[] = ["title", "summary", "departmentId", "steps"];

/** وحقولُ الخطوة كذلك. */
export const STEP_FIELDS: readonly string[] =
  ["title", "description", "ownerTitle", "departmentId", "durationDays", "notes", "attachments"];

/** أقصى عددٍ من الخطوات في إجراء — حدٌّ يمنع مستنداً يتجاوز حدَّ Firestore. */
export const MAX_STEPS = 100;

/**
 * هل يحرّر هذا المتصلُ دليلَ الإجراءات؟
 *
 * ــ ومن يحرّر يقرأ، لا العكس ــ
 *
 * `epc` وحدَها تفتح التحرير. و`vpc` قراءةٌ لا غير: من مُنح الاطّلاع لا
 * يعدّل ما اطّلع عليه.
 *
 * @param {Editor} editor المتصل كما تصفه بطاقتُه.
 * @return {boolean} هل يحقّ له؟
 */
export function mayEditProcedures(editor: Editor): boolean {
  if (editor.isAdmin) return true;
  return editor.perms?.epc === true;
}

/** يقرأ نصّاً مشذَّباً من قيمةٍ مهما كان نوعُها. */
function text(raw: unknown): string {
  return typeof raw === "string" ? raw.trim() : "";
}

/**
 * يحوّل حمولةَ الخطوات إلى ما يُكتب فعلاً — وما عداه يُهمَل.
 *
 * ــ وخطوةٌ بلا عنوان تسقط ــ
 *
 * لأنّ العنوانَ هو كلُّ ما يظهر في القائمة، فسطرٌ فارغٌ في دليلٍ عطلٌ لا
 * بيان. والواجهةُ تُبقي صفّاً فارغاً حتى يُملأ، فيصل أحياناً في الحمولة.
 *
 * ــ والمدّةُ السالبة تُردّ لا تُقلب ــ
 *
 * قلبُها إلى موجبٍ يخترع رقماً لم يقله أحد؛ وقراءتُها صفراً تدّعي أنّ
 * الخطوةَ تقع في يومها. فتُقرأ **«غير مسجّلة»**، وهي الحقيقة.
 *
 * @param {unknown} raw حمولةُ الخطوات كما وصلت.
 * @return {Step[]} ما يُكتب.
 */
export function normalizeSteps(raw: unknown): Step[] {
  if (!Array.isArray(raw)) return [];
  const steps: Step[] = [];
  for (const item of raw) {
    if (steps.length >= MAX_STEPS) break;
    // و`null` هو النصفُ الحامل: قراءةُ حقلٍ منه ترمي. أمّا `typeof` فحارسٌ
    // مضاعف — كلُّ ما تردّه (نصٌّ ورقمٌ وقيمةٌ منطقية) لا حقلَ `title` فيه
    // فيسقط بالحدّ التالي على كلّ حال. فطفرتُه لا تعضّ لأنّها لا تغيّر
    // سلوكاً على حمولةٍ تصل JSON، لا لأنّ اختباراً ناقص.
    if (typeof item !== "object" || item === null) continue;
    const src = item as Record<string, unknown>;
    const title = text(src.title);
    if (title === "") continue;

    const deptId = text(src.departmentId);
    const rawDays = src.durationDays;
    const days = typeof rawDays === "number" && Number.isFinite(rawDays) && rawDays >= 0 ?
      Math.round(rawDays) :
      null;

    steps.push({
      title,
      description: text(src.description),
      ownerTitle: text(src.ownerTitle),
      departmentId: deptId === "" ? null : deptId,
      durationDays: days,
      notes: text(src.notes),
      // والمرفقاتُ تمرّ كما هي: النموذجُ في العميل يُسقط ما ليس مرفقاً عند
      // القراءة، وحصرُ حقولها هنا يكرّر منطقاً قائماً ويُخالفه يوماً.
      attachments: Array.isArray(src.attachments) ? src.attachments : [],
    });
  }
  return steps;
}

/**
 * ما يُكتب على مستند الإجراء من هذه الحمولة — **قائمةٌ مغلقة**.
 *
 * ولا تمرّ منه `version` ولا `updatedAt` ولا `isActive`: الرقمُ يقرّره
 * [nextVersion] على الخادم، والوقتُ وقتُ الخادم، والأرشفةُ بابُها آخر.
 * ولو مرّت `version` من الحمولة لَأمكن أن يُكتب رقمٌ يتخطّى نسخةً محفوظة،
 * فتبدو صورتان لرقمٍ واحد ولا يُعرف أيُّهما الأسبق.
 *
 * @param {Record<string, unknown>} data الحمولةُ كما وصلت.
 * @return {Record<string, unknown>} ما يُكتب.
 */
export function procedurePatch(data: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  if ("title" in data) {
    const title = text(data.title);
    // عنوانٌ فارغ ليس تصحيحاً بل محو — فيُترك العنوانُ القائم.
    if (title !== "") patch.title = title;
  }
  if ("summary" in data) patch.summary = text(data.summary);
  if ("departmentId" in data) {
    const dept = text(data.departmentId);
    patch.departmentId = dept === "" ? null : dept;
  }
  if ("steps" in data) patch.steps = normalizeSteps(data.steps);

  return patch;
}

/**
 * رقمُ النسخة التالية.
 *
 * وأيُّ قيمةٍ غير رقمٍ صحيحٍ موجب تُقرأ نسخةً أولى — فمستندٌ قديمٌ بلا
 * حقلٍ للرقم، أو حقلٌ كُتب نصّاً، لا يُنتج `NaN` يُكتب في قاعدة البيانات
 * فيُفسد كلَّ ترتيبٍ بعده.
 *
 * @param {unknown} current رقمُ النسخة السارية كما قُرئ من المستند.
 * @return {number} رقمُ النسخة بعد هذا الحفظ.
 */
export function nextVersion(current: unknown): number {
  const n = typeof current === "number" ? current : Number(current);
  if (!Number.isFinite(n) || n < 1) return 2;
  return Math.floor(n) + 1;
}
