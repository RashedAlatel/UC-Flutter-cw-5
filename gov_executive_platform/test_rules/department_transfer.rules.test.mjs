// نقلُ المشروع بين الإدارتين — والتوابعُ التي لا تنتقل معه.
//
// ــــ إعادةُ إنتاجٍ لعطلٍ قائمٍ اليوم، لا حراسةٌ لمستقبل ــــ
//
// المهامُّ والتحديثاتُ اليومية والمخاطرُ والعوائق **تنسخ `departmentId` على
// نفسها**، وقاعدةُ قراءتها تقرأ المنسوخَ لا إدارةَ المشروع:
// `deptOf(resource.data)` لا `deptOf(realProject(...))`.
//
// وفي المنصة اليوم طريقان ينقلان مشروعاً بين إدارتين —
// `moveSectionToDepartment` و`convertDepartmentToSection` في `app_store.dart`
// — وكلاهما يكتب `projects/{id}.departmentId` **ولا يمسّ التوابع**.
//
// فالنتيجة: مديرُ الإدارة الجديدة يرى المشروع ولا يرى مهامَّه، ومديرُ
// القديمة ما زال يراها. وهذا ما يُقاس هنا **قبل** كتابة الإصلاح.
//
// ــــ ولماذا لا يُصلحه العميل ــــ
//
// لأن قواعد المهام والمخاطر والعوائق تمنع تعديل `departmentId` صراحةً
// (`hasAny(['projectId', 'departmentId', 'managerUid'])`)، والتحديثاتُ
// اليومية `update: if false`. فلا سبيل إلى الختم إلا من الخادم بصلاحية
// المدير — وذلك ما تفعله `restampChildDepartments`.
//
// وما يُقاس:
//   ١) الحالُ بعد نقلٍ بالطريقة القديمة: الجديدُ لا يقرأ، والقديمُ يقرأ.
//   ٢) والحالُ بعد إعادة الختم: الجديدُ يقرأ، والقديمُ لا يقرأ.
//   ٣) وأن العميل لا يستطيع الختم بنفسه — فالإصلاحُ من الخادم لا منه.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, updateDoc} from "firebase/firestore";

const OLD_DEPT = "d-old";
const NEW_DEPT = "d-new";

let env;

/** مديرُ إدارةٍ بعينها — بطاقةٌ كاملة. */
const managerOf = (dept) => ({
  role: "departmentManager",
  approved: true,
  departmentId: dept,
  departmentIds: [dept],
  perms: {},
});

/**
 * الحالُ **بعد نقلٍ بالطريقة القديمة**: المشروع انتقل، والتوابع لم تنتقل.
 *
 * ولا يُخترع هنا شيء: هذا حرفياً ما تتركه `moveSectionToDepartment` —
 * تكتب `projects/{id}.departmentId` وحدها.
 */
async function seedMovedTheOldWay() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "projects/p1"), {
      departmentId: NEW_DEPT, // ← نُقل
      name: "رقمنة صحيفة الدعوى",
      description: "",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 20,
      createdByUid: "u-admin",
      managerUid: null,
      managerUids: [],
      executorUids: [],
      executorNames: [],
      categoryIds: [],
    });
    // والتوابعُ بقيت مختومةً بالقديمة — أربعتُها.
    for (const [path, extra] of [
      ["tasks/t1", {title: "حصر النماذج", status: "inProgress"}],
      ["dailyUpdates/u1", {date: new Date("2026-03-01"), notes: "تقدّم"}],
      ["risks/r1", {title: "تأخّر التوريد"}],
      ["blockers/b1", {title: "انتظار موافقة"}],
    ]) {
      await setDoc(doc(db, path), {
        projectId: "p1",
        departmentId: OLD_DEPT, // ← لم يُنقل
        managerUid: null,
        managerUids: [],
        executorUids: [],
        ...extra,
      });
    }
  });
}

