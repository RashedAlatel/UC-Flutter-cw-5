import * as admin from "firebase-admin";
import {HttpsError, onCall, CallableRequest} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";

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

/**
 * يتحقق أن المتصل يملك صلاحية مراسلة **هؤلاء المستلمين تحديداً**، لا مجرد
 * صلاحية الإرسال. النطاق يُفحص على الخادم بقراءة مستندات المستلمين، لا
 * بالاعتماد على ما يرسله العميل الذي قد يكون منتحلاً.
 *
 * - مسؤول النظام: أي مستلم.
 * - يملك ntf مع vad (يرى كل الإدارات): أي مستلم.
 * - مدير إدارة يملك ntf: مستلمون داخل إداراته.
 * - أي دور آخر يملك ntf: مستلمون داخل إدارته نفسها.
 */
async function requireNotifyAccess(request: CallableRequest, targetUids: string[]) {
  const auth = requireAuth(request);
  const role = auth.token.role as string | undefined;
  if (role === "systemAdmin") return auth;

  const perms = auth.token.perms as Record<string, boolean> | undefined;
  if (perms?.ntf !== true) {
    throw new HttpsError("permission-denied", "لا تملك صلاحية إرسال الإشعارات");
  }
  if (perms.vad === true) return auth;

  const myDepts: string[] = role === "departmentManager" ?
    ((auth.token.departmentIds as string[] | undefined) ?? []) :
    [(auth.token.departmentId as string | undefined) ?? ""].filter(Boolean);

  if (!myDepts.length) {
    throw new HttpsError("permission-denied", "لا توجد إدارة مرتبطة بحسابك لتحديد نطاق المراسلة");
  }

  const docs = await Promise.all(targetUids.map((uid) => db().collection("users").doc(uid).get()));
  const outside = docs.filter((d) => {
    const dept = (d.data()?.departmentId as string | undefined) ?? "";
    return !myDepts.includes(dept);
  });
  if (outside.length) {
    throw new HttpsError("permission-denied", "بعض المستلمين خارج نطاق إدارتك");
  }
  return auth;
}

async function logAudit(userName: string, action: string, details: string): Promise<void> {
  await db().collection("auditLog").add({userName, action, details, timestamp: now()});
}

// "val" (الاطلاع على سجل التدقيق) أُزيلت عمداً من الصلاحيات القابلة للتفويض:
// سجل التدقيق يبقى حصراً لمسؤول النظام، لا يملك أي دور مخصص الوصول إليه.
// مفاتيح الصلاحيات القابلة للتفويض. لا تتضمن — ولن تتضمن — بوابات الاعتماد
// الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي)؛ تلك تبقى محصورة
// بـ systemAdmin عبر requireAdmin وقواعد Firestore معاً.
const CUSTOM_ROLE_PERM_KEYS = ["vad", "mr", "md", "agd", "mw", "del", "ntf"] as const;

/** الأدوار الأساسية التي يضبط مسؤول النظام صلاحياتها من شاشة "صلاحيات الأدوار". */
const CONFIGURABLE_ROLES = ["executiveViewer", "departmentManager", "projectOfficer", "employee"] as const;

/** الإعداد المبدئي إن لم يُنشأ مستند settings/rolePermissions بعد — مطابق لسلوك المنصة السابق. */
const DEFAULT_ROLE_PERMS: Record<string, string[]> = {
  executiveViewer: ["vad", "mr", "agd"],
  departmentManager: ["mw"],
  projectOfficer: [],
  employee: [],
};

function emptyPerms(): Record<string, boolean> {
  const perms: Record<string, boolean> = {};
  for (const key of CUSTOM_ROLE_PERM_KEYS) perms[key] = false;
  return perms;
}

/**
 * يُحمّل مجموعة الصلاحيات المضغوطة لتضمينها في Custom Claims.
 *
 * - `custom`: تُقرأ من مستند الدور المخصص في مجموعة roles.
 * - الأدوار الأساسية القابلة للضبط: تُقرأ من settings/rolePermissions.
 * - `systemAdmin`: undefined — صلاحياته كاملة عبر isAdmin() لا عبر الأعلام.
 */
