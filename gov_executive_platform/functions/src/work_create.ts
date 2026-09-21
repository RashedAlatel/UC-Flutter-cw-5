/**
 * بناءُ مستند العمل الذي يُنشأ **باعتماد طلب**.
 *
 * ــــ العطل الذي أوجد هذه الوحدة ــــ
 *
 * كانت الخريطة تُبنى بيدها داخل `approveRequest`، وتنقصها حقولٌ يكتبها
 * العميل دائماً: `status` و`isRecurring` و`closure` وحقولُ الحذف والتحويل
 * السبعة. فكلُّ عملٍ أُنشئ باعتماد طلبٍ وُلد ناقصاً، وأثرُ ذلك اثنان:
 *
 * (١) **لا يُعدَّل إطلاقاً.** تعديلُه يُضيف المفاتيح الغائبة لأول مرّة،
 *     فتدخل في `diff().affectedKeys()`، وقاعدةُ `works` تشترط ألّا يُمسّ
 *     أيٌّ من مفاتيح الحذف والتحويل في التعديل العادي — فيُردّ الحفظ كلُّه.
 *
 * (٢) **ولا يمرّ إغلاقُه بأحد.** `closure` الغائب يُقرأ سجلَّ إغلاقٍ فارغ،
 *     أي بلا معتمِد — فيُغلقه المُسنَد إليه بنفسه، بينما العمل المُنشَأ
 *     مباشرةً يُغلقه طالبُه. ودورةُ الإغلاق على مرحلتين كانت معطَّلةً في
 *     مسار الطلب كلِّه ولا يظهر ذلك في شيء.
 *
 * وهي **نقيّة**: لا تعرف Firestore ولا تكتب شيئاً. تأخذ ما تحتاجه وتُعيد
 * المستند، فيُقاس أن كل حقلٍ يقرؤه `WorkItem.fromDoc` موجودٌ فيه — بلا
 * محاكٍ ولا شبكة. كما `convert_record.ts` و`child_membership.ts`.
 */

export interface WorkDocInput {
  departmentId: string | null;
  title: string;
  description: string;
  assigneeUid: string | null;
  assigneeName: string;
  priority: string;
  dueDate: unknown;
  createdByUid: string;
  createdAt: unknown;
  /** مقدّم الطلب — وهو **معتمِد الإغلاق**. */
  requesterUid: string;
  requesterName: string;
}

/**
 * سجلُّ الإغلاق: معتمِدُه **مقدّم الطلب**.
 *
 * ونظيرُه في العميل `addWork`: «المعتمِد هو الطالب نفسه — من طلب العمل هو
 * من يراجع إتمامه». والمسارُ الذي يمرّ بطلبٍ أولى بذلك لا أحقّ منه: فيه
 * طالبٌ معروفٌ بالاسم على مستند الطلب.
 *
 * وطالبٌ بلا معرّف يُنتج سجلاً فارغاً — أي إغلاقاً مباشراً كما كانت المنصة.
 * ولا يُختلق له معتمِد: بندٌ ينتظر اعتماد «لا أحد» لا يُغلق أبداً.
 */
export function closureForRequest(
  requesterUid: string,
  requesterName: string,
): Record<string, unknown> {
  const uid = (requesterUid ?? "").trim();
  if (!uid) return {};
  return {approverUid: uid, approverName: requesterName ?? ""};
}

/**
 * مستندُ العمل كاملاً.
 *
 * وحقول الحذف والتحويل تُكتب فارغةً صراحةً لا تُترك غائبة: غيابُها هو
 * العطل بعينه — راجع أعلاه.
 */
export function buildWorkDoc(input: WorkDocInput): Record<string, unknown> {
  return {
    departmentId: input.departmentId,
    title: input.title,
    description: input.description,
    assigneeUid: input.assigneeUid,
    assigneeName: input.assigneeName,
    // العمل المُعتمَد يبدأ من قائمة الانتظار — ولا يُترك بلا حالة فتُقرأ
    // بقيمةٍ افتراضية لا يعرف أحدٌ أنها افتراضية.
    status: "todo",
    priority: input.priority,
    progressPercent: 0,
    dueDate: input.dueDate,
    completedDate: null,
    isRecurring: false,
    createdByUid: input.createdByUid,
    createdAt: input.createdAt,
    closure: closureForRequest(input.requesterUid, input.requesterName),
    deletedAt: null,
    deletedBy: null,
    deletedReason: null,
    convertedFromType: null,
    convertedFromId: null,
    convertedToType: null,
    convertedToId: null,
  };
}

/**
 * الحقول التي يقرؤها `WorkItem.fromDoc` في العميل.
 *
 * تُذكر هنا لتُقاس: مستندٌ ينقصه أحدها يُقرأ بقيمةٍ افتراضية صامتة، أو
 * يُردّ تعديلُه. وهي مرآةٌ لـ`lib/models/work_item.dart` — والحَكَم هو.
 */
export const WORK_DOC_FIELDS: readonly string[] = [
  "departmentId", "title", "description", "assigneeUid", "assigneeName",
  "status", "priority", "progressPercent", "dueDate", "completedDate",
  "isRecurring", "createdByUid", "createdAt", "closure",
  "deletedAt", "deletedBy", "deletedReason",
  "convertedFromType", "convertedFromId", "convertedToType", "convertedToId",
];
