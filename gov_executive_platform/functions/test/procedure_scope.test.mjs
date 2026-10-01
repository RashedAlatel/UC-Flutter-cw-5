// دليلُ الإجراءات: من يحرّر، وما يُكتب، وأيَّ رقمٍ تحمل النسخة.
//
// ــــ لماذا وحدةٌ نقيّة ــــ
//
// `index.ts` ملفٌّ لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه
// المنصة). وهذا **قرارُ حوكمة** لا تفصيلُ تنفيذ.
//
// ــــ وثلاثةُ حدودٍ تُقاس هنا ــــ
//
// (١) **من يحرّر**: `epc` وحدَها تفتح التحرير، و`vpc` قراءةٌ لا غير. فمن
//     مُنح الاطّلاع لا يعدّل ما اطّلع عليه.
//
// (٢) **والقائمةُ مغلقة**: الدالّةُ تُطبَّق بصلاحية المدير فتتجاوز كلَّ
//     قاعدة. فحقلٌ غريبٌ يُدسّ يُكتب بلا مانع لو لم تُغلق — ووقع ذلك في
//     المنصة مرّتين. و`version` منها بقرارٍ صريح: لو كُتبت من الحمولة
//     لأمكن أن يتخطّى الرقمُ نسخةً محفوظة، فتبدو صورتان لرقمٍ واحد.
//
// (٣) **ولا يُختلق رقم**: مدّةٌ سالبةٌ تُقرأ «غير مسجّلة» لا صفراً ولا
//     موجبةً — فالصفرُ دعوى أنّ الخطوةَ تقع في يومها، والقلبُ اختراعُ رقم.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  mayEditProcedures,
  normalizeSteps,
  procedurePatch,
  nextVersion,
  PROCEDURE_FIELDS,
  STEP_FIELDS,
  MAX_STEPS,
} from "../lib/procedure_scope.js";

const admin = {isAdmin: true};
const editor = {isAdmin: false, perms: {epc: true, vpc: true}};
const reader = {isAdmin: false, perms: {vpc: true}};
const stranger = {isAdmin: false, perms: {}};

describe("من يحرّر دليل الإجراءات", () => {
  test("مسؤولُ النظام", () => {
    assert.equal(mayEditProcedures(admin), true);
  });

  test("ومن مُنح epc", () => {
    assert.equal(mayEditProcedures(editor), true);
  });

  // ــ ومن مُنح الاطّلاع لا يعدّل ما اطّلع عليه ــ
  test("ولا من مُنح vpc وحدَها", () => {
    assert.equal(mayEditProcedures(reader), false);
  });

  test("ولا من لا مفتاحَ له", () => {
    assert.equal(mayEditProcedures(stranger), false);
    assert.equal(mayEditProcedures({isAdmin: false}), false);
  });

  // بطاقةٌ يُدسّ فيها العلمُ نصّاً أو رقماً لا تفتح باباً: المقارنةُ
  // بـ`=== true` لا بصدقِ القيمة.
  test("وعلمٌ ليس `true` لا يفتح", () => {
    assert.equal(mayEditProcedures({isAdmin: false, perms: {epc: "true"}}), false);
    assert.equal(mayEditProcedures({isAdmin: false, perms: {epc: 1}}), false);
    assert.equal(mayEditProcedures({isAdmin: false, perms: {epc: false}}), false);
  });
});

describe("وما يُكتب على الإجراء — قائمةٌ مغلقة", () => {
  test("العنوانُ والملخّصُ والإدارةُ والخطوات لا غير", () => {
    assert.deepEqual([...PROCEDURE_FIELDS].sort(),
      ["departmentId", "steps", "summary", "title"]);
  });

  test("والعنوانُ يُشذَّب", () => {
    assert.deepEqual(procedurePatch({title: "  توثيق عقد  "}), {title: "توثيق عقد"});
  });

  // عنوانٌ فارغ ليس تصحيحاً بل محو: يُردّ ولا يُكتب.
  test("وعنوانٌ فارغ لا يُكتب", () => {
    assert.deepEqual(procedurePatch({title: "   "}), {});
  });

  test("وإدارةٌ فارغةٌ تعني «إجراءٌ عامّ» فتُكتب null", () => {
    assert.deepEqual(procedurePatch({departmentId: "  "}), {departmentId: null});
    assert.deepEqual(procedurePatch({departmentId: "d-1"}), {departmentId: "d-1"});
  });

  // ــ وهذا هو الحدُّ الذي يمنع تخطّي نسخةٍ محفوظة ــ
  //
  // لو مرّت `version` من الحمولة لأمكن أن يُكتب رقمٌ يتخطّى صورةً محفوظة،
  // فتبدو صورتان لرقمٍ واحد ولا يُعرف أيُّهما الأسبق.
  test("ولا يمرّ رقمُ نسخةٍ ولا وقتٌ ولا أرشفةٌ ولو دُسَّت", () => {
    const patch = procedurePatch({
      title: "إجراء",
      version: 99,
      updatedAt: "2020-01-01",
      isActive: false,
      createdAt: "2020-01-01",
      updatedByUid: "u-x",
      updatedByName: "منتحل",
    });
    assert.deepEqual(patch, {title: "إجراء"});
  });

  test("وحمولةٌ فارغةٌ لا تُنتج كتابة", () => {
    assert.deepEqual(procedurePatch({}), {});
  });

  // ومفتاحٌ غائبٌ يعني «لا تمسّ هذا الحقل»، لا «امحُه».
  test("وملخّصٌ غائبٌ لا يُمحى", () => {
    assert.deepEqual(procedurePatch({title: "إ"}), {title: "إ"});
    assert.deepEqual(procedurePatch({summary: ""}), {summary: ""});
  });
});

