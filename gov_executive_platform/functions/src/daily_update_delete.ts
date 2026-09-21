/**
 * من يحقّ له حذف تحديثٍ يومي — قرارٌ نقيّ يُختبَر بلا Firestore.
 *
 * ــــ وهو **مرآةُ** قاعدة `dailyUpdates` في firestore.rules ــــ
 *
 * والقاعدة هي الحَكَم. لكن الحذف يقع هنا بصلاحية المدير (Admin SDK يتجاوز
 * القواعد أصلاً) — لأن معه محوَ ملفاتٍ من التخزين لا تستطيع قواعدُ التخزين
 * أن تأذن به: هي لا تقرأ Firestore فلا تعرف من يملك المشروع. فيلزم أن
 * يُعاد النصّ نفسه هنا، ويُقاس على الحالات نفسها التي تُقاس بها القاعدة.
 *
 * ــــ ولمن يُفتح ــــ
 *
 *   • **كاتبُه** — يمحو ما كتبه هو، لا ما كتبه غيره.
 *   • **مالكُ المشروع**: مسؤول النظام، ومدير الإدارة صاحبتِه، ومديرو
 *     المشروع — **بالقائمة `managerUids` لا بالمفرد الموروث**، فيعمل
 *     المدير الثاني فصاعداً.
 *
 * ولا يشمل **منفّذي** المشروع: العضوية تنفيذاً ليست ملكاً، فلا يمحو منفّذٌ
 * تحديثَ مديره. وهو الحدُّ الذي تُقاس عليه هذه الدالّة أكثر من غيره.
 */

export interface DeleteActor {
  uid: string;
  role?: unknown;
  /** إدارات مدير الإدارة، من بصمة الدخول (`auth.token.departmentIds`). */
  departmentIds?: unknown;
}

export interface UpdateDoc {
  authorUid?: unknown;
}

export interface ProjectDoc {
  departmentId?: unknown;
  managerUids?: unknown;
}

function strList(raw: unknown): string[] {
  return Array.isArray(raw) ? raw.filter((v): v is string => typeof v === "string") : [];
}

export function mayDeleteDailyUpdate(
  actor: DeleteActor,
  update: UpdateDoc,
  project: ProjectDoc | null,
): boolean {
  if (!actor.uid) return false;
  if (actor.role === "systemAdmin") return true;

  // المستخدم التنفيذي يرى كل شيء ولا يغيّر شيئاً — قاعدةٌ قائمة في المنصة،
  // وتسبق حقَّ الكتابة: لا يكتب أصلاً فلا يكون كاتباً.
  if (actor.role === "executiveViewer") return false;

  if (update.authorUid === actor.uid) return true;

  if (!project) return false;
  if (strList(project.managerUids).includes(actor.uid)) return true;

  if (actor.role === "departmentManager") {
    const dept = typeof project.departmentId === "string" ? project.departmentId : null;
    return dept !== null && strList(actor.departmentIds).includes(dept);
  }

  return false;
}
