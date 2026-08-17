import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {sendEmail, wrapEmailHtml} from "./email";
import {sendWhatsApp} from "./whatsapp";

interface NotifyChannels {
  email?: boolean;
  whatsapp?: boolean;
}

/**
 * إرسال إشعار لمستخدم عبر البريد و/أو واتساب حسب بيانات الاتصال المسجّلة له.
 * فشل قناة واحدة (مثلاً رقم واتساب غير منضم لبيئة Sandbox) لا يوقف باقي العملية.
 */
export async function notifyUser(
  uid: string,
  subject: string,
  message: string,
  channels: NotifyChannels = {email: true, whatsapp: true},
): Promise<void> {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    logger.warn(`notifyUser: user ${uid} not found`);
    return;
  }
  const data = userDoc.data() as {email?: string; phone?: string; name?: string};

  const tasks: Promise<void>[] = [];

  if (channels.email !== false && data.email) {
    tasks.push(
      sendEmail(data.email, subject, wrapEmailHtml(data.name ?? "", message)).catch((e) =>
        logger.error("sendEmail failed", e),
      ),
    );
  }
  if (channels.whatsapp !== false && data.phone) {
    tasks.push(sendWhatsApp(data.phone, message).catch((e) => logger.error("sendWhatsApp failed", e)));
  }

  await Promise.all(tasks);
}
