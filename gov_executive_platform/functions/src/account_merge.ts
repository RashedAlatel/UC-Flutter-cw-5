/**
 * من يُدمَج مع من، عند اعتماد تسجيلٍ جديد بنفس بريد حسابٍ موقوف أو محذوف.
 *
 * ــــ لماذا وحدةٌ مستقلّة لهذا القرار وحده؟ ــــ
 *
 * لأن الباقي (البحث في `users`/`deletedAccounts`، وكتابة الدفعات على
 * `works`/`tasks`/`projects`) عمليات Firestore حقيقية لا تُقاس إلا بمحاكٍ.
 * أما **القرار نفسه** — أيّ حسابٍ قديم يُدمَج، إن وُجد — فمنطقٌ صِرف: مدخله
 * قائمتا تطابق، ومخرجه معرِّفٌ أو لا شيء. فيُعزَل هنا ويُختبر بلا Firestore،
 * كما عُزل `judgeOverride` في `approval_override.ts` من قبله.
 *
 * ــــ لماذا الرفض عند أكثر من مطابقة، لا اختيار أوّلهم؟ ــــ
 *
 * أكثر من مطابقةٍ بالبريد نفسه حالةٌ لا يجوز أن تُخمَّن: قد يكون توقيفان
 * لشخصين مختلفين تشاركا بريداً بخطأ إدخال، أو ازدواجاً حقيقياً يستحقّ نظر
 * مسؤول النظام لا نقلاً آلياً صامتاً. فالدمج يقع على **يقينٍ واحد** فحسب —
 * وإلا لا شيء، بلا خطأ يُرفع ولا سطرٍ في سجل التدقيق.
 */

export interface MergeMatch {
  uid: string;
}

export type MergeCandidate =
  | {found: true; oldUid: string; source: "suspended" | "deleted"}
  | {found: false};

export function pickMergeCandidate(
  suspendedMatches: readonly MergeMatch[],
  deletedMatches: readonly MergeMatch[],
): MergeCandidate {
  const total = suspendedMatches.length + deletedMatches.length;
  if (total !== 1) return {found: false};

  if (suspendedMatches.length === 1) {
    return {found: true, oldUid: suspendedMatches[0].uid, source: "suspended"};
  }
  return {found: true, oldUid: deletedMatches[0].uid, source: "deleted"};
}

// ــــــــــــــــــ عضوية المشروع: القائمة ومفردُها الموروث ــــــــــــــــــ

/**
 * ما يُكتب على مستند مشروعٍ حين ينتقل عضوٌ فيه من معرِّفٍ قديم إلى جديد.
 *
 * ــــ لماذا هذه دالّةٌ قائمة بذاتها؟ ــــ
 *
 * لأن مستند المشروع يحمل **حقلين** للمدير: القائمة `managerUids`، ومفرداً
 * موروثاً `managerUid`. وقواعد الأمان تقرأ المفرد في موضعين حاسمين:
 * `legacyManagerConsistent()` تشترط أن يكون عضواً في القائمة، و
 * `matchesRealProject()` تشترط أن يساويَه ما نسخه التحديثُ اليومي الجديد.
 *
 * فتحديث القائمة وحدها — وهو ما كان يقع — يترك المفرد على معرِّفٍ لم يعد
 * لصاحبه حساب: تُنقض الثابتة، فتُردّ كلُّ كتابةٍ لاحقة على المشروع، وتُرفض
 * إضافة أيّ تحديثٍ يومي عليه. فمن أُعيد تسجيله يرى مشروعه ولا يعمل فيه.
 *
 * والحقلان يُكتبان هنا معاً أو لا يُكتب شيء — وهذا هو سبب وجود الدالّة:
 * لتصير الثابتة مقروءةً في مكانٍ واحد، ومُختبَرةً بلا Firestore.
 */
export interface ProjectMembership {
  managerUids?: unknown;
  executorUids?: unknown;
  managerUid?: unknown;
}

/**
 * تُبدِل المعرِّف في قائمةٍ وتُعيد الناتج — أو `null` إن لم يكن فيها أصلاً.
 *
 * والإبدال يُنقّي المكرّر: لو كان الجديد عضواً سلفاً (شخصٌ سُجّل من جديد ثم
 * أُضيف يدوياً قبل أن يُعتمد تسجيله) لَتكرّر معرِّفه في القائمة بعد الإبدال،
 * فيُحسب عضواً مرّتين في كل عدّ.
 */
