// ختمُ البطاقة يصل صاحبَه في حينه — لا بعد ساعة.
//
// ــــ الحادثةُ التي أوجبت هذه الوحدة ــــ
//
// قواعدُ Firestore تحتكم إلى بطاقة الدخول لا إلى مستند المستخدم. والبطاقةُ
// في المتصفّح لا تتجدّد إلا بانتهاء أجل الرمز — وقد يبلغ ساعة. فمن غُيّر
// دورُه أو إدارتُه كان يجلس أمام منصّةٍ تردّ قراءاتِه وكتاباتِه والشاشةُ
// تقول إنه يملكها. ووقع ذلك في وزارة العدل فأخفى مشاريعَها يوماً كاملاً.
//
// وما يُقاس هنا ثلاثة، وكلٌّ منه قرارٌ لا تفصيل:
//
// (١) **الختمُ أوّلاً والعلامةُ بعده.** لو عُكس الترتيب لأيقظت العلامةُ
//     المتصفّحَ ليقرأ بطاقةً لم تتغيّر بعد — فيُجدّد رمزَه بلا جدوى ويظنّ
//     الأمر قد أُصلح.
//
// (٢) **إخفاقُ العلامة لا يُسقط الختم.** الختمُ هو الفعل، والعلامةُ تُسرّعه.
//     وتُنادى هذه الدالّة قبل إنشاء مستند المستخدم أحياناً (`createUser`).
//
// (٣) **وإخفاقُ الختم يُرمى.** بطاقةٌ لم تُختم عطلٌ صامتٌ لا يجوز ابتلاعه.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {stampClaims, sameClaims} from "../lib/claims_stamp.js";

/** تبعيّاتٌ تسجّل ما وقع وبأي ترتيب. */
function spyDeps(overrides = {}) {
  const calls = [];
  return {
    calls,
    deps: {
      setClaims: async (uid, claims) => {
        calls.push(["setClaims", uid, claims]);
      },
      markUser: async (uid) => {
        calls.push(["markUser", uid]);
      },
      warn: (message, err) => {
        calls.push(["warn", message, err]);
      },
      ...overrides,
    },
  };
}

const CLAIMS = {role: "departmentManager", departmentId: "d-1", approved: true};

// ــــ والحلقةُ التي عطّلت المنصّة ــــ
//
// `syncMyClaims` تُعيد ختمَ البطاقة نفسِها. فكانت العلامةُ تُكتب في كل ختم،
// فتوقظ متصفّحَ صاحبها، فيفحص بطاقتَه، فينادي `syncMyClaims` من جديد —
// دورةٌ لا تنتهي تُلغي كلَّ اشتراكاته وتُعيدها في كل لفّة. فالعلامةُ خبرُ
// **تغيُّر**، ولا خبر في ختمٍ أعاد ما كان.
describe("العلامةُ خبرُ تغيُّر لا خبرُ ختم", () => {
  const SAME = {role: "employee", departmentId: "d-1", approved: true};

  test("ختمٌ أعاد ما كان لا يوقظ أحداً", async () => {
    const calls = [];
    await stampClaims("u-1", {...SAME}, {
      setClaims: async () => calls.push("claims"),
      markUser: async () => calls.push("mark"),
      warn: () => {},
      readClaims: async () => ({...SAME}),
    });
    assert.deepEqual(calls, ["claims"], "البطاقةُ تُختم، والعلامةُ لا تُكتب");
  });

  test("وختمٌ غيَّر حقلاً يوقظ", async () => {
    const calls = [];
    await stampClaims("u-1", {...SAME, departmentId: "d-2"}, {
      setClaims: async () => calls.push("claims"),
      markUser: async () => calls.push("mark"),
      warn: () => {},
      readClaims: async () => ({...SAME}),
    });
    assert.deepEqual(calls, ["claims", "mark"]);
  });

  // حسابٌ لم يُنشأ بعد (`createUser`): لا سابقةَ له، فالختمُ جديدٌ حقاً.
  test("وحسابٌ بلا بطاقةٍ سابقة يوقظ", async () => {
    const calls = [];
    await stampClaims("u-1", {...SAME}, {
      setClaims: async () => calls.push("claims"),
      markUser: async () => calls.push("mark"),
      warn: () => {},
      readClaims: async () => undefined,
    });
    assert.deepEqual(calls, ["claims", "mark"]);
  });

  test("وبلا قارئِ بطاقةٍ أصلاً يوقظ — لا يُسكَت على شكّ", async () => {
    const calls = [];
    await stampClaims("u-1", {...SAME}, {
      setClaims: async () => calls.push("claims"),
      markUser: async () => calls.push("mark"),
      warn: () => {},
    });
    assert.deepEqual(calls, ["claims", "mark"]);
  });

  // ــ وترتيبُ المفاتيح ليس تغييراً ــ
  //
  // مفاتيحُ الكائن ترتيبُها ترتيبُ إدخالها، فبطاقتان متطابقتان تخرجان
  // بترتيبين. ولو قِيستا بالترتيب لَعادت الحلقةُ من بابها.
  test("وترتيبُ المفاتيح لا يُقرأ تغييراً", () => {
    assert.equal(
      sameClaims({role: "a", approved: true}, {approved: true, role: "a"}),
      true,
    );
  });

  test("وقائمةُ الإدارات تُقارن بعناصرها", () => {
    assert.equal(sameClaims({d: ["x", "y"]}, {d: ["x", "y"]}), true);
    assert.equal(sameClaims({d: ["x", "y"]}, {d: ["y", "x"]}), false);
  });

  test("ومفتاحٌ زائدٌ في إحداهما تغيير", () => {
    assert.equal(sameClaims({role: "a"}, {role: "a", perms: 3}), false);
  });
});

