// الحذف المنطقي: من يحذف، ومن يستعيد، وما يبقى مجمَّداً.
//
// ــــ ما كان قبله ــــ
//
// حذفُ المشروع كان **نهائياً متسلسلاً**: يمحو مهامّه وتحديثاته ومخاطره
// وعوائقه معه بلا رجعة. وحذفُ العمل نهائياً كذلك. ولا سبيل إلى استعادة
// شيء — ولا لمسؤول النظام.
//
// وصلاحية «حذف السجلات» (`del`) كانت **بلا نطاق**: `allow delete: if
// isAdmin() || perm('del')` — فحاملُها يمحو أعمال **أي إدارة في الوزارة**.
//
// وثلاث ثوابت تُقاس هنا، كلٌّ منها بطفرة:
//   ١) الحذف داخل الإدارة وحدها.
//   ٢) والاستعادة لمسؤول النظام وحده — فمن حذف لا يُعيد ما حذف.
//   ٣) والمحذوف مجمَّد، وإلا صار الحذف باباً لتعديلٍ لا يراه أحد.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc, deleteDoc} from "firebase/firestore";

const DEPT = "d-justice";
const OTHER = "d-elsewhere";
const HEAD = "u-head";
const DELETER = "u-deleter";
const EMPLOYEE = "u-emp";

let env;

function claims(uid, {role = "employee", dept = DEPT, depts = [], perms = {}} = {}) {
  return {role, approved: true, departmentId: dept, departmentIds: depts, perms};
}

const headOf = (dept) =>
  claims(HEAD, {role: "departmentManager", dept, depts: [dept]});

async function seed({deleted = false} = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const mark = deleted
      ? {deletedAt: new Date("2026-08-01"), deletedBy: HEAD, deletedReason: "سببٌ ما"}
      : {deletedAt: null, deletedBy: null, deletedReason: null};
    await setDoc(doc(db, "works/w1"), {
      departmentId: DEPT,
      title: "عمل",
      description: "",
      assigneeUid: EMPLOYEE,
      assigneeName: "موظف",
      status: "inProgress",
      priority: "medium",
      progressPercent: 10,
      dueDate: new Date("2026-12-31"),
      createdByUid: "admin",
      createdAt: new Date("2026-01-01"),
      ...mark,
    });
  });
}

const deleteMark = (by) => ({
  deletedAt: new Date("2026-08-20"),
  deletedBy: by,
  deletedReason: "لم يعد مطلوباً",
});

const restoreMark = {deletedAt: null, deletedBy: null, deletedReason: null};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-soft-delete",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("١) من يحذف حذفاً منطقياً", () => {
  test("مدير الإدارة داخل إدارته", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), deleteMark(HEAD)));
  });

  // الثغرة بعينها: `del` كانت بلا نطاق إطلاقاً.
  test("ولا يحذف مديرُ إدارةٍ أخرى", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(OTHER)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), deleteMark(HEAD)));
  });

  test("وحاملُ «حذف السجلات» داخل إدارته", async () => {
    await seed();
    const db = env
      .authenticatedContext(DELETER, claims(DELETER, {perms: {del: true}}))
      .firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), deleteMark(DELETER)));
  });

  test("ولا يحذف بها في إدارةٍ ليست له — وكانت تُجيز الوزارة كلَّها", async () => {
    await seed();
    const db = env
      .authenticatedContext(DELETER, claims(DELETER, {dept: OTHER, perms: {del: true}}))
      .firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), deleteMark(DELETER)));
  });

  test("ولا موظفٌ عادي في الإدارة نفسها", async () => {
    await seed();
    const db = env.authenticatedContext(EMPLOYEE, claims(EMPLOYEE)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), deleteMark(EMPLOYEE)));
  });

  // ولا يُنسب الحذف إلى غيره: `deletedBy` هو المتصل نفسه.
  test("ولا يحذف باسم غيره", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), deleteMark("u-someone-else")));
  });
});

describe("٢) والاستعادة لمسؤول النظام وحده", () => {
  test("مسؤول النظام يستعيد", async () => {
    await seed({deleted: true});
    const db = env
      .authenticatedContext("u-admin", claims("u-admin", {role: "systemAdmin"}))
      .firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), restoreMark));
  });

  // من حذف لا يُعيد ما حذف بنفسه — وإلا صار الحذف والاستعادة بيدٍ واحدة
  // فيُمحى الأثر ويُعاد بلا أن يمرّ بأحد.
  test("ولا يستعيد مديرُ الإدارة ما حذفه هو", async () => {
    await seed({deleted: true});
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), restoreMark));
  });

  test("ولا حاملُ «حذف السجلات»", async () => {
    await seed({deleted: true});
    const db = env
      .authenticatedContext(DELETER, claims(DELETER, {perms: {del: true}}))
      .firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), restoreMark));
  });
});

describe("٣) والمحذوف مجمَّد", () => {
  // ولولا التجميد لَصار الحذف باباً لتعديلٍ لا يراه أحد: المحذوف لا يُعرض
  // في شيء، فمن عدّله بعد حذفه عدّل في الظلام ثم استُعيد السجل معدَّلاً.
  test("لا يُعدَّل عملٌ محذوف — ولا لمن يملك تعديله وهو حيّ", async () => {
    await seed({deleted: true});
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {title: "عنوانٌ جديد"}));
  });

  test("ولا يحرّكه المُسنَد إليه", async () => {
    await seed({deleted: true});
    const db = env.authenticatedContext(EMPLOYEE, claims(EMPLOYEE)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {progressPercent: 80}));
  });

  test("والحيُّ يُعدَّل كما كان — فالتجميد للمحذوف وحده", async () => {
    await seed();
    const db = env.authenticatedContext(EMPLOYEE, claims(EMPLOYEE)).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), {progressPercent: 80}));
  });
});

describe("والحذف النهائي لمسؤول النظام وحده", () => {
  test("يحذفه نهائياً", async () => {
    await seed();
    const db = env
      .authenticatedContext("u-admin", claims("u-admin", {role: "systemAdmin"}))
      .firestore();
    await assertSucceeds(deleteDoc(doc(db, "works/w1")));
  });

  // وكانت `perm('del')` تُجيز المحو النهائي في أي إدارة.
  test("ولا يحذفه حاملُ «حذف السجلات» نهائياً — يحذف منطقياً وحسب", async () => {
    await seed();
    const db = env
      .authenticatedContext(DELETER, claims(DELETER, {perms: {del: true}}))
      .firestore();
    await assertFails(deleteDoc(doc(db, "works/w1")));
  });
});
