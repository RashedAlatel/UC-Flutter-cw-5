/**
 * إصلاحُ حقلِ تاريخٍ خُزّن نصّاً — القرارُ وحده، بلا Firestore.
 *
 * ــــ الحادثةُ ــــ
 *
 * اختفت مشاريعُ وزارة العدل كلُّها — مئةٌ وأربعةٌ وثمانون — يوماً كاملاً،
 * والسببُ مستندٌ واحد حمل `contractEndDate` نصّاً: `'2026-05-17T00:00:00.000'`.
 * كتبَه مسارُ اعتماد تعديل المشروع (أُصلح في `approval_stage.ts`).
 *
 * ــــ ولماذا يُصلَح المكتوب وقد حُصِّنت القراءة ــــ
 *
 * لأن القارئ المتسامح في العميل يُظهر المشروع، **ولا يُصلح المستند**.
 * والتقريرُ اليوميّ يُولَّد على الخادم ويقرأ المستند مباشرةً، والتصديرُ
 * كذلك، وأيُّ استعلامٍ يرتّب بتاريخٍ يقارن نصّاً بختمٍ فيخرج بترتيبٍ كاذب.
 * فالحصانةُ تمنع الانهيار، والإصلاحُ يُعيد البيانات إلى نوعها.
 *
 * وهي وحدةٌ نقيّة لتُقاس: `index.ts` لا يعمل إلا بـFirebase حيّ. وهو النمطُ
 * القائم في هذا المجلّد (`approval_stage.ts` و`claims_stamp.ts`).
 */

/**
 * حقولُ التاريخ في مستند المشروع — كلُّها، لا حقولَ العقد وحدها.
 *
 * والشمولُ مقصود: العطلُ عُرف في حقلٍ واحد، ولا يُعرف أيُّ مسارٍ كتب نصّاً
 * في غيره قبل اليوم. والإصلاحُ لا يمسّ ختماً صحيحاً على أي حال.
 */
export const PROJECT_DATE_FIELDS: readonly string[] = [
  "startDate",
  "dueDate",
  "createdAt",
  "departmentTransferredAt",
  "deletedAt",
  "contractDate",
  "contractStartDate",
  "contractEndDate",
  "invoiceDueDate",
];

/**
 * ما يجب إعادةُ كتابته في هذا المستند — أو خريطةٌ فارغة إن كان سليماً.
 *
 * ــ وثلاثةٌ لا تُمسّ ــ
 *
 * • **الختمُ الصحيح**: يُترك كما هو، فلا كتابةَ بلا سبب.
 * • **الغياب**: لا يُختلق له تاريخ — «غير مسجّل» قيمةٌ تُقال.
 * • **النصُّ الذي لا يُقرأ تاريخاً**: يُترك ويُعدّ، ولا يُبدَّل بتاريخِ
 *   اليوم ولا بتاريخِ الحقبة. وتبديلُه اختلاقُ رقمٍ يُتّخذ عليه قرار.
 *
 * @param {Record<string, unknown>} data مستندُ المشروع كما هو.
 * @return {{patch: Record<string, Date>, unreadable: string[]}}
 *   ما يُعاد كتابته، وما بقي نصّاً لا يُقرأ تاريخاً.
 */
export function dateRepairPatch(
  data: Record<string, unknown>,
): {patch: Record<string, Date>; unreadable: string[]} {
  const patch: Record<string, Date> = {};
  const unreadable: string[] = [];

  for (const field of PROJECT_DATE_FIELDS) {
    const raw = data[field];
    // ختمٌ صحيح، أو غياب، أو أيُّ نوعٍ آخر: لا يُمسّ.
    if (typeof raw !== "string") continue;
    const text = raw.trim();
    // نصٌّ فارغ «غير مسجّل» — ولا يُحوَّل إلى تاريخ.
    if (text === "") continue;
    const parsed = new Date(text);
    if (Number.isNaN(parsed.getTime())) {
      unreadable.push(field);
      continue;
    }
    patch[field] = parsed;
  }

  return {patch, unreadable};
}
