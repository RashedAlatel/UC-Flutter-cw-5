// بوابةُ تعديل بيانات المشروع — وما تُغلقه، وما يجب أن يبقى مفتوحاً.
//
// ــــ إعادةُ إنتاجٍ حقيقية، لا حارسٌ احتياطي ــــ
//
// يُشغَّل هذا الملفّ **مرّتين**: مرّةً على القاعدة كما هي فتمرّ كتاباتُ
// «يجب أن تُردّ» — وذلك إثباتُ أن الباب مفتوحٌ اليوم فعلاً؛ ثم بعد التضييق
// فتُردّ. ولولا القياسُ الأول لَكان التضييقُ إصلاحاً لعطلٍ مُفترَض.
//
// ــــ والنصفُ الثاني أخطرُ من الأول ــــ
//
// تضييقُ قاعدةٍ يكسر ما يكتبها من حيث لا يُرى. فقِيس في الشيفرة من يكتب على
// `projects`، وثبِّت هنا **ما يجب أن يبقى ماراً**: التحديثُ اليومي
// (`progressPercent` و`status`)، وإسنادُ القسم، وأسماءُ المنفّذين النصّية —
// وهي التي قرّرتَ إبقاءها مباشرة.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const DEPT_MANAGER = "u-dept";
const PROJECT_MANAGER = "u-lead";

let env;

const deptManagerClaims = {
  role: "departmentManager",
  approved: true,
  departmentId: DEPT,
  departmentIds: [DEPT],
  perms: {},
};

// مديرُ المشروع دورُه الأساسي «موظف» — القيادةُ مسؤوليةٌ داخل مشروع لا دور.
const projectManagerClaims = {
  role: "employee",
  approved: true,
  departmentId: DEPT,
  departmentIds: [],
  perms: {},
};

const adminClaims = {role: "systemAdmin", approved: true, perms: {}};

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "projects/p1"), {
      departmentId: DEPT,
      name: "مشروع العدالة الرقمية",
      description: "وصفٌ قائم",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 20,
      createdByUid: PROJECT_MANAGER,
      managerUid: PROJECT_MANAGER,
      managerUids: [PROJECT_MANAGER],
      executorUids: [],
      executorNames: ["منفّذ نصّي"],
      categoryIds: [],
      sectionId: null,
      contractDate: null,
      contractStartDate: null,
      contractEndDate: null,
      invoiceDueDate: null,
      durationDays: null,
      contractValue: null,
      contractorName: "",
    });
  });
}

/** الحقولُ الأحدَ عشرَ التي تصير بالاعتماد — كلٌّ وحدَه. */
const gated = {
  "اسم المشروع": {name: "اسمٌ جديد"},
  "وصف المشروع": {description: "وصفٌ جديد"},
  "الأولوية": {priority: "critical"},
  "التصنيف": {categoryIds: ["c1"]},
  "تاريخ العقد": {contractDate: new Date("2026-02-01")},
  "بداية العقد": {contractStartDate: new Date("2026-02-15")},
  "نهاية العقد": {contractEndDate: new Date("2027-02-14")},
  "استحقاق الفاتورة": {invoiceDueDate: new Date("2026-03-01")},
  "مدة المشروع": {durationDays: 365},
  "قيمة العقد": {contractValue: 125000.5},
  "الجهة المنفّذة": {contractorName: "شركة النظم"},
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-project-edit",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("البياناتُ الأساسية لا تُكتب مباشرةً", () => {
  for (const [label, patch] of Object.entries(gated)) {
    test(`مديرُ الإدارة لا يكتب «${label}»`, async () => {
      await seed();
      const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
      await assertFails(updateDoc(doc(db, "projects/p1"), patch));
    });

    test(`ومديرُ المشروع لا يكتب «${label}»`, async () => {
      await seed();
      const db = env.authenticatedContext(PROJECT_MANAGER, projectManagerClaims).firestore();
      await assertFails(updateDoc(doc(db, "projects/p1"), patch));
    });
  }

  // ولا يُدسّ حقلٌ محظور مع حقلٍ مسموح: الفتحةُ حقلٌ لا باب.
  test("ولا يُدسّ الاسم مع نسبة الإنجاز", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {
      progressPercent: 60,
      name: "اسمٌ مدسوس",
    }));
  });

  // ومسؤولُ النظام يعدّل مباشرةً — هو المعتمِد النهائي، فلا معنى لأن يطلب
  // من نفسه.
  test("ومسؤولُ النظام يكتبها كلَّها", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", adminClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      name: "اسمٌ جديد",
      description: "وصفٌ جديد",
      priority: "critical",
      categoryIds: ["c1"],
      contractValue: 125000.5,
      contractorName: "شركة النظم",
      durationDays: 365,
    }));
  });
});

describe("وما قرّرتَ إبقاءه مباشراً يبقى", () => {
  // قلبُ المنصة: التحديثُ اليومي يكتب نسبةَ الإنجاز والحالة.
  test("التحديثُ اليومي يكتب نسبة الإنجاز والحالة", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      progressPercent: 60,
      status: "atRisk",
    }));
  });

  test("ومديرُ المشروع كذلك", async () => {
    await seed();
    const db = env.authenticatedContext(PROJECT_MANAGER, projectManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      progressPercent: 55,
      status: "onTrack",
    }));
  });

  // تنظيمٌ داخلي لا يغيّر من يرى المشروع — قرارك.
  test("وإسنادُ المشروع إلى قسمٍ داخل الإدارة", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {sectionId: "s1"}));
  });

  test("وأسماءُ المنفّذين النصّية", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      executorNames: ["منفّذ أول", "منفّذ ثانٍ"],
    }));
  });
});

describe("والبواباتُ القائمة بقيت مغلقة", () => {
  test("الموعدُ النهائي", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {dueDate: new Date("2027-06-30")}));
  });

  test("ونقلُ المشروع إلى إدارةٍ أخرى", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {departmentId: "d-other"}));
  });

  test("وتغييرُ مدير المشروع", async () => {
    await seed();
    const db = env.authenticatedContext(DEPT_MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {managerUids: ["u-x"]}));
  });
});
