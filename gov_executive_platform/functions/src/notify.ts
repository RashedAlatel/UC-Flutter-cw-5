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
  const data = userDoc.data() as {email?: string; phone?: string; name?: string};
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