async function loadCustomRolePerms(role: string, customRoleId?: string | null): Promise<Record<string, boolean> | undefined> {
  if (role === "custom") {
    if (!customRoleId) throw new HttpsError("invalid-argument", "الرجاء اختيار الدور المخصص");
    const doc = await db().collection("roles").doc(customRoleId).get();
    if (!doc.exists) throw new HttpsError("not-found", "الدور المخصص غير موجود");
    const data = doc.data()!;
    const perms = emptyPerms();
    perms.vad = data.viewAllDepartments === true;
    perms.mr = data.manageReports === true;
    perms.md = data.manageDashboard === true;
    perms.agd = data.approveGeneralDecisions === true;
    return perms;
  }

  if (!(CONFIGURABLE_ROLES as readonly string[]).includes(role)) return undefined;

  const doc = await db().collection("settings").doc("rolePermissions").get();
  const data = doc.exists ? doc.data() ?? {} : {};
  const granted: string[] = Array.isArray(data[role]) ? data[role] : DEFAULT_ROLE_PERMS[role] ?? [];
  const perms = emptyPerms();
  for (const key of granted) {
    if (key in perms) perms[key] = true;
  }
  return perms;
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

function checkApprovalPermission(type: string, auth: CallableRequest["auth"]) {
  const callerRole = auth?.token.role as string | undefined;
  const perms = auth?.token.perms as Record<string, boolean> | undefined;
  // بوابات الموافقة الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي) تبقى
  // حصراً لمسؤول النظام ولا يمكن لأي دور مخصص تجاوزها مهما كانت صلاحياته.
  const allowed =
    type === "decision"
      ? callerRole === "systemAdmin" || callerRole === "executiveViewer" || perms?.agd === true
      : callerRole === "systemAdmin";
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

  checkApprovalPermission(data.type, auth);

  const payload = (data.payload ?? {}) as Record<string, unknown>;

  switch (data.type) {
    case "registration": {
      const uid = payload.uid as string;
      const role = payload.requestedRole as string;
      const departmentId = (payload.requestedDepartmentId as string | null) ?? null;
      const sectionId = (payload.requestedSectionId as string | null) ?? null;

      // شرط البريد الوزاري المؤكَّد يُفحص **هنا** لا في المتصفح: هذه هي
      // بوابة الاعتماد الفعلية، وأي فحص في الواجهة يمكن تجاوزه. ومسؤول
      // النظام يستثني من يشاء بحقل على سجل المستخدم لا يكتبه غيره.
      const policySnap = await db().collection("settings").doc("registration").get();
      const policy = policySnap.exists ? policySnap.data() ?? {} : {};
      const requireVerification = policy.requireEmailVerification !== false;
      if (requireVerification) {
        const userSnap = await db().collection("users").doc(uid).get();
        const exempt = userSnap.exists && userSnap.data()?.emailVerificationExempt === true;
        if (!exempt) {
          const account = await admin.auth().getUser(uid);
          if (!account.emailVerified) {
            throw new HttpsError(
              "failed-precondition",
              "لم يؤكّد هذا الموظف بريده الوزاري بعد. اطلب منه فتح رسالة التأكيد، " +
              "أو امنحه استثناءً من شاشة إدارة المستخدمين ثم أعد المحاولة.",
            );
          }
        }
      }

      // النطاق المسموح يُفحص هنا أيضاً: نموذج التسجيل يفحصه لطفاً بالموظف،
      // لكن الاعتماد لا يجوز أن يعتمد على فحص جرى في متصفحه.
      const domains: string[] = Array.isArray(policy.allowedEmailDomains) ?
        policy.allowedEmailDomains.map((d: unknown) => String(d).trim().toLowerCase()) :
        [];
      if (domains.length > 0) {
        const email = String(payload.email ?? "").trim().toLowerCase();
        const at = email.lastIndexOf("@");
        const domain = at >= 0 ? email.slice(at + 1) : "";
        const userSnap = await db().collection("users").doc(uid).get();
        const exempt = userSnap.exists && userSnap.data()?.emailVerificationExempt === true;
        if (!exempt && !domains.includes(domain)) {
          throw new HttpsError(
            "failed-precondition",
            `بريد هذا الموظف خارج النطاقات الوزارية المقبولة (${domains.map((d) => "@" + d).join(" أو ")}).`,
          );
        }
      }
      // التسجيل الذاتي يسمح باختيار إدارة واحدة فقط؛ مسؤول النظام يمكنه لاحقاً
      // توسيع إدارات مدير الإدارة عبر setUserRole إن احتاج أكثر من إدارة.
      const departmentIds = role === "departmentManager" && departmentId ? [departmentId] : [];
      await admin.auth().setCustomUserClaims(uid, {role, departmentId, departmentIds, approved: true});
      // القسم يُحفظ في السجل ولا يدخل بطاقة الدخول: لا قاعدة أمان تحتكم إليه،
      // وبطاقة الدخول لها حدّ حجم صارم فلا تُثقَل بما لا يُفحص عليها.
      await db().collection("users").doc(uid)
        .update({role, departmentId, departmentIds, sectionId, status: "approved"});
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
        executorNames: payload.executorNames ?? [],
        createdByUid: data.requestedByUid,
        managerUid: null,
        // القسم داخل الإدارة كما اختاره مقدّم الطلب (null = تحت الإدارة مباشرةً).
        sectionId: payload.sectionId ?? null,
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

  checkApprovalPermission(data.type, auth);

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
  const {name, email, phone, password, role, customRoleId, departmentId, departmentIds} = (request.data ?? {}) as {
    name?: string;
    email?: string;
    phone?: string;
    password?: string;
    role?: string;
    customRoleId?: string | null;
    departmentId?: string | null;
    departmentIds?: string[] | null;
  };
  if (!name || !email || !password || !role) {
    throw new HttpsError("invalid-argument", "الرجاء تعبئة جميع الحقول المطلوبة");
  }

  const perms = await loadCustomRolePerms(role, customRoleId);
  // مدير الإدارة قد يدير أكثر من إدارة (departmentIds)؛ بقية الأدوار تستخدم departmentId مفرد.
  const deptIds = role === "departmentManager" ? departmentIds ?? [] : [];

  const userRecord = await admin.auth().createUser({email, password, displayName: name});
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    role,
    departmentId: departmentId ?? null,
    departmentIds: deptIds,
    approved: true,
    ...(perms ? {perms} : {}),
  });
  await db()
    .collection("users")
    .doc(userRecord.uid)
    .set({
      name,
      email,
      phone: phone ?? "",
      role,
      customRoleId: role === "custom" ? customRoleId : null,
      departmentId: departmentId ?? null,
      departmentIds: deptIds,
      status: "approved",
      createdAt: now(),
    });

  await logAudit(auth.token.name ?? "مسؤول النظام", "إضافة مستخدم مباشرة", `أضاف مسؤول النظام مستخدماً جديداً "${name}"`);

  return {ok: true, uid: userRecord.uid};
});

