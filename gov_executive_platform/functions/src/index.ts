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

// كانت هنا `requireNotifyAccess`: تسمح لصاحب `ntf` بالإرسال **فوراً** ضمن
// نطاق إدارته. وحُذفت لا لأنها كانت مكسورة، بل لأن مسؤول النظام قرّر أن أي
// بريد يخرج باسم المنصة يمرّ بموافقته. فصار الإرسال المباشر له وحده
// (`requireAdmin`)، ومن دونه يمرّ بطلب `notifySend` كسائر بوابات الاعتماد.
//
// و`ntf` لم تفقد معناها: هي الآن **من يحقّ له كتابة الطلب**، لا من ينفّذه.
// وتُفحص في الواجهة عند فتح النموذج. ولا تُفحص هنا عمداً: مستند الطلب لا
// يُنفِّذ شيئاً بنفسه، والتنفيذ كله يمرّ بـ`approveRequest` وهي محصورة
// بمسؤول النظام. فأسوأ ما يصنعه من كتب طلباً بلا `ntf` أن يرى مسؤولُ النظام
// طلباً يرفضه.

async function logAudit(userName: string, action: string, details: string): Promise<void> {
  await db().collection("auditLog").add({userName, action, details, timestamp: now()});
}

// "val" (الاطلاع على سجل التدقيق) أُزيلت عمداً من الصلاحيات القابلة للتفويض:
// سجل التدقيق يبقى حصراً لمسؤول النظام، لا يملك أي دور مخصص الوصول إليه.
// مفاتيح الصلاحيات القابلة للتفويض. لا تتضمن — ولن تتضمن — بوابات الاعتماد
// الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي)؛ تلك تبقى محصورة
// بـ systemAdmin عبر requireAdmin وقواعد Firestore معاً.
const CUSTOM_ROLE_PERM_KEYS = ["vad", "mr", "md", "agd", "mw", "del", "ntf", "sap", "sfb", "mfb",
  "mpr", "apr", "dsh", "dpg"] as const;

/**
 * صلاحيتان **لا تُمنحان لدور قط**، بل لفرد بعينه ومعهما نطاق إدارات.
 *
 * `apr` منهما تفتح بوابةً كانت محصورة بمسؤول النظام وحده (اعتماد إضافة
 * المشاريع)، بقرار صريح منه. فهي مغلقة افتراضياً، ولا يمنحها إلا هو،
 * ومقيَّدة بنطاق، وقابلة للسحب. أما تسجيل الأعضاء وتعديل المواعيد النهائية
 * فتبقيان محصورتين به وحده.
 *
 * وتُستبعَد من صلاحيات الأدوار عند الختم مهما كُتب في settings/rolePermissions،
 * حتى لا يفتحها أحد بالخطأ من شاشة الأدوار.
 */
const SCOPED_PERM_KEYS: readonly string[] = ["mpr", "apr"];

/** نطاق صلاحية كما يُختم في البطاقة: `'*'` أو قائمة معرّفات إدارات. */
type GrantScopeClaim = "*" | string[];

/**
 * يقرأ منح النطاقات من سجل المستخدم إلى صورتها في البطاقة.
 *
 * «إدارته وحدها» تُحلّ هنا إلى معرّف إدارته، فلا تحتاج القواعد قراءة سجل
 * ولا حالة خاصة. والقائمة تُقتطع عند ثلاثين لأن للبطاقة حدّ حجم صارم.
 */
function readScopedGrants(
  raw: unknown,
  ownDepartmentId: string | null,
): {perms: Record<string, boolean>; scopes: Record<string, GrantScopeClaim>} {
  const perms: Record<string, boolean> = {};
  const scopes: Record<string, GrantScopeClaim> = {};
  if (!raw || typeof raw !== "object") return {perms, scopes};
  for (const key of SCOPED_PERM_KEYS) {
    const grant = (raw as Record<string, unknown>)[key];
    if (!grant || typeof grant !== "object") continue;
    const g = grant as Record<string, unknown>;
    if (g.all === true) {
      perms[key] = true;
      scopes[key] = "*";
      continue;
    }
    const ids = Array.isArray(g.departmentIds) ?
      g.departmentIds.map((d: unknown) => String(d)).filter(Boolean) :
      [];
    const resolved = ids.length > 0 ? ids : (g.own === true && ownDepartmentId ? [ownDepartmentId] : []);
    // نطاق فارغ ليس منحاً: لا يُختم علَمٌ بلا نطاق، لأن علَماً بلا نطاق قد
    // يُقرأ يوماً على أنه «الكل» — وهو أخطر ما يقع في صلاحية تفتح بوابة.
    if (resolved.length === 0) continue;
    perms[key] = true;
    scopes[key] = resolved.slice(0, 30);
  }
  return {perms, scopes};
}

/** الأدوار الأساسية التي يضبط مسؤول النظام صلاحياتها من شاشة "صلاحيات الأدوار". */
const CONFIGURABLE_ROLES = ["executiveViewer", "departmentManager", "projectOfficer", "employee"] as const;

/** الإعداد المبدئي إن لم يُنشأ مستند settings/rolePermissions بعد — مطابق لسلوك المنصة السابق. */
const DEFAULT_ROLE_PERMS: Record<string, string[]> = {
  // "dsh"/"dpg": مدخلا لوحة القيادة وصفحة الإدارة. مفتوحان لكل دور إلا
  // «موظف». وهما ترتيب واجهة لا حراسة بيانات — القواعد لم تتغيّر.
  executiveViewer: ["vad", "mr", "agd", "dsh", "dpg"],
  departmentManager: ["mw", "dsh", "dpg"],
  projectOfficer: ["dsh", "dpg"],
  employee: [],
};

/**
 * صلاحيات **حق أساسي** لكل حساب معتمد، لا تُمنح لدور ولا تُطلب.
 *
 * `sfb` (رفع شكوى أو اقتراح) منها: لا معنى لأن يُحرَم موظف من إيصال صوته
 * إلى مسؤول النظام حتى يُؤذن له. ولم يكن جعلها كذلك بتعديل
 * DEFAULT_ROLE_PERMS كافياً، لأن مستند settings/rolePermissions مكتوبٌ فعلاً
 * في المنصة الحيّة والمخزَّن يُقدَّم على المبدئي — فتبقى مطفأة إلى الأبد.
 *
 * ومسؤول النظام يسحبها من فرد بعينه عبر permissionOverrides، فتُطفأ في
 * applyOverrides بعد أن تُشعَل هنا.
 */
