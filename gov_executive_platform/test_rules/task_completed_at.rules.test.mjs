// تاريخُ إنجاز المهمة — ومن يكتبه.
//
// ــــ الفخّ الذي وقعنا فيه مرّتين هذا الأسبوع ــــ
//
// قاعدةُ `tasks` تحصر ما يكتبه **المُسنَد إليه** في قائمةٍ مغلقة
// (`hasOnly`). فأيُّ حقلٍ جديد يُضاف إلى النموذج ويُكتب من مسار المُسنَد
// إليه **يُردّ**، ويُعرض له «تعذّر الحفظ: permission-denied» على فعلٍ يملكه.
//
// وقد وقع ذلك مرّتين: في تعديل العمل (حقول الحذف والتحويل)، وفي تسمية
// المشروع (قراءةُ بطاقة الإدارة). فيُقاس هنا **قبل** الإضافة لا بعدها.
//
// وما يُقاس: أن المُسنَد إليه يكتب تاريخ الإنجاز مع إغلاق مهمته، وأن
// القائمة المغلقة بقيت مغلقة على ما سواه — فلم يُفتح بابٌ آخر معه.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const ASSIGNEE = "u-emp";

let env;

const assigneeClaims = {
  role: "employee",
  approved: true,
  departmentId: DEPT,
  departmentIds: [],
  perms: {},
};

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "tasks/t1"), {
      projectId: "p1",
      departmentId: DEPT,
      title: "مهمة",
      assigneeUid: ASSIGNEE,
      assigneeName: "موظف",
      status: "inProgress",
      progressPercent: 40,
      lastUpdated: new Date("2026-08-01"),
      dueDate: new Date("2026-12-31"),
      priority: "medium",
      createdByUid: "u-lead",
      managerUid: "u-lead",
      managerUids: ["u-lead"],
      executorUids: [],
      closure: {},
    });
  });
}

/** إغلاقُ المهمة كما يكتبه المُسنَد إليه بعد إضافة الحقل. */
const closeWithDate = {
  status: "done",
  progressPercent: 100,
  lastUpdated: new Date("2026-08-26"),
  closure: {},
  completedAt: new Date("2026-08-26"),
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-task-completed",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("المُسنَد إليه يُغلق مهمته ويكتب تاريخها", () => {
  test("الإغلاق مع تاريخ الإنجاز يمرّ", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "tasks/t1"), closeWithDate));
  });

  // وما كان يمرّ قبل الإضافة يبقى ماراً: لا تُكسر مهمةٌ قائمة.
  test("والإغلاق بلا تاريخ يبقى ماراً", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "tasks/t1"), {
      status: "done", progressPercent: 100, lastUpdated: new Date("2026-08-26"), closure: {},
    }));
  });
});

describe("والقائمة المغلقة بقيت مغلقة", () => {
  test("لا يغيّر المُسنَد إليه عنوان مهمته", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {title: "عنوانٌ آخر"}));
  });

  test("ولا موعدها النهائي", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {dueDate: new Date("2027-01-01")}));
  });

  // ولا يُدسّ تاريخ الإنجاز مع حقلٍ ممنوع: الفتحة حقلٌ واحد لا باب.
  test("ولا يُدسّ التاريخ مع حقلٍ ممنوع", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {
      ...closeWithDate,
      priority: "critical",
    }));
  });

  test("ولا يُغيَّر مشروعُ المهمة", async () => {
    await seed();
    const db = env.authenticatedContext(ASSIGNEE, assigneeClaims).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {...closeWithDate, projectId: "p9"}));
  });

  // وغريبٌ لا صلة له بالمهمة لا يمرّ ولو كتب الحقول المسموحة.
  test("ولا يكتبها غيرُ المُسنَد إليه", async () => {
    await seed();
    const db = env
      .authenticatedContext("u-other", {...assigneeClaims})
      .firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), closeWithDate));
  });
});
