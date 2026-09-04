// مستندُ العمل المُنشَأ باعتماد طلب — لا يُولد ناقصاً.
//
// ــــ ما يُقاس هنا، وكلٌّ منه عطلٌ وقع ــــ
//
// (١) **لا حقلَ يسقط.** الخريطة كانت تُبنى بيدها فنقصتها حقول: الحالة،
//     و«دوري متكرر»، وسجلُّ الإغلاق، وحقولُ الحذف والتحويل السبعة.
//     ونقصُ الأخيرة كان يجعل العمل **لا يُعدَّل إطلاقاً**: تعديلُه يُضيفها
//     لأول مرّة فتدخل في `affectedKeys`، وقاعدةُ `works` تمنع مسّها في
//     التعديل العادي — فيُردّ الحفظ كلُّه.
//
// (٢) **والمعتمِد مقدّم الطلب.** `closure` الغائب كان يُقرأ سجلاً فارغاً،
//     أي بلا معتمِد — فيُغلق المُسنَد إليه العملَ بنفسه، ودورةُ الإغلاق على
//     مرحلتين معطَّلةٌ في مسار الطلب كلِّه ولا يظهر ذلك في شيء.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {buildWorkDoc, closureForRequest, WORK_DOC_FIELDS} from "../lib/work_create.js";

const NOW = "‗الآن‗";
const DUE = "‗موعد‗";

const input = {
  departmentId: "d-justice",
  title: "نظام احالات دوائر العمالي",
  description: "احالة القضايا إلى دائرة عمالي كلي",
  assigneeUid: "u-emp",
  assigneeName: "موظف",
  priority: "high",
  dueDate: DUE,
  createdByUid: "u-requester",
  createdAt: NOW,
  requesterUid: "u-requester",
  requesterName: "مقدّم الطلب",
};

describe("لا حقلَ يسقط", () => {
  const doc = buildWorkDoc(input);

  // الحارس الأهمّ: كل حقلٍ يقرؤه `WorkItem.fromDoc` موجود.
  test("كل حقلٍ يقرؤه العميل مكتوبٌ في المستند", () => {
    for (const field of WORK_DOC_FIELDS) {
      assert.ok(field in doc, `الحقل ${field} مفقود من مستند العمل`);
    }
  });

  test("وحقول الحذف مكتوبةٌ فارغةً لا غائبة — وغيابُها هو العطل", () => {
    for (const field of ["deletedAt", "deletedBy", "deletedReason"]) {
      assert.ok(field in doc);
      assert.equal(doc[field], null);
    }
  });

  test("وحقول التحويل كذلك", () => {
    for (const field of
      ["convertedFromType", "convertedFromId", "convertedToType", "convertedToId"]) {
      assert.ok(field in doc);
      assert.equal(doc[field], null);
    }
  });

  test("والحالة مكتوبةٌ لا متروكةٌ لقيمةٍ افتراضية صامتة", () => {
    assert.equal(doc.status, "todo");
  });

  test("و«دوري متكرر» مكتوب", () => {
    assert.equal(doc.isRecurring, false);
  });
});

describe("والبيانات تُنقل كما وردت", () => {
  const doc = buildWorkDoc(input);

  test("العنوان والوصف والإدارة والأولوية والموعد", () => {
    assert.equal(doc.title, input.title);
    assert.equal(doc.description, input.description);
    assert.equal(doc.departmentId, input.departmentId);
    assert.equal(doc.priority, input.priority);
    assert.equal(doc.dueDate, DUE);
  });

  test("والمُسنَد إليه باسمه", () => {
    assert.equal(doc.assigneeUid, "u-emp");
    assert.equal(doc.assigneeName, "موظف");
  });

  test("ويبدأ من الصفر بلا تاريخ إنجاز", () => {
    assert.equal(doc.progressPercent, 0);
    assert.equal(doc.completedDate, null);
  });
});

describe("والمعتمِد مقدّم الطلب", () => {
  test("يُكتب معتمِداً باسمه", () => {
    const doc = buildWorkDoc(input);
    assert.equal(doc.closure.approverUid, "u-requester");
    assert.equal(doc.closure.approverName, "مقدّم الطلب");
  });

  // ولا المُسنَد إليه: من يُنفّذ لا يعتمد إتمام نفسه — وهو الثقب بعينه.
  test("ولا يكون المُسنَد إليه هو المعتمِد", () => {
    const doc = buildWorkDoc(input);
    assert.notEqual(doc.closure.approverUid, doc.assigneeUid);
  });

  test("وطلبٌ بلا مقدّمٍ معروف يُنتج سجلاً فارغاً — إغلاقاً مباشراً كما كان", () => {
    assert.deepEqual(closureForRequest("", "لا أحد"), {});
    assert.deepEqual(buildWorkDoc({...input, requesterUid: ""}).closure, {});
  });

  // ولا يُختلق معتمِد: بندٌ ينتظر اعتماد «لا أحد» لا يُغلق أبداً.
  test("ولا يُختلق معتمِدٌ من فراغ", () => {
    const doc = buildWorkDoc({...input, requesterUid: "   "});
    assert.deepEqual(doc.closure, {});
  });
});
