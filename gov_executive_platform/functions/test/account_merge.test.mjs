// من يُدمَج مع من عند إعادة التسجيل بنفس بريد حسابٍ موقوف أو محذوف.
//
// وما يُقاس هنا هو **يقين المطابقة الواحدة**: أكثر من مرشّح — من أيّ
// مصدرٍ أو كليهما — لا يُخمَّن فيه، بل يُرفض الدمج كلّه بلا نقلٍ ولا خطأ.
// ولولا هذا الاختبار لَأمكن أن يُختار أول عنصرٍ في مصفوفةٍ متعدّدة صمتاً،
// فتُنقل أعمال شخصٍ إلى حساب شخصٍ آخر شاركه بريداً بخطأ إدخال.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  pickMergeCandidate,
  projectMemberPatch,
  pruneUidFromReportSettings,
} from "../lib/account_merge.js";

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

// ــــــــــــــــــ عضوية المشروع ــــــــــــــــــ
//
// هنا يُقاس العطل الذي أُدخل في الجولة الماضية: الدمج كان يُحدّث قائمة
// `managerUids` ويترك المفرد الموروث `managerUid` على معرِّفٍ ميّت. وقواعد
// الأمان تقرأ المفرد، فتُنقض الثابتة وتُردّ كلُّ كتابةٍ لاحقة على المشروع،
// وتُرفض إضافة أيّ تحديثٍ يومي عليه.
//
// وما يُقاس **هنا** هو الحمولة وحدها. أما أثرُها على القواعد فمُقاسٌ على
// المحاكي في `test_rules/account_merge.rules.test.mjs` — لأن هذا الملف لا
// يعرف Firestore، وذاك لا يستدعي هذه الدالّة. فالاثنان يلتقيان على الحقل
// نفسه من طرفيه، ولا يُغني أحدهما عن الآخر.
describe("حمولة نقل العضوية على مستند المشروع", () => {
  test("مديرٌ منقول: القائمة **والمفرد** معاً", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-old"], executorUids: [], managerUid: "u-old"},
        "u-old",
        "u-new",
      ),
      {managerUids: ["u-new"], managerUid: "u-new"},
    );
  });

  test("والمفرد يتبع المنقول ولو كان ثانيَ المديرين — لا يُعاد حسابه من أوّل القائمة", () => {
    // لو كُتب `managerUid = managerUids[0]` لَصار «u-a» — أي لَنقلت عمليةُ
    // دمجِ حسابٍ القيادةَ الاسمية إلى شخصٍ آخر لا شأن له بها.
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-a", "u-old"], executorUids: [], managerUid: "u-old"},
        "u-old",
        "u-new",
      ),
      {managerUids: ["u-a", "u-new"], managerUid: "u-new"},
    );
  });

  test("ومديرٌ منقولٌ ليس هو المفرد — القائمة وحدها، والمفرد لا يُمسّ", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-a", "u-old"], executorUids: [], managerUid: "u-a"},
        "u-old",
        "u-new",
      ),
      {managerUids: ["u-a", "u-new"]},
    );
  });

  test("ومنفّذٌ منقول — قائمة المنفّذين وحدها", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-a"], executorUids: ["u-old", "u-b"], managerUid: "u-a"},
        "u-old",
        "u-new",
      ),
      {executorUids: ["u-new", "u-b"]},
    );
  });

  test("ومن كان في القائمتين — تُصحَّحان معاً", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-old"], executorUids: ["u-old"], managerUid: "u-old"},
        "u-old",
        "u-new",
      ),
      {managerUids: ["u-new"], executorUids: ["u-new"], managerUid: "u-new"},
    );
  });

  test("ومشروعٌ لا صلة له بالمنقول — حمولةٌ فارغة، فلا كتابة", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-a"], executorUids: ["u-b"], managerUid: "u-a"},
        "u-old",
        "u-new",
      ),
      {},
    );
  });

  // حالةٌ واقعية: من سُجّل من جديد ثم أُضيف يدوياً إلى المشروع قبل أن
  // يُعتمد تسجيله. فلولا التنقية لَتكرّر معرِّفه ولَحُسب عضواً مرّتين.
  test("والجديد عضوٌ سلفاً — لا يتكرّر معرِّفه", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-new", "u-old"], executorUids: [], managerUid: "u-new"},
        "u-old",
        "u-new",
      ),
      {managerUids: ["u-new"]},
    );
  });

  // أثرُ دمجٍ سابقٍ ناقص وقع قبل هذا الإصلاح: القائمة [u-mid] والمفرد u-a.
  // ثم يُدمَج u-mid بدوره. والثابتة منقوضةٌ أصلاً، والمشروع تحت اليد الآن.
  test("ومفردٌ خرج من القائمة قبل هذه العملية — يُردّ إليها بدل أن يُترك ناقضاً", () => {
    assert.deepEqual(
      projectMemberPatch(
        {managerUids: ["u-mid"], executorUids: [], managerUid: "u-a"},
        "u-mid",
        "u-new",
      ),
      {managerUids: ["u-new"], managerUid: "u-new"},
    );
  });

  test("ومستندٌ قديم بلا حقول عضوية إطلاقاً — لا ينكسر ولا يُكتب", () => {
    assert.deepEqual(projectMemberPatch({}, "u-old", "u-new"), {});
  });
});