function replaceUid(list: unknown, oldUid: string, newUid: string): string[] | null {
  const arr = Array.isArray(list) ? list.filter((u): u is string => typeof u === "string") : [];
  if (!arr.includes(oldUid)) return null;
  const out: string[] = [];
  for (const u of arr) {
    const v = u === oldUid ? newUid : u;
    if (!out.includes(v)) out.push(v);
  }
  return out;
}

export function projectMemberPatch(
  data: ProjectMembership,
  oldUid: string,
  newUid: string,
): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  const managers = replaceUid(data.managerUids, oldUid, newUid);
  if (managers) patch.managerUids = managers;

  const executors = replaceUid(data.executorUids, oldUid, newUid);
  if (executors) patch.executorUids = executors;

  const legacy = typeof data.managerUid === "string" ? data.managerUid : null;
  if (legacy === oldUid) {
    // المفرد هو المنتقل نفسه — يتبع القائمة حرفاً بحرف، ولا يُعاد حسابه من
    // أوّلها: لو كان القديمُ ثانيَ المديرين لَنقَل «أوّلُ القائمة» القيادة
    // الاسمية إلى غيره في أثناء عمليةٍ لا شأن لها بترتيب المديرين.
    patch.managerUid = newUid;
  } else if (managers && legacy !== null && !managers.includes(legacy)) {
    // مفردٌ خرج من القائمة قبل هذه العملية — أثرُ دمجٍ سابق ناقص. والثابتة
    // منقوضة أصلاً، فلا يُترك على حاله وقد صار المشروع تحت اليد: يُردّ إلى
    // أوّل القائمة، وهو أقرب ما يمكن قوله بيقين.
    patch.managerUid = managers[0] ?? null;
  }

  return patch;
}

// ــــــــــــــــــ قوائم إعدادات التقرير اليومي ــــــــــــــــــ

/** القوائم الثلاث في `settings/dailyReport` التي تحمل معرِّفات مستخدمين. */
export const DAILY_REPORT_UID_LISTS = [
  "excludedUids",
  "extraRecipientUids",
  "emailRecipientUids",
] as const;

export interface SettingsPrune {
  /** ما يُكتب على `settings/dailyReport` — فارغٌ إن لم يكن المعرِّف في شيء. */
  patch: Record<string, unknown>;
  /** قائمةٌ تُرك فيها المعرِّف عمداً لئلا ينقلب معناها — تُذكر في سجل التدقيق. */
  keptForSafety: string[];
}

/**
 * يشطب المعرِّف القديم من قوائم إعدادات التقرير — **ولا يضع الجديد مكانه**.
 *
 * ــــ لماذا شطبٌ لا إبدال؟ ــــ
 *
 * قلتَ: «يُعامَل كمستخدم قابل للتواصل بشكل طبيعي… وعدم بقاء أي قيود مرتبطة
 * بالحساب السابق». والإبدال يورّث القيدَ نفسه: استثناءٌ قديم يعود فيمنع
 * بريده من حيث لا يدري أحد، أو إدراجٌ قسريّ قديم يُفترض عنه. فيُشطب القديم،
 * ويبقى القرار لمسؤول النظام يتّخذه عن قصدٍ لا وراثة.
 *
 * ــــ وموضعٌ واحد يُستثنى من الشطب ــــ
 *
 * `emailRecipientUids` قائمةُ **حصر**: غيرُ الفارغة تعني «البريد لهؤلاء
 * وحدهم»، والفارغة تعني «للجميع». فشطبُ آخر معرِّفٍ فيها لا يرفع قيداً عن
 * شخص — بل يفتح بريد التقرير على الوزارة كلها من حيث لا يُقصد. والإرسال
 * بوابةٌ في هذه المنصة لا تُوسَّع بأثرٍ جانبي لعمليةٍ أخرى. فتُترك كما هي
 * ويُقال ذلك في سجل التدقيق ليُصلحها مسؤول النظام بيده.
 */
export function pruneUidFromReportSettings(
  settings: Record<string, unknown>,
  oldUid: string,
): SettingsPrune {
  const patch: Record<string, unknown> = {};
  const keptForSafety: string[] = [];

  for (const key of DAILY_REPORT_UID_LISTS) {
    const raw = settings[key];
    if (!Array.isArray(raw)) continue;
    const kept = raw.filter((u) => typeof u !== "string" || u !== oldUid);
    if (kept.length === raw.length) continue;

    if (key === "emailRecipientUids" && kept.length === 0) {
      keptForSafety.push(key);
      continue;
    }
    patch[key] = kept;
  }

  return {patch, keptForSafety};
}