describe("ختمُ البطاقة", () => {
  test("يختم البطاقة كما وردت", async () => {
    const {calls, deps} = spyDeps();
    await stampClaims("u-1", CLAIMS, deps);
    assert.deepEqual(calls[0], ["setClaims", "u-1", CLAIMS]);
  });

  test("ويعلّم مستند المستخدم بعده", async () => {
    const {calls, deps} = spyDeps();
    await stampClaims("u-1", CLAIMS, deps);
    assert.deepEqual(calls[1], ["markUser", "u-1"]);
  });

  // ــ والترتيبُ هو القاعدة لا صدفةَ كتابة ــ
  test("والختمُ يسبق العلامة — لا العكس", async () => {
    const order = [];
    await stampClaims("u-1", CLAIMS, {
      setClaims: async () => {
        order.push("claims");
      },
      markUser: async () => {
        order.push("mark");
      },
      warn: () => {},
    });
    assert.deepEqual(order, ["claims", "mark"]);
  });

  test("وعلامةٌ تُخفق لا تُسقط الختم", async () => {
    const seen = [];
    await stampClaims("u-1", CLAIMS, {
      setClaims: async () => {
        seen.push("claims");
      },
      markUser: async () => {
        throw new Error("NOT_FOUND");
      },
      warn: (m) => seen.push(m),
    });
    assert.equal(seen[0], "claims");
    assert.match(seen[1], /claimsUpdatedAt/);
    assert.match(seen[1], /u-1/, "ويُسمَّى صاحبُ البطاقة في التحذير");
  });

  // ــ وما لا يُبتلع ــ
  test("أمّا إخفاقُ الختم فيُرمى ولا يُبتلع", async () => {
    await assert.rejects(
      () => stampClaims("u-1", CLAIMS, {
        setClaims: async () => {
          throw new Error("auth/user-not-found");
        },
        markUser: async () => {},
        warn: () => {},
      }),
      /user-not-found/,
    );
  });

  test("ولا تُكتب علامةٌ لبطاقةٍ لم تُختم", async () => {
    const calls = [];
    await assert.rejects(() => stampClaims("u-1", CLAIMS, {
      setClaims: async () => {
        throw new Error("boom");
      },
      markUser: async () => calls.push("mark"),
      warn: () => {},
    }));
    assert.deepEqual(calls, []);
  });
});

