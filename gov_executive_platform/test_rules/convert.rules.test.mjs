// التحويل والتعديل: ما يملكه مديرُ الإدارة بدوره، وما لا يكتبه عميلٌ قط.
//
// ــــ ثلاثة تُقاس هنا ــــ
//
// (١) **تعديلُ العمل حقُّ مدير الإدارة بدوره لا بعلَمٍ يُطفأ.** كان الطريق
//     الوحيد صلاحية «إدارة الأعمال» (`mw`)، وهي تُطفأ من شاشة صلاحيات
//     الأدوار — فكان مديرُ الإدارة يملك **حذف** العمل من إدارته ولا يملك
//     تصحيح سطرٍ فيه. وحقُّه داخل إداراته وحدها.
//
// (٢) **وحقول التحويل لا يكتبها عميل.** التحويل عمليةٌ ذرّية من خطوتين تقع
//     كلُّها على الخادم. ولو كتبها العميل لَادّعى سجلٌّ حيٌّ أنه محوَّلٌ عن
//     آخر لا وجود له، أو عُلِّم أصلٌ محذوف «محوَّلاً» فامتنعت استعادتُه.
//
// (٣) **والمحوَّل لا يُستعاد بضغطة.** له نسخةٌ حيّة تحمل بياناته، فاستعادتُه
//     تُنتج الشيء الواحد مرّتين. ويُفكّ ارتباطه أولاً في كتابةٍ مستقلّة
//     يبقى بعدها محذوفاً — خطوتان بقصد.
import {readFileSync} from "node:fs";
import {test, before, after, beforeEach, describe} from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {doc, setDoc, updateDoc} from "firebase/firestore";

const DEPT = "d-justice";
const OTHER = "d-elsewhere";
const HEAD = "u-head";
const ADMIN = "u-admin";
const EMPLOYEE = "u-emp";

let env;

function claims(uid, {role = "employee", dept = DEPT, depts = [], perms = {}} = {}) {
  return {role, approved: true, departmentId: dept, departmentIds: depts, perms};
}

/** مديرُ إدارةٍ **بلا** صلاحية «إدارة الأعمال» — وهي الحالة التي كُسرت. */
const headOf = (dept) => claims(HEAD, {role: "departmentManager", dept, depts: [dept]});
const adminClaims = {role: "systemAdmin", approved: true, departmentId: null, departmentIds: [], perms: {}};

const LIVE = {deletedAt: null, deletedBy: null, deletedReason: null};
const DELETED = {deletedAt: new Date("2026-08-01"), deletedBy: HEAD, deletedReason: "سببٌ ما"};
const NO_LINK = {
  convertedFromType: null,
  convertedFromId: null,
  convertedToType: null,
  convertedToId: null,
};
const CONVERTED = {
  convertedFromType: null,
  convertedFromId: null,
  convertedToType: "work",
  convertedToId: "w-new",
};

async function seed({mark = LIVE, link = NO_LINK, dept = DEPT} = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "works/w1"), {
      departmentId: dept,
      title: "جرد الأرشيف",
      description: "",
      assigneeUid: EMPLOYEE,
      assigneeName: "موظف",
      status: "inProgress",
      priority: "medium",
      progressPercent: 10,
      dueDate: new Date("2026-12-31"),
      createdByUid: ADMIN,
      createdAt: new Date("2026-01-01"),
      closure: {},
      ...mark,
      ...link,
    });
    await setDoc(doc(db, "projects/p1"), {
      departmentId: dept,
      name: "رقمنة الصحيفة",
      description: "",
      startDate: new Date("2026-01-01"),
      dueDate: new Date("2026-12-31"),
      status: "onTrack",
      priority: "medium",
      progressPercent: 20,
      executorNames: [],
      createdByUid: ADMIN,
      managerUids: [],
      executorUids: [],
      managerUid: null,
      sectionId: null,
      categoryIds: [],
      ...mark,
      ...link,
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "rules-test-convert",
    firestore: {rules: readFileSync("../firestore.rules", "utf8"), host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

describe("١) تعديل بيانات العمل — حقُّ الدور", () => {
  // العطل بعينه: مديرُ إدارةٍ بلا `mw` كان يُردّ هنا.
  test("مديرُ الإدارة يعدّل عملاً في إدارته ولو أُطفئت «إدارة الأعمال»", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "works/w1"), {title: "جرد الأرشيف ٢٠٢٤"}));
  });

  test("ولا يعدّل عمل إدارةٍ ليست له", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(OTHER)).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {title: "لا شأن له به"}));
  });

  test("والموظف العادي في الإدارة نفسها لا يعدّل بيانات عملٍ لغيره", async () => {
    await seed();
    const db = env.authenticatedContext("u-other", claims("u-other")).firestore();
    await assertFails(updateDoc(doc(db, "works/w1"), {title: "تعديلٌ بلا صفة"}));
  });

  test("ومديرُ الإدارة يعدّل بيانات مشروعٍ في إدارته", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertSucceeds(updateDoc(doc(db, "projects/p1"), {name: "رقمنة صحيفة الدعوى"}));
  });

  // البوابة التي لا تُفتح بحال: الموعد النهائي يمرّ بطلبٍ يعتمده مسؤول النظام.
  test("ولا يمسّ الموعد النهائي — ولو كان مشروع إدارته", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(
      updateDoc(doc(db, "projects/p1"), {dueDate: new Date("2027-06-30")}),
    );
  });
});

