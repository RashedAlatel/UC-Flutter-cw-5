// أثرٌ خفيف يكتبه `deleteUserAccount` قبل محو `users/{uid}` — اسمٌ وبريدٌ
// وتاريخ حذف، لا شيء غير ذلك — ليقرأه الخادم وحده حين يُسجَّل الشخص نفسه
// من جديد بالبريد نفسه، فتُنقل أعماله القديمة إلى حسابه الجديد.
//
// ولا وظيفة له خارج ذلك، ولا يقرؤه عميلٌ قط: الدالّة الخلفية وحدها تكتبه
// وتقرؤه بحساب المدير (Admin SDK يتجاوز القواعد أصلاً)، فلا حاجة لفتح شيء
// هنا لأي طرف — **مسؤول النظام نفسه لا يقرؤه من العميل**، وهذا ما يُقاس.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, getDoc, updateDoc, deleteDoc} from "firebase/firestore";

const TARGET = "u-was-deleted";

let env;

function claims({role = "systemAdmin"} = {}) {
  return {role, approved: true, departmentId: null, departmentIds: [], perms: {}};
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-deleted-accounts",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

after(async () => {
  await env?.cleanup();
});

describe("deletedAccounts مقفلة تماماً أمام العميل", () => {
  test("لا يقرؤها مسؤول النظام", async () => {
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertFails(getDoc(doc(db, `deletedAccounts/${TARGET}`)));
  });

  test("ولا يكتبها", async () => {
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertFails(setDoc(doc(db, `deletedAccounts/${TARGET}`), {
      name: "موظف", email: "e@moj.gov.kw", deletedAt: new Date(), deletedBy: "u-admin",
    }));
  });

  test("ولا يعدّلها — حتى مستنداً وُضع خارج القواعد", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `deletedAccounts/${TARGET}`), {
        name: "موظف", email: "e@moj.gov.kw", deletedAt: new Date(), deletedBy: "u-admin",
      });
    });
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertFails(updateDoc(doc(db, `deletedAccounts/${TARGET}`), {migratedTo: "u-new"}));
  });

  test("ولا يحذفها", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `deletedAccounts/${TARGET}`), {
        name: "موظف", email: "e@moj.gov.kw", deletedAt: new Date(), deletedBy: "u-admin",
      });
    });
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertFails(deleteDoc(doc(db, `deletedAccounts/${TARGET}`)));
  });

  // ولا موظفٌ عادي بالطبع — إعادةٌ للتأكيد على مسؤول النظام أولاً لا فرقاً
  // بينهما: القاعدة `if false` لا تفرّق بين الأدوار أصلاً.
  test("ولا موظفٌ عادي", async () => {
    const db = env.authenticatedContext("u-emp", claims({role: "employee"})).firestore();
    await assertFails(getDoc(doc(db, `deletedAccounts/${TARGET}`)));
  });
});