const BASELINE_PERM_KEYS: readonly string[] = ["sfb"];

/** أعلام الصلاحيات في حالتها الأساسية: كلها مطفأة إلا الحقوق الأساسية. */
function basePerms(): Record<string, boolean> {
  const perms: Record<string, boolean> = {};
  for (const key of CUSTOM_ROLE_PERM_KEYS) perms[key] = BASELINE_PERM_KEYS.includes(key);
  return perms;
}

/**
 * يطبّق الاستثناءات الفردية فوق صلاحيات الدور.
 *
 * تعلو على الدور في الاتجاهين: `true` تمنح ما لا يمنحه الدور، و`false` تمنع
 * ما يمنحه. ومصدرها حقل `permissionOverrides` على سجل المستخدم، وقاعدة
 * `/users/{uid}` تقصر كتابته على مسؤول النظام وتمنع المسجِّل من زرعه لنفسه
 * لحظة التسجيل. والمفاتيح المجهولة تُهمَل فلا تتضخّم البطاقة بما لا يُفحص.
 *
 * ولا تشمل بوابات الاعتماد الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد):
 * تلك ليست مفاتيح صلاحيات أصلاً، وتبقى محصورة بـ systemAdmin.
 */
function applyOverrides(
  perms: Record<string, boolean> | undefined,
  overrides: unknown,
): Record<string, boolean> | undefined {
  if (!overrides || typeof overrides !== "object") return perms;
  const entries = Object.entries(overrides as Record<string, unknown>)
    .filter(([key, value]) => typeof value === "boolean" && (CUSTOM_ROLE_PERM_KEYS as readonly string[]).includes(key));
  if (entries.length === 0) return perms;
  // مسؤول النظام يدخل هنا بـ undefined ويخرج به: صلاحياته كاملة عبر isAdmin()
  // لا عبر أعلام، فلا معنى لختم أعلام عليه.
  if (perms === undefined) return undefined;
  const merged = {...perms};
  for (const [key, value] of entries) merged[key] = value as boolean;
  return merged;
}

/**
 * أعلام الصلاحيات ونطاقاتها كما تُختم على البطاقة — **المصدر الوحيد**.
 *
 * ستة مواضع كانت تختم البطاقة، وكلٌّ يحسب `perms` بنفسه. وإضافة النطاقات
 * إلى خمسة منها ونسيان السادس عطلٌ صامت لا يظهر إلا حين يُستعمل ذلك المسار.
 * فجُمِع الحساب هنا.
 *
 * والصلاحيتان المقيَّدتان بنطاق تُمسحان أولاً ثم تُكتبان من `scopedGrants`
 * وحدها: لا يمنحهما دورٌ ولا استثناءٌ فردي مهما كُتب في المستندات.
 */
function claimPermissions(
  rolePerms: Record<string, boolean> | undefined,
  userData: Record<string, unknown> | undefined,
  departmentId: string | null,
): {perms?: Record<string, boolean>; scopes?: Record<string, GrantScopeClaim>} {
  // مسؤول النظام يدخل بـ undefined ويخرج بلا أعلام: صلاحياته عبر isAdmin().
  if (rolePerms === undefined) return {};
  const merged = {...(applyOverrides(rolePerms, userData?.permissionOverrides) ?? rolePerms)};
  for (const key of SCOPED_PERM_KEYS) merged[key] = false;
  const {perms: granted, scopes} = readScopedGrants(userData?.scopedGrants, departmentId);
  for (const [key, value] of Object.entries(granted)) merged[key] = value;
  return Object.keys(scopes).length > 0 ? {perms: merged, scopes} : {perms: merged};
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
    const perms = basePerms();
    perms.vad = data.viewAllDepartments === true;
    perms.mr = data.manageReports === true;
    perms.md = data.manageDashboard === true;
    perms.agd = data.approveGeneralDecisions === true;
    perms.sap = data.selfAssignProjects === true;
    return perms;
  }

  if (!(CONFIGURABLE_ROLES as readonly string[]).includes(role)) return undefined;

  const doc = await db().collection("settings").doc("rolePermissions").get();
  const data = doc.exists ? doc.data() ?? {} : {};
  const granted: string[] = Array.isArray(data[role]) ? data[role] : DEFAULT_ROLE_PERMS[role] ?? [];

  // ــــ مفتاح لم يعرفه المستند لا يُقرأ «ممنوعاً» ــــ
  //
  // مستند settings/rolePermissions مكتوبٌ فعلاً في المنصة الحيّة والمخزَّن
  // يُقدَّم على المبدئي. فأي صلاحية تُضاف بعد كتابته تكون غائبة عنه، وتُقرأ
  // منعاً — فيفقد كل مستخدم قائم ميزةً لم يقرّر أحد منعها. وقد وقع هذا مع
  // `sfb` وعولج باستثناء خاص؛ وهذا يعالج الصنف كله.
  //
  // والحقل يكتبه العميل عند كل حفظ (RolePermissionsConfig.knownKeysField).
  const known: string[] = Array.isArray(data._knownKeys) ? data._knownKeys.map((k: unknown) => String(k)) : [];
  const unknownDefaults = (DEFAULT_ROLE_PERMS[role] ?? []).filter((key) => !known.includes(key));

  const perms = basePerms();
  for (const key of [...granted, ...unknownDefaults]) {
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

/** هل يشمل نطاق صلاحية في البطاقة هذه الإدارة؟ */
function tokenScopeCovers(
  auth: CallableRequest["auth"],
  key: string,
  departmentId: string | null,
): boolean {
  const perms = auth?.token.perms as Record<string, boolean> | undefined;
  if (perms?.[key] !== true) return false;
  const scopes = auth?.token.scopes as Record<string, unknown> | undefined;
  const scope = scopes?.[key];
  if (scope === "*") return true;
  // نطاق غائب ليس «الكل»: علَمٌ بلا نطاق لا يمنح شيئاً.
  if (!Array.isArray(scope) || !departmentId) return false;
  return scope.map((d) => String(d)).includes(departmentId);
}

/**
 * يقرأ قائمة معرّفات حسابات من حمولة طلبٍ كتبها العميل.
 *
 * **الحمولة لا يُوثَق بها** — كما في `requestedRole` في طلب التسجيل: مستند
 * الطلب يكتبه العميل، فتُنقّى القيم هنا حقلاً حقلاً بدل تمريرها كما وردت.
 * والتكرار يُزال: عضوٌ مكرَّر في القائمة يجعل عدّ الأعضاء كاذباً.
 */
function uidList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const uid = item.trim();
    if (uid && !out.includes(uid)) out.push(uid);
  }
  return out;
}

