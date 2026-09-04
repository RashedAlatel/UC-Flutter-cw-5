// من يملك تعديلَ بيانات مستخدم — الدائرةُ وحدودُها.
//
// ــــ لماذا وحدةٌ نقيّة ــــ
//
// `index.ts` ملفٌّ لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه
// المنصة). وهذا **قرارُ حوكمة** لا تفصيلُ تنفيذ: خطأٌ فيه يجعل مديرَ إدارةٍ
// يعدّل موظّفي إدارةٍ ليست له، أو يجعل حقلاً لم يُقصد فتحُه يُكتب من حمولةٍ
// مدسوسة.
//
// وهو نمطُ `approval_stage.ts` و`claims_stamp.ts` القائم في هذا المجلّد.
//
// ــــ وثلاثةُ حدودٍ تُقاس هنا ــــ
//
// (١) **الإداراتُ من البطاقة لا من الحمولة.** لو قُرئت مما يرسله المتصل
//     لَكتب أيُّ مديرِ إدارةٍ ما شاء بإضافة سطرٍ في أدوات المتصفح.
//
// (٢) **والقائمةُ مغلقة** (`hasOnly` لا قائمةَ منع): هذه الدالّة تُطبَّق
//     بصلاحية المدير فتتجاوز كلَّ قاعدة. فحقلٌ غريبٌ يُدسّ يُكتب بلا مانع
//     لو لم تُغلق. ووقع ذلك في المنصة مرّتين من قبل.
//
// (٣) **والبواباتُ لا تُفتح من هنا**: الدورُ والحالةُ والصلاحياتُ والإدارة
//     ليست من هذا الطريق. وتسجيلُ الأعضاء يبقى لمسؤول النظام وحده.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {
  mayEditUserProfile,
  profilePatch,
  PROFILE_FIELDS,
} from "../lib/user_scope.js";

const DEPT = "d-justice";
const OTHER = "d-other";

const admin = {isAdmin: true, role: "systemAdmin", departmentIds: []};
const head = {isAdmin: false, role: "departmentManager", departmentIds: [DEPT]};
const otherHead = {isAdmin: false, role: "departmentManager", departmentIds: [OTHER]};
const employee = {isAdmin: false, role: "employee", departmentIds: [DEPT]};
const executive = {isAdmin: false, role: "executiveViewer", departmentIds: []};

describe("من يعدّل بيانات مستخدم", () => {
  test("مسؤولُ النظام لأي مستخدم", () => {
    assert.equal(mayEditUserProfile(admin, {departmentId: OTHER}), true);
  });

  test("ومديرُ الإدارة لموظّف إدارته", () => {
    assert.equal(mayEditUserProfile(head, {departmentId: DEPT}), true);
  });

  test("ولا لموظّف إدارةٍ أخرى", () => {
    assert.equal(mayEditUserProfile(otherHead, {departmentId: DEPT}), false);
  });

  // ــ وهو يدير أكثر من إدارة أحياناً ــ
  test("ومديرُ إدارتين لموظّفي كلتيهما", () => {
    const two = {isAdmin: false, role: "departmentManager", departmentIds: [DEPT, OTHER]};
    assert.equal(mayEditUserProfile(two, {departmentId: OTHER}), true);
  });

  test("ولا الموظفُ ولو كان في الإدارة", () => {
    assert.equal(mayEditUserProfile(employee, {departmentId: DEPT}), false);
  });

  // التنفيذي يطّلع على كل شيء ولا يغيّر شيئاً — قاعدةٌ قائمة في المنصة.
  test("ولا المستخدمُ التنفيذي", () => {
    assert.equal(mayEditUserProfile(executive, {departmentId: DEPT}), false);
  });

  // ــ ومستخدمٌ بلا إدارة لمسؤول النظام وحده ــ
  //
  // ولو فُتح لمدير إدارةٍ لَادّعى كلُّ مديرٍ من لا إدارة له.
  test("ومن لا إدارةَ له لا يعدّله إلا مسؤولُ النظام", () => {
    assert.equal(mayEditUserProfile(head, {departmentId: null}), false);
    assert.equal(mayEditUserProfile(admin, {departmentId: null}), true);
  });

  test("وإدارةٌ فارغةٌ نصّاً كذلك", () => {
    assert.equal(mayEditUserProfile(head, {departmentId: ""}), false);
  });

  // ــ وبطاقةٌ فيها إدارةٌ فارغة لا تفتح من لا إدارةَ له ــ
  //
  // وهذه هي الحالةُ التي يقيسها حارسُ `dept === ""` وحدَه: بدونه يلتقي
  // الفراغُ بالفراغ في `includes` فيمرّ، فيصير كلُّ من لا إدارةَ له —
  // وهم أكثرُ من يحتاج تصحيحَ بياناته — تحت يدِ مديرٍ بمدخلٍ شاردٍ في
  // بطاقته. نجت هذه الطفرةُ في أوّل جولةٍ لأنّ `includes` كانت تحرسها.
  test("ومديرٌ في بطاقته إدارةٌ فارغة لا يعدّل من لا إدارةَ له", () => {
    const stray = {isAdmin: false, role: "departmentManager", departmentIds: [""]};
    assert.equal(mayEditUserProfile(stray, {departmentId: ""}), false);
    assert.equal(mayEditUserProfile(stray, {departmentId: null}), false);
  });

  // ــ والإداراتُ من البطاقة لا من الحمولة ــ
  //
  // وهذا هو أخطرُ ما في الملفّ: لو قُرئت مما يرسله المتصل لَكتب أيُّ مدير
  // إدارةٍ ما شاء بإضافة سطرٍ في أدوات المتصفح.
  test("وقائمةُ إداراتٍ غائبةٌ عن البطاقة تُقرأ فارغة لا مفتوحة", () => {
    const noClaims = {isAdmin: false, role: "departmentManager"};
    assert.equal(mayEditUserProfile(noClaims, {departmentId: DEPT}), false);
  });
});

