// من يكتب في سجل التدقيق، وبأي اسم، وبأي وقت.
//
// ــــ الثغرة التي أوجدت هذا الملف ــــ
//
// كانت القاعدة `allow create: if isApproved()` بلا أيّ تحقّق. فأيُّ موظفٍ
// معتمد يستطيع أن يكتب سطراً **باسم مسؤول النظام**، **وبأي تاريخ
// يختاره** — فيُنسب إلى غيره فعلٌ لم يفعله، أو يُقدَّم فعلُه إلى ما قبل
// وقته. وسجلٌّ يُكتب فيه ما شاء من شاء ليس سجل تدقيق.
//
// وحدُّ ما تُغلقه هذه القاعدة يُقال صراحةً: الفاعلُ والوقت يصيران غير
// قابلين للتزوير. أما نصُّ «قبل/بعد» فيبقى ممّا يكتبه العميل — لأن
// التسجيل يقع في المتصفّح — وما تكتبه الدوالُّ الخلفية موثوقٌ كاملاً لأنها
// تتجاوز القواعد بصلاحية المدير.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

const EMP = "u-emp";

let env;

function claims({role = "employee"} = {}) {
  return {role, approved: true, departmentId: "d-1", departmentIds: [], perms: {}};
}

/// سطرٌ سليم كما يكتبه المتجر.
const entry = (extra = {}) => ({
  userName: "موظف",
  action: "تعديل عمل",
  details: "عدّل بيانات العمل",
  timestamp: serverTimestamp(),
  type: "update",
  actorUid: EMP,
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-audit-log",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("الكتابة في سجل التدقيق", () => {
  test("سطرٌ سليم باسم كاتبه ووقت الخادم — يُقبل", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    await assertSucceeds(addDoc(collection(db, "auditLog"), entry()));
  });

  // الثغرة بعينها.
  test("ولا يُكتب سطرٌ باسم غيره", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    await assertFails(
      addDoc(collection(db, "auditLog"), entry({actorUid: "u-admin", userName: "مسؤول النظام"})),
    );
  });

  test("ولا سطرٌ بلا فاعلٍ إطلاقاً", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    const e = entry();
    delete e.actorUid;
    await assertFails(addDoc(collection(db, "auditLog"), e));
  });

  // وقتُ جهاز الكاتب لا يُوثق به: من قدّم ساعة جهازه سنةً كتب سطراً يسبق
  // كل ما في السجل، فيُقرأ كأنه أقدم من الفعل الذي يشهد عليه.
  test("ولا سطرٌ بوقتٍ من عند الكاتب", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    await assertFails(
      addDoc(collection(db, "auditLog"), entry({timestamp: new Date("2020-01-01")})),
    );
  });

  // ــــ والعطلُ الذي كلّف المنصّة سجلَّها ــــ
  //
  // الاختبار أعلاه يكتب تاريخ ٢٠٢٠، فيُقرأ وكأن المردود هو **التزوير**
  // وحده. وليس كذلك: الشرط `timestamp == request.time` يردّ ساعةَ الجهاز
  // **ولو كانت صحيحة إلى الميلي‑ثانية** — إذ لا تُطابق وقتَ الخادم أبداً.
  //
  // وهذا بعينه ما كان التطبيق يكتبه (`Timestamp.fromDate(DateTime.now())`)،
  // فرُدّ كلُّ سطرٍ يكتبه المتصفّح منذ نشر القاعدة. ولم يمسكه هذا الملف لأن
  // كل حالاته تبني بيانَها بـ`serverTimestamp()` — فأثبتت أن **القاعدة**
  // صحيحة، ولم تسأل قط: هل يكتب التطبيقُ ما تشترطه؟
  test("ولا بساعةِ جهازه وهي مضبوطة — وهذا هو العطل الذي وقع", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    await assertFails(addDoc(collection(db, "auditLog"), entry({timestamp: new Date()})));
  });

  test("ولا سطرٌ بلا نوعٍ يُصفّى به", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    const e = entry();
    delete e.type;
    await assertFails(addDoc(collection(db, "auditLog"), e));
  });

  test("ولا سطرٌ ناقصُ الحقول الأساسية", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    const e = entry();
    delete e.action;
    await assertFails(addDoc(collection(db, "auditLog"), e));
  });

  test("ولا يكتب فيه من لم يُعتمد بعد", async () => {
    const db = env
      .authenticatedContext("u-pending", {role: "employee", approved: false})
      .firestore();
    await assertFails(addDoc(collection(db, "auditLog"), entry({actorUid: "u-pending"})));
  });
});

describe("والسجل لا يُنقَّح ولا يُقرأ إلا لمسؤول النظام", () => {
  const ID = "seeded";

  test("لا يُعدَّل — ولا لمسؤول النظام", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `auditLog/${ID}`), {
        userName: "موظف", action: "فعل", details: "تفصيل",
        timestamp: new Date("2026-08-01"), type: "update", actorUid: EMP,
      });
    });
    const db = env
      .authenticatedContext("u-admin", claims({role: "systemAdmin"}))
      .firestore();
    await assertFails(updateDoc(doc(db, `auditLog/${ID}`), {details: "تفصيلٌ آخر"}));
  });

  // سجلٌّ يُمحى منه ما لا يُعجب ليس شاهداً على شيء.
  test("ولا يُحذف — ولا لمسؤول النظام", async () => {
    const db = env
      .authenticatedContext("u-admin", claims({role: "systemAdmin"}))
      .firestore();
    await assertFails(deleteDoc(doc(db, `auditLog/${ID}`)));
  });

  test("ويقرؤه مسؤول النظام", async () => {
    const db = env
      .authenticatedContext("u-admin", claims({role: "systemAdmin"}))
      .firestore();
    await assertSucceeds(getDoc(doc(db, `auditLog/${ID}`)));
  });

  test("ولا يقرؤه موظف — ولو كان هو كاتبَه", async () => {
    const db = env.authenticatedContext(EMP, claims()).firestore();
    await assertFails(getDoc(doc(db, `auditLog/${ID}`)));
  });
});
