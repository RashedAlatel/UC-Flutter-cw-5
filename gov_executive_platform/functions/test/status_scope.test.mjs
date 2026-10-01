// حالاتُ الموظفين اليومية: من يكتب، ومن يصحّح، وما الذي يُكتب.
//
// ــــ لماذا تُقاس هنا ــــ
//
// `index.ts` لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه المنصة).
// وهذا **قرارُ خصوصيّة** لا تفصيلُ تنفيذ: خطأٌ فيه يجعل موظّفاً يقرأ متى
// مرض زميلُه، أو يجعل سجلَّ حضورٍ يُكتب بأثرٍ رجعيّ فيفقد معناه.
//
// ــــ وأربعةُ حدودٍ تُقاس ــــ
//
// (١) **اليومُ يُحسب بتوقيت الكويت** لا بالعالميّ: من سجّل العاشرةَ ليلاً
//     كان سجلُّه يُكتب في يوم الغد بحساب `toISOString`.
// (٢) **والتسجيلُ لليوم وحدَه** — لا أمسٍ ولا غد.
// (٣) **والتصحيحُ للمسؤول** — لا لصاحب السجلّ ولا للمراقب.
// (٤) **والقائمةُ مغلقة**: حقلٌ غريبٌ يُدسّ في الحمولة لا يُكتب.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  dayKeyOf,
  dayDocId,
  isWorkingDay,
  mayRecordOn,
  mayCorrectStatus,
  statusPatch,
  outingProblem,
  STATUS_FIELDS,
} from "../lib/status_scope.js";

describe("مفتاحُ اليوم بتوقيت الكويت", () => {
  test("الظهرُ يُقرأ يومَه", () => {
    assert.equal(dayKeyOf(new Date("2026-09-20T09:00:00Z")), "2026-09-20");
  });

  // ــ وهذا هو الحدُّ الذي يُخطئه `toISOString` ــ
  //
  // العاشرةُ ليلاً بتوقيت الكويت هي السابعةُ مساءً عالميّاً **من اليوم
  // نفسِه**؛ أمّا الواحدةُ صباحاً بتوقيت الكويت فهي العاشرةُ مساءً عالميّاً
  // **من اليوم السابق**. فمن سجّل بعد منتصف الليل كان يُكتب سجلُّه أمس.
  test("والساعةُ الواحدةُ صباحاً تُكتب في يومها لا في أمس", () => {
    // ٢٢:٠٠ عالميّاً في ١٩ سبتمبر = ٠١:٠٠ بالكويت في ٢٠ سبتمبر.
    assert.equal(dayKeyOf(new Date("2026-09-19T22:00:00Z")), "2026-09-20");
  });

  test("والعاشرةُ ليلاً تبقى في يومها", () => {
    // ١٩:٠٠ عالميّاً = ٢٢:٠٠ بالكويت، في اليوم نفسِه.
    assert.equal(dayKeyOf(new Date("2026-09-20T19:00:00Z")), "2026-09-20");
  });

  test("والشهرُ واليومُ بخانتين دائماً", () => {
    assert.equal(dayKeyOf(new Date("2026-01-05T09:00:00Z")), "2026-01-05");
  });

  test("ومعرّفُ سجلِّ اليوم يجمع صاحبَه ويومَه", () => {
    assert.equal(dayDocId("u1", "2026-09-20"), "u1_2026-09-20");
  });
});

describe("أيامُ العمل: الأحد إلى الخميس", () => {
  // ٢٠ سبتمبر ٢٠٢٦ أحدٌ، و٢٤ خميس، و٢٥ جمعة، و٢٦ سبت.
  test("الأحدُ إلى الخميس عملٌ", () => {
    for (const day of ["2026-09-20", "2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24"]) {
      assert.equal(isWorkingDay(day, []), true, `${day} يومُ عمل`);
    }
  });

  test("والجمعةُ والسبتُ ليسا عملاً", () => {
    assert.equal(isWorkingDay("2026-09-25", []), false);
    assert.equal(isWorkingDay("2026-09-26", []), false);
  });

  // ــ وبلا هذا يصير كلُّ عيدٍ غياباً جماعيّاً ــ
  test("ويومُ عملٍ سُجّل عطلةً ليس عملاً", () => {
    assert.equal(isWorkingDay("2026-09-20", ["2026-09-20"]), false);
  });

  test("ومفتاحٌ لا يُقرأ تاريخاً لا يُعدّ يومَ عمل", () => {
    assert.equal(isWorkingDay("ليس تاريخاً", []), false);
  });
});

describe("والتسجيلُ لليوم وحدَه", () => {
  const now = new Date("2026-09-20T09:00:00Z");

  test("اليومُ يُقبل", () => {
    assert.equal(mayRecordOn("2026-09-20", now), true);
  });

  // ــ وهذا قرارُ مسؤول النظام: لا سجلَّ بأثرٍ رجعيّ ــ
  //
  // فسجلٌّ يُكتب متى شاء صاحبُه يمكن ملءُ شهرٍ كاملٍ حضوراً في آخره.
  test("وأمسِ يُردّ", () => {
    assert.equal(mayRecordOn("2026-09-19", now), false);
  });

  test("وغدٌ يُردّ كذلك", () => {
    assert.equal(mayRecordOn("2026-09-21", now), false);
  });
});