describe("٢) حقول التحويل لا يكتبها عميل", () => {
  test("ولا مديرُ الإدارة على عملٍ في إدارته", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {convertedFromType: "project", convertedFromId: "p1"}),
    );
  });

  test("ولا مسؤولُ النظام — الطريق دالّةُ التحويل وحدها", async () => {
    await seed();
    const db = env.authenticatedContext(ADMIN, adminClaims).firestore();
    await assertFails(
      updateDoc(doc(db, "projects/p1"), {convertedToType: "work", convertedToId: "w-new"}),
    );
  });

  test("ولا تُدسّ مع تعديلٍ مشروع", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {title: "اسمٌ جديد", convertedToId: "w-new"}),
    );
  });

  test("ولا يُعلَّم سجلٌّ «محوَّلاً» من باب الحذف المنطقي", async () => {
    await seed();
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {
        deletedAt: new Date("2026-08-20"),
        deletedBy: HEAD,
        deletedReason: "لم يعد مطلوباً",
        convertedToType: "work",
        convertedToId: "w-fake",
      }),
    );
  });
});

describe("٣) والمحوَّل لا يُستعاد بضغطة", () => {
  test("مسؤول النظام يستعيد المحذوف العادي", async () => {
    await seed({mark: DELETED});
    const db = env.authenticatedContext(ADMIN, adminClaims).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "works/w1"), {deletedAt: null, deletedBy: null, deletedReason: null}),
    );
  });

  test("ولا يستعيد أصلاً محوَّلاً ما دام الارتباط قائماً", async () => {
    await seed({mark: DELETED, link: CONVERTED});
    const db = env.authenticatedContext(ADMIN, adminClaims).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {deletedAt: null, deletedBy: null, deletedReason: null}),
    );
  });

  test("ويفكّ الارتباط في كتابةٍ مستقلّة يبقى بعدها محذوفاً", async () => {
    await seed({mark: DELETED, link: CONVERTED});
    const db = env.authenticatedContext(ADMIN, adminClaims).firestore();
    await assertSucceeds(
      updateDoc(doc(db, "works/w1"), {convertedToType: null, convertedToId: null}),
    );
  });

  // فكُّ الارتباط لا يكون سُلَّماً إلى استعادةٍ في الكتابة نفسها.
  test("ولا يُفكّ ويُستعاد في كتابةٍ واحدة", async () => {
    await seed({mark: DELETED, link: CONVERTED});
    const db = env.authenticatedContext(ADMIN, adminClaims).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {
        convertedToType: null,
        convertedToId: null,
        deletedAt: null,
        deletedBy: null,
        deletedReason: null,
      }),
    );
  });

  test("ولا يفكّ مديرُ الإدارة ارتباطاً ليستعيد به", async () => {
    await seed({mark: DELETED, link: CONVERTED});
    const db = env.authenticatedContext(HEAD, headOf(DEPT)).firestore();
    await assertFails(
      updateDoc(doc(db, "works/w1"), {convertedToType: null, convertedToId: null}),
    );
  });
});
