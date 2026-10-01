// قاعدة قراءة التقرير التنفيذي اليومي.
//
// التقرير مستندٌ **لكل مستلم**، وهذا هو ما يجعل فرض النطاق ممكناً أصلاً:
// قواعد Firestore ترفض ولا تُصفّي، فمستندٌ جامع يعني إمّا تسرّباً وإمّا
// شاشةً خالية. وهذه الاختبارات تُثبت الطرفين معاً: أن صاحب المستند يقرؤه،
// وأن غيره لا يقرؤه — ولو كان مدير إدارةٍ أو مسؤولاً تنفيذياً.
//
// وتُثبت كذلك أن **لا أحد يكتبه من العميل**: التقرير يُحسب على الخادم،
// فلو أمكن للمستلم أن يكتبه لَأمكنه أن يمحو منه ما لا يعجبه.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, deleteDoc, updateDoc} from "firebase/firestore";

const DAY = "2026-08-22";
const ME = "u-me";
const OTHER = "u-other";

let env;

function claims({role = "departmentManager", approved = true} = {}) {
  return {role, approved, departmentId: "d-1", departmentIds: ["d-1"], perms: {}};
}

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `dailyReports/${DAY}`), {generatedAt: "x", recipientCount: 2});
    for (const uid of [ME, OTHER]) {
      await setDoc(doc(db, `dailyReports/${DAY}/recipients/${uid}`), {
        recipientUid: uid, headline: `تقرير ${uid}`, sections: [],
      });
    }
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-daily-report",
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

describe("لكل مستلمٍ تقريره", () => {
  test("صاحب المستند يقرؤه", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(getDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`)));
  });

  test("ولا يقرأ تقرير غيره", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(getDoc(doc(db, `dailyReports/${DAY}/recipients/${OTHER}`)));
  });

  // المسؤول التنفيذي يرى كل الإدارات في المنصة، ولا يرى **تقرير غيره**:
  // التقرير مخاطبةٌ شخصية لا بيانَ حالة، وتقريرُ مدير الإدارة يحمل ترتيب
  // أولوياته هو.
  test("والمسؤول التنفيذي لا يقرأ تقرير غيره", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims({role: "executiveViewer"})).firestore();
    await assertFails(getDoc(doc(db, `dailyReports/${DAY}/recipients/${OTHER}`)));
  });

  test("ومسؤول النظام يقرأ الجميع — هو من يتحقّق من التوليد", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", claims({role: "systemAdmin"})).firestore();
    await assertSucceeds(getDoc(doc(db, `dailyReports/${DAY}/recipients/${OTHER}`)));
  });

  test("وغير المعتمَد لا يقرأ شيئاً", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims({approved: false})).firestore();
    await assertFails(getDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`)));
  });
});

describe("ولا يُكتب من العميل", () => {
  test("المستلم لا يكتب تقريره", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(setDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`), {headline: "لا شيء"}));
  });

  test("ولا يعدّله", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(
      updateDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`), {headline: "كل شيء ممتاز"}),
    );
  });

  test("ولا يحذفه", async () => {
    await seed();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(deleteDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`)));
  });

  // ولا مسؤول النظام: الحساب يجري على الخادم، وكتابةٌ من العميل تعني تقريراً
  // لا يقابله حسابٌ — وهو أسوأ من غياب التقرير، لأنه يُقرأ وكأنه محسوب.
  test("ولا مسؤول النظام نفسه", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", claims({role: "systemAdmin"})).firestore();
    await assertFails(setDoc(doc(db, `dailyReports/${DAY}/recipients/${ME}`), {headline: "أ"}));
    await assertFails(setDoc(doc(db, `dailyReports/${DAY}`), {recipientCount: 0}));
  });
});

// ــــ مستند الإعدادات لا يُقرأ من زائرٍ بلا حساب ــــ
//
// قاعدة `settings/{id}` قراءتها **عامة** عمداً: ألوان الهوية تُقرأ على شاشة
// الدخول قبل الدخول. ولولا استثناءٌ صريح لَصار `settings/dailyReport` —
// وفيه قائمة معرّفات من يصله بريد التقرير — مقروءاً لأي أحد على الإنترنت.
describe("إعدادات التقرير ليست من المقروء عاماً", () => {
  async function seedSettings() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "settings/theme"), {primary: "#0E4D3C"});
      await setDoc(doc(db, "settings/dailyReport"), {
        enabled: true, emailRecipientUids: [ME],
      });
    });
  }

  test("زائرٌ بلا تسجيل دخول يقرأ الألوان", async () => {
    await seedSettings();
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "settings/theme")));
  });

  test("ولا يقرأ إعدادات التقرير", async () => {
    await seedSettings();
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "settings/dailyReport")));
  });

  test("ولا يقرؤها موظفٌ معتمَد", async () => {
    await seedSettings();
    const db = env.authenticatedContext(ME, claims({role: "employee"})).firestore();
    await assertFails(getDoc(doc(db, "settings/dailyReport")));
  });

  test("ومسؤول النظام يقرؤها ويكتبها", async () => {
    await seedSettings();
    const db = env.authenticatedContext("u-admin", claims({role: "systemAdmin"})).firestore();
    await assertSucceeds(getDoc(doc(db, "settings/dailyReport")));
    await assertSucceeds(setDoc(doc(db, "settings/dailyReport"), {emailRecipientUids: []}));
  });
});