describe("والتصحيحُ للمسؤول وحدَه", () => {
  const target = {uid: "emp", departmentId: "d1", sectionId: "s1"};

  test("مسؤولُ النظام يصحّح في كلّ الوزارة", () => {
    assert.equal(mayCorrectStatus({uid: "a", isAdmin: true}, target), true);
  });

  test("ومديرُ الإدارة في إداراته", () => {
    const mgr = {uid: "m", isAdmin: false, role: "departmentManager", departmentIds: ["d1"]};
    assert.equal(mayCorrectStatus(mgr, target), true);
  });

  test("ولا يصحّح في إدارةٍ ليست له", () => {
    const mgr = {uid: "m", isAdmin: false, role: "departmentManager", departmentIds: ["d2"]};
    assert.equal(mayCorrectStatus(mgr, target), false);
  });

  test("ورئيسُ القسم في أقسامه", () => {
    const head = {uid: "h", isAdmin: false, role: "employee", headedSectionIds: ["s1"]};
    assert.equal(mayCorrectStatus(head, target), true);
  });

  test("ولا يصحّح في قسمٍ لا يرأسه", () => {
    const head = {uid: "h", isAdmin: false, role: "employee", headedSectionIds: ["s2"]};
    assert.equal(mayCorrectStatus(head, target), false);
  });

  // ــ وصاحبُ السجلّ لا يصحّح سجلَّ نفسِه ــ
  //
  // وهو قرارُ مسؤول النظام صراحةً: كلُّ تعديلٍ على سجلٍّ محفوظٍ يحمل اسمَ
  // مسؤولٍ يُسأل عنه.
  test("والموظّفُ لا يصحّح سجلَّ نفسِه", () => {
    const self = {uid: "emp", isAdmin: false, role: "employee"};
    assert.equal(mayCorrectStatus(self, target), false);
  });

  // ــ والمراقبُ نافذةٌ لا يد ــ
  test("والمستخدمُ التنفيذيُّ يرى ولا يصحّح ولو حمل الإدارة", () => {
    const viewer = {uid: "v", isAdmin: false, role: "executiveViewer", departmentIds: ["d1"]};
    assert.equal(mayCorrectStatus(viewer, target), false);
  });

  test("وسجلٌّ بلا إدارةٍ ولا قسمٍ لمسؤول النظام وحده", () => {
    const orphan = {uid: "x"};
    const mgr = {uid: "m", isAdmin: false, role: "departmentManager", departmentIds: ["d1"]};
    assert.equal(mayCorrectStatus(mgr, orphan), false);
    assert.equal(mayCorrectStatus({uid: "a", isAdmin: true}, orphan), true);
  });
});

describe("وما يُكتب من الحمولة", () => {
  test("القائمةُ مغلقة: ما ليس فيها يُهمَل", () => {
    const patch = statusPatch({
      typeId: "t1",
      uid: "someone-else",
      day: "2020-01-01",
      correctedByName: "مدسوس",
      role: "systemAdmin",
    });
    assert.deepEqual(Object.keys(patch), ["typeId"]);
  });

  test("وكلُّ حقلٍ مسموحٍ مذكورٌ في القائمة المعلنة", () => {
    const patch = statusPatch({
      typeId: "t1", typeName: "حضور", toneKey: "success",
      fromMinutes: 540, toMinutes: 660, place: "وزارة المالية", note: "اجتماع",
    });
    for (const key of Object.keys(patch)) {
      assert.ok(STATUS_FIELDS.includes(key), `${key} يُكتب ولا يُعلن`);
    }
  });

  test("والنوعُ لا يُمحى بنصٍّ فارغ", () => {
    assert.deepEqual(statusPatch({typeId: "   "}), {});
  });

  test("والملاحظةُ تُمحى صراحةً — ومحوُها تصحيح", () => {
    assert.deepEqual(statusPatch({note: ""}), {note: ""});
  });

  test("ووقتٌ خارجَ اليوم يُهمَل ولا يُقصّ", () => {
    // ولا يُقصّ إلى ٢٣:٥٩: القصُّ يخترع وقتاً لم يقله أحد.
    assert.deepEqual(statusPatch({fromMinutes: 1441}), {});
    assert.deepEqual(statusPatch({fromMinutes: -1}), {});
  });

  test("و`null` يمحو الوقتَ صراحةً — وهي حالُ مَن صار خروجُه يوماً كاملاً", () => {
    assert.deepEqual(statusPatch({fromMinutes: null}), {fromMinutes: null});
  });

  test("ونصٌّ في موضع الرقم يُهمَل", () => {
    assert.deepEqual(statusPatch({fromMinutes: "540"}), {});
  });
});

describe("والخروجُ له وقتان", () => {
  test("بلا وقتٍ ليس خروجاً", () => {
    assert.notEqual(outingProblem({}), "");
  });

  test("وعودةٌ قبل الخروج تُردّ ولا تُبادَل", () => {
    // ولا تُبادَل: لا أحد يعلم أيَّهما قصد.
    assert.notEqual(outingProblem({fromMinutes: 660, toMinutes: 540}), "");
  });

  test("وعودةٌ في لحظة الخروج ليست خروجاً", () => {
    assert.notEqual(outingProblem({fromMinutes: 600, toMinutes: 600}), "");
  });

  test("ووقتان صحيحان يمرّان", () => {
    assert.equal(outingProblem({fromMinutes: 540, toMinutes: 660}), "");
  });
});