/** وإعادةُ الختم كما تفعلها الدالّة الخلفية بصلاحية المدير. */
async function restampChildren() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const path of ["tasks/t1", "dailyUpdates/u1", "risks/r1", "blockers/b1"]) {
      await updateDoc(doc(db, path), {departmentId: NEW_DEPT});
    }
  });
}

const CHILDREN = ["tasks/t1", "dailyUpdates/u1", "risks/r1", "blockers/b1"];

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-dept-transfer",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("العطل: المشروع انتقل وتوابعُه لم تنتقل", () => {
  test("مديرُ الإدارة الجديدة يقرأ المشروع", async () => {
    await seedMovedTheOldWay();
    const db = env.authenticatedContext("u-new", managerOf(NEW_DEPT)).firestore();
    await assertSucceeds(getDoc(doc(db, "projects/p1")));
  });

  // وهذا هو العطل بعينه: يرى المشروع ولا يرى ما فيه.
  for (const path of CHILDREN) {
    test(`ولا يقرأ ${path.split("/")[0]}`, async () => {
      await seedMovedTheOldWay();
      const db = env.authenticatedContext("u-new", managerOf(NEW_DEPT)).firestore();
      await assertFails(getDoc(doc(db, path)));
    });
  }

  // والقديمُ ما زال يقرأها وقد خرج المشروعُ من إدارته.
  test("ومديرُ الإدارة القديمة ما زال يقرأ المهمّة", async () => {
    await seedMovedTheOldWay();
    const db = env.authenticatedContext("u-old", managerOf(OLD_DEPT)).firestore();
    await assertSucceeds(getDoc(doc(db, "tasks/t1")));
  });

  test("ولا يقرأ المشروعَ نفسَه — فالانقسامُ في الاتجاهين", async () => {
    await seedMovedTheOldWay();
    const db = env.authenticatedContext("u-old", managerOf(OLD_DEPT)).firestore();
    await assertFails(getDoc(doc(db, "projects/p1")));
  });
});

describe("وبعد إعادة الختم", () => {
  for (const path of CHILDREN) {
    test(`مديرُ الجديدة يقرأ ${path.split("/")[0]}`, async () => {
      await seedMovedTheOldWay();
      await restampChildren();
      const db = env.authenticatedContext("u-new", managerOf(NEW_DEPT)).firestore();
      await assertSucceeds(getDoc(doc(db, path)));
    });
  }

  test("ومديرُ القديمة لم يعد يقرأ المهمّة", async () => {
    await seedMovedTheOldWay();
    await restampChildren();
    const db = env.authenticatedContext("u-old", managerOf(OLD_DEPT)).firestore();
    await assertFails(getDoc(doc(db, "tasks/t1")));
  });
});

describe("والختمُ من الخادم لا من العميل", () => {
  // مديرُ الإدارة القديمة يملك المهمّة اليوم (يقرؤها ويعدّلها)، ومع ذلك لا
  // يُقبل منه ختمُها بالإدارة الجديدة. فلو قُبل لَنقل مهامَّه إلى إدارةٍ
  // أخرى بلا اعتماد أحد.
  test("مديرُ الإدارة القديمة لا يختم المهمّة بالإدارة الجديدة", async () => {
    await seedMovedTheOldWay();
    const db = env.authenticatedContext("u-old", managerOf(OLD_DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {departmentId: NEW_DEPT}));
  });

  test("ولا مديرُ الإدارة الجديدة — ولا يقرؤها أصلاً", async () => {
    await seedMovedTheOldWay();
    const db = env.authenticatedContext("u-new", managerOf(NEW_DEPT)).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {departmentId: NEW_DEPT}));
  });

  // والتحديثُ اليومي `update: if false` — لا يُعدَّل بحال، ولا لمسؤول النظام.
  test("والتحديثُ اليومي لا يُختم ولو من مسؤول النظام", async () => {
    await seedMovedTheOldWay();
    const db = env
      .authenticatedContext("u-admin", {role: "systemAdmin", approved: true, perms: {}})
      .firestore();
    await assertFails(updateDoc(doc(db, "dailyUpdates/u1"), {departmentId: NEW_DEPT}));
  });
});
