// من يحذف تحديثاً يومياً — على الخادم.
//
// الحذف يقع بصلاحية المدير (لأن معه محوَ ملفاتٍ من التخزين لا تأذن به
// قواعدُ التخزين)، فيتجاوز قواعد Firestore. فما يُقاس هنا هو أن النصّ
// المُعاد على الخادم **هو نفسه** نصُّ القاعدة، على الحالات نفسها.
//
// ونظيرُه على المحاكي في `test_rules/daily_update.rules.test.mjs`،
// ونظيرُه في العميل في `test/daily_update_delete_test.dart`. ثلاثةُ
// مواضع لنصٍّ واحد — فإن افترقت، افترق ما يراه المستخدم عمّا يقع فعلاً.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {mayDeleteDailyUpdate} from "../lib/daily_update_delete.js";

const DEPT = "d-1";
const project = (extra = {}) => ({
  departmentId: DEPT,
  managerUids: ["m1", "m2"],
  executorUids: ["e1"],
  ...extra,
});
const update = (authorUid = "m1") => ({authorUid});

const actor = (uid, role, departmentIds = [DEPT]) => ({uid, role, departmentIds});

describe("من يحذف", () => {
  test("مسؤول النظام — أيّ تحديث", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("a", "systemAdmin", []), update(), project()),
      true,
    );
  });

  test("وكاتبُه — ولو كان موظفاً منفّذاً", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("e1", "employee"), update("e1"), project()),
      true,
    );
  });

  test("ومديرُ المشروع الأول على تحديثٍ لم يكتبه", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("m1", "projectOfficer"), update("e1"), project()),
      true,
    );
  });

  // نظير عطل الاشتراك والدمج: القائمة لا المفرد.
  test("والمدير الثاني كذلك — بالقائمة لا بالمفرد", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("m2", "projectOfficer"), update("m1"), project()),
      true,
    );
  });

  test("ومديرُ الإدارة صاحبتِه", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("h", "departmentManager"), update(), project()),
      true,
    );
  });

  test("ومديرُ إدارةٍ يديرُ أكثر من واحدة، منها إدارةُ المشروع", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("h", "departmentManager", ["d-9", DEPT]), update(), project()),
      true,
    );
  });
});

describe("ومن لا يحذف", () => {
  // حدُّ الفتح: المنفّذ **يكتب** التحديث اليومي ولا يمحو تحديث مديره.
  test("المنفّذُ تحديثَ مديره", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("e1", "employee"), update("m1"), project()),
      false,
    );
  });

  test("وزميلٌ في الإدارة ليس عضواً", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("z", "employee"), update("m1"), project()),
      false,
    );
  });

  test("ومديرُ إدارةٍ أخرى", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("h", "departmentManager", ["d-9"]), update(), project()),
      false,
    );
  });

  // يرى كل الإدارات ولا يغيّر فيها شيئاً.
  test("والمستخدم التنفيذي", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("v", "executiveViewer", []), update(), project()),
      false,
    );
  });

  // ــ والحالة التي بها وحدها يُقاس هذا الشرط ــ
  //
  // المستخدم التنفيذي لا يمرّ بالفروع الأخرى أصلاً (ليس كاتباً ولا مديراً
  // ولا مدير إدارة)، فإسقاطُ شرطه لا يغيّر النتيجة — **إلا إن كان هو
  // الكاتب**. وذلك يقع فعلاً: موظفٌ كتب تحديثاته ثم نُقل إلى هذا الدور،
  // فبقي اسمُه عليها. وبعد النقل هو ناظرٌ لا عامل، فلا يمحو.
  test("ولو كان هو كاتبَ التحديث — نُقل إلى الدور بعد أن كتب", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("v", "executiveViewer", []), update("v"), project()),
      false,
    );
  });

  test("وبلا معرّف حساب", () => {
    assert.equal(mayDeleteDailyUpdate(actor("", "systemAdmin", []), update(), project()), false);
  });
});

describe("ولا ينكسر على مستندٍ ناقص", () => {
  // مشروعٌ حُذف بينما نافذةُ اليوم مفتوحة: يبقى للكاتب حقُّه ولا يُخمَّن غيره.
  test("مشروعٌ غير موجود — للكاتب وحده", () => {
    assert.equal(mayDeleteDailyUpdate(actor("e1", "employee"), update("e1"), null), true);
    assert.equal(mayDeleteDailyUpdate(actor("m1", "projectOfficer"), update("e1"), null), false);
  });

  test("ومشروعٌ قديم بلا قائمة مديرين", () => {
    assert.equal(
      mayDeleteDailyUpdate(actor("m1", "projectOfficer"), update("e1"), {departmentId: DEPT}),
      false,
    );
  });

  test("ومديرُ إدارةٍ بلا إدارات في بصمته", () => {
    assert.equal(
      mayDeleteDailyUpdate({uid: "h", role: "departmentManager"}, update(), project()),
      false,
    );
  });
});
