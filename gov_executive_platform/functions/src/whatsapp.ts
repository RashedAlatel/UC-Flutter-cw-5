import twilio from "twilio";

import {twilioAccountSid, twilioAuthToken, twilioWhatsappFrom} from "./secrets";

/**
 * إرسال رسالة واتساب عبر Twilio WhatsApp API.
 * أثناء استخدام بيئة الـ Sandbox المجانية، يجب أن يرسل كل رقم مستلم رسالة
 * "join <code>" إلى رقم Twilio مرة واحدة قبل استقبال الرسائل.
 * عند الانتقال لاحقاً لحساب واتساب أعمال رسمي عبر Meta Cloud API، يكفي تعديل
 * جسم هذه الدالة فقط.
 */
export async function sendWhatsApp(toPhoneE164: string, message: string): Promise<void> {
  if (!toPhoneE164) return;

  const client = twilio(twilioAccountSid.value(), twilioAuthToken.value());
  const from = twilioWhatsappFrom.value();

  await client.messages.create({
    from: from.startsWith("whatsapp:") ? from : `whatsapp:${from}`,
    to: toPhoneE164.startsWith("whatsapp:") ? toPhoneE164 : `whatsapp:${toPhoneE164}`,
    body: message,
  });
}
