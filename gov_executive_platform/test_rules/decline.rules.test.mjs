// ردُّ المُسنَد إليه البندَ لعدم الاختصاص.
//
// ــــ ما الذي يُحرَس هنا بالضبط؟ ــــ
//
// القاعدة العامة تمنع المُسنَد إليه أن يمسّ الإسناد إطلاقاً — وإلا حوّل
// عملَه إلى زميله بضغطة. والردّ لعدم الاختصاص استثناءٌ منها، فيجب أن يبقى
// **ضيّقاً**: تفريغُ الحقل لا ملؤه بغيره، وباسم صاحبه مختوماً في السجل.
//
// ولولا الاختباران الأخيران لَكان الاستثناء باباً أوسع ممّا قُصد: من يستطيع
// تفريغ إسناده يستطيع إسناده لغيره، ومن يستطيع ختم اسم غيره يستطيع تفريغ
// إسناد زميلٍ لا يخصّه.
import {readFileSync} from "node:fs";
import {test, before, after, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-1";
const ME = "u-me";
const COLLEAGUE = "u-colleague";

let env;

function claims({role = "employee", dept = DEPT} = {}) {
  return {role, approved: true, departmentId: dept, departmentIds: [], perms: {}};
}

async function seedWork(over = {}) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // سجلّ الزميل يُبذَر عمداً.
    //
    // فحصُ الرتبة `mayAssign()` يقرأ سجلّ من يُسنَد إليه، وسجلٌّ غائبٌ
    // يُسقط القراءة فيُردّ الطلب. فلو تُرك غائباً لَمرّ اختبار «لا يُحوّله
    // إلى زميله» بسبب البذرة لا بسبب القاعدة — وقد قِيس ذلك: طفرةٌ تُسقط
    // شرط التفريغ من `isSelfDecline()` كانت تمرّ عليه.
    await setDoc(doc(db, "users/" + COLLEAGUE), {
      name: "زميل", role: "employee", status: "approved", departmentId: DEPT,
    });
    await setDoc(doc(db, "works/w1"), {
      title: "عمل", departmentId: DEPT,
      assigneeUid: ME, assigneeName: "أنا",
      status: "todo", progressPercent: 0,
      dueDate: new Date("2026-12-31"), createdByUid: "u-req",
      createdAt: new Date("2026-08-01"), closure: {},
      ...over,
    });
  });
}

/** الكتابة التي يُنتجها زرّ «عدم اختصاص». */
const declinePayload = (by) => ({
  assigneeUid: "",
  assigneeName: "",
  status: "todo",
  closure: {declinedByUid: by, declinedByName: "أنا", declinedReason: "ليس من اختصاصي"},
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-decline",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

after(async () => {
  await env?.cleanup();
});

describe("الأعمال: ردُّ المُسنَد إليه لعدم الاختصاص", () => {
  test("المُسنَد إليه يرفع اسمه عن العمل — يُقبل", async () => {
    await seedWork();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), declinePayload(ME)));
  });

  // الاستثناء **تفريغٌ لا تحويل**: لولا هذا لَصار كل موظفٍ يُحوّل عمله لزميله.
  test("ولا يُحوّله إلى زميله", async () => {
    await seedWork();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {
      assigneeUid: COLLEAGUE, assigneeName: "زميل",
      closure: {declinedByUid: ME, declinedByName: "أنا", declinedReason: "خذها"},
    }));
  });

  // وباسمه هو: لولاه لَأمكن لأي مُسنَدٍ إليه أن يفرّغ إسناداً ليس إسناده.
  test("ولا يُفرّغ الإسناد باسم غيره", async () => {
    await seedWork();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), declinePayload(COLLEAGUE)));
  });

  test("ومن ليس مُسنَداً إليه لا يردّه", async () => {
    await seedWork();
    const db = env.authenticatedContext(COLLEAGUE, claims()).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), declinePayload(COLLEAGUE)));
  });

  // ولا يُفتح بابٌ آخر تحت غطاء الردّ.
  test("ولا يُمرَّر تحته نقلُ العمل لإدارة أخرى", async () => {
    await seedWork();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {
      ...declinePayload(ME), departmentId: "d-2",
    }));
  });

  // والحالة الأصلية لم تُمسّ: تحديثُ التقدّم يبقى يعمل كما كان.
  test("وتحديث التقدّم يبقى مقبولاً كما كان", async () => {
    await seedWork();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), {
      status: "inProgress", progressPercent: 40,
    }));
  });
});

describe("مهام المشاريع: النظير نفسه", () => {
  async function seedTask() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "projects/p1"), {
        departmentId: DEPT, name: "مشروع", managerUids: [], managerUid: null,
        executorUids: [], dueDate: new Date("2026-12-31"), createdByUid: "admin",
      });
      await setDoc(doc(db, "tasks/t1"), {
        projectId: "p1", departmentId: DEPT, title: "مهمة",
        assigneeUid: ME, assigneeName: "أنا", status: "todo", progressPercent: 0,
        lastUpdated: new Date("2026-08-01"), dueDate: new Date("2026-12-31"),
        priority: "medium", createdByUid: "u-req", closure: {},
      });
    });
  }

  test("المُسنَد إليه يردّها — يُقبل", async () => {
    await seedTask();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, "tasks/t1"), {
      ...declinePayload(ME), lastUpdated: new Date(),
    }));
  });

  test("ولا يُحوّلها إلى زميله", async () => {
    await seedTask();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertFails(updateDoc(doc(db, "tasks/t1"), {
      assigneeUid: COLLEAGUE, assigneeName: "زميل", lastUpdated: new Date(),
      closure: {declinedByUid: ME, declinedByName: "أنا", declinedReason: "خذها"},
    }));
  });

  test("وتحديث التقدّم يبقى مقبولاً كما كان", async () => {
    await seedTask();
    const db = env.authenticatedContext(ME, claims()).firestore();
    await assertSucceeds(updateDoc(doc(db, "tasks/t1"), {
      status: "inProgress", progressPercent: 30, lastUpdated: new Date(),
    }));
  });
});
