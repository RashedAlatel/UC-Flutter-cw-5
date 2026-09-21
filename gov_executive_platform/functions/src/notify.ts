import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {sendEmail, wrapEmailHtml} from "./email";
import {sendWhatsApp} from "./whatsapp";

interface NotifyChannels {
  email?: boolean;
  whatsapp?: boolean;
}

export interface NotifyResult {
  emailSent: boolean;
  whatsappSent: boolean;
  emailError?: string;
  whatsappError?: string;
}

/**
 * سببُ امتناع الإرسال إلى حسابٍ بعينه — أو `null` إن كان يُراسَل.
 *
 * ــــ لماذا يُفحص هذا على الخادم وقد صُفّيت القائمة في الواجهة؟ ــــ
 *
 * لأن الواجهة ترتيبٌ والخادم حراسة، كما في بقية المنصة. والمستلمون قد
 * يأتون من مسارٍ لا نافذة فيه أصلاً (تنبيه المشاريع المتأخرة يجمعهم من
 * المشاريع)، وقد تتغيّر حالُ حسابٍ بين اختياره والإرسال.
 *
 * ــــ ولماذا هاتان الحالتان دون غيرهما؟ ــــ
 *
 * • **المندمج**: مستندٌ قديم بالبريد نفسه لحسابٍ جديد قائم. الإرسال إليه
 *   ليس إرسالاً إلى أحد، بل نسخةٌ ثانية تصل الشخصَ نفسه.
 * • **الموقوف**: مُنع من المنصة بقرار، فلا تصله مراسلاتها.
 *
 * أما **المعلَّق** و**المرفوض** فيُراسَلان عمداً: «تم اعتماد تسجيلك» و«تم
 * رفض طلبك» يُرسَلان في اللحظة التي تكون فيها الحالُ كذلك بالضبط. فمنعُهما
 * كان يُسكت الإخطارَين اللذين لا بديل عنهما.
 */
export function undeliverableReason(
  data: {status?: unknown; mergedIntoUid?: unknown},
): string | null {
  if (typeof data.mergedIntoUid === "string" && data.mergedIntoUid) {
    return "هذا الحساب دُمج مع حسابٍ جديد بالبريد نفسه — تُرسَل الرسالة إلى الحساب الجديد";
  }
  if (data.status === "suspended") {
    return "حساب هذا المستخدم موقوف";
  }
  return null;
}

/**
 * إرسال إشعار لمستخدم عبر البريد و/أو واتساب حسب بيانات الاتصال المسجّلة له.
 * على عكس السلوك السابق، لا تُبتلع أخطاء الإرسال بصمت: تُعاد في النتيجة
 * حتى يظهر الفشل الفعلي (بيانات اعتماد بريد خاطئة، رقم واتساب غير صالح...)
 * لمسؤول النظام بدل رسالة "تم الإرسال" خادعة رغم عدم وصول الرسالة فعلياً.
 */
export async function notifyUser(
  uid: string,
  subject: string,
  message: string,
  channels: NotifyChannels = {email: true, whatsapp: true},
): Promise<NotifyResult> {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    logger.warn(`notifyUser: user ${uid} not found`);
    return {emailSent: false, whatsappSent: false, emailError: "المستخدم غير موجود"};
  }
  const data = userDoc.data() as {
    email?: string; phone?: string; name?: string;
    status?: string; mergedIntoUid?: string;
  };

  const blocked = undeliverableReason(data);
  if (blocked) {
    logger.warn(`notifyUser: ${uid} undeliverable — ${blocked}`);
    return {
      emailSent: false,
      whatsappSent: false,
      ...(channels.email !== false ? {emailError: blocked} : {}),
      ...(channels.whatsapp !== false ? {whatsappError: blocked} : {}),
    };
  }

  const result: NotifyResult = {emailSent: false, whatsappSent: false};

  if (channels.email !== false) {
    if (!data.email) {
      result.emailError = "لا يوجد بريد إلكتروني مسجَّل لهذا المستخدم";
    } else {
      try {
        await sendEmail(data.email, subject, wrapEmailHtml(data.name ?? "", message));
        result.emailSent = true;
      } catch (e) {
        logger.error("sendEmail failed", e);
        result.emailError = e instanceof Error ? e.message : "تعذر إرسال البريد الإلكتروني";
      }
    }
  }

  if (channels.whatsapp !== false) {
    if (!data.phone) {
      result.whatsappError = "لا يوجد رقم جوال مسجَّل لهذا المستخدم";
    } else {
      try {
        await sendWhatsApp(data.phone, message);
        result.whatsappSent = true;
      } catch (e) {
        logger.error("sendWhatsApp failed", e);
        result.whatsappError = e instanceof Error ? e.message : "تعذر إرسال رسالة واتساب";
      }
    }
  }

  return result;
}
