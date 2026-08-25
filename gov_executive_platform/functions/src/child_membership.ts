/**
 * ختمُ عضوية المشروع على مستنداته التابعة.
 *
 * ــــ لماذا يلزم ختمٌ لمرّةٍ واحدة؟ ــــ
 *
 * توابعُ المشروع — المهام والتحديثات اليومية والمخاطر والعوائق — تحمل نسخةً
 * من عضوية المشروع لتُفحص القراءةُ بحقلٍ على المستند نفسه، لا باستعلامٍ عن
 * المشروع في كل مرّة. وقاعدةُ `isProjectMember` تقرأ القائمتين معاً.
 *
 * لكنّ `executorUids` **لم تكن تُنسخ قط**. فمن كان منفّذاً في مشروع لا
 * تعرفه القاعدةُ على توابعه، ولا يستطيع الاستعلامُ أن يسأل عن عضويته —
 * فلا يصله تحديثٌ واحد على مشروعٍ هو منفّذُه.
 *
 * وصار الحقل يُكتب من الآن. أما ما كُتب قبل ذلك فيحتاج ختماً، وهو ما تفعله
 * هذه الوحدة: تُقارن ما على التابع بما على مشروعه، وتُعيد ما يجب تصحيحه.
 */

export interface MembershipSource {
  managerUids?: unknown;
  executorUids?: unknown;
}

function strList(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((v): v is string => typeof v === "string") : [];
}

function sameList(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

/**
 * ما يجب كتابته على المستند التابع ليطابق عضوية مشروعه — أو `{}` إن كان
 * مطابقاً أصلاً.
 *
 * والفارغ يعني **لا كتابة**: ختمُ آلاف المستندات المطابقة سلفاً يكلّف
 * كتاباتٍ بلا أثر، ويُغرق أي حصرٍ لما تغيّر فعلاً.
 */
export function childMembershipPatch(
  child: MembershipSource,
  project: MembershipSource,
): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  const wantManagers = strList(project.managerUids);
  const wantExecutors = strList(project.executorUids);

  // الغائب ليس كالفارغ: مستندٌ لا يحمل الحقل إطلاقاً يجب أن يُكتب عليه
  // حتى لو كانت قائمةُ مشروعه فارغة — فبغير الحقل لا تراه القاعدة عضواً
  // ولا يجده الاستعلام، وهذا هو العطل بعينه.
  if (!Array.isArray(child.managerUids) || !sameList(strList(child.managerUids), wantManagers)) {
    patch.managerUids = wantManagers;
  }
  if (!Array.isArray(child.executorUids) || !sameList(strList(child.executorUids), wantExecutors)) {
    patch.executorUids = wantExecutors;
  }

  return patch;
}
