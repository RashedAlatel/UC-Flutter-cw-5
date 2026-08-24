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
