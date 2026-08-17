import * as admin from "firebase-admin";
import {HttpsError, onCall, CallableRequest} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";

import {notifyUser} from "./notify";
import {notificationSecrets} from "./secrets";

admin.initializeApp();

// منطقة قريبة من دول الخليج لتقليل زمن الاستجابة؛ عدّلها إن نشرت في منطقة أخرى.
// invoker: "public" يجعل الدوال قابلة للاستدعاء عبر HTTPS من تطبيق العميل
// (وهو المطلوب لأي دالة callable)، بينما التحقق من الهوية والصلاحية الفعلي
// يبقى داخل كود كل دالة (requireAuth/requireAdmin) عبر توكن Firebase Auth.
// بدون هذا الخيار، تحتاج لضبط "Allow public access" يدوياً من Google Cloud
// Console بعد كل نشر جديد للدوال.
setGlobalOptions({region: "europe-west1", maxInstances: 10, invoker: "public"});

const db = () => admin.firestore();
const now = () => admin.firestore.Timestamp.now();

function requireAuth(request: CallableRequest) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لتنفيذ هذا الإجراء");
  }
  return request.auth;
}

function requireAdmin(request: CallableRequest) {
  const auth = requireAuth(request);
  if (auth.token.role !== "systemAdmin") {
    throw new HttpsError("permission-denied", "هذا الإجراء يتطلب صلاحية مسؤول النظام");
  }
  return auth;
}

async function logAudit(userName: string, action: string, details: string): Promise<void> {
  await db().collection("auditLog").add({userName, action, details, timestamp: now()});
}

// ------------------------------------------------------------------
// التهيئة الأولى: تعيين أول مسؤول نظام (مرة واحدة فقط لكل مشروع)
// ------------------------------------------------------------------

export const checkBootstrapNeeded = onCall(async (request) => {
  requireAuth(request);
  const doc = await db().collection("system").doc("config").get();
  const bootstrapped = doc.exists && doc.data()?.bootstrapped === true;
  return {needed: !bootstrapped};
});

export const bootstrapFirstAdmin = onCall(async (request) => {
  const auth = requireAuth(request);
  const systemRef = db().collection("system").doc("config");

  await db().runTransaction(async (tx) => {
    const doc = await tx.get(systemRef);
    if (doc.exists && doc.data()?.bootstrapped === true) {
      throw new HttpsError("failed-precondition", "تم تعيين مسؤول نظام للمنصة مسبقاً");
    }
    tx.set(systemRef, {bootstrapped: true, bootstrappedBy: auth.uid, bootstrappedAt: now()}, {merge: true});
  });

  await admin.auth().setCustomUserClaims(auth.uid, {role: "systemAdmin", departmentId: null, approved: true});
  await db().collection("users").doc(auth.uid).update({role: "systemAdmin", status: "approved", departmentId: null});
  await logAudit(auth.token.name ?? "مستخدم", "تعيين أول مسؤول نظام", "تم تعيين أول مسؤول نظام للمنصة عبر إجراء التهيئة الأولى");

  return {ok: true};
});

// ------------------------------------------------------------------
// اعتماد/رفض طلبات مركز القرارات التنفيذية
// (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي / قرار تنفيذي عام)
// ------------------------------------------------------------------

function checkApprovalPermission(type: string, callerRole: string | undefined) {
  const allowed = type === "decision" ? callerRole === "systemAdmin" || callerRole === "executiveViewer" : callerRole === "systemAdmin";
  if (!allowed) {
    throw new HttpsError("permission-denied", "ليست لديك صلاحية البت في هذا النوع من الطلبات");
  }
}

export const approveRequest = onCall({secrets: notificationSecrets}, async (request) => {
  const auth = requireAuth(request);
  const {requestId, note} = (request.data ?? {}) as {requestId?: string; note?: string};
  if (!requestId) throw new HttpsError("invalid-argument", "معرف الطلب مطلوب");

  const ref = db().collection("approvalRequests").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
  const data = snap.data()!;
  if (data.status !== "pending") throw new HttpsError("failed-precondition", "تم البت في هذا الطلب مسبقاً");

  checkApprovalPermission(data.type, auth.token.role as string | undefined);

  const payload = (data.payload ?? {}) as Record<string, unknown>;

  switch (data.type) {
    case "registration": {
      const uid = payload.uid as string;
      const role = payload.requestedRole as string;
      const departmentId = (payload.requestedDepartmentId as string | null) ?? null;
      await admin.auth().setCustomUserClaims(uid, {role, departmentId, approved: true});
      await db().collection("users").doc(uid).update({role, departmentId, status: "approved"});
      break;
    }
    case "projectCreate": {
      await db().collection("projects").doc().set({
        departmentId: payload.departmentId,
        name: payload.name,
        description: payload.description,
        startDate: admin.firestore.Timestamp.fromDate(new Date(payload.startDate as string)),
        dueDate: admin.firestore.Timestamp.fromDate(new Date(payload.dueDate as string)),
        status: "onTrack",
        priority: payload.priority ?? "medium",
        progressPercent: 0,
        delayDays: 0,
        executorName: payload.executorName ?? "",
        createdByUid: data.requestedByUid,
      });
      break;
    }
    case "deadlineChange": {
      await db()
        .collection("projects")
        .doc(payload.projectId as string)
        .update({dueDate: admin.firestore.Timestamp.fromDate(new Date(payload.newDueDate as string))});
      break;
    }
    case "decision":
      // لا حاجة لأي تعديل إضافي على البيانات، القرار توثيقي بحت.
      break;
    default:
      throw new HttpsError("invalid-argument", "نوع طلب غير معروف");
  }

  await ref.update({status: "approved", resolutionNote: note ?? null, resolvedDate: now()});
  await logAudit(auth.token.name ?? "مسؤول النظام", "اعتماد طلب", `تم اعتماد طلب: "${data.title}"`);

  if (data.requestedByUid) {
    await notifyUser(
      data.requestedByUid,
      "تمت الموافقة على طلبك",
      `تمت الموافقة على طلبك: "${data.title}".${note ? ` ملاحظة القيادة: ${note}` : ""}`,
    );
  }

  return {ok: true};
});