// ــــــــــــــــــ قيود الحساب السابق ــــــــــــــــــ
//
// «عدم بقاء أي قيود مرتبطة بالحساب السابق» — فالمعرِّف القديم يُشطب من
// قوائم إعدادات التقرير ولا يُستبدل بالجديد. والاستثناء الوحيد قائمةُ
// الحصر حين يكون شطبُها يفتح البريد على الجميع.
describe("شطب المعرِّف القديم من إعدادات التقرير", () => {
  test("يُشطب من قائمة المستثنين — ولا يُوضع الجديد مكانه", () => {
    const {patch, keptForSafety} = pruneUidFromReportSettings(
      {excludedUids: ["u-old", "u-x"]},
      "u-old",
    );
    assert.deepEqual(patch, {excludedUids: ["u-x"]});
    assert.deepEqual(keptForSafety, []);
    // الصريح أولى: لا يظهر الجديد في الحمولة بأي صورة.
    assert.equal(JSON.stringify(patch).includes("u-new"), false);
  });

  test("ومن قائمة المُضافين قسراً", () => {
    const {patch} = pruneUidFromReportSettings(
      {extraRecipientUids: ["u-x", "u-old"]},
      "u-old",
    );
    assert.deepEqual(patch, {extraRecipientUids: ["u-x"]});
  });

  test("ومن قائمة الحصر ما دام فيها غيرُه", () => {
    const {patch, keptForSafety} = pruneUidFromReportSettings(
      {emailRecipientUids: ["u-old", "u-boss"]},
      "u-old",
    );
    assert.deepEqual(patch, {emailRecipientUids: ["u-boss"]});
    assert.deepEqual(keptForSafety, []);
  });

  // الحالة التي بُني لأجلها الاستثناء: قائمةٌ من معرِّفٍ واحد. شطبُه يجعلها
  // فارغة، والفارغة تعني «البريد للجميع» — فينفتح إرسالُ التقرير على
  // الوزارة كلّها أثراً جانبياً لعمليةٍ لا شأن لها بالبريد.
  test("ولا تُفرَّغ قائمةُ الحصر — فتفريغُها يفتح البريد على الجميع", () => {
    const {patch, keptForSafety} = pruneUidFromReportSettings(
      {emailRecipientUids: ["u-old"]},
      "u-old",
    );
    assert.deepEqual(patch, {});
    assert.deepEqual(keptForSafety, ["emailRecipientUids"]);
  });

  // والاستثناء لقائمة الحصر وحدها: تفريغ «المستثنين» يرفع قيداً ولا يضع
  // أحداً تحت قيد، فيقع بلا تحفّظ.
  test("أما قائمة المستثنين فتُفرَّغ بلا تحفّظ", () => {
    const {patch, keptForSafety} = pruneUidFromReportSettings(
      {excludedUids: ["u-old"]},
      "u-old",
    );
    assert.deepEqual(patch, {excludedUids: []});
    assert.deepEqual(keptForSafety, []);
  });

  test("والقوائم الثلاث معاً", () => {
    const {patch} = pruneUidFromReportSettings({
      excludedUids: ["u-old"],
      extraRecipientUids: ["u-old", "u-y"],
      emailRecipientUids: ["u-old", "u-boss"],
    }, "u-old");
    assert.deepEqual(patch, {
      excludedUids: [],
      extraRecipientUids: ["u-y"],
      emailRecipientUids: ["u-boss"],
    });
  });

  test("ومعرِّفٌ ليس في شيءٍ منها — حمولةٌ فارغة، فلا كتابة", () => {
    const {patch, keptForSafety} = pruneUidFromReportSettings({
      excludedUids: ["u-x"],
      extraRecipientUids: [],
      emailRecipientUids: ["u-boss"],
    }, "u-old");
    assert.deepEqual(patch, {});
    assert.deepEqual(keptForSafety, []);
  });

  test("ومستند إعداداتٍ ناقص الحقول — لا ينكسر", () => {
    assert.deepEqual(
      pruneUidFromReportSettings({}, "u-old"),
      {patch: {}, keptForSafety: []},
    );
  });
});