// ــــ المفاتيحُ المحمولة: ما لا رأيَ للخاتم فيه يُنقل كما هو ــــ
//
// `setCustomUserClaims` **تستبدل البطاقة كلَّها** ولا تدمج. وفي `index.ts`
// خمسةُ مواضعَ تختم بطاقةَ مستخدمٍ قائم بيدها — اعتمادُ تسجيل، ونقلُ موظّف
// بين إدارتين، وتعديلُ دور، وتغييرُ حالة، **وحفظُ شاشة صلاحيات الأدوار**
// (وهذا الأخير يختم لكلّ حاملي الدور دفعةً واحدة).
//
// ولا واحدٌ منها يمرّر `hs` — الأقسامَ التي يرأسها صاحبُ البطاقة. فكان
// **كلُّ** واحدٍ منها يمحو رئاستَه صامتاً: يبقى رئيسَ قسمه في السجلّ،
// وتتوقّف `isSectionHeadOf()` في القواعد عن معرفته، فلا يرى حالاتِ أهل
// قسمه ولا يُقال له لماذا. ويعود الأمرُ إن أعاد `restampClaims` ختمَه
// يوماً — وقد لا يقع أبداً.
//
// وعلاجُه في خمسة مواضعَ علاجٌ يُنسى عند السادس. فالقرار: **الخاتمُ نفسُه
// يحمل ما لا رأيَ للمُستدعي فيه**. وهو يقرأ البطاقةَ السابقة أصلاً للمقارنة،
// فالحملُ بلا قراءةٍ زائدة.
describe("المفاتيحُ المحمولة", () => {
  test("ختمٌ لا يذكر `hs` لا يمحوها", async () => {
    const {calls, deps} = spyDeps({
      readClaims: async () => ({role: "employee", hs: ["s-1", "s-2"]}),
    });
    await stampClaims("u-1", {role: "departmentManager", approved: true}, deps);
    const stamped = calls.find((c) => c[0] === "setClaims")[2];
    assert.deepEqual(stamped.hs, ["s-1", "s-2"]);
  });

  test("ولا يمحو `w` — قائمةَ من يراقبهم", async () => {
    const {calls, deps} = spyDeps({
      readClaims: async () => ({role: "monitor", w: ["u-7", "u-8"]}),
    });
    await stampClaims("u-1", {role: "monitor", departmentId: "d-2"}, deps);
    const stamped = calls.find((c) => c[0] === "setClaims")[2];
    assert.deepEqual(stamped.w, ["u-7", "u-8"]);
  });

  // ــ والضابط: الصريحُ يَغلِب المحمول ــ
  //
  // ولولا هذا لكان «الحمل» دمجاً أعمى لا يُنزع به شيءٌ أبداً: من عُزل عن
  // رئاسة قسمه تبقى رئاستُه في بطاقته إلى الأبد. فـ`restampClaims` تمرّر
  // `hs` و`w` صراحةً دائماً — وهي الجهةُ الوحيدة التي لها رأيٌ فيهما.
  test("و`hs: []` مُرسَلةٌ صراحةً تنزع ولا تُحمَل", async () => {
    const {calls, deps} = spyDeps({
      readClaims: async () => ({role: "employee", hs: ["s-1"]}),
    });
    await stampClaims("u-1", {role: "employee", hs: []}, deps);
    const stamped = calls.find((c) => c[0] === "setClaims")[2];
    assert.deepEqual(stamped.hs, []);
  });

  // ــ وضابطٌ محايد: مفتاحٌ ليس من المحمولة لا يُحمَل ــ
  //
  // لو حُمل كلُّ غائبٍ لصارت البطاقةُ تنمو ولا تنقص، ولَبقيت `departmentId`
  // القديمةُ بعد نزعها — وهو عطلٌ أسوأ من الذي عولج.
  test("و`departmentId` الغائبةُ لا تُحمَل", async () => {
    const {calls, deps} = spyDeps({
      readClaims: async () => ({role: "employee", departmentId: "d-9", hs: ["s-1"]}),
    });
    await stampClaims("u-1", {role: "employee"}, deps);
    const stamped = calls.find((c) => c[0] === "setClaims")[2];
    assert.equal(stamped.departmentId, undefined);
    assert.deepEqual(stamped.hs, ["s-1"]);
  });
});
