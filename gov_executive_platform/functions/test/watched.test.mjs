// قائمةُ المراقَبين — تنقيحُها، وحدُّها، **وقياسُ أنّ الحدَّ يَسَع**.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {sanitizeWatched, overLimitMessage, MAX_WATCHED} from "../lib/watched.js";

const OWNER = "u-monitor";

describe("التنقيح", () => {
  test("المكرَّرُ يُطرح — وإلا أكل من الحدّ بلا أن يراقب أحداً", () => {
    const r = sanitizeWatched(["u-1", "u-1", "u-2", "u-1"], OWNER);
    assert.deepEqual(r.uids, ["u-1", "u-2"]);
  });

  // والفراغُ أخطرُ من التكرار: `'' in w` يصدق على كلّ مستندٍ بلا حقل `uid`،
  // فيفتح ما لم يُفتح.
  test("والفارغُ والمسافاتُ تُطرح", () => {
    const r = sanitizeWatched(["u-1", "", "   ", "u-2"], OWNER);
    assert.deepEqual(r.uids, ["u-1", "u-2"]);
  });

  test("وما ليس نصّاً يُطرح ولا يُسقط الطلب", () => {
    const r = sanitizeWatched(["u-1", 7, null, {uid: "u-9"}, "u-2"], OWNER);
    assert.deepEqual(r.uids, ["u-1", "u-2"]);
  });

  test("وصاحبُ القائمة يُطرح منها ويُخبَر، ولا يُردّ الطلب", () => {
    const r = sanitizeWatched(["u-1", OWNER, "u-2"], OWNER);
    assert.deepEqual(r.uids, ["u-1", "u-2"]);
    assert.equal(r.droppedSelf, true);
    assert.equal(r.overLimit, false);
  });

  test("ومن لم يُرسل قائمةً أصلاً تُقرأ له فارغةً لا تُسقط الدالّة", () => {
    assert.deepEqual(sanitizeWatched(undefined, OWNER).uids, []);
    assert.deepEqual(sanitizeWatched("u-1", OWNER).uids, []);
  });
});

describe("الحدّ", () => {
  const many = (n) => Array.from({length: n}, (_, i) => `uid-${i}`);

  test(`${MAX_WATCHED} تمرّ`, () => {
    const r = sanitizeWatched(many(MAX_WATCHED), OWNER);
    assert.equal(r.overLimit, false);
    assert.equal(r.uids.length, MAX_WATCHED);
  });

  test(`و${MAX_WATCHED + 1} تُردّ — ولا تُقتطع بصمت`, () => {
    const r = sanitizeWatched(many(MAX_WATCHED + 1), OWNER);
    assert.equal(r.overLimit, true);
    // **وهذا هو بيتُ القصيد**: القائمةُ تعود كاملةً لا مقتطعة. فالاقتطاعُ
    // يترك مسؤولَ النظام يظنّ أنه سمّى واحداً وعشرين والمراقبَ يظنّ أنه
    // يرى الكلّ، ولا يُكتشف إلا حين يُسأل عمّا لم يره.
    assert.equal(r.uids.length, MAX_WATCHED + 1);
  });

  test("والرسالةُ تسمّي العددَ والحدَّ وكم يُرفع", () => {
    const m = overLimitMessage(25);
    assert.match(m, /25/);
    assert.match(m, new RegExp(String(MAX_WATCHED)));
    assert.match(m, /5/); // 25 - 20
  });

  // والمكرَّرُ لا يُفجّر الحدَّ: ثلاثون نسخةً من اسمٍ واحد اسمٌ واحد.
  test("والتكرارُ يُنقَّى قبل أن يُقاس على الحدّ", () => {
    const r = sanitizeWatched(Array(30).fill("u-1"), OWNER);
    assert.equal(r.overLimit, false);
  });
});

// ــــ وقياسُ أنّ الحدَّ يَسَع فعلاً ــــ
//
// حدٌّ مكتوبٌ بلا قياسٍ يشيخ: يطول معرّفٌ، أو يُضاف مفتاحٌ إلى البطاقة،
// فتتجاوز الألفَ ويسقط الختمُ كلُّه — ولا شيء يقول إنّ العشرين لم تعد تسع.
//
// ومعرّفاتُ Firebase ثمانيةٌ وعشرون محرفاً. فتُقاس البطاقةُ بأطولِ ما يُحتمل
// لا بأقصرِه: مراقبٌ بصلاحياته، وإدارةٌ، وعشرون معرّفاً كاملَ الطول.
describe("ميزانيّةُ البطاقة", () => {
  const FIREBASE_UID_LEN = 28;
  const CLAIM_BYTE_LIMIT = 1000;

  test(`بطاقةُ مراقبٍ بـ${MAX_WATCHED} اسماً تبقى تحت ${CLAIM_BYTE_LIMIT} بايت`, () => {
    const claims = {
      role: "monitor",
      departmentId: "d".repeat(FIREBASE_UID_LEN),
      departmentIds: [],
      approved: true,
      hs: [],
      perms: {dsh: true, dpg: true, sfb: true, vcc: true},
      w: Array.from({length: MAX_WATCHED}, (_, i) =>
        `u${String(i).padStart(2, "0")}${"x".repeat(FIREBASE_UID_LEN - 3)}`),
    };
    const size = Buffer.byteLength(JSON.stringify(claims), "utf8");
    assert.ok(
      size < CLAIM_BYTE_LIMIT,
      `بطاقةُ ${MAX_WATCHED} مراقَباً = ${size} بايت، والحدُّ ${CLAIM_BYTE_LIMIT}`,
    );
  });

  // ــ والضابط: الحدُّ ليس فضفاضاً بلا سبب ــ
  //
  // لو مرّ الضِّعفُ أيضاً لكان القياسُ أعلاه لا يقيس شيئاً — ولَدلّ على أنّ
  // العشرين اختيارٌ بلا موجب.
  test(`و${MAX_WATCHED * 2} اسماً تتجاوزه — فالحدُّ قريبٌ من الحافّة بحقّ`, () => {
    const claims = {
      role: "monitor",
      departmentId: "d".repeat(FIREBASE_UID_LEN),
      departmentIds: [],
      approved: true,
      hs: [],
      perms: {dsh: true, dpg: true, sfb: true, vcc: true},
      w: Array.from({length: MAX_WATCHED * 2}, (_, i) =>
        `u${String(i).padStart(2, "0")}${"x".repeat(FIREBASE_UID_LEN - 3)}`),
    };
    const size = Buffer.byteLength(JSON.stringify(claims), "utf8");
    assert.ok(size > CLAIM_BYTE_LIMIT, `${MAX_WATCHED * 2} اسماً = ${size} بايت فقط`);
  });
});