// ــــــــــــــ رتبة الإسناد: من يحقّ له أن يُسنِد إلى مَن ــــــــــــــ
//
// نظير `lib/models/assignment_policy.dart` و`roleRank` في `firestore.rules`.
// والثلاثة تُقرأ معاً: من غيّر واحداً ولم يغيّر أخويه فتح ثغرة أو أغلق باباً
// مشروعاً. والجدول مكتوب في المواضع الثلاثة صراحةً لأن لا سبيل لمشاركته
// بينها — لغاتٌ ثلاث ومحرّكاتٌ ثلاثة.
const ASSIGN_RANK: Record<string, number> = {
  systemAdmin: 5,
  executiveViewer: 4,
  departmentManager: 3,
  projectOfficer: 2,
  custom: 2,
  employee: 1,
};

function assignRank(role: string | undefined): number {
  return ASSIGN_RANK[role ?? "employee"] ?? 1;
}

/**
 * يرفض الطلب إن كان في [uids] من هو أعلى رتبةً من [actorUid].
 *
 * **والرسالة تسمّي المخالِف**: «لا يمكنك الإسناد إلى هذا المستخدم» يترك من
 * اختار عشرة أسماء يخمّن أيّها المقصود، فيحذفهم واحداً واحداً حتى يمرّ.
 */
async function assertAssignable(
  uids: string[],
  actorUid: string,
  actorRole: string | undefined,
  departmentId?: string | null,
): Promise<void> {
  const actorRank = assignRank(actorRole);
  if (actorRole === "systemAdmin") return;
  for (const uid of uids) {
    // المرء يُسنِد إلى نفسه دائماً — رتبته رتبته، ولا حاجة لقراءة سجلّه.
    if (uid === actorUid) continue;
    const snap = await db().collection("users").doc(uid).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", `لا يوجد حساب بهذا المعرّف: ${uid}`);
    }
    const data = snap.data() ?? {};
    const targetRole = data.role as string | undefined;
    // النطاق يُفحص هنا وقد قُرئ السجل أصلاً — بلا قراءة إضافية.
    if (departmentId) {
      const ids = Array.isArray(data.departmentIds) ? data.departmentIds.map(String) : [];
      if (data.departmentId !== departmentId && !ids.includes(departmentId)) {
        throw new HttpsError(
          "permission-denied",
          `"${data.name ?? uid}" ليس من هذه الإدارة، فلا يُسنَد إليها.`,
        );
      }
    }
    if (assignRank(targetRole) > actorRank) {
      throw new HttpsError(
        "permission-denied",
        `لا يمكنك إسناد هذا العمل إلى "${data.name ?? uid}" — ` +
        "فدوره أعلى من دورك في ترتيب الإسناد. الإسناد إلى من هو أعلى " +
        "يقوم به مسؤول النظام.",
      );
    }
  }
}

/** رسالة موجَّهة لمستلم بعينه — لكلٍّ عنوانه ونصّه. */
interface OutgoingMessage {
  uid: string;
  subject: string;
  body: string;
}

/**
 * يُسلّم رسائل مخصَّصة لمستلميها، ويرمي عند أول إخفاق فعلي.
 *
 * تعريف **واحد** يستعمله مساران: إرسال مسؤول النظام المباشر
 * (`sendUserNotification`)، واعتماد طلب `notifySend`. ولولا ذلك لافترقا:
 * أحدهما يُبلّغ بفشل البريد والآخر يبتلعه، فيقول مركز القرار «اعتُمد» بينما
 * لم تصل رسالة واحدة.
 *
 * والرسائل مخصَّصة لا نصّاً واحداً للجميع، لأن تنبيه المشاريع المتأخرة يسرد
 * لكل مسؤول مشاريعَه هو.
 */
