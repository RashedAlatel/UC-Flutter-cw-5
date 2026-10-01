/**
 * حدُّ تعديل الطلب قبل اعتماده.
 *
 * ــــ لماذا وحدةٌ مستقلّة لشرطٍ من سطرين؟ ــــ
 *
 * لأن هذا الشرط **حارسُ بوابة**، و`index.ts` ملفٌّ لا تقرؤه مجموعة اختبارات:
 * ما فيه يُحرَس بفحصٍ نصّي في `tool/test/approval_gates_test.sh` — وذلك
 * يمنع أن تُحذف الحراسة بصمت، ولا يثبت أنها **تعمل**. فمن هنا يُقاس
 * الشرط طفرةً كما تُقاس القواعد.
 *
 * ــــ ما الذي يُحرَس بالضبط؟ ــــ
 *
 * حمولة الطلب تحمل `dueDate`. فمن يعدّلها قبل الاعتماد يُعدّل موعداً
 * نهائياً من بابٍ جانبيّ حول بوابة «تعديل المواعيد النهائية» المحصورة
 * بمسؤول النظام وحده. ولهذا كان التعديل كلّه محصوراً به.
 *
 * وحاجةُ مدير الإدارة ليست الحمولة: هي **أن يكلّف منفّذاً** عند اعتماد
 * طلب عمل — فالطلب يصله من إدارةٍ أخرى لا يعرف صاحبها توزيع الاختصاصات
 * في إدارته. فيُفتح له **حقلٌ واحد** لا الباب: `assigneeUid` على
 * `workCreate` وحدها. ويبقى `dueDate` و`title` و`priority` كما كانت.
 */

/** المفاتيح التي يجوز لغير مسؤول النظام تجاوزها، بحسب نوع الطلب. */
const DELEGATED_OVERRIDE_KEYS: Record<string, readonly string[]> = {
  // التكليف وحده. ولا `assigneeName` معه عمداً: الاسم يشتقّه الخادم من
  // المعرّف، فلا يُقبل من الحمولة أصلاً — وإلا كُتب اسمٌ لا يخصّ صاحبه.
  workCreate: ["assigneeUid"],
};

/** أنواع الطلبات التي تُعدَّل قبل اعتمادها أصلاً — ولو من مسؤول النظام. */
const EDITABLE_TYPES = ["projectCreate", "workCreate"];

export type OverrideVerdict =
  | {allowed: true; byApprover: boolean}
  | {allowed: false; reason: string};

/**
 * هل يُقبل هذا التجاوز؟
 *
 * @param type نوع الطلب كما هو في **مستند الطلب** لا في الحمولة.
 * @param callerRole دور المعتمِد من بطاقة دخوله (لا من سجلّه).
 * @param keys مفاتيح التجاوز المرسَل.
 *
 * و`byApprover` في الحكم ليست زينة: بها يُعرف أن المُسنَد إليه اختاره
 * **المعتمِد** لا مقدّم الطلب — وعليها يُبنى فحص الرتبة، فتُقاس برتبة من
 * اختار فعلاً. ولولاها لَمُنع مديرُ إدارةٍ من إسناد عملٍ يحقّ له إسنادُه،
 * لأن مقدّم الطلب موظفٌ أدنى رتبةً منه.
 */
export function judgeOverride(
  type: string,
  callerRole: string | undefined,
  keys: readonly string[],
): OverrideVerdict {
  if (!EDITABLE_TYPES.includes(type)) {
    return {allowed: false, reason: "هذا النوع من الطلبات لا يُعدَّل قبل اعتماده"};
  }
  if (callerRole === "systemAdmin") return {allowed: true, byApprover: true};

  const permitted = DELEGATED_OVERRIDE_KEYS[type];
  if (!permitted) {
    return {allowed: false, reason: "تعديل هذا الطلب قبل اعتماده لمسؤول النظام وحده"};
  }
  // تجاوزٌ بلا مفاتيح ليس تجاوزاً — ويُردّ لا يُقبل صامتاً: من أرسله يظنّ
  // أنه غيّر شيئاً، والاعتماد يمضي بالحمولة كما وردت فيخالف ظنَّه.
  if (keys.length === 0) {
    return {allowed: false, reason: "لم يُرسَل أي تعديل"};
  }
  const extra = keys.filter((k) => !permitted.includes(k));
  if (extra.length > 0) {
    return {
      allowed: false,
      reason:
        `لا يُعدَّل من هذا الطلب إلا ${permitted.join("، ")} — ` +
        `وما سواه لمسؤول النظام وحده (وصل: ${extra.join("، ")})`,
    };
  }
  return {allowed: true, byApprover: true};
}