export const setUserRole = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {uid, role, customRoleId, departmentId, departmentIds} = (request.data ?? {}) as {
    uid?: string;
    role?: string;
    customRoleId?: string | null;
    departmentId?: string | null;
    departmentIds?: string[] | null;
  };
  if (!uid || !role) throw new HttpsError("invalid-argument", "بيانات ناقصة");

  const userRef = db().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new HttpsError("not-found", "المستخدم غير موجود");
  const current = userDoc.data()!;

  const perms = await loadCustomRolePerms(role, customRoleId);
  const deptIds = role === "departmentManager" ? departmentIds ?? [] : [];

  await userRef.update({
    role,
    customRoleId: role === "custom" ? customRoleId : null,
    departmentId: departmentId ?? null,
    departmentIds: deptIds,
  });
  await admin.auth().setCustomUserClaims(uid, {
    role,
    departmentId: departmentId ?? null,
    departmentIds: deptIds,
    approved: current.status === "approved",
    ...(perms ? {perms} : {}),
  });

  await logAudit(auth.token.name ?? "مسؤول النظام", "تعديل دور مستخدم", `تم تغيير دور المستخدم "${current.name}"`);

  return {ok: true};
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
  const perms = await loadCustomRolePerms(current.role, current.customRoleId);
  await admin.auth().setCustomUserClaims(uid, {
    role: current.role,
    departmentId: current.departmentId ?? null,
    departmentIds: current.departmentIds ?? [],
    approved,
    ...(perms ? {perms} : {}),
  });
  await admin.auth().updateUser(uid, {disabled: !approved});
  if (!approved) {
    await admin.auth().revokeRefreshTokens(uid);
  }

  await logAudit(auth.token.name ?? "مسؤول النظام", "تحديث حالة مستخدم", `تم تغيير حالة المستخدم "${current.name}" إلى ${status}`);

  return {ok: true};
});