async function deliverMessages(messages: OutgoingMessage[], channel: string | undefined): Promise<number> {
  const channels = {
    email: channel === "email" || channel === "both",
    whatsapp: channel === "whatsapp" || channel === "both",
  };
  // قناة مجهولة كانت تمرّ بنجاح صامت: `notifyUser` تُستدعى بقناتين مطفأتين
  // فلا تُرسل شيئاً، ومُرشِّح الإخفاقات أدناه لا يجد ما يشتكي منه — فيُقال
  // للمستخدم «تم الإرسال» ولم يُرسَل شيء. تُرفض صراحةً.
  if (!channels.email && !channels.whatsapp) {
    throw new HttpsError("invalid-argument", "قناة الإرسال غير محددة");
  }
  if (!messages.length) throw new HttpsError("invalid-argument", "لا يوجد مستلمون");

  const results = await Promise.all(
    messages.map(async (m) => ({
      uid: m.uid,
      result: await notifyUser(m.uid, m.subject || "إشعار من المنصة التنفيذية الحكومية", m.body, channels),
    })),
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

  return messages.length;
}

/**
 * يقرأ رسائل طلب `notifySend` من حمولته.
 *
 * **الحمولة لا يُوثَق بها** — كما في طلب التسجيل: مستند الطلب يكتبه العميل،
 * فتُنقّى هنا حقلاً حقلاً بدل تمريرها كما وردت. ومسؤول النظام يقرأ النصّ في
 * بطاقة الطلب قبل الاعتماد، فالحدّ الأدنى أن يكون ما قرأه هو ما يُرسَل.
 */
function messagesFromPayload(payload: Record<string, unknown>): OutgoingMessage[] {
  const raw = Array.isArray(payload.messages) ? payload.messages : [];
  const messages: OutgoingMessage[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const m = item as Record<string, unknown>;
    const uid = typeof m.uid === "string" ? m.uid.trim() : "";
    const body = typeof m.body === "string" ? m.body.trim() : "";
    if (!uid || !body) continue;
    messages.push({
      uid,
      subject: typeof m.subject === "string" ? m.subject.trim() : "",
      body,
    });
  }
  return messages;
}

/**
 * من يبتّ في كل نوع من الطلبات.
 *
 * **تسجيل الأعضاء** و**تعديل المواعيد النهائية** يبقيان حصراً لمسؤول النظام
 * ولا يفتحهما أي مفتاح — لم يطلب مسؤول النظام فتحهما.
 *
 * أما **إضافة المشاريع** فقد قرّر فتحها صراحةً عبر مفتاح بيده: `apr` تُمنح
 * لفرد بعينه ضمن نطاق إدارات، وهي مغلقة افتراضياً وقابلة للسحب. والنطاق
 * يُقاس بإدارة **الطلب نفسه** كما هي في مستنده على الخادم، لا كما يرسلها
 * العميل.
 *
 * و**إضافة الأعمال** نوع جديد ليس من البوابات: يعتمده مدير الإدارة صاحبته،
 * أو صاحب `mpr` في نطاقها.
 */
function checkApprovalPermission(
  type: string,
  auth: CallableRequest["auth"],
  departmentId: string | null,
) {
  const callerRole = auth?.token.role as string | undefined;
  const perms = auth?.token.perms as Record<string, boolean> | undefined;
  const isAdmin = callerRole === "systemAdmin";

  let allowed: boolean;
  switch (type) {
    case "decision":
      allowed = isAdmin || callerRole === "executiveViewer" || perms?.agd === true;
      break;
    case "projectCreate":
      allowed = isAdmin || tokenScopeCovers(auth, "apr", departmentId);
      break;
    case "workCreate": {
      const myDepts = callerRole === "departmentManager" ?
        ((auth?.token.departmentIds as string[] | undefined) ?? []) :
        [];
      allowed = isAdmin ||
        (departmentId !== null && myDepts.includes(departmentId)) ||
        tokenScopeCovers(auth, "mpr", departmentId);
      break;
    }
    // registration و deadlineChange و notifySend و managerChange: مسؤول
    // النظام وحده، بلا استثناء. و`notifySend` أُلحقت بهنّ بقرار صريح منه: كل بريد يخرج باسم
    // المنصة يمرّ بموافقته. ولا يفتحها مفتاح مفوَّض — لا `ntf` ولا غيرها —
    // وإلا لعاد الإرسال بلا رقابة من باب آخر.
    default:
      allowed = isAdmin;
  }
  if (!allowed) {
    throw new HttpsError("permission-denied", "ليست لديك صلاحية البت في هذا النوع من الطلبات");
  }
}

export const approveRequest = onCall({secrets: notificationSecrets}, async (request) => {
  const auth = requireAuth(request);
  const {requestId, note, payloadOverride} = (request.data ?? {}) as {
    requestId?: string;
    note?: string;
    payloadOverride?: Record<string, unknown>;
  };
  if (!requestId) throw new HttpsError("invalid-argument", "معرف الطلب مطلوب");

  const ref = db().collection("approvalRequests").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
  const data = snap.data()!;
  if (data.status !== "pending") throw new HttpsError("failed-precondition", "تم البت في هذا الطلب مسبقاً");

  checkApprovalPermission(data.type, auth, (data.departmentId as string | null) ?? null);

  const stored = (data.payload ?? {}) as Record<string, unknown>;

  // ــــ تعديل الطلب قبل اعتماده: لمسؤول النظام وحده ــــ
  //
  // والفحص هنا لا في الواجهة. ولمَ لا يُعطى لصاحب `apr`؟ لأن تاريخ
  // الاستحقاق من الحمولة، فتعديله من داخل الطلب يصير باباً جانبياً حول
  // بوابة «تعديل المواعيد النهائية» المحصورة بمسؤول النظام وحده. وصاحب
  // `apr` يعتمد الطلب كما قُدّم أو يرفضه.
  const isAdminCaller = auth.token.role === "systemAdmin";
  if (payloadOverride && !isAdminCaller) {
    throw new HttpsError("permission-denied", "تعديل الطلب قبل اعتماده لمسؤول النظام وحده");
  }
  // التعديل يقتصر على `projectCreate` و`workCreate`: حمولة طلب التسجيل
  // تحمل هوية حساب، وتعديلها اعتمادٌ لشخص غير الذي طلب.
  if (payloadOverride && data.type !== "projectCreate" && data.type !== "workCreate") {
    throw new HttpsError("failed-precondition", "هذا النوع من الطلبات لا يُعدَّل قبل اعتماده");
  }
  const payload: Record<string, unknown> = payloadOverride ? {...stored, ...payloadOverride} : stored;

  switch (data.type) {
    case "registration": {
      const uid = payload.uid as string;
      const role = payload.requestedRole as string;
      const departmentId = (payload.requestedDepartmentId as string | null) ?? null;
      const sectionId = (payload.requestedSectionId as string | null) ?? null;

      // ------- حمولة الطلب لا يُوثَق بها -------
      // مستند الطلب يكتبه العميل (قاعدة approvalRequests تسمح بالإنشاء لأي
      // مستخدم مسجَّل، وهو لازم لأن المسجِّل الجديد غير معتمد بعد). ومسؤول
      // النظام لا يرى في بطاقة الطلب إلا عنواناً ووصفاً كتبهما العميل أيضاً.
      // فلو أُخذ الدور من الحمولة بلا فحص لأمكن تقديم طلب وصفه «موظف»
      // وحمولته systemAdmin، فيُمنَح باعتمادٍ يبدو روتينياً. الفحوص الثلاثة
      // التالية هي ما يجعل البوابة تحرس فعلاً لا شكلاً.

      // ١) لا يُمنح عبر التسجيل إلا دور أساسي مضبوط الصلاحيات. وعلى رأس
      // المستبعَد systemAdmin: مسؤول النظام لا يُصنع إلا بـ setUserRole.
      if (!(CONFIGURABLE_ROLES as readonly string[]).includes(role)) {
        throw new HttpsError(
          "invalid-argument",
          "الدور المطلوب في هذا الطلب غير مسموح به عند التسجيل. " +
          "الأدوار المسموحة: مستخدم تنفيذي، مدير إدارة، مدير مشروع، موظف. " +
          "لمنح دور آخر استخدم شاشة إدارة المستخدمين بعد الاعتماد.",
        );
      }

      // ٢) الطلب يخصّ مقدّمه وحده، فلا يُقدَّم طلب تسجيل باسم حساب آخر.
      if (!uid || uid !== data.requestedByUid) {
        throw new HttpsError("invalid-argument", "حمولة طلب التسجيل لا تطابق مُقدّمه.");
      }

      // ٣) مسار التسجيل يعتمد حساباً منتظراً فقط. ولولا هذا الشرط لأمكن
      // إعادة استعمال طلب تسجيل قديم لتغيير دور حساب معتمد.
      const userSnap = await db().collection("users").doc(uid).get();
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "سجل المستخدم المطلوب اعتماده غير موجود.");
      }
      if (userSnap.data()?.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "هذا الحساب لم يعد بانتظار الاعتماد. لتغيير دوره استخدم شاشة إدارة المستخدمين.",
        );
      }
      // استثناء مسؤول النظام من شرطَي التأكيد والنطاق — حقل لا يكتبه غيره.
      const exempt = userSnap.data()?.emailVerificationExempt === true;

      // شرط البريد الوزاري المؤكَّد يُفحص **هنا** لا في المتصفح: هذه هي
      // بوابة الاعتماد الفعلية، وأي فحص في الواجهة يمكن تجاوزه. ومسؤول
      // النظام يستثني من يشاء بحقل على سجل المستخدم لا يكتبه غيره.
      const policySnap = await db().collection("settings").doc("registration").get();
      const policy = policySnap.exists ? policySnap.data() ?? {} : {};
      const requireVerification = policy.requireEmailVerification !== false;
      // حساب المصادقة هو مرجع البريد: `payload.email` كتبه العميل ويمكن أن
      // يخالف البريد الذي أُنشئ به الحساب فعلاً وأُرسلت إليه رسالة التأكيد.
      const account = await admin.auth().getUser(uid);
      if (requireVerification && !exempt && !account.emailVerified) {
        throw new HttpsError(
          "failed-precondition",
          "لم يؤكّد هذا الموظف بريده الوزاري بعد. اطلب منه فتح رسالة التأكيد، " +
          "أو امنحه استثناءً من شاشة إدارة المستخدمين ثم أعد المحاولة.",
        );
      }

      // النطاق المسموح يُفحص هنا أيضاً: نموذج التسجيل يفحصه لطفاً بالموظف،
      // لكن الاعتماد لا يجوز أن يعتمد على فحص جرى في متصفحه.
      const domains: string[] = Array.isArray(policy.allowedEmailDomains) ?
        policy.allowedEmailDomains.map((d: unknown) => String(d).trim().toLowerCase()) :
        [];
      if (domains.length > 0) {
        const email = String(account.email ?? "").trim().toLowerCase();
        const at = email.lastIndexOf("@");
        const domain = at >= 0 ? email.slice(at + 1) : "";
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
      // بصمات الصلاحيات تُختم **هنا** مع بقية البطاقة.
      //
      // وغيابها كان عطلاً صامتاً: الحساب المعتمَد حديثاً يخرج بلا حقل `perms`
      // إطلاقاً، فكل `perm(key)` في القواعد يعود false مهما منح مسؤول النظام
      // لدوره — ولا يُصلَح إلا بإعادة ختم لاحقة قد لا تقع أبداً.
      await admin.auth().setCustomUserClaims(uid, {
        role, departmentId, departmentIds, approved: true,
        ...claimPermissions(await loadCustomRolePerms(role, null), userSnap.data(), departmentId),
      });
      // القسم يُحفظ في السجل ولا يدخل بطاقة الدخول: لا قاعدة أمان تحتكم إليه،
      // وبطاقة الدخول لها حدّ حجم صارم فلا تُثقَل بما لا يُفحص عليها.
      await db().collection("users").doc(uid)
        .update({role, departmentId, departmentIds, sectionId, status: "approved"});
      break;
    }
    case "projectCreate": {
      // ــــ العضوية تُكتب، ولا تُترك فارغة ــــ
      //
      // كان يُكتب `managerUid: null` بلا `managerUids` ولا `executorUids`
      // إطلاقاً، فيخرج المشروع المُعتمَد **بلا عضو واحد**. و«المُسنَد إليّ»
      // مبنيّة على العضوية، فلا تجد شيئاً — ولا لمقدّم الطلب نفسه الذي
      // سجّل نفسه منفّذاً عند تقديمه.
      //
      // والاتساق شرطٌ لا تجميل: قاعدة `projects` في firestore.rules تشترط
      // أن يكون `managerUid` عضواً في `managerUids`، فكتابة أحدهما دون
      // الآخر تترك مستنداً لا تقبله القاعدة عند أول تعديل عليه.
      const managerUids = uidList(payload.managerUids);
      const executorUids = uidList(payload.executorUids);
      // ــ رتبة الإسناد تُفحص هنا لا في متصفح مقدّم الطلب ــ
      //
      // والمقياس رتبة **مقدّم الطلب** لا المعتمِد: هو من اختار الفريق، وهو
      // من تسري عليه القاعدة. ولو قيست برتبة المعتمِد لصار الطلب باباً
      // جانبياً: يكتب الموظف في حمولته المسؤول التنفيذي، فيعتمده مسؤول
      // النظام روتينياً فيمرّ ما لا يحقّ للموظف أن يفعله بيده.
      const requesterSnap = await db().collection("users").doc(String(data.requestedByUid ?? "")).get();
      await assertAssignable(
        [...managerUids, ...executorUids],
        String(data.requestedByUid ?? ""),
        requesterSnap.data()?.role as string | undefined,
      );
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
        managerUids,
        executorUids,
        managerUid: managerUids.length ? managerUids[0] : null,
        // تاريخ الإضافة الحقيقي — لا تاريخ البدء. وبه يعمل ترتيب «الأحدث».
        createdAt: now(),
        // القسم داخل الإدارة كما اختاره مقدّم الطلب (null = تحت الإدارة مباشرةً).
        sectionId: payload.sectionId ?? null,
      });
      break;
    }
    case "workCreate": {
      // العمل التشغيلي ليس من بوابات الاعتماد: يعتمده مدير الإدارة صاحبته.
      // والإدارة تُؤخذ من **مستند الطلب** لا من الحمولة، فهي التي فُحص عليها
      // نطاق المعتمِد قبل قليل — وإلا لأمكن أن يُفحص نطاقٌ ويُكتب غيره.
      //
      // ورتبة الإسناد تُفحص برتبة مقدّم الطلب للسبب نفسه المشروح أعلاه.
      const workAssignee = typeof payload.assigneeUid === "string" ? payload.assigneeUid.trim() : "";
      if (workAssignee) {
        const reqSnap = await db().collection("users").doc(String(data.requestedByUid ?? "")).get();
        await assertAssignable(
          [workAssignee],
          String(data.requestedByUid ?? ""),
          reqSnap.data()?.role as string | undefined,
        );
      }
      await db().collection("works").doc().set({
        departmentId: data.departmentId ?? null,
        title: payload.title,
        description: payload.description ?? "",
        assigneeUid: payload.assigneeUid ?? null,
        assigneeName: payload.assigneeName ?? "",
        priority: payload.priority ?? "medium",
        progressPercent: 0,
        dueDate: admin.firestore.Timestamp.fromDate(new Date(payload.dueDate as string)),
        completedDate: null,
        createdByUid: data.requestedByUid,
        createdAt: now(),
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
    // ــ تغيير مدير المشروع ــ
    //
    // يطلبه مدير الإدارة أو المستخدم التنفيذي، ولا يبتّ فيه إلا مسؤول
    // النظام (راجع `checkApprovalPermission`). والأثر يُكتب في سجل التدقيق
    // باسمَي المدير القديم والجديد ومقدّم الطلب — فلا ينتقل مشروع من يدٍ
    // إلى يد بلا سطرٍ يقول من نقله ومتى ولماذا.
    case "managerChange": {
      const newUid = payload.newManagerUid as string | undefined;
      if (!newUid) {
        throw new HttpsError("failed-precondition", "الطلب لا يحمل مديراً جديداً");
      }
      const projectId = payload.projectId as string;
      const projectRef = db().collection("projects").doc(projectId);
      const snap = await projectRef.get();
      if (!snap.exists) {
        throw new HttpsError("failed-precondition", "المشروع لم يعد موجوداً");
      }
      // القائمة **تُستبدل** لا يُضاف إليها: «تغيير المدير» يعني أن من كان
      // يقود لم يعد يقود. ومن أراد مديرين اثنين يضيفهما من صفحة المشروع.
      await projectRef.update({
        managerUids: [newUid],
        managerUid: newUid,
      });
      const oldNames = (payload.currentManagerNames as string[] | undefined) ?? [];
      await logAudit(
        auth.token.name ?? "مسؤول النظام",
        "تغيير مدير المشروع",
        `اعتُمد نقل قيادة المشروع "${payload.projectName ?? projectId}" من ` +
          `${oldNames.length ? oldNames.join("، ") : "بلا مدير"} إلى ` +
          `${payload.newManagerName ?? newUid} — بطلب من ${data.requestedByName ?? "مستخدم"}` +
          `${payload.reason ? ` — السبب: ${payload.reason}` : ""}`,
      );
      break;
    }
    case "notifySend": {
      const messages = messagesFromPayload(payload);
      if (!messages.length) {
        throw new HttpsError("failed-precondition", "لا توجد رسائل صالحة في هذا الطلب");
      }
      // الإرسال **قبل** ختم الطلب بـ«معتمَد» أدناه: لو أخفق البريد فعلياً
      // رمت `deliverMessages` وبقي الطلب معلّقاً كما هو، فيُعاد اعتماده بعد
      // معالجة السبب. ولو خُتم أولاً لصار في السجل بريد «معتمَد» لم يصل،
      // ولا سبيل لإعادة إرساله لأن الطلب لم يعد معلّقاً.
      await deliverMessages(messages, payload.channel as string | undefined);
      await logAudit(
        auth.token.name ?? "مسؤول النظام",
        "إرسال إشعار",
        `اعتُمد وأُرسل بريد إلى ${messages.length} مستخدم(ين) بطلب من ${data.requestedByName ?? "مستخدم"}`,
      );
      break;
    }
    case "decision":
      // لا حاجة لأي تعديل إضافي على البيانات، القرار توثيقي بحت.
      break;
    default:
      throw new HttpsError("invalid-argument", "نوع طلب غير معروف");
  }

  // الحمولة المعدَّلة تُحفظ على الطلب: ما اعتُمد غير ما طُلب، ومن قدّم الطلب
  // له حقّ أن يرى ما صار إليه — ولا يُترك المستند يقول غير ما نُفّذ.
  await ref.update({
    status: "approved",
    resolutionNote: note ?? null,
    resolvedDate: now(),
    ...(payloadOverride ? {payload, editedByApprover: true} : {}),
  });
  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "اعتماد طلب",
    payloadOverride ?
      `تم اعتماد طلب بعد تعديله: "${data.title}" (الحقول المعدَّلة: ${Object.keys(payloadOverride).join("، ")})` :
      `تم اعتماد طلب: "${data.title}"`,
  );

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

  checkApprovalPermission(data.type, auth, (data.departmentId as string | null) ?? null);

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

  const rolePerms = await loadCustomRolePerms(role, customRoleId);
  // مدير الإدارة قد يدير أكثر من إدارة (departmentIds)؛ بقية الأدوار تستخدم departmentId مفرد.
  const deptIds = role === "departmentManager" ? departmentIds ?? [] : [];

  const userRecord = await admin.auth().createUser({email, password, displayName: name});
  // حسابٌ جديد بلا منح نطاقات — تُمنح لاحقاً من شاشة صلاحيات المستخدم.
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    role,
    departmentId: departmentId ?? null,
    departmentIds: deptIds,
    approved: true,
    ...claimPermissions(rolePerms, undefined, departmentId ?? null),
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

  const claimPerms = claimPermissions(
    await loadCustomRolePerms(role, customRoleId), current, departmentId ?? null);
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
    ...claimPerms,
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
  await admin.auth().setCustomUserClaims(uid, {
    role: current.role,
    departmentId: current.departmentId ?? null,
    departmentIds: current.departmentIds ?? [],
    approved,
    ...claimPermissions(
      await loadCustomRolePerms(current.role, current.customRoleId),
      current,
      (current.departmentId as string | null) ?? null,
    ),
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

  const rolePerms = await loadCustomRolePerms(role, null);
  const snap = await db().collection("users").where("role", "==", role).get();

  let updated = 0;
  for (const doc of snap.docs) {
    const u = doc.data();
    // الاستثناء الفردي يُطبَّق لكل حساب على حدة، وإلا محا تعديلُ صلاحيات
    // الدور استثناءاتٍ منحها مسؤول النظام لأشخاص بأعيانهم.
    try {
      await admin.auth().setCustomUserClaims(doc.id, {
        role,
        departmentId: u.departmentId ?? null,
        departmentIds: u.departmentIds ?? [],
        approved: u.status === "approved",
        ...claimPermissions(rolePerms, u, (u.departmentId as string | null) ?? null),
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
  const {uids, uid, channel, subject, message, messages} = (request.data ?? {}) as {
    uids?: string[];
    uid?: string;
    channel?: string;
    subject?: string;
    message?: string;
    messages?: unknown;
  };

  // شكلان مقبولان، وشكل **واحد** داخلي:
  //   `messages` — رسالة مخصَّصة لكل مستلم (تنبيه المتأخرات يسرد لكلٍّ مشاريعه).
  //   `uids`/`uid` مع `message` — نصّ واحد للجميع (نموذج المراسلة العادي).
  // والثاني يُحوَّل إلى الأول فوراً، فلا يوجد مساران للتسليم يفترقان.
  const outgoing = Array.isArray(messages) ?
    messagesFromPayload({messages}) :
    (() => {
      const targets = uids && uids.length ? uids : uid ? [uid] : [];
      if (!targets.length || !message) return [];
      return targets.map((t) => ({uid: t, subject: subject ?? "", body: message}));
    })();
  if (!outgoing.length) throw new HttpsError("invalid-argument", "بيانات ناقصة");

  // ــــ الإرسال المباشر لمسؤول النظام وحده ــــ
  //
  // كان هنا `requireNotifyAccess` فيرسل صاحب `ntf` فوراً. وهذا السطر هو
  // البوابة نفسها لا زينةً حولها: تبديلُ نموذج الواجهة وحده يترك هذه الدالة
  // مفتوحة، ونسخةٌ قديمة من التطبيق مخزَّنة في متصفح المستخدم تكفي لاستدعائها
  // مباشرةً وتخطّي الاعتماد كله. فمن دون مسؤول النظام يمرّ بطلب `notifySend`.
  const auth = requireAdmin(request);

  const sent = await deliverMessages(outgoing, channel);

  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "إرسال إشعار",
    `أُرسل إشعار (${channel}) إلى ${sent} مستخدم(ين)`,
  );

  return {ok: true, sent};
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
  const claims = {
    role,
    departmentId: (u.departmentId as string | null) ?? null,
    // حسابات أُنشئت قبل حقل الإدارات الجمع تحمل المفرد وحده؛ نشتقّ منه القائمة
    // حتى لا يبقى مدير إدارة بنطاق فارغ فلا يرى شيئاً.
    departmentIds: Array.isArray(u.departmentIds) && u.departmentIds.length > 0 ?
      u.departmentIds :
      (role === "departmentManager" && u.departmentId ? [u.departmentId] : []),
    approved: u.status === "approved",
    ...claimPermissions(
      await loadCustomRolePerms(role, (u.customRoleId as string | null) ?? null),
      u,
      (u.departmentId as string | null) ?? null,
    ),
  };
  await admin.auth().setCustomUserClaims(uid, claims);
  return claims;
}

/**
 * يضبط **الاستثناءات الفردية** لصلاحيات مستخدم بعينه، ويعيد ختم بطاقته فوراً.
 *
 * وهذا هو ما يجعل المنح «لأي مستخدم» ممكناً: مسؤول النظام يمنح أو يمنع
 * صلاحيةً لشخص واحد دون تغيير دوره ولا مساس بزملائه في الدور نفسه.
 *
 * القيمة `true` منحٌ، و`false` منعٌ، وحذف المفتاح رجوعٌ إلى إعدادات الدور.
 * والمفاتيح المجهولة تُرفض صراحةً لا تُهمَل بصمت — فمفتاح أُسيء كتابته يبدو
 * ممنوحاً في الشاشة ولا يعمل أبداً. ولا سبيل من هنا إلى بوابات الاعتماد
 * الثلاث: ليست مفاتيح صلاحيات أصلاً.
 */
export const setUserPermissionOverrides = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {uid, overrides} = (request.data ?? {}) as {uid?: string; overrides?: Record<string, unknown>};
  if (!uid) throw new HttpsError("invalid-argument", "الرجاء تحديد المستخدم");

  const clean: Record<string, boolean> = {};
  for (const [key, value] of Object.entries(overrides ?? {})) {
    if (!(CUSTOM_ROLE_PERM_KEYS as readonly string[]).includes(key)) {
      throw new HttpsError("invalid-argument", `صلاحية غير معروفة: ${key}`);
    }
    if (typeof value !== "boolean") {
      throw new HttpsError("invalid-argument", `قيمة غير صالحة للصلاحية ${key}`);
    }
    clean[key] = value;
  }

  const userRef = db().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new HttpsError("not-found", "المستخدم غير موجود");

  await userRef.update({permissionOverrides: clean});
  const claims = await restampClaims(uid);

  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "ضبط صلاحيات فردية",
    `تم ضبط استثناءات صلاحيات المستخدم "${userDoc.data()?.name ?? uid}": ` +
    (Object.keys(clean).length === 0 ?
      "بلا استثناءات (يتبع دوره)" :
      Object.entries(clean).map(([k, v]) => `${k}=${v ? "ممنوحة" : "ممنوعة"}`).join("، ")),
  );

  return {ok: true, claims};
});

/**
 * يمنح مستخدماً بعينه صلاحيةً مقيَّدة بنطاق، أو يسحبها منه.
 *
 * وهاتان الصلاحيتان (`mpr` الإنشاء المباشر، و`apr` اعتماد طلبات إضافة
 * المشاريع) لا تُمنحان من شاشة «صلاحيات الأدوار» ولا يرثهما دور — بل من هنا
 * وحدها، لفرد، بنطاق. و`apr` منهما تفتح بوابةً كانت محصورة بمسؤول النظام
 * بقرار صريح منه، فيُسجَّل كل منح وسحب في سجل التدقيق باسم المانح والنطاق.
 *
 * ونطاق فارغ = سحب: لا يُكتب علَمٌ بلا نطاق أبداً.
 */
export const setScopedGrant = onCall(async (request) => {
  const auth = requireAdmin(request);
  const {uid, key, all, departmentIds, own} = (request.data ?? {}) as {
    uid?: string; key?: string; all?: boolean; departmentIds?: unknown; own?: boolean;
  };
  if (!uid) throw new HttpsError("invalid-argument", "الرجاء تحديد المستخدم");
  if (!key || !SCOPED_PERM_KEYS.includes(key)) {
    throw new HttpsError("invalid-argument", "هذه الصلاحية لا تُمنح بنطاق");
  }

  const userRef = db().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new HttpsError("not-found", "المستخدم غير موجود");
  const user = userDoc.data()!;

  const ids = Array.isArray(departmentIds) ? departmentIds.map((d) => String(d)).filter(Boolean) : [];
  // الإدارات تُتحقَّق من وجودها: نطاقٌ يشير إلى إدارة محذوفة يبدو منحاً وهو
  // لا يسري على شيء، ولا شيء يخبر مسؤول النظام بذلك.
  for (const id of ids) {
    const dept = await db().collection("departments").doc(id).get();
    if (!dept.exists) throw new HttpsError("invalid-argument", `إدارة غير موجودة: ${id}`);
  }
  if (own === true && !user.departmentId) {
    throw new HttpsError("failed-precondition", "لا توجد إدارة مرتبطة بهذا الحساب لتكون نطاقاً له");
  }

  const grants = {...(user.scopedGrants ?? {})} as Record<string, unknown>;
  let summary: string;
  if (all === true) {
    grants[key] = {all: true};
    summary = "كل الإدارات";
  } else if (own === true) {
    grants[key] = {all: false, own: true};
    summary = "إدارته وحدها";
  } else if (ids.length > 0) {
    grants[key] = {all: false, departmentIds: ids};
    summary = `${ids.length} إدارة`;
  } else {
    delete grants[key];
    summary = "سُحبت";
  }

  await userRef.update({scopedGrants: grants});
  const claims = await restampClaims(uid);

  await logAudit(
    auth.token.name ?? "مسؤول النظام",
    "منح صلاحية بنطاق",
    `الصلاحية "${key}" للمستخدم "${user.name ?? uid}": ${summary}`,
  );

  return {ok: true, claims};
});

/**
 * يكتب فريق المشروع (المديرون والمنفّذون) بعد فحص رتبة كل عضو.
 *
 * ــــ ولماذا دالّة، والقواعد تكفي في الأعمال؟ ــــ
 *
 * لأن المسؤول عن العمل حقلٌ **مفرد**، فتُقرأ رتبته في القاعدة بقراءة واحدة.
 * وفريق المشروع **قائمتان**، ولغة قواعد Firestore بلا حلقات: لا سبيل للمرور
 * على `executorUids` عنصراً عنصراً فيها إطلاقاً.
 *
 * فصار الفحص هنا، وضُيِّقت القاعدة لتمنع كتابة العضوية مباشرةً من العميل
 * إلا لمسؤول النظام (بلا قيد أصلاً) أو للمستخدم على **نفسه** وحده.
 */
export const setProjectTeam = onCall(async (request) => {
  const auth = requireAuth(request);
  const {projectId, managerUids: rawManagers, executorUids: rawExecutors} =
    (request.data ?? {}) as {
      projectId?: string; managerUids?: unknown; executorUids?: unknown;
    };
  if (!projectId) throw new HttpsError("invalid-argument", "معرّف المشروع مطلوب");

  const ref = db().collection("projects").doc(projectId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "المشروع غير موجود");
  const project = snap.data() ?? {};
  const departmentId = (project.departmentId as string | null) ?? null;

  const callerRole = auth.token.role as string | undefined;
  const isAdminCaller = callerRole === "systemAdmin";
  const myDepts = (auth.token.departmentIds as string[] | undefined) ?? [];
  const isDeptManager =
    callerRole === "departmentManager" && departmentId !== null && myDepts.includes(departmentId);
  if (!isAdminCaller && !isDeptManager && !tokenScopeCovers(auth, "mpr", departmentId)) {
    throw new HttpsError("permission-denied", "لا تملك صلاحية تعديل فريق هذا المشروع");
  }

  const managerUids = uidList(rawManagers);
  const executorUids = uidList(rawExecutors);
  await assertAssignable(
    [...managerUids, ...executorUids],
    auth.uid,
    callerRole,
    departmentId,
  );

  // القوائم الثلاث تُكتب معاً: القاعدة تشترط أن يكون `managerUid` عضواً في
  // `managerUids`، فكتابة أحدهما دون الآخر تترك مستنداً لا تقبله عند أول
  // تعديل عليه.
  await ref.update({
    managerUids,
    executorUids,
    managerUid: managerUids.length ? managerUids[0] : null,
  });

  await logAudit(
    (auth.token.name as string | undefined) ?? "مستخدم",
    "تعديل فريق المشروع",
    `مشروع "${project.name ?? projectId}": ${managerUids.length} مديراً و${executorUids.length} منفّذاً`,
  );
  return {ok: true};
});

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
