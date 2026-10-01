// ما يتركه دمجُ الحساب على مستند المشروع — وأثره على صاحب الحساب الجديد.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// مستند المشروع يحمل حقلين للمدير: القائمة `managerUids`، وحقلاً **مفرداً
// موروثاً** `managerUid`. ودمجُ الحساب عند إعادة التسجيل كان يُحدّث القائمة
// وحدها ويترك المفرد على المعرّف القديم — وهو معرّفٌ لم يعد لصاحبه حساب.
//
// والقواعد تقرأ المفرد في موضعين حاسمين:
//
//   • `legacyManagerConsistent()` تشترط أن يكون المفرد عضواً في القائمة،
//     فتصير الثابتة منقوضة وتُردّ أيُّ كتابةٍ لاحقة على المشروع.
//   • `matchesRealProject()` تشترط أن يساوي المفردُ المنسوخ على التحديث
//     اليومي قيمةَ المشروع الحقيقية. والعميل ينسخ أوّلَ القائمة (الجديد)
//     والمشروع يحمل القديم — فتُرفض إضافة التحديث.
//
// فمن أُعيد تسجيله يرى مشروعه ولا يستطيع التحديث عليه. وهذا ما يُقاس هنا:
// **الحالُ الذي يتركه الدمج**، لا وصفُه.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-1";
const OLD = "u-old";
const NEW = "u-new";
const PROJECT = "p1";

let env;

function claims({role = "employee", dept = DEPT} = {}) {
  return {role, approved: true, departmentId: dept, departmentIds: [], perms: {}};
}

/// المشروع كما يتركه الدمج: القائمة صُحّحت، و[legacyManagerUid] هو ما يُقاس.
async function seedProject(legacyManagerUid) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `projects/${PROJECT}`), {
      departmentId: DEPT,
      name: "مشروع",
      description: "",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 0,
      createdByUid: "admin",
      managerUids: [NEW],
      executorUids: [],
      managerUid: legacyManagerUid,
    });
  });
}

/// التحديث اليومي كما يكتبه العميل: ينسخ `managerUids.first` — أي الجديد.
const updatePayload = () => ({
  projectId: PROJECT,
  departmentId: DEPT,
  authorUid: NEW,
  authorName: "المدير الجديد",
  date: new Date("2026-06-01"),
  achievements: "أنجزنا الربط",
  completedTasks: [],
  newRisks: [],
  blockers: [],
  decisionsRequired: [],
  progressPercent: 40,
  notes: "",
  attachments: [],
  managerUid: NEW,
  managerUids: [NEW],
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-account-merge",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

after(async () => {
  await env?.cleanup();
});

describe("دمجٌ ناقص: المفرد بقي على المعرّف القديم", () => {
  // هذا هو العطل بعينه. ولولا هذا الاختبار لَبقي وصفاً في رسالة.
  test("صاحب الحساب الجديد لا يستطيع إضافة تحديثٍ يومي على مشروعه", async () => {
    await seedProject(OLD);
    const db = env.authenticatedContext(NEW, claims()).firestore();
    await assertFails(setDoc(doc(db, "dailyUpdates/u1"), updatePayload()));
  });

  // والثابتة منقوضة كذلك: المفرد ليس عضواً في القائمة، فتُردّ الكتابة على
  // المشروع نفسه — ولو كانت تسجيلَ عضويةٍ ذاتية مشروعة.
  test("وأيُّ كتابةٍ على المشروع تُردّ لنقض الثابتة", async () => {
    await seedProject(OLD);
    const db = env.authenticatedContext(NEW, claims()).firestore();
    await assertFails(updateDoc(doc(db, `projects/${PROJECT}`), {
      executorUids: [NEW],
    }));
  });
});

describe("ودمجٌ تامّ: المفرد صُحّح مع القائمة", () => {
  test("فيضيف تحديثه اليومي كما يفعل أيُّ مدير", async () => {
    await seedProject(NEW);
    const db = env.authenticatedContext(NEW, claims()).firestore();
    await assertSucceeds(setDoc(doc(db, "dailyUpdates/u1"), updatePayload()));
  });

  // والحالُ الأصلي لم يُمسّ: من ليس عضواً لا يكتب، مهما صُحّح المفرد.
  test("ولا يكتب من ليس عضواً في المشروع", async () => {
    await seedProject(NEW);
    const db = env.authenticatedContext("u-stranger", claims({dept: "d-2"})).firestore();
    await assertFails(setDoc(doc(db, "dailyUpdates/u1"), updatePayload()));
  });
});