/**
 * يعيد ختم بصمات الصلاحيات (Custom Claims) على كل مستخدمي دور أساسي معيّن،
 * ليسري تعديل "صلاحيات الأدوار" فعلياً على الخادم لا في الواجهة وحدها.
 *
 * لا يُغيّر دور أي مستخدم ولا حالته — يعيد كتابة أعلام الصلاحيات فقط بحسب
 * settings/rolePermissions الحالي. التغيير يسري على المستخدم عند تجديد رمزه
 * (إعادة الدخول أو تحديث الرمز تلقائياً بعد ساعة).
 */
export const refreshRolePermissions = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {role} = (request.data ?? {}) as {role?: string};
  if (!role) throw new HttpsError("invalid-argument", "الرجاء تحديد الدور");
  if (!(CONFIGURABLE_ROLES as readonly string[]).includes(role)) {
    throw new HttpsError("invalid-argument", "هذا الدور لا تُضبط صلاحياته من هنا");
  }

  const perms = await loadCustomRolePerms(role, null);
  const snap = await db().collection("users").where("role", "==", role).get();

  let updated = 0;
  for (const doc of snap.docs) {
    const u = doc.data();
    try {
      await admin.auth().setCustomUserClaims(doc.id, {
        role,
        departmentId: u.departmentId ?? null,
        departmentIds: u.departmentIds ?? [],
        approved: u.status === "approved",
        ...(perms ? {perms} : {}),
      });
      updated++;
    } catch (err) {
      // حساب محذوف من Authentication لكن سجله باقٍ في Firestore — نتخطاه بدل
      // إفشال العملية كلها على بقية المستخدمين.
      logger.warn(`تعذر تحديث صلاحيات المستخدم ${doc.id}`, err);
    }
  }

  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "تطبيق صلاحيات دور",
    `تم تحديث صلاحيات ${updated} حساباً بدور "${role}"`,
  );

  return {ok: true, updated};
});

export const sendUserNotification = onCall({secrets: notificationSecrets}, async (request) => {
  const {uids, uid, channel, subject, message} = (request.data ?? {}) as {
    uids?: string[];
    uid?: string;
    channel?: string;
    subject?: string;
    message?: string;
  };
  const targets = uids && uids.length ? uids : uid ? [uid] : [];
  if (!targets.length || !message) throw new HttpsError("invalid-argument", "بيانات ناقصة");
  const auth = await requireNotifyAccess(request, targets);

  const channels = {
    email: channel === "email" || channel === "both",
    whatsapp: channel === "whatsapp" || channel === "both",
  };

  const results = await Promise.all(
    targets.map(async (t) => ({
      uid: t,
      result: await notifyUser(t, subject || "إشعار من المنصة التنفيذية الحكومية", message, channels),
    })),
  );

  await logAudit(
    auth.token.name ?? "مستخدم",
    "إرسال إشعار",
    `أُرسل إشعار (${channel}) إلى ${targets.length} مستخدم(ين)`,
  );

  // لا نُخفي فشل الإرسال الفعلي (بيانات بريد خاطئة، رقم واتساب غير صالح...):
  // نُبلّغ به صراحة بدل رسالة "تم الإرسال" الخادعة التي كانت تظهر سابقاً حتى
  // عندما لا تصل الرسالة فعلياً.
  const failures = results.filter(
    ({result}) => (channels.email && !result.emailSent) || (channels.whatsapp && !result.whatsappSent),
  );
  if (failures.length) {
    const detail = failures
      .map(({uid: t, result}) => `${t}: ${[result.emailError, result.whatsappError].filter(Boolean).join(" / ")}`)
      .join("، ");
    throw new HttpsError("internal", `فشل الإرسال لبعض المستخدمين: ${detail}`);
  }

  return {ok: true, sent: targets.length};
});

