// مراحلُ اعتماد تعديل بيانات المشروع.
//
// ــــ ثلاثةُ قراراتٍ لو أخطأ أحدُها سقط المسار كلُّه ــــ
//
// (١) **من يبتّ في أي مرحلة.** لو بتّ مسؤولُ النظام في مرحلة مدير الإدارة
//     لَاختصر مساراً طُلب أن يكون مرحلتين، وسقط رأيُ صاحب الإدارة. ولو بتّ
//     مديرُ الإدارة في المرحلة الأخيرة لَصار الاعتمادُ النهائي بيده.
//
// (٢) **ومتى يُطبَّق التغيير.** لو طُبّق عند المرحلة الأولى لَسقط دورُ
//     مسؤول النظام كلُّه بلا أن يظهر في شيء: الطلبُ يُعرض معتمَداً، والمشروع
//     تغيّر، ولا أحد يعلم أن مرحلةً لم تقع.
//
// (٣) **وهل تبدّلت القيمةُ منذ تقديم الطلب.** الطلبُ يُعتمد بعد يومين، فلو
//     صحّح أحدٌ الاسمَ بينهما ثم طُبّق المسجَّل، مُحي التصحيحُ بلا أن يعلم
//     به المعتمِد ولا من صحّح.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  canActAtStage,
  nextStage,
  appliesAt,
  firstStageFor,
  judgeChanges,
  sameStoredValue,
  sensitiveOf,
  EDITABLE_FIELDS,
  SENSITIVE_FIELDS,
} from "../lib/approval_stage.js";

const DEPT = "d-justice";

const admin = {isAdmin: true, role: "systemAdmin", departmentIds: []};
const deptHead = {isAdmin: false, role: "departmentManager", departmentIds: [DEPT]};
const otherHead = {isAdmin: false, role: "departmentManager", departmentIds: ["d-other"]};
const employee = {isAdmin: false, role: "employee", departmentIds: []};

describe("من يبتّ في أي مرحلة", () => {
  test("مديرُ إدارة المشروع يبتّ في مرحلته", () => {
    assert.equal(canActAtStage("departmentManager", deptHead, DEPT), true);
  });

  // المرحلةُ هي الحَكَم لا الدور: مسؤولُ النظام لا يختصر مرحلةً ليست له.
  test("ومسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة", () => {
    assert.equal(canActAtStage("departmentManager", admin, DEPT), false);
  });

  test("ومسؤولُ النظام يبتّ في المرحلة الأخيرة", () => {
    assert.equal(canActAtStage("systemAdmin", admin, DEPT), true);
  });

  test("ومديرُ الإدارة لا يبتّ في المرحلة الأخيرة", () => {
    assert.equal(canActAtStage("systemAdmin", deptHead, DEPT), false);
  });

  // إدارةُ المشروع لا إدارةُ الطالب.
  test("ومديرُ إدارةٍ أخرى لا يبتّ", () => {
    assert.equal(canActAtStage("departmentManager", otherHead, DEPT), false);
  });

  test("ولا الموظف", () => {
    assert.equal(canActAtStage("departmentManager", employee, DEPT), false);
  });

  // مشروعٌ بلا إدارة: لا يُفتح البابُ لمن لا إدارة له فيُقرأ الفراغُ تطابقاً.
  test("ومشروعٌ بلا إدارة لا يبتّ فيه مديرُ إدارة", () => {
    assert.equal(canActAtStage("departmentManager", deptHead, null), false);
  });
});

describe("والمرحلةُ التالية، ومتى يُطبَّق", () => {
  test("بعد مدير الإدارة تأتي مرحلةُ مسؤول النظام", () => {
    assert.equal(nextStage("departmentManager"), "systemAdmin");
  });

  test("وبعد مسؤول النظام ينتهي المسار", () => {
    assert.equal(nextStage("systemAdmin"), null);
  });

  // العطلُ الذي يُخشى: التطبيقُ عند المرحلة الأولى.
  test("ولا يُطبَّق التغيير إلا عند الأخيرة", () => {
    assert.equal(appliesAt("departmentManager"), false);
    assert.equal(appliesAt("systemAdmin"), true);
  });
});

