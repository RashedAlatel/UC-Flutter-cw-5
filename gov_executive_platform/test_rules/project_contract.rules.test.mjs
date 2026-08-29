// حقولُ العقد على المشروع — وحدُّ ما تسمح به القاعدة.
//
// ــــ لماذا يُقاس هذا **قبل** إضافة الحقول ــــ
//
// وقع في هذا المستودع مرّتين أن سجلاً وُلد ناقصاً حقلاً، ثم رُدّ أوّلُ تعديلٍ
// عليه: في الأعمال (`ba220b7`) وفي `completedAt` على المهام. والسبب أن
// `diff().affectedKeys()` يشمل المفتاح الذي يُضاف **لأول مرّة** ولو كُتب
// فارغاً، فيصطدم بقائمة القاعدة.
//
// **وقيس هذا الملفّ على القاعدة قبل إضافة أي حقل: مرّ سبعةً من سبعة.**
//
// والسبب أن قائمة `projects` قائمةُ **منع** (`hasAny`) لا قائمةَ سماح
// (`hasOnly`) — بخلاف `works` و`tasks` اللتين وقع فيهما العطل. فالحقولُ
// الجديدة تمرّ بلا تعديلِ قاعدة.
//
// فهذا الملفّ **حارسٌ لا إعادةُ إنتاج**: لا يُصلح عطلاً قائماً، بل يمنع أن
// تُقلب القائمةُ يوماً إلى `hasOnly` فيُردّ تعديلُ كل مشروعٍ قديم بلا أن
// يكشفه شيء. وذلك فرقٌ يُقال ولا يُلبَّس.
//
// وما يُقاس:
//   ١) مشروعٌ وُلد **بلا** حقول العقد يقبل تعديلاً يُضيفها.
//   ٢) والقائمةُ المحظورة بقيت محظورة — فلم يُفتح مع حقول العقد بابٌ آخر.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const MANAGER = "u-lead";

let env;

const deptManagerClaims = {
  role: "departmentManager",
  approved: true,
  departmentId: DEPT,
  departmentIds: [DEPT],
  perms: {},
};

/** مشروعٌ **كما وُلد قبل حقول العقد** — بلا أيٍّ منها. */
async function seedLegacyProject() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "projects/p1"), {
      departmentId: DEPT,
      name: "مشروع قديم",
      description: "",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 20,
      createdByUid: MANAGER,
      managerUid: MANAGER,
      managerUids: [MANAGER],
      executorUids: [],
      executorNames: [],
      categoryIds: [],
    });
  });
}

/** حقولُ العقد السبعة كما يكتبها التعديل. */
const contractPatch = {
  contractDate: new Date("2026-02-01"),
  contractStartDate: new Date("2026-02-15"),
  contractEndDate: new Date("2027-02-14"),
  invoiceDueDate: new Date("2026-03-01"),
  durationDays: 365,
  contractValue: 125000.5,
  contractorName: "شركة النظم المتقدمة",
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-project-contract",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("مشروعٌ وُلد بلا حقول العقد يقبل إضافتها", () => {
  test("مديرُ الإدارة يكتب حقول العقد السبعة على مشروعٍ قديم", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), contractPatch));
  });

  test("ويكتب بعضَها ويترك بعضاً", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      contractValue: 9000,
      contractorName: "مؤسسة التوريد",
    }));
  });

  // والفارغُ يُكتب `null` لا يُحذف: «غير مسجّل» قيمةٌ لا غياب.
  test("ويكتبها فارغةً بلا رفض", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      contractDate: null,
      contractValue: null,
      contractorName: "",
    }));
  });
});

describe("والقائمةُ المحظورة بقيت محظورة", () => {
  // حقولُ العقد لا تفتح باباً لغيرها: الموعدُ النهائي بوابةٌ قائمة بذاتها،
  // ودسُّه مع حقلٍ مسموح لا يمرّره.
  test("لا يُدسّ الموعد النهائي مع حقول العقد", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {
      ...contractPatch,
      dueDate: new Date("2027-06-30"),
    }));
  });

  test("ولا نقلُ المشروع إلى إدارةٍ أخرى", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {
      ...contractPatch,
      departmentId: "d-other",
    }));
  });

  test("ولا تغييرُ مدير المشروع", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext(MANAGER, deptManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), {
      ...contractPatch,
      managerUids: ["u-other"],
    }));
  });

  // وغريبٌ عن الإدارة لا يكتبها ولو كانت الحقول مسموحةً في ذاتها.
  test("ولا يكتبها مديرُ إدارةٍ أخرى", async () => {
    await seedLegacyProject();
    const db = env
      .authenticatedContext("u-stranger", {
        ...deptManagerClaims,
        departmentId: "d-other",
        departmentIds: ["d-other"],
      })
      .firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), contractPatch));
  });
});
