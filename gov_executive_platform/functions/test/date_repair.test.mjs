// إصلاحُ تاريخٍ خُزّن نصّاً — وما لا يُمسّ.
//
// ــــ الحادثةُ ــــ
//
// مستندٌ واحد حمل `contractEndDate` نصّاً — `'2026-05-17T00:00:00.000'` —
// فأخفى مشاريعَ وزارة العدل كلَّها يوماً كاملاً. والقراءةُ حُصِّنت،
// والكتابةُ أُصلحت، وبقي **المكتوبُ سلفاً** في قاعدة البيانات: التقريرُ
// اليوميّ يُولَّد على الخادم ويقرأ المستند مباشرةً، فيقرأ نصّاً حيث ينتظر
// ختماً.
//
// وما يُقاس هنا هو **ما لا يُمسّ** بقدر ما يُصلَح: كتابةٌ بلا سبب على مئات
// المستندات أسوأ من ترك حقلٍ واحدٍ نصّاً.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {dateRepairPatch, PROJECT_DATE_FIELDS} from "../lib/date_repair.js";

const ISO = "2026-05-17T00:00:00.000";

/** ختمٌ صحيح كما يعود من Firestore — يحمل `toDate`. */
const stamp = (iso) => ({toDate: () => new Date(iso)});

describe("ما يُصلَح", () => {
  test("نصُّ تاريخٍ يُعاد تاريخاً", () => {
    const {patch} = dateRepairPatch({contractEndDate: ISO});
    assert.ok(patch.contractEndDate instanceof Date);
    assert.equal(patch.contractEndDate.toISOString(), new Date(ISO).toISOString());
  });

  test("وكلُّ حقلٍ نصّيٍّ في المستند الواحد", () => {
    const {patch} = dateRepairPatch({
      contractStartDate: ISO,
      contractEndDate: ISO,
      invoiceDueDate: ISO,
    });
    assert.deepEqual(Object.keys(patch).sort(), [
      "contractEndDate",
      "contractStartDate",
      "invoiceDueDate",
    ]);
  });

  // ــ والشمولُ مقصود ــ
  //
  // العطلُ عُرف في حقول العقد، ولا يُعرف أيُّ مسارٍ كتب نصّاً في غيرها قبل
  // اليوم. فتُفحص التواريخُ كلُّها.
  test("وتواريخُ المشروع نفسِه لا حقولَ العقد وحدها", () => {
    const {patch} = dateRepairPatch({startDate: ISO, dueDate: ISO});
    assert.deepEqual(Object.keys(patch).sort(), ["dueDate", "startDate"]);
  });
});

describe("وما لا يُمسّ", () => {
  // كتابةٌ بلا سبب على مئات المستندات أسوأ من ترك حقلٍ نصّاً.
  test("ختمٌ صحيح يُترك", () => {
    const {patch} = dateRepairPatch({contractEndDate: stamp(ISO)});
    assert.deepEqual(patch, {});
  });

  test("وغيابٌ لا يُختلق له تاريخ", () => {
    const {patch} = dateRepairPatch({name: "مشروع"});
    assert.deepEqual(patch, {});
  });

  test("و`null` تبقى «غير مسجّل»", () => {
    const {patch} = dateRepairPatch({contractEndDate: null});
    assert.deepEqual(patch, {});
  });

  test("ونصٌّ فارغ يبقى فارغاً", () => {
    const {patch} = dateRepairPatch({contractEndDate: "   "});
    assert.deepEqual(patch, {});
  });

  // ــ وهذا أهمُّ ما لا يُمسّ ــ
  //
  // «قريباً إن شاء الله» لا يُبدَّل بتاريخ اليوم ولا بتاريخ الحقبة: ذلك
  // اختلاقُ رقمٍ يُتّخذ عليه قرار، وهو أسوأ من فراغٍ صريح.
  test("ونصٌّ لا يُقرأ تاريخاً يُترك ويُعدّ", () => {
    const {patch, unreadable} = dateRepairPatch({
      contractEndDate: "قريباً إن شاء الله",
    });
    assert.deepEqual(patch, {});
    assert.deepEqual(unreadable, ["contractEndDate"]);
  });

  test("وحقلٌ ليس تاريخاً لا يُفحص وإن أشبه نصُّه تاريخاً", () => {
    const {patch, unreadable} = dateRepairPatch({contractorName: ISO});
    assert.deepEqual(patch, {});
    assert.deepEqual(unreadable, []);
  });
});

// ــ ومستندٌ سليمٌ لا يُكتب عليه ــ
//
// وهو ما يجعل إعادةَ الضغط بلا ضرر: مرّةٌ ثانية تفحص ولا تكتب.
test("وإعادةُ الإصلاح على مستندٍ أُصلح لا تكتب شيئاً", () => {
  const first = dateRepairPatch({contractEndDate: ISO});
  const repaired = {contractEndDate: stamp(first.patch.contractEndDate.toISOString())};
  assert.deepEqual(dateRepairPatch(repaired).patch, {});
});

test("والقائمةُ لا تحمل مكرَّراً", () => {
  assert.equal(new Set(PROJECT_DATE_FIELDS).size, PROJECT_DATE_FIELDS.length);
});
