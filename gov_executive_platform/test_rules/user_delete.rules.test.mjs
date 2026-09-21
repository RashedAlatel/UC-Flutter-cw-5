// حذف سجل المستخدم من العميل — **مرفوض، ولو كان الضاغط مسؤول النظام**.
//
// وهذا ليس تشدّداً: حذف السجل من قاعدة البيانات **لا يحذف حساب المصادقة**.
// فمن حُذف من `/users` يبقى قادراً على تسجيل الدخول، فيُنشئ سجلّاً جديداً
// «بانتظار الموافقة» ثم يعود. وكانت القاعدة `allow delete: if isAdmin()`،
// أي أن ذلك يقع فعلاً بضغطةٍ من الشاشة.
//
// فالحذف يمرّ بـ`deleteUserAccount` وحدها: تحذف الاثنين معاً وتكتب أثره.
//
// والتعطيل يبقى كما هو: تعديل الحالة `update` لمسؤول النظام، وهو الطريق
// الذي يمرّ به `setUserStatus`.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, deleteDoc, updateDoc} from "firebase/firestore";

const TARGET = "u-target";

let env;

function claims({role = "systemAdmin", approved = true} = {}) {
  return {role, approved, departmentId: "d-1", departmentIds: ["d-1"], perms: {}};
}

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${TARGET}`), {
      name: "الموظف", email: "e@moj.gov.kw", phone: "",
      role: "employee", status: "approved", createdAt: new Date(),
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-user-delete",
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

describe("سجل المستخدم لا يُحذف من العميل", () => {
  test("ولا مسؤول النظام يحذفه — حساب الدخول يبقى حيّاً", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertFails(deleteDoc(doc(db, `users/${TARGET}`)));
  });

  test("ولا صاحبه يحذف سجل نفسه", async () => {
    await seed();
    const db = env.authenticatedContext(TARGET, claims({role: "employee"})).firestore();
    await assertFails(deleteDoc(doc(db, `users/${TARGET}`)));
  });

  test("ولا مدير الإدارة", async () => {
    await seed();
    const db = env.authenticatedContext("u-head", claims({role: "departmentManager"})).firestore();
    await assertFails(deleteDoc(doc(db, `users/${TARGET}`)));
  });
});

// ولولا هذا لَأمكن أن يُقفل الباب على التعطيل نفسه وهو يمرّ من هنا: كلاهما
// كتابةٌ على `/users`، وتضييقُ أحدهما بلا اختبارٍ للآخر يُسقط الميزة القائمة.
describe("والتعطيل يبقى كما هو", () => {
  test("مسؤول النظام يوقف الحساب", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, `users/${TARGET}`), {status: "suspended"}));
  });

  test("ويعيد تفعيله", async () => {
    await seed();
    const db = env.authenticatedContext("u-admin", claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, `users/${TARGET}`), {status: "approved"}));
  });

  test("ولا يوقفه غيره", async () => {
    await seed();
    const db = env.authenticatedContext("u-head", claims({role: "departmentManager"})).firestore();
    await assertFails(updateDoc(doc(db, `users/${TARGET}`), {status: "suspended"}));
  });
});