describe("والمرحلةُ الأولى بحسب رتبة الطالب", () => {
  test("مديرُ المشروع (موظف) يبدأ عند مدير الإدارة", () => {
    assert.equal(firstStageFor("employee"), "departmentManager");
  });

  // لا يعتمد أحدٌ طلبَ نفسه.
  test("ومديرُ الإدارة يبدأ عند مسؤول النظام مباشرةً", () => {
    assert.equal(firstStageFor("departmentManager"), "systemAdmin");
  });

  test("ودورٌ مجهول يبدأ عند مدير الإدارة — أطولُ المسارين لا أقصرُهما", () => {
    assert.equal(firstStageFor(undefined), "departmentManager");
    assert.equal(firstStageFor("projectOfficer"), "departmentManager");
  });
});

describe("وحمولةُ التغييرات تُفحص", () => {
  const current = {
    name: "مشروع قائم",
    description: "",
    contractValue: 5000,
    contractorName: "شركة",
  };

  test("ما لم يتبدّل يُكتب", () => {
    const {patch, stale, rejected} = judgeChanges(
      {name: {before: "مشروع قائم", after: "اسمٌ جديد"}},
      current,
    );
    assert.deepEqual(patch, {name: "اسمٌ جديد"});
    assert.deepEqual(stale, []);
    assert.deepEqual(rejected, []);
  });

  // العطلُ الذي يُخشى: اعتمادٌ عمرُه يومان يمحو تصحيحاً وقع بينهما.
  test("وما تبدّل يُردّ ويُسمّى", () => {
    const {patch, stale} = judgeChanges(
      {name: {before: "اسمٌ قديم", after: "اسمٌ جديد"}},
      current,
    );
    assert.deepEqual(patch, {});
    assert.deepEqual(stale, ["name"]);
  });

  // حقلٌ غريبٌ يُدسّ في الحمولة: التطبيقُ بصلاحية المدير يتجاوز كل قاعدة،
  // فالقائمةُ هنا **مغلقة** لا قائمةَ منع.
  test("وحقلٌ خارج القائمة يُرفض", () => {
    const {patch, rejected} = judgeChanges(
      {dueDate: {before: null, after: "2030-01-01"}},
      current,
    );
    assert.deepEqual(patch, {});
    assert.deepEqual(rejected, ["dueDate"]);
  });

  test("والعضويةُ كذلك لا تمرّ من هنا", () => {
    const {rejected} = judgeChanges(
      {managerUids: {before: [], after: ["u-x"]}},
      current,
    );
    assert.deepEqual(rejected, ["managerUids"]);
  });

  test("وحمولةٌ مشوّهة تُرفض ولا تنهار", () => {
    const {patch, rejected} = judgeChanges({name: "نصٌّ لا خريطة"}, current);
    assert.deepEqual(patch, {});
    assert.deepEqual(rejected, ["name"]);
  });

  // «غير مسجّل» يُكتب `null` صراحةً لا يُترك غائباً.
  test("والمسحُ يُكتب عدماً", () => {
    const {patch} = judgeChanges(
      {contractValue: {before: 5000, after: null}},
      current,
    );
    assert.deepEqual(patch, {contractValue: null});
  });

  test("وتُفحص الحقولُ حقلاً حقلاً — يمرّ السليم ويُردّ المتبدّل", () => {
    const {patch, stale} = judgeChanges(
      {
        name: {before: "مشروع قائم", after: "اسمٌ جديد"},
        contractValue: {before: 9999, after: 7000},
      },
      current,
    );
    assert.deepEqual(patch, {name: "اسمٌ جديد"});
    assert.deepEqual(stale, ["contractValue"]);
  });
});

