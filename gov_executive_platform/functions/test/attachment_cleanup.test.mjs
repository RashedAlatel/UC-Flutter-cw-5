// أيُّ ملفاتٍ تُمحى حين يُحذف تحديثٌ يومي — وأيُّها لا يُمسّ.
//
// الحقل `storagePath` **يكتبه العميل**، ودالّة التنظيف تعمل بصلاحية
// المدير فتتجاوز كل القواعد. فما يُقاس هنا ليس «هل تُمحى المرفقات» — بل
// **أنّ مسارَ غيرِه لا يُمحى له**: موظفٌ يكتب تحديثاً على مشروعه ويضع في
// مرفقه مسار ملفٍ لا يخصّه، ثم يحذف تحديثه فيمحو الخادمُ عنه ملفَ غيره.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {storagePathsToDelete} from "../lib/attachment_cleanup.js";

const P = "p1";
const up = (storagePath) => ({kind: "upload", storagePath});

describe("ما يُمحى", () => {
  test("مرفوعٌ في مجلّد المشروع", () => {
    assert.deepEqual(
      storagePathsToDelete([up("projects/p1/dailyUpdates/a.pdf")], P),
      ["projects/p1/dailyUpdates/a.pdf"],
    );
  });

  test("وأكثر من واحد", () => {
    assert.deepEqual(
      storagePathsToDelete(
        [up("projects/p1/dailyUpdates/a.pdf"), up("projects/p1/dailyUpdates/b.xlsx")],
        P,
      ),
      ["projects/p1/dailyUpdates/a.pdf", "projects/p1/dailyUpdates/b.xlsx"],
    );
  });

  test("والمكرّر مرّةً واحدة", () => {
    assert.deepEqual(
      storagePathsToDelete(
        [up("projects/p1/dailyUpdates/a.pdf"), up("projects/p1/dailyUpdates/a.pdf")],
        P,
      ),
      ["projects/p1/dailyUpdates/a.pdf"],
    );
  });
});

describe("وما لا يُمسّ", () => {
  // الحالة التي بُني لأجلها الفحص كلّه.
  test("مسارُ مشروعٍ آخر — ولو كتبه صاحبُ التحديث بيده", () => {
    assert.deepEqual(
      storagePathsToDelete([up("projects/p2/dailyUpdates/سرّي.pdf")], P),
      [],
    );
  });

  test("ومسارٌ خارج مجلّد المرفقات أصلاً", () => {
    assert.deepEqual(storagePathsToDelete([up("users/u-1/توقيع.png")], P), []);
  });

  // بادئةٌ صحيحة واسمٌ يصعد بها إلى خارج المجلّد.
  test("وصعودٌ بـ`..` من داخل بادئةٍ صحيحة", () => {
    assert.deepEqual(
      storagePathsToDelete([up("projects/p1/dailyUpdates/../../p2/dailyUpdates/x.pdf")], P),
      [],
    );
  });

  test("وشرطةٌ مائلة تُخرجه إلى مجلّدٍ فرعي", () => {
    assert.deepEqual(
      storagePathsToDelete([up("projects/p1/dailyUpdates/sub/x.pdf")], P),
      [],
    );
  });

  // بادئةٌ متشابهة لا مطابقة: `p1` ليست `p10`.
  test("ومشروعٌ اسمه يبدأ باسم مشروعنا", () => {
    assert.deepEqual(
      storagePathsToDelete([up("projects/p10/dailyUpdates/x.pdf")], P),
      [],
    );
  });

  test("والرابط الخارجي — لا تملك المنصة ملفَّه", () => {
    assert.deepEqual(
      storagePathsToDelete(
        [{kind: "link", storagePath: "projects/p1/dailyUpdates/a.pdf"}],
        P,
      ),
      [],
    );
  });

  test("ومرفقٌ بلا مسار — مرفوعٌ قديم قبل وجود الحقل", () => {
    assert.deepEqual(storagePathsToDelete([{kind: "upload"}], P), []);
  });
});

describe("ولا ينكسر على مستندٍ ناقص", () => {
  test("بلا مرفقات إطلاقاً", () => {
    assert.deepEqual(storagePathsToDelete(undefined, P), []);
    assert.deepEqual(storagePathsToDelete(null, P), []);
    assert.deepEqual(storagePathsToDelete([], P), []);
  });

  test("وقيمٌ ليست كائنات", () => {
    assert.deepEqual(storagePathsToDelete(["نصّ", 7, null], P), []);
  });

  // بلا معرّف مشروع لا بادئة يُوثق بها — فلا يُمحى شيء.
  test("وبلا معرّف مشروع لا يُمحى شيء", () => {
    assert.deepEqual(storagePathsToDelete([up("projects/p1/dailyUpdates/a.pdf")], ""), []);
  });
});