/**
 * يعيد ختم بصمات الدخول (Custom Claims) من مستند المستخدم إلى بطاقته.
 *
 * لماذا تلزم؟ قواعد Firestore كلها تبدأ من `isApproved()`، وهي تقرأ
 * `request.auth.token.approved` — أي بصمة في **بطاقة الدخول**، لا الحقل
 * الموجود في مستند المستخدم. بينما التطبيق يقرّر دخول المستخدم من المستند.
 * فحساب مستنده يقول «معتمد» وبطاقته لا تحمل البصمة يدخل المنصة ثم يجد كل
 * شيء فارغاً: لا مشاريعه ولا حتى التعميمات العامة. وهذا ما وقع فعلاً لمدير
 * إدارة مُسنَد لإدارة فيها مشاريع.
 *
 * **ولا تصعيد صلاحيات فيها**، وهذا مقصود ومبنيّ على قاعدتين قائمتين في
 * firestore.rules: مستند المستخدم `allow update: if isAdmin()` فلا يكتب فيه
 * إلا مسؤول النظام، والتسجيل الذاتي مُجبَر على `status: 'pending'` و
 * `role: 'projectOfficer'`. فالدالة تنسخ ما كتبه مسؤول النظام حرفياً ولا
 * تضيف حرفاً. ولا تمسّ بوابات الاعتماد الثلاث (تسجيل الأعضاء، إضافة
 * المشاريع، تغيير المواعيد النهائية) فهي تبقى حكراً على systemAdmin.
 */
async function restampClaims(uid: string): Promise<Record<string, unknown>> {
  const doc = await db().collection("users").doc(uid).get();
  if (!doc.exists) throw new HttpsError("not-found", "لا يوجد سجل لهذا المستخدم");
  const u = doc.data()!;
  const role = (u.role as string | undefined) ?? "projectOfficer";
  const perms = await loadCustomRolePerms(role, (u.customRoleId as string | null) ?? null);
  const claims = {
    role,
    departmentId: (u.departmentId as string | null) ?? null,
    // حسابات أُنشئت قبل حقل الإدارات الجمع تحمل المفرد وحده؛ نشتقّ منه القائمة
    // حتى لا يبقى مدير إدارة بنطاق فارغ فلا يرى شيئاً.
    departmentIds: Array.isArray(u.departmentIds) && u.departmentIds.length > 0 ?
      u.departmentIds :
      (role === "departmentManager" && u.departmentId ? [u.departmentId] : []),
    approved: u.status === "approved",
    ...(perms ? {perms} : {}),
  };
  await admin.auth().setCustomUserClaims(uid, claims);
  return claims;
}

/** يزامن بطاقة **المتصل نفسه** فقط. */
export const syncMyClaims = onCall(async (request) => {
  const auth = requireAuth(request);
  const claims = await restampClaims(auth.uid);
  return {ok: true, claims};
});

/** يعيد ختم بطاقة مستخدم بعينه — لمسؤول النظام، دون تعديل دوره أو حالته. */
export const adminRestampClaims = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {uid} = (request.data ?? {}) as {uid?: string};
  if (!uid) throw new HttpsError("invalid-argument", "الرجاء تحديد المستخدم");
  const claims = await restampClaims(uid);
  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "إعادة ختم الصلاحيات",
    `أُعيد ختم بصمات الدخول للمستخدم ${uid} من سجله دون تغيير دوره`,
  );
  return {ok: true, claims};
});
