// تعديلُ عملٍ وُلد ناقصاً.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// دالّةُ `approveRequest` تكتب مستند العمل بخريطةٍ مبنيّةٍ بيدها تنقصها
// حقولٌ يكتبها العميل دائماً — ومنها **حقول الحذف والتحويل السبعة**. فكلُّ
// عملٍ أُنشئ باعتماد طلبٍ يُولد بلا تلك المفاتيح.
//
// وفي الطرف الآخر كانت `updateWork` تكتب المستند كاملاً بـ`toMap()`، وهي
// تكتب السبعة دائماً ولو فارغة. فحين يُعدَّل ذلك العمل تُضاف المفاتيح لأول
// مرّة، فتدخل في `diff().affectedKeys()` — وقاعدةُ `works` تشترط ألّا يُمسّ
// أيٌّ منها في التعديل العادي (`deletionUntouched`). فيُردّ الحفظ كلُّه.
//
// وهو حتميٌّ لا عارض: كلُّ عملٍ أُنشئ باعتماد طلبٍ لا يُعدَّل إطلاقاً.
//
// ــــ وما يُقاس هنا ــــ
//
// (١) الكتابةُ الكاملة على مستندٍ ناقص **تُردّ** — وهذا هو العطل معروضاً.
// (٢) والكتابةُ المقصودة بحقول النموذج وحدها **تمرّ** على المستند نفسه.
// (٣) والقاعدة لم تُرخَّص: المفاتيح المجمَّدة تبقى ممنوعة على التعديل.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const HEAD = "u-head";
const EMPLOYEE = "u-emp";

let env;

const headClaims = {
  role: "departmentManager",
  approved: true,
  departmentId: DEPT,
  departmentIds: [DEPT],
  perms: {mw: false},
};

/**
 * مستندُ عملٍ كما تكتبه `approveRequest` **اليوم**: بلا `status` ولا
 * `isRecurring` ولا `closure` ولا حقول الحذف والتحويل.
 */
async function seedHalfFormed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "works/w1"), {
      departmentId: DEPT,
      title: "نظام احالات دوائر العمالي",
      description: "وصف",
      assigneeUid: EMPLOYEE,
      assigneeName: "موظف",
      priority: "high",
      progressPercent: 0,
      dueDate: new Date("2026-10-01"),
      completedDate: null,
      createdByUid: EMPLOYEE,
      createdAt: new Date("2026-08-01"),
    });
  });
}

/** ما كانت `updateWork` تكتبه: المستند كاملاً، ومعه السبعة المجمَّدة. */
const fullPayload = {
  title: "نظام احالات دوائر العمالي",
  description: "وصف",
  departmentId: DEPT,
  assigneeUid: EMPLOYEE,
  assigneeName: "موظف",
  status: "todo",
  priority: "high",
  progressPercent: 0,
  dueDate: new Date("2026-10-01"),
  completedDate: null,
  isRecurring: false,
  createdByUid: EMPLOYEE,
  createdAt: new Date("2026-08-01"),
  closure: {},
  deletedAt: null,
  deletedBy: null,
  deletedReason: null,
  convertedFromType: null,
  convertedFromId: null,
  convertedToType: null,
  convertedToId: null,
};

/** وما تكتبه بعد الإصلاح: حقول النموذج وحدها. */
const narrowPayload = {
  title: "نظام احالات دوائر العمالي",
  description: "وصف",
  departmentId: DEPT,
  assigneeUid: EMPLOYEE,
  assigneeName: "موظف",
  status: "todo",
  priority: "high",
  progressPercent: 0,
  dueDate: new Date("2026-10-01"),
  completedDate: null,
  isRecurring: false,
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-work-edit",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("تعديلُ عملٍ وُلد ناقصاً", () => {
  // العطل بعينه: مديرُ الإدارة يملك تعديل العمل، ويُردّ.
  test("الكتابة الكاملة تُردّ — لأنها تُضيف المفاتيح المجمَّدة", async () => {
    await seedHalfFormed();
    const db = env.authenticatedContext(HEAD, headClaims).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), fullPayload));
  });

  test("والكتابة المقصودة تمرّ على المستند نفسه", async () => {
    await seedHalfFormed();
    const db = env.authenticatedContext(HEAD, headClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), narrowPayload));
  });

  // وإسنادُ العمل — وهو ما كان يفعله مسؤول النظام حين ظهرت الرسالة.
  test("وإسنادُه إلى غيره يمرّ بها كذلك", async () => {
    await seedHalfFormed();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/u-other"), {
        name: "زميل", role: "employee", departmentId: DEPT, status: "approved",
      });
    });
    const db = env.authenticatedContext(HEAD, headClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), {
      ...narrowPayload,
      assigneeUid: "u-other",
      assigneeName: "زميل",
    }));
  });
});

describe("والقاعدة لم تُرخَّص", () => {
  test("لا تُكتب علامةُ الحذف من باب التعديل", async () => {
    await seedHalfFormed();
    const db = env.authenticatedContext(HEAD, headClaims).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {
      ...narrowPayload,
      deletedAt: new Date("2026-08-20"),
    }));
  });

  test("ولا حقولُ التحويل", async () => {
    await seedHalfFormed();
    const db = env.authenticatedContext(HEAD, headClaims).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {
      ...narrowPayload,
      convertedToType: "project",
      convertedToId: "p-fake",
    }));
  });

  // ولا تُفتح لمن ليست الإدارة إدارته.
  test("ولا يعدّله مديرُ إدارةٍ أخرى", async () => {
    await seedHalfFormed();
    const db = env
      .authenticatedContext(HEAD, {...headClaims, departmentId: "d-other", departmentIds: ["d-other"]})
      .firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), narrowPayload));
  });
});
