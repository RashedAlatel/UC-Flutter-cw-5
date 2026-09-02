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
import {stampClaims} from "../lib/claims_stamp.js";

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
