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
// ــــ ومن يكتبها تبدّل بعد ذلك ــــ
//
// كان الكاتبُ هنا **مديرَ الإدارة**، ثم صارت حقولُ العقد تمرّ بمسار الاعتماد
// بقرارٍ صريح — فما عاد يكتبها مباشرةً (راجع `project_edit.rules.test.mjs`).
// فصار الكاتبُ **مسؤولَ النظام**: هو من يبقى يكتب مباشرةً، وهو من يُطبَّق
// باسمه اعتمادُ الطلب. والسؤالُ المقيس واحدٌ لم يتغيّر: هل يقبل مستندٌ وُلد
// ناقصاً مفاتيحَ تُضاف إليه لأوّل مرّة؟
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

// مسؤولُ النظام: هو الكاتبُ المباشر الوحيد لحقول العقد بعد التضييق.
const adminClaims = {role: "systemAdmin", approved: true, perms: {}};

// ومديرُ إدارةٍ أخرى — لقياس أن الغريب يُردّ حتى لو كان مديراً.
const strangerManagerClaims = {
  role: "departmentManager",
  approved: true,
  departmentId: "d-other",
  departmentIds: ["d-other"],
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
  test("مسؤولُ النظام يكتب حقول العقد السبعة على مشروعٍ قديم", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext("u-admin", adminClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), contractPatch));
  });

  test("ويكتب بعضَها ويترك بعضاً", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext("u-admin", adminClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      contractValue: 9000,
      contractorName: "مؤسسة التوريد",
    }));
  });

  // والفارغُ يُكتب `null` لا يُحذف: «غير مسجّل» قيمةٌ لا غياب.
  test("ويكتبها فارغةً بلا رفض", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext("u-admin", adminClaims).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {
      contractDate: null,
      contractValue: null,
      contractorName: "",
    }));
  });
});

describe("ومن دون مسؤول النظام تمرّ بالاعتماد", () => {
  // ــــ لماذا لم يبقَ هنا اختبارُ «لا يُدسّ الموعد النهائي» ــــ
  //
  // كان يُكتب بمدير الإدارة، فيقيس أن حقول العقد لم تفتح باباً للموعد. ثم
  // صارت حقولُ العقد نفسُها ممنوعةً عليه، فما عاد للسؤال محلّ هنا — ومسؤولُ
  // النظام يكتب الموعدَ بحقّه، فقياسُ منعِه عليه يقيس عدماً.
  //
  // وانتقل السؤالُ كاملاً إلى `project_edit.rules.test.mjs`: هناك تُقاس
  // البواباتُ الثلاث (الموعد · الإدارة · المدير) بمدير الإدارة، وهو صاحبُها.
  // ولا يُترك اختبارٌ يمرّ بلا أن يقيس شيئاً.
  test("مديرُ الإدارة لا يكتب حقول العقد مباشرةً", async () => {
    await seedLegacyProject();
    const db = env
      .authenticatedContext(MANAGER, {
        role: "departmentManager",
        approved: true,
        departmentId: DEPT,
        departmentIds: [DEPT],
        perms: {},
      })
      .firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), contractPatch));
  });

  // وغريبٌ عن الإدارة يُردّ كذلك — من بابين لا باب.
  test("ولا مديرُ إدارةٍ أخرى", async () => {
    await seedLegacyProject();
    const db = env.authenticatedContext("u-stranger", strangerManagerClaims).firestore();
    await assertFails(updateDoc(doc(db, "projects/p1"), contractPatch));
  });
});