describe("وما يُكتب — قائمةٌ مغلقة", () => {
  test("الاسمُ والقسمُ لا غير", () => {
    assert.deepEqual([...PROFILE_FIELDS].sort(), ["name", "sectionId"]);
  });

  test("والاسمُ يُشذَّب", () => {
    assert.deepEqual(profilePatch({name: "  عبدالله  "}), {name: "عبدالله"});
  });

  test("والقسمُ يُكتب، و`null` تعني «تحت الإدارة مباشرةً»", () => {
    assert.deepEqual(profilePatch({sectionId: "s-1"}), {sectionId: "s-1"});
    assert.deepEqual(profilePatch({sectionId: null}), {sectionId: null});
  });

  // ــ ونصٌّ فارغ هو `null` نفسُها ــ
  //
  // والقائمةُ في الواجهة تُرسل `""` حين يُختار «تحت الإدارة مباشرةً»،
  // فلو كُتب النصُّ كما هو لصار للموظّف قسمٌ باسمٍ فارغ لا يطابق قسماً
  // قائماً — فيختفي من كلِّ تصفيةٍ بالقسم بلا رسالة. لم أكن كتبتُ لهذا
  // اختباراً، فنجت طفرتُه.
  test("ونصُّ قسمٍ فارغ يصير `null` لا نصّاً فارغاً", () => {
    assert.deepEqual(profilePatch({sectionId: ""}), {sectionId: null});
    assert.deepEqual(profilePatch({sectionId: "   "}), {sectionId: null});
  });

  test("والقسمُ يُشذَّب", () => {
    assert.deepEqual(profilePatch({sectionId: "  s-1  "}), {sectionId: "s-1"});
  });

  // ــ وهذا هو الحدُّ الذي يمنع فتح البوابات من هنا ــ
  test("ولا يمرّ دورٌ ولا حالةٌ ولا إدارةٌ ولو دُسَّت", () => {
    const patch = profilePatch({
      name: "اسم",
      role: "systemAdmin",
      status: "approved",
      departmentId: OTHER,
      departmentIds: [OTHER],
      permissionOverrides: {vad: true},
      scopedGrants: {mpr: {}},
    });
    assert.deepEqual(patch, {name: "اسم"});
  });

  test("وحمولةٌ فارغةٌ لا تُنتج كتابة", () => {
    assert.deepEqual(profilePatch({}), {});
  });

  // اسمٌ فارغ ليس تصحيحاً بل محو: يُردّ ولا يُكتب.
  test("واسمٌ فارغ لا يُكتب", () => {
    assert.deepEqual(profilePatch({name: "   "}), {});
  });
});
