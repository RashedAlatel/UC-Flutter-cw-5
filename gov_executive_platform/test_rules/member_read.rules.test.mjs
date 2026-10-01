// عضوُ المشروع يقرأ توابعه — ولو كانت إدارتُه غير إدارة المشروع.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// مستندُ المشروع يُقرأ بثلاثة تدفّقات: الإدارة، وعضويتي مديراً، وعضويتي
// منفّذاً. أما توابعه — التحديثات اليومية والمهام والمخاطر والعوائق —
// فكانت تُقرأ **بالإدارة وحدها**. فمن كان عضواً في مشروعٍ خارج إدارته، أو
// لم تُختم إدارتُه في بطاقة دخوله بعد، لا يصله تحديثٌ واحد على مشروعه.
//
// والقاعدة تعرف العضوية أصلاً (`isProjectMember`)، لكنها تقرؤها من
// **المستند نفسه**: `managerUids` كانت منسوخةً عليه، و`executorUids` **لم
// تكن تُنسخ قط**. فالمنفّذ كان ممنوعاً بالقاعدة لا بالاستعلام وحده.
//
// فما يُقاس هنا: أن الحقلين متى كانا على التابع، قرأه صاحبُهما — مديراً
// كان أو منفّذاً — من أي إدارة. وأن الغريب يبقى ممنوعاً.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc} from "firebase/firestore";

const PROJECT_DEPT = "d-justice";
const OTHER_DEPT = "d-elsewhere";
const MANAGER = "u-manager";
const EXECUTOR = "u-executor";
const STRANGER = "u-stranger";

let env;

/** بطاقةُ دخولٍ لموظفٍ في إدارةٍ **غير** إدارة المشروع. */
function claims({role = "employee", dept = OTHER_DEPT} = {}) {
  return {role, approved: true, departmentId: dept, departmentIds: [], perms: {}};
}

/** تحديثٌ يومي كما يكتبه العميل بعد هذه الجولة: القائمتان منسوختان. */
const update = (extra = {}) => ({
  projectId: "p1",
  departmentId: PROJECT_DEPT,
  authorUid: MANAGER,
  authorName: "المدير",
  date: new Date("2026-08-25"),
  achievements: "أُنجز كذا",
  completedTasks: [],
  newRisks: [],
  blockers: [],
  decisionsRequired: [],
  progressPercent: 40,
  notes: "",
  attachments: [],
  managerUid: MANAGER,
  managerUids: [MANAGER],
  executorUids: [EXECUTOR],
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-member-read",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "projects/p1"), {
      departmentId: PROJECT_DEPT,
      name: "مشروع",
      dueDate: new Date("2026-12-31"),
      createdByUid: "admin",
      managerUids: [MANAGER],
      executorUids: [EXECUTOR],
      managerUid: MANAGER,
    });
    await setDoc(doc(db, "dailyUpdates/u1"), update());
    // وتابعٌ قديم كُتب قبل نسخ القائمتين — لا يحمل إلا المفرد الموروث.
    // والحقلان يُحذفان حذفاً: `undefined` لا يقبله Firestore، والغياب هو
    // المقصود بالضبط لا قيمةٌ فارغة.
    const legacy = update();
    delete legacy.managerUids;
    delete legacy.executorUids;
    await setDoc(doc(db, "dailyUpdates/legacy"), legacy);
  });
});

after(async () => {
  await env?.cleanup();
});

describe("عضوُ المشروع من إدارةٍ أخرى", () => {
  test("المدير يقرأ التحديث اليومي", async () => {
    const db = env.authenticatedContext(MANAGER, claims()).firestore();
    await assertSucceeds(getDoc(doc(db, "dailyUpdates/u1")));
  });

  // العطل بعينه: `executorUids` لم تكن منسوخةً على التابع، فكان المنفّذ
  // ممنوعاً بالقاعدة نفسها لا بالاستعلام وحده.
  test("والمنفّذ كذلك — وهو ما كان ممنوعاً", async () => {
    const db = env.authenticatedContext(EXECUTOR, claims()).firestore();
    await assertSucceeds(getDoc(doc(db, "dailyUpdates/u1")));
  });

  // المستند القديم لا يحمل القائمتين، ويبقى المفرد الموروث يفتحه لأوّل
  // المديرين — وهذا ما يجعل ختم السجلات القديمة لازماً للمنفّذ.
  test("والمستند القديم يفتحه المفرد الموروث لمديره", async () => {
    const db = env.authenticatedContext(MANAGER, claims()).firestore();
    await assertSucceeds(getDoc(doc(db, "dailyUpdates/legacy")));
  });

  test("ولا يفتحه للمنفّذ — فيلزم ختمُ السجلات القديمة", async () => {
    const db = env.authenticatedContext(EXECUTOR, claims()).firestore();
    await assertFails(getDoc(doc(db, "dailyUpdates/legacy")));
  });
});

describe("والحدُّ لم يُمسّ", () => {
  test("من ليس عضواً ولا من الإدارة يُردّ", async () => {
    const db = env.authenticatedContext(STRANGER, claims()).firestore();
    await assertFails(getDoc(doc(db, "dailyUpdates/u1")));
  });

  test("ومن ليس عضواً لكنه من إدارة المشروع يقرأ — حقٌّ قائم", async () => {
    const db = env
      .authenticatedContext(STRANGER, claims({dept: PROJECT_DEPT}))
      .firestore();
    await assertSucceeds(getDoc(doc(db, "dailyUpdates/u1")));
  });
});