describe("والخطواتُ تُنقّى", () => {
  test("حقولُ الخطوة سبعةٌ لا غير", () => {
    assert.deepEqual([...STEP_FIELDS].sort(), [
      "attachments", "departmentId", "description", "durationDays",
      "notes", "ownerTitle", "title",
    ]);
  });

  test("والترتيبُ ترتيبُ القائمة", () => {
    const steps = normalizeSteps([{title: "الأولى"}, {title: "الثانية"}]);
    assert.deepEqual(steps.map((s) => s.title), ["الأولى", "الثانية"]);
  });

  // ــ وخطوةٌ بلا عنوان تسقط ــ
  //
  // فالعنوانُ كلُّ ما يظهر في القائمة، وسطرٌ فارغٌ في دليلٍ عطلٌ لا بيان.
  // والواجهةُ تُبقي صفّاً فارغاً حتى يُملأ فيصل أحياناً في الحمولة.
  test("وما ليس خطوةً يسقط ولا يُسقط ما بعده", () => {
    const steps = normalizeSteps([
      "نصّ", {title: "  صحيحة  "}, null, 42, {description: "بلا عنوان"}, {title: "   "},
    ]);
    assert.deepEqual(steps.map((s) => s.title), ["صحيحة"]);
  });

  test("وقائمةٌ ليست قائمةً تُقرأ فارغة", () => {
    assert.deepEqual(normalizeSteps("ليست قائمة"), []);
    assert.deepEqual(normalizeSteps(undefined), []);
  });

  test("وحقلٌ غريبٌ في الخطوة لا يُنسخ", () => {
    const [step] = normalizeSteps([{title: "خ", ownerUid: "u-1", isDone: true}]);
    assert.deepEqual(Object.keys(step).sort(), [...STEP_FIELDS].sort());
  });

  test("والمرفقاتُ تمرّ، وما ليس قائمةً يُقرأ فارغاً", () => {
    assert.deepEqual(normalizeSteps([{title: "خ", attachments: [{name: "a"}]}])[0].attachments,
      [{name: "a"}]);
    assert.deepEqual(normalizeSteps([{title: "خ", attachments: "تالف"}])[0].attachments, []);
  });

  describe("والمدّةُ لا تُختلق", () => {
    const days = (raw) => normalizeSteps([{title: "خ", durationDays: raw}])[0].durationDays;

    test("رقمٌ صحيحٌ يُكتب", () => {
      assert.equal(days(5), 5);
    });

    test("وصفرٌ يبقى صفراً — «تقع في يومها» قولٌ يُقال", () => {
      assert.equal(days(0), 0);
    });

    // ــ وسالبةٌ تُردّ لا تُقلب ولا تُصفَّر ــ
    test("وسالبةٌ تُقرأ «غير مسجّلة»", () => {
      assert.equal(days(-3), null);
    });

    test("وما ليس رقماً كذلك", () => {
      assert.equal(days("5"), null);
      assert.equal(days(NaN), null);
      assert.equal(days(Infinity), null);
      assert.equal(days(undefined), null);
    });

    test("وكسرٌ يُقرَّب", () => {
      assert.equal(days(2.6), 3);
    });
  });

  // حدٌّ يمنع مستنداً يتجاوز حدَّ Firestore فيُردّ الحفظُ كلُّه بلا بيان.
  test("وعددُ الخطوات محدود", () => {
    const many = Array.from({length: MAX_STEPS + 20}, (_, i) => ({title: `خ${i}`}));
    assert.equal(normalizeSteps(many).length, MAX_STEPS);
  });
});

describe("ورقمُ النسخة يتقدّم ولا يتراجع", () => {
  test("واحدةٌ تصير اثنتين", () => {
    assert.equal(nextVersion(1), 2);
    assert.equal(nextVersion(7), 8);
  });

  // ــ ولا `NaN` يُكتب في قاعدة البيانات ــ
  //
  // فمستندٌ قديمٌ بلا حقلٍ للرقم، أو حقلٌ كُتب نصّاً، يُفسد كلَّ ترتيبٍ
  // بعده لو مرّ.
  test("وما ليس رقماً صالحاً يُقرأ نسخةً أولى فتليها الثانية", () => {
    assert.equal(nextVersion(undefined), 2);
    assert.equal(nextVersion(null), 2);
    assert.equal(nextVersion("تالف"), 2);
    assert.equal(nextVersion(0), 2);
    assert.equal(nextVersion(-5), 2);
  });

  test("ورقمٌ مكتوبٌ نصّاً يُقرأ رقماً", () => {
    assert.equal(nextVersion("3"), 4);
  });

  test("وكسرٌ لا يُنتج كسراً", () => {
    assert.equal(nextVersion(2.7), 3);
  });
});
