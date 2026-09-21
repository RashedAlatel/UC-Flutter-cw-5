// حدُّ تعديل الطلب قبل اعتماده.
//
// كان التعديل كلّه محصوراً بمسؤول النظام، وسببُ الحصر أن الحمولة تحمل
// `dueDate` — فتعديلها بابٌ جانبيّ حول بوابة «تعديل المواعيد النهائية».
// وفُتح منه **حقلٌ واحد**: تكليفُ منفّذ على طلب عمل، وهو ما يحتاجه مدير
// الإدارة ليعمل ترتيبُ «الطلب يُعرض عليه فيكلّف».
//
// فما يُقاس هنا هو **ضيق** الفتحة لا وجودها: كل اختبارٍ من اختبارات الردّ
// أدناه يمثّل باباً كان يمكن أن يُفتح سهواً.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {judgeOverride} from "../lib/approval_override.js";

describe("حدّ تعديل الطلب قبل اعتماده", () => {
  test("مدير إدارة يكلّف منفّذاً على طلب عمل — يُقبل", () => {
    const v = judgeOverride("workCreate", "departmentManager", ["assigneeUid"]);
    assert.equal(v.allowed, true);
    // وبها يُعرف أن الرتبة تُفحص برتبة **المعتمِد** لا برتبة مقدّم الطلب.
    assert.equal(v.byApprover, true);
  });

  // البوابة التي من أجلها كُتب هذا كلّه: الموعد النهائي.
  test("ولا يمسّ الموعد النهائي — يُردّ", () => {
    const v = judgeOverride("workCreate", "departmentManager", ["dueDate"]);
    assert.equal(v.allowed, false);
    assert.match(v.reason, /مسؤول النظام/);
  });

  // الحيلة الأقرب: مفتاحٌ مسموح **ومعه** ممنوع في الطلب نفسه.
  test("ولا يمرّره تحت غطاء التكليف — يُردّ", () => {
    const v = judgeOverride("workCreate", "departmentManager", ["assigneeUid", "dueDate"]);
    assert.equal(v.allowed, false);
    assert.match(v.reason, /dueDate/);
  });

  // الاسم يشتقّه الخادم من المعرّف، فلا يُقبل من الحمولة أصلاً.
  test("ولا يكتب اسماً لا يخصّ المعرّف — يُردّ", () => {
    const v = judgeOverride("workCreate", "departmentManager", ["assigneeUid", "assigneeName"]);
    assert.equal(v.allowed, false);
    assert.match(v.reason, /assigneeName/);
  });

  test("وطلب المشروع لا يُعدّله غير مسؤول النظام — يُردّ", () => {
    const v = judgeOverride("projectCreate", "departmentManager", ["managerUids"]);
    assert.equal(v.allowed, false);
  });

  // حمولة طلب التسجيل تحمل هوية حساب، وتعديلها اعتمادٌ لشخصٍ غير الذي طلب.
  test("وطلب التسجيل لا يُعدَّل ولو من مسؤول النظام — يُردّ", () => {
    const v = judgeOverride("registration", "systemAdmin", ["requestedRole"]);
    assert.equal(v.allowed, false);
    assert.match(v.reason, /لا يُعدَّل/);
  });

  test("وبوابة البريد كذلك — يُردّ", () => {
    assert.equal(judgeOverride("notifySend", "systemAdmin", ["body"]).allowed, false);
    assert.equal(judgeOverride("deadlineChange", "systemAdmin", ["newDate"]).allowed, false);
  });

  test("ومسؤول النظام يعدّل حمولة العمل والمشروع كما كان", () => {
    assert.equal(judgeOverride("workCreate", "systemAdmin", ["dueDate", "title"]).allowed, true);
    assert.equal(judgeOverride("projectCreate", "systemAdmin", ["managerUids"]).allowed, true);
  });

  // من أرسل تجاوزاً فارغاً يظنّ أنه غيّر شيئاً، والاعتماد يمضي بالحمولة كما
  // وردت — فيُقال له بدل أن يمضي على ظنٍّ خاطئ.
  test("وتجاوزٌ بلا مفاتيح — يُردّ لا يمضي صامتاً", () => {
    assert.equal(judgeOverride("workCreate", "departmentManager", []).allowed, false);
  });

  // الدور من **بطاقة الدخول**، وقد تصل بلا دور. والغياب لا يُقرأ سماحاً.
  test("وبطاقةٌ بلا دور تُعامَل معاملة غير المسؤول", () => {
    assert.equal(judgeOverride("workCreate", undefined, ["dueDate"]).allowed, false);
    assert.equal(judgeOverride("workCreate", undefined, ["assigneeUid"]).allowed, true);
    assert.equal(judgeOverride("projectCreate", undefined, ["managerUids"]).allowed, false);
  });
});
