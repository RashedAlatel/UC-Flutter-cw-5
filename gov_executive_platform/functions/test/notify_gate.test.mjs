// إلى مَن يُرسِل الخادمُ بريداً، وإلى مَن يمتنع.
//
// الواجهة تُصفّي قائمة المستلمين، لكن المستلمين يأتون من مسارٍ لا نافذة
// فيه أصلاً (تنبيه المشاريع المتأخرة يجمعهم من المشاريع)، وحالُ حسابٍ قد
// تتغيّر بين اختياره والضغط على «إرسال». فالفحص هنا هو الحارس.
//
// وما يُقاس **أكثر من** المنع: أن المعلَّق والمرفوض **يُراسَلان**. فلولا
// اختبارُهما لَأمكن أن يُشدّد الشرط يوماً إلى «المعتمَد وحده» فيسكت إخطارا
// «تم اعتماد تسجيلك» و«تم رفض طلبك» — وهما ما لا بديل عنه.
import {test, describe} from "node:test";
import assert from "node:assert/strict";
import {undeliverableReason} from "../lib/notify.js";

describe("من لا يُرسَل إليه", () => {
  test("الموقوف — قُطعت صلته بالمنصة بقرار", () => {
    assert.equal(
      undeliverableReason({status: "suspended"}),
      "حساب هذا المستخدم موقوف",
    );
  });

  // مستندٌ قديم بالبريد نفسه لحسابٍ جديد قائم: الإرسال إليه نسخةٌ ثانية
  // تصل الشخصَ نفسه، لا رسالةٌ إلى أحد.
  test("والمندمج مع حسابٍ جديد — ولو بقيت حالُه معتمَدة", () => {
    assert.equal(
      undeliverableReason({status: "approved", mergedIntoUid: "u-new"}),
      "هذا الحساب دُمج مع حسابٍ جديد بالبريد نفسه — تُرسَل الرسالة إلى الحساب الجديد",
    );
  });
});

describe("ومن يُرسَل إليه", () => {
  test("المعتمَد", () => {
    assert.equal(undeliverableReason({status: "approved"}), null);
  });

  test("والمعلَّق — «تم اعتماد تسجيلك» يُرسَل والحالُ معلَّقة بعدُ", () => {
    assert.equal(undeliverableReason({status: "pending"}), null);
  });

  test("والمرفوض — «تم رفض طلبك» يُرسَل بعد وضع الحال على «مرفوض» مباشرةً", () => {
    assert.equal(undeliverableReason({status: "rejected"}), null);
  });

  test("ومستندٌ قديم بلا حقل حالة إطلاقاً — لا يُمنع بالشكّ", () => {
    assert.equal(undeliverableReason({}), null);
  });

  // حقلٌ موجودٌ فارغ ليس دمجاً: الختم يُكتب معرِّفاً أو لا يُكتب.
  test("و`mergedIntoUid` فارغٌ أو null ليس دمجاً", () => {
    assert.equal(undeliverableReason({status: "approved", mergedIntoUid: ""}), null);
    assert.equal(undeliverableReason({status: "approved", mergedIntoUid: null}), null);
  });
});