describe("ومقارنةُ المخزَّن بالمسجَّل", () => {
  test("الفراغُ والعدمُ سواء", () => {
    assert.equal(sameStoredValue(null, ""), true);
    assert.equal(sameStoredValue("", null), true);
    assert.equal(sameStoredValue("   ", null), true);
  });

  test("والنصُّ يُقارن مشذَّباً", () => {
    assert.equal(sameStoredValue("شركة ", "شركة"), true);
    assert.equal(sameStoredValue("شركة", "مؤسسة"), false);
  });

  test("والختمُ يُقارن بنصّه الزمني", () => {
    const stamp = {toDate: () => new Date("2026-02-01T00:00:00.000Z")};
    assert.equal(sameStoredValue(stamp, "2026-02-01T00:00:00.000Z"), true);
    assert.equal(sameStoredValue(stamp, "2026-03-01T00:00:00.000Z"), false);
  });

  test("والقوائمُ بعناصرها بترتيبها", () => {
    assert.equal(sameStoredValue(["a", "b"], ["a", "b"]), true);
    assert.equal(sameStoredValue(["a", "b"], ["b", "a"]), false);
    assert.equal(sameStoredValue(["a"], ["a", "b"]), false);
  });

  test("والأرقامُ بقيمتها — والصفرُ ليس عدماً", () => {
    assert.equal(sameStoredValue(0, 0), true);
    assert.equal(sameStoredValue(0, null), false);
  });
});

describe("وقائمةُ الحقول تطابق نظيرَها في العميل", () => {
  test("أحدَ عشرَ حقلاً، والبواباتُ القائمة ليست منها", () => {
    assert.equal(EDITABLE_FIELDS.length, 11);
    for (const gate of ["dueDate", "departmentId", "managerUids", "executorUids"]) {
      assert.equal(EDITABLE_FIELDS.includes(gate), false, `«${gate}» لا يمرّ من هنا`);
    }
  });
});

describe("والجوهريُّ يُعرف — وبه يقع الإشعار", () => {
  test("عشرةُ حقولٍ جوهرية، وهي نظيرُ ما في العميل", () => {
    assert.equal(SENSITIVE_FIELDS.length, 10);
    for (const field of ["name", "contractValue", "durationDays", "dueDate"]) {
      assert.equal(SENSITIVE_FIELDS.includes(field), true, `«${field}» جوهري`);
    }
  });

  // وليست كلُّ حقول المسار جوهرية: تصحيحُ وصفٍ ليس كتغيير قيمة عقد. ولو
  // عُدَّت كلُّها جوهرية لَخرج إشعارٌ عن كل فاصلة، فتُقرأ الإشعاراتُ ولا
  // تُقرأ — وهو أسوأ من ألّا تخرج.
  test("والوصفُ والجهةُ المنفّذة ليسا جوهريَّين", () => {
    assert.equal(SENSITIVE_FIELDS.includes("description"), false);
    assert.equal(SENSITIVE_FIELDS.includes("contractorName"), false);
    assert.equal(SENSITIVE_FIELDS.includes("priority"), false);
    assert.equal(SENSITIVE_FIELDS.includes("categoryIds"), false);
  });

  test("يُخرج الجوهريَّ من المُطبَّق وحده", () => {
    assert.deepEqual(sensitiveOf({description: "x", contractValue: 1}), ["contractValue"]);
    assert.deepEqual(sensitiveOf({description: "x"}), []);
    assert.deepEqual(sensitiveOf({}), []);
  });

  // ــ والترتيبُ من القائمة لا من الحمولة ــ
  //
  // مفاتيحُ الكائن ترتيبُها ترتيبُ إدخالها، فرسالتان عن التغيير نفسه تخرجان
  // بترتيبين. ونصُّ إشعارٍ يتبدّل بلا سببٍ يُقرأ تبدُّلاً في الأمر لا في
  // العرض.
  test("والترتيبُ ثابتٌ مهما اختلف ترتيب الحمولة", () => {
    assert.deepEqual(
      sensitiveOf({contractValue: 1, name: "x"}),
      sensitiveOf({name: "x", contractValue: 1}),
    );
    assert.deepEqual(sensitiveOf({contractValue: 1, name: "x"}), ["name", "contractValue"]);
  });

  // وقيمةٌ تُمسح (`null`) تغييرٌ كغيرها: المفتاحُ موجود، والفعلُ وقع.
  test("ومسحُ قيمةٍ جوهرية جوهريّ", () => {
    assert.deepEqual(sensitiveOf({contractValue: null}), ["contractValue"]);
  });
});
