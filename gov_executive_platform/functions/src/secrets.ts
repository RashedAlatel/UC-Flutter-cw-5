import {defineSecret} from "firebase-functions/params";

// أسرار يتم تخزينها عبر Google Secret Manager (وليس في الكود) بالأمر:
//   firebase functions:secrets:set <NAME>
export const gmailUser = defineSecret("GMAIL_USER");
export const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");
export const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
export const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
export const twilioWhatsappFrom = defineSecret("TWILIO_WHATSAPP_FROM");

export const notificationSecrets = [
  gmailUser,
  gmailAppPassword,
  twilioAccountSid,
  twilioAuthToken,
  twilioWhatsappFrom,
];