export const rejectRequest = onCall({secrets: notificationSecrets}, async (request) => {
  const auth = requireAuth(request);
  const {requestId, note} = (request.data ?? {}) as {requestId?: string; note?: string};
  if (!requestId) throw new HttpsError("invalid-argument", "معرف الطلب مطلوب");

  const ref = db().collection("approvalRequests").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
  const data = snap.data()!;
  if (data.status !== "pending") throw new HttpsError("failed-precondition", "تم البت في هذا الطلب مسبقاً");

  checkApprovalPermission(data.type, auth.token.role as string | undefined);

  if (data.type === "registration") {
    const uid = (data.payload as Record<string, unknown>)?.uid as string;
    if (uid) await db().collection("users").doc(uid).update({status: "rejected"});
  }

  await ref.update({status: "rejected", resolutionNote: note ?? null, resolvedDate: now()});
  await logAudit(auth.token.name ?? "مسؤول النظام", "رفض طلب", `تم رفض طلب: "${data.title}"`);

  if (data.requestedByUid) {
    await notifyUser(
      data.requestedByUid,
      "تم رفض طلبك",
      `نأسف، تم رفض طلبك: "${data.title}".${note ? ` السبب: ${note}` : ""}`,
    );
  }

  return {ok: true};
});

// ------------------------------------------------------------------
// إدارة المستخدمين (مسؤول النظام فقط)
// ------------------------------------------------------------------

export const adminCreateUser = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {name, email, phone, password, role, departmentId} = (request.data ?? {}) as {
    name?: string;
    email?: string;
    phone?: string;
    password?: string;
    role?: string;
    departmentId?: string | null;
  };
  if (!name || !email || !password || !role) {
    throw new HttpsError("invalid-argument", "الرجاء تعبئة جميع الحقول المطلوبة");
  }

  const userRecord = await admin.auth().createUser({email, password, displayName: name});
  await admin.auth().setCustomUserClaims(userRecord.uid, {role, departmentId: departmentId ?? null, approved: true});
  await db()
    .collection("users")
    .doc(userRecord.uid)
    .set({
      name,
      email,
      phone: phone ?? "",
      role,
      departmentId: departmentId ?? null,
      status: "approved",
      createdAt: now(),
    });

  await logAudit(auth.token.name ?? "مسؤول النظام", "إضافة مستخدم مباشرة", `أضاف مسؤول النظام مستخدماً جديداً "${name}"`);

  return {ok: true, uid: userRecord.uid};
});

export const setUserStatus = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {uid, status} = (request.data ?? {}) as {uid?: string; status?: string};
  if (!uid || !status) throw new HttpsError("invalid-argument", "بيانات ناقصة");

  const userRef = db().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new HttpsError("not-found", "المستخدم غير موجود");
  const current = userDoc.data()!;

  await userRef.update({status});

  const approved = status === "approved";
  await admin.auth().setCustomUserClaims(uid, {
    role: current.role,
    departmentId: current.departmentId ?? null,
    approved,
  });
  await admin.auth().updateUser(uid, {disabled: !approved});
  if (!approved) {
    await admin.auth().revokeRefreshTokens(uid);
  }

  await logAudit(auth.token.name ?? "مسؤول النظام", "تحديث حالة مستخدم", `تم تغيير حالة المستخدم "${current.name}" إلى ${status}`);

  return {ok: true};
});

export const sendUserNotification = onCall({secrets: notificationSecrets}, async (request) => {
  const auth = requireAdmin(request);
  const {uid, channel, subject, message} = (request.data ?? {}) as {
    uid?: string;
    channel?: string;
    subject?: string;
    message?: string;
  };
  if (!uid || !message) throw new HttpsError("invalid-argument", "بيانات ناقصة");

  await notifyUser(uid, subject || "إشعار من المنصة التنفيذية الحكومية", message, {
    email: channel === "email" || channel === "both",
    whatsapp: channel === "whatsapp" || channel === "both",
  });

  await logAudit(auth.token.name ?? "مسؤول النظام", "إرسال إشعار", `أرسل مسؤول النظام إشعاراً (${channel}) إلى مستخدم`);

  return {ok: true};
});
