// ما يُختم على المستند التابع، وما يُترك.
//
// العطل: `executorUids` لم تكن تُنسخ على توابع المشروع قط. فالقاعدة لا
// تعرف المنفّذ عليها (`isProjectMember` تقرأ القائمتين)، والاستعلام لا
// يستطيع أن يسأل عن عضويته — فلا يصله تحديثٌ واحد على مشروعٍ هو منفّذُه.
//
// وما يُقاس هنا شيئان: أن الناقص يُختم، وأن **المطابق لا يُكتب** — فختمُ
// آلاف المستندات المطابقة سلفاً كتاباتٌ بلا أثر تُغرق حصرَ ما تغيّر.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {childMembershipPatch} from "../lib/child_membership.js";

const project = {managerUids: ["m1", "m2"], executorUids: ["e1"]};

describe("ما يُختم", () => {
  // الحالة التي بُنيت الوحدة لأجلها: الحقل غائبٌ إطلاقاً.
  test("تابعٌ بلا قائمة منفّذين إطلاقاً", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m1", "m2"]}, project),
      {executorUids: ["e1"]},
    );
  });

  test("وتابعٌ بلا القائمتين معاً", () => {
    assert.deepEqual(
      childMembershipPatch({managerUid: "m1"}, project),
      {managerUids: ["m1", "m2"], executorUids: ["e1"]},
    );
  });

  test("وتابعٌ قائمتُه قديمة — عضوٌ أُضيف بعد كتابته", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m1"], executorUids: ["e1"]}, project),
      {managerUids: ["m1", "m2"]},
    );
  });

  test("وعضوٌ خرج من المشروع يخرج من التابع", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m1", "m2"], executorUids: ["e1", "e9"]}, project),
      {executorUids: ["e1"]},
    );
  });

  // ــ الغائب ليس كالفارغ ــ
  //
  // مشروعٌ بلا منفّذين وتابعٌ لا يحمل الحقل: يُكتب الحقلُ فارغاً. فبغيره
  // لا تراه القاعدة ولا يجده الاستعلام — وهو الفرق الذي لولاه لَبقي
  // مستندٌ خارج كل قراءة.
  test("ومشروعٌ بلا منفّذين — يُكتب الحقل فارغاً لا يُترك غائباً", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m1"]}, {managerUids: ["m1"], executorUids: []}),
      {executorUids: []},
    );
  });
});

describe("وما لا يُكتب", () => {
  test("تابعٌ مطابقٌ لمشروعه — حمولةٌ فارغة", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m1", "m2"], executorUids: ["e1"]}, project),
      {},
    );
  });

  test("ومشروعٌ فارغ القائمتين وتابعٌ مثله", () => {
    assert.deepEqual(
      childMembershipPatch(
        {managerUids: [], executorUids: []},
        {managerUids: [], executorUids: []},
      ),
      {},
    );
  });

  // الترتيب جزءٌ من المطابقة: `arrayContains` لا يبالي به، لكن إعادة
  // الكتابة لمجرّد اختلافه ضجيجٌ بلا فائدة.
  test("والترتيب المختلف يُعاد ختمُه — لا يُترك مشكوكاً فيه", () => {
    assert.deepEqual(
      childMembershipPatch({managerUids: ["m2", "m1"], executorUids: ["e1"]}, project),
      {managerUids: ["m1", "m2"]},
    );
  });
});
