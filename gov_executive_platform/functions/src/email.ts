import * as nodemailer from "nodemailer";

import {gmailAppPassword, gmailUser} from "./secrets";

/**
 * إرسال بريد إلكتروني عبر Gmail SMTP (App Password).
 * لبدء استخدام مزود بريد مؤسسي (SendGrid/Mailgun) لاحقاً، استبدل جسم هذه
 * الدالة فقط دون تعديل أي مكان آخر يستدعيها.
 */
export async function sendEmail(to: string, subject: string, html: string): Promise<void> {
  if (!to) return;

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailUser.value(),
      pass: gmailAppPassword.value(),
    },
  });

  await transporter.sendMail({
    from: `"المنصة التنفيذية الحكومية" <${gmailUser.value()}>`,
    to,
    subject,
    html,
  });
}

export function wrapEmailHtml(recipientName: string, message: string): string {
  return `
    <div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;text-align:right;line-height:1.8;color:#1C2733">
      <p>مرحباً ${recipientName || ""}،</p>
      <p>${message}</p>
      <hr style="border:none;border-top:1px solid #E1E6EB;margin:16px 0"/>
      <p style="color:#5B6B79;font-size:12px">هذه رسالة آلية من المنصة التنفيذية الحكومية، الرجاء عدم الرد عليها مباشرة.</p>
    </div>
  `;
}
