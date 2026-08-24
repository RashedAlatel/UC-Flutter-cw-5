// من يُدمَج مع من عند إعادة التسجيل بنفس بريد حسابٍ موقوف أو محذوف.
//
// وما يُقاس هنا هو **يقين المطابقة الواحدة**: أكثر من مرشّح — من أيّ
// مصدرٍ أو كليهما — لا يُخمَّن فيه، بل يُرفض الدمج كلّه بلا نقلٍ ولا خطأ.
// ولولا هذا الاختبار لَأمكن أن يُختار أول عنصرٍ في مصفوفةٍ متعدّدة صمتاً،
// فتُنقل أعمال شخصٍ إلى حساب شخصٍ آخر شاركه بريداً بخطأ إدخال.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {pickMergeCandidate} from "../lib/account_merge.js";

describe("اختيار مُرشَّح الدمج", () => {
  test("لا مطابقة — لا دمج", () => {
    assert.deepEqual(pickMergeCandidate([], []), {found: false});
  });

  test("مطابقةٌ واحدة موقوفة — تُختار", () => {
    assert.deepEqual(
      pickMergeCandidate([{uid: "u-old"}], []),
      {found: true, oldUid: "u-old", source: "suspended"},
    );
  });

  test("ومطابقةٌ واحدة محذوفة — تُختار", () => {
    assert.deepEqual(
      pickMergeCandidate([], [{uid: "u-gone"}]),
      {found: true, oldUid: "u-gone", source: "deleted"},
    );
  });

  // الحالة التي بُنيت الدالّة لأجلها: تعدّدٌ لا يُخمَّن فيه.
  test("مطابقتان موقوفتان — لا دمج", () => {
    assert.deepEqual(
      pickMergeCandidate([{uid: "a"}, {uid: "b"}], []),
      {found: false},
    );
  });

  test("ومطابقتان محذوفتان — لا دمج", () => {
    assert.deepEqual(
      pickMergeCandidate([], [{uid: "a"}, {uid: "b"}]),
      {found: false},
    );
  });

  // حالةٌ لا يُفترض وقوعها (حسابٌ موقوفٌ ومحذوفٌ بالبريد نفسه) — ومع ذلك
  // تُعامَل كأي تعدّدٍ آخر: رفضٌ لا تفضيل مصدرٍ على آخر.
  test("مطابقةٌ من كلا المصدرين معاً — لا دمج", () => {
    assert.deepEqual(
      pickMergeCandidate([{uid: "a"}], [{uid: "b"}]),
      {found: false},
    );
  });
});
