// مديرُ الإدارة وبطاقتُه: الإدارةُ المفردة والقائمة.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// بطاقةُ الدخول تحمل الإدارة في موضعين: `departmentId` مفرداً (وهو الأقدم،
// ويحمله كلُّ حساب) و`departmentIds` قائمةً (أُضيفت حين صار مديرُ الإدارة
// قد يدير أكثر من إدارة). ومنهما تقرأ القواعد.
//
// وقُرئت **بطريقتين مختلفتين في المنصة الواحدة**:
//
//   • قاعدةُ الأعمال تقرأ `isMyDeptAny` — المفرد **أو** القائمة.
//   • و`canEditDept` تقرأ `isMyDeptOfManager` — القائمة وحدها.
//   • والعميل يقرأ `myDepartmentIds` وهي **تعود إلى المفرد** عند فراغ القائمة.
//
// فمديرُ إدارةٍ بطاقتُه تحمل المفرد وقائمتُه فارغة — وهو حالُ كل حسابٍ
// رُقّي قبل إضافة القائمة أو ضُبط من مسارٍ لم يملأها — يرى قلمَ التعديل
// (لأن العميل يقول نعم)، **ويعدّل أعمال إدارته** (لأن قاعدتها تقبل المفرد)،
// **ويُردّ عليه تعديل المشروع**. وهذا بعينه ما بلّغ عنه مسؤول النظام.
//
// وما يُقاس هنا: أن الثلاثة صارت تقرأ البطاقة قراءةً واحدة — وأن التوسيع
// لم يتجاوز **مديرَ الإدارة في إدارته**.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const OTHER = "d-elsewhere";
const HEAD = "u-head";

let env;

/** بطاقةُ مدير إدارةٍ تحمل **المفرد وحده** — والقائمة فارغة. */
const singularOnly = (dept) => ({
  role: "departmentManager",
  approved: true,
  departmentId: dept,
  departmentIds: [],
  perms: {mw: false},
});

/** وبطاقةٌ تحمل القائمة — وهي الحال بعد ضبطٍ حديث. */
const listClaim = (dept) => ({
  role: "departmentManager",
  approved: true,
  departmentId: null,
  departmentIds: [dept],
  perms: {mw: false},
});

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "projects/p1"), {
      departmentId: DEPT,
      name: "الاسم القديم",
      description: "وصف",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 20,
      executorNames: [],
      createdByUid: "u-admin",
      managerUids: [],
      executorUids: [],
      managerUid: null,
      sectionId: null,
      categoryIds: [],
      deletedAt: null,
      deletedBy: null,
      deletedReason: null,
    });
    await setDoc(doc(db, "works/w1"), {
      departmentId: DEPT,
      title: "عمل",
      description: "",
      assigneeUid: "u-emp",
      assigneeName: "موظف",
      status: "inProgress",
      priority: "medium",
      progressPercent: 0,
      dueDate: new Date("2026-12-31"),
      createdByUid: "u-admin",
      createdAt: new Date("2026-01-01"),
      closure: {},
      deletedAt: null,
      deletedBy: null,
      deletedReason: null,
    });
  });
}

/** ما تكتبه `updateProjectDetails` بالضبط. */
const rename = {
  name: "الاسم الجديد",
  description: "وصف",
  priority: "medium",
  sectionId: null,
  categoryIds: [],
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-dept-claim",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("بطاقةٌ بالمفرد وحده", () => {
  // العطل بعينه: يعدّل العمل ولا يعدّل المشروع.
  test("مديرُ الإدارة يعدّل اسم مشروع إدارته", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, singularOnly(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), rename));
  });

  test("وكان يعدّل أعمالها أصلاً — والقراءتان صارتا واحدة", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, singularOnly(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), {title: "عملٌ باسمٍ جديد"}));
  });
});

describe("وبطاقةٌ بالقائمة", () => {
  test("تعمل كما كانت", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, listClaim(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), rename));
  });
});

describe("والتوسيع لم يتجاوز مديرَ الإدارة في إدارته", () => {
  test("لا يعدّل مديرُ إدارةٍ أخرى — بالمفرد", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, singularOnly(OTHER)).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), rename));
  });

  test("ولا بالقائمة", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, listClaim(OTHER)).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), rename));
  });

  // والشرطُ الذي يحمل التوسيع كلَّه: الدور. فموظفٌ في الإدارة نفسها لا يمرّ.
  test("ولا موظفٌ في الإدارة نفسها وليس مديرها", async () => {
    await seed();
    const db = env
      .authenticatedContext("u-emp", {
        role: "employee", approved: true, departmentId: DEPT, departmentIds: [], perms: {},
      })
      .firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), rename));
  });

  test("ولا المستخدم التنفيذي وهو يقرأ كل الإدارات", async () => {
    await seed();
    const db = env
      .authenticatedContext("u-exec", {
        role: "executiveViewer", approved: true, departmentId: DEPT, departmentIds: [], perms: {},
      })
      .firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), rename));
  });

  // والموعد النهائي بوابةُ اعتمادٍ لا يفتحها هذا التوسيع.
  test("ولا يُفتح الموعد النهائي لمدير الإدارة", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, singularOnly(DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {dueDate: new Date("2027-06-30")}));
  });
});
