/**
 * من يملك تعديلَ بيانات مستخدم، وما الذي يُكتب — **القرارُ وحده**.
 *
 * ــــ لماذا وحدةٌ نقيّة ــــ
 *
 * `index.ts` لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه المنصة).
 * وهذا قرارُ **حوكمة** لا تفصيلُ تنفيذ: خطأٌ فيه يجعل مديرَ إدارةٍ يعدّل
 * موظّفي إدارةٍ ليست له، أو يجعل حقلاً لم يُقصد فتحُه يُكتب من حمولةٍ
 * مدسوسة. وهو نمطُ `approval_stage.ts` و`claims_stamp.ts`.
 *
 * ــــ وما لا يُفتح من هنا ــــ
 *
 * الدورُ، والحالة، والصلاحيات، والإدارة، وتسجيلُ الأعضاء. لكلٍّ بابُه:
 * `setUserRole` و`setUserStatus` و`setUserPermissionOverrides` وطلبُ
 * `userTransfer` — وكلُّها لمسؤول النظام. وهذه الدالّة **لا تلمس شيئاً
 * منها ولو وردت في الحمولة**.
 */

/** ما تعرفه بطاقةُ الدخول عن المتصل. */
export interface Editor {
  isAdmin: boolean;
  role?: string;
  /** الإداراتُ التي يديرها — **من البطاقة لا من الحمولة**. */
  departmentIds?: string[];
}

/** ما يُقرأ من مستند المستخدم المستهدَف. */
export interface TargetUser {
  departmentId?: string | null;
}

/**
 * الحقولُ التي يقبلها هذا الطريق — **قائمةٌ مغلقة**.
 *
 * ومغلقةٌ لا قائمةَ منع: الدالّةُ تُطبَّق بصلاحية المدير فتتجاوز كلَّ
 * قاعدة، فحقلٌ غريبٌ يُدسّ في الحمولة يُكتب بلا مانع لو لم تُغلق. ووقع ذلك
 * في المنصة من قبل — في تعديل العمل وفي تسمية المشروع.
 */
export const PROFILE_FIELDS: readonly string[] = ["name", "sectionId"];

/**
 * هل يملك هذا المتصلُ تعديلَ بيانات هذا المستخدم؟
 *
 * ــ ومستخدمٌ بلا إدارة لمسؤول النظام وحده ــ
 *
 * ولو فُتح لمدير إدارةٍ لَادّعى كلُّ مديرٍ من لا إدارة له — وهم أكثرُ من
 * يحتاج تصحيحَ بياناته.
 *
 * @param {Editor} editor المتصل كما تصفه بطاقتُه.
 * @param {TargetUser} target مستندُ المستخدم المستهدَف.
 * @return {boolean} هل يحقّ له؟
 */
export function mayEditUserProfile(editor: Editor, target: TargetUser): boolean {
  if (editor.isAdmin) return true;
  if (editor.role !== "departmentManager") return false;
  const dept = (target.departmentId ?? "").trim();
  if (dept === "") return false;
  return (editor.departmentIds ?? []).includes(dept);
}

/**
 * ما يُكتب فعلاً من هذه الحمولة — وما عداه يُهمَل بلا ضجيج.
 *
 * و«يُهمَل» لا «يُردّ»: الحمولةُ قد تحمل حقولاً تخصّ الواجهة، والمقصودُ أن
 * **لا يُكتب** ما ليس من القائمة — لا أن يُوقف الحفظ كلُّه.
 *
 * @param {Record<string, unknown>} data الحمولةُ كما وصلت.
 * @return {Record<string, unknown>} ما يُكتب.
 */
export function profilePatch(data: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  if (typeof data.name === "string") {
    const name = data.name.trim();
    // اسمٌ فارغ ليس تصحيحاً بل محو — فيُترك الاسمُ القائم.
    if (name !== "") patch.name = name;
  }

  // والقسمُ يُكتب `null` صراحةً: «تحت الإدارة مباشرةً» قيمةٌ تُقال، وهي
  // الحالُ حين يخرج الموظّفُ من قسمٍ ولا يدخل غيرَه.
  //
  // و`in` هنا تقول المقصود: **وجودُ المفتاح** هو الطلب. ولا يفرّقها عن
  // `!== undefined` مدخلٌ يعبر السلك — فالحمولةُ تصل JSON ولا `undefined`
  // فيها، وجسمُ الفرع يهمل `undefined` أصلاً. فطفرتُها لا تعضّ لأنّها لا
  // تغيّر سلوكاً، لا لأنّ اختباراً ناقص.
  if ("sectionId" in data) {
    const raw = data.sectionId;
    if (raw === null) {
      patch.sectionId = null;
    } else if (typeof raw === "string") {
      patch.sectionId = raw.trim() === "" ? null : raw.trim();
    }
  }

  return patch;
}
