/**
 * تقرير السابعة صباحاً — القراءة من Firestore والكتابة والإرسال.
 *
 * الحساب كله في `daily_report.ts` بلا Firestore، وهنا وحده ما يمسّ قاعدة
 * البيانات: يقرأ اللقطة، ويبني لكل مستلمٍ تقريره **ضمن نطاقه**، ويكتبه في
 * مستندٍ خاص به، ثم يرسله بريداً.
 *
 * ــــ لماذا مستندٌ لكل مستلم؟ ــــ
 *
 * لأن قواعد Firestore **ترفض ولا تُصفّي**. فلو كان التقرير مستنداً واحداً
 * يحوي كل شيء، لَقرأ مديرُ إدارةٍ ما ليس له — أو لَرُفض عليه الاستعلام كله
 * فرأى شاشةً خالية. ومستندٌ لكل مستلم يجعل قاعدة القراءة سطراً واحداً لا
 * يحتمل الخطأ: `request.auth.uid == uid`.
 */
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {sendEmail} from "./email";
import {
  BlockerRec,
  DEFAULT_THRESHOLDS,
  DailyReport,
  ItemRec,
  ProjectRec,
  RecipientScope,
  ReportThresholds,
  Snapshot,
  UpdateRec,
  buildReport,
  emailTargets,
  renderReportHtml,
  reportSubject,
} from "./daily_report";

const db = () => admin.firestore();

/** توقيت الكويت ثابتٌ بلا توقيت صيفي، فيكفي إزاحةٌ واحدة. */
const KUWAIT_OFFSET_MS = 3 * 3600 * 1000;

/** «اليوم» بتقويم الكويت لا بتوقيت الخادم — وإلا صدر تقرير الغد أو الأمس. */
export function kuwaitToday(nowMs: number): Date {
  const k = new Date(nowMs + KUWAIT_OFFSET_MS);
  return new Date(Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate()));
}

export function dateKeyOf(day: Date): string {
  const y = day.getUTCFullYear();
  const m = String(day.getUTCMonth() + 1).padStart(2, "0");
  const d = String(day.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function toDate(v: unknown, fallback: Date): Date {
  if (v instanceof admin.firestore.Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return fallback;
}

function num(v: unknown): number {
  return typeof v === "number" ? v : 0;
}

function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function strList(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
}

interface UserRec {
  uid: string;
  name: string;
  email: string;
  role: string;
  status: string;
  departmentId: string | null;
  departmentIds: string[];
}

/** إعدادات التقرير كما يضبطها مسؤول النظام في `settings/dailyReport`. */
export interface ReportSettings {
  enabled: boolean;
  /** إرسال البريد — والعرض داخل المنصة يبقى قائماً حتى لو أُطفئ. */
  emailEnabled: boolean;
  /** عنوان المنصة الذي تُبنى منه الروابط المباشرة في البريد. */
  baseUrl: string;
  /** مستلمون إضافيون بأعيانهم، فوق من يستحقّه بدوره. */
  extraRecipientUids: string[];
  /** مستبعَدون بأعيانهم — لا يُولَّد لهم تقرير أصلاً. */
  excludedUids: string[];
  /**
   * قائمةُ سماحٍ للبريد وحده.
   *
   * فارغةً: البريد لكل من وُلِّد له تقرير. وغير فارغة: **لمن فيها وحدهم**.
   * ولا تمسّ التوليد: من له مدخل «التقرير اليومي» يبقى يقرؤه على الشاشة
   * سواءٌ وصله بريدٌ أم لا — وهو قرارٌ صريح من مسؤول النظام.
   */
  emailRecipientUids: string[];
  thresholds: ReportThresholds;
}

export function readSettings(
  raw: Record<string, unknown> | undefined,
  alertRules: Record<string, unknown> | undefined,
  projectId: string,
): ReportSettings {
  const r = raw ?? {};
  return {
    enabled: r.enabled !== false,
    emailEnabled: r.emailEnabled !== false,
    baseUrl: str(r.baseUrl) || `https://${projectId}.web.app`,
    extraRecipientUids: strList(r.extraRecipientUids),
    excludedUids: strList(r.excludedUids),
    emailRecipientUids: strList(r.emailRecipientUids),
    thresholds: {
      // العتبتان الأوليان تُقرآن من `settings/alertRules` القائمة إن لم
      // تُضبطا هنا، فلا يكون للمنصة عتبتا «قريب الاستحقاق» مختلفتان.
      dueSoonDays: num(r.dueSoonDays) || num(alertRules?.dueSoonDays) ||
        DEFAULT_THRESHOLDS.dueSoonDays,
      staleUpdateDays: num(r.staleUpdateDays) || num(alertRules?.staleUpdateDays) ||
        DEFAULT_THRESHOLDS.staleUpdateDays,
      lagMarginPercent: num(r.lagMarginPercent) || DEFAULT_THRESHOLDS.lagMarginPercent,
    },
  };
}

/**
 * من يستحقّ التقرير.
 *
 * **المستوى الإشرافي وحده** بقرار صريح: مسؤول النظام، والمسؤول التنفيذي،
 * ومدير الإدارة، ومن يقود مشروعاً فعلاً — ولو كان دوره الأساسي «موظفاً»،
 * فقيادة المشروع صفةٌ على المشروع لا دورٌ على الشخص. ولا نسخة للموظف
 * العادي: التقرير أداةُ إشراف لا لوحةُ عملٍ شخصية.
 */
export function scopesFor(
  users: UserRec[],
  projects: ProjectRec[],
  settings: ReportSettings,
): RecipientScope[] {
  const ledBy = new Map<string, string[]>();
  for (const p of projects) {
    for (const uid of p.managerUids) {
      ledBy.set(uid, [...(ledBy.get(uid) ?? []), p.id]);
    }
  }

  const out: RecipientScope[] = [];
  for (const u of users) {
    if (u.status !== "approved") continue;
    if (settings.excludedUids.includes(u.uid)) continue;

    const led = ledBy.get(u.uid) ?? [];
    const viewsAll = u.role === "systemAdmin" || u.role === "executiveViewer";
    const isHead = u.role === "departmentManager";
    const forced = settings.extraRecipientUids.includes(u.uid);
    if (!viewsAll && !isHead && led.length === 0 && !forced) continue;

    const departmentIds = isHead || forced ?
      [...new Set([...(u.departmentId ? [u.departmentId] : []), ...u.departmentIds])] :
      [];

    out.push({
      uid: u.uid,
      name: u.name,
      viewsAll,
      departmentIds,
      projectIds: led,
      label: scopeLabel(viewsAll, departmentIds.length, led.length),
    });
  }
  return out;
}

function scopeLabel(viewsAll: boolean, deptCount: number, projectCount: number): string {
  if (viewsAll) return "كل الإدارات";
  const parts: string[] = [];
  if (deptCount === 1) parts.push("إدارتك");
  else if (deptCount > 1) parts.push(`${deptCount} إدارات تديرها`);
  if (projectCount === 1) parts.push("والمشروع الذي تقوده");
  else if (projectCount > 1) parts.push(`و${projectCount} مشاريع تقودها`);
  return parts.length ? parts.join(" ") : "ما أُسنِد إليك";
}

// ============================ قراءة اللقطة ============================

/**
 * كم يوماً من التحديثات تُقرأ.
 *
 * الأبواب تحتاج آخر ٢٤ ساعة **وآخر تحديثٍ مهما قدُم** — والثاني يحتاج نافذةً
 * أوسع. وثلاثون يوماً تكفي: ما لم يُحدَّث منذ شهر يُصنَّف «قديماً» بأي عتبة
 * معقولة، فقراءة أبعد منه لا تغيّر التصنيف وتُثقل التشغيل.
 */
const UPDATE_WINDOW_DAYS = 30;

export async function loadSnapshot(
  today: Date,
  thresholds: ReportThresholds,
): Promise<{snap: Snapshot; users: UserRec[]}> {
  const since = admin.firestore.Timestamp.fromDate(
    new Date(today.getTime() - UPDATE_WINDOW_DAYS * 86400000),
  );

  const [
    usersSnap, projectsSnap, tasksSnap, worksSnap, blockersSnap,
    dailySnap, workUpdatesSnap,
  ] = await Promise.all([
    db().collection("users").get(),
    db().collection("projects").get(),
    db().collection("tasks").get(),
    db().collection("works").get(),
    db().collection("blockers").get(),
    db().collection("dailyUpdates").where("date", ">=", since).get(),
    db().collection("workUpdates").where("date", ">=", since).get(),
  ]);

  const users: UserRec[] = usersSnap.docs.map((d) => {
    const j = d.data();
    return {
      uid: d.id,
      name: str(j.name),
      email: str(j.email),
      role: str(j.role),
      status: str(j.status),
      departmentId: str(j.departmentId) || null,
      departmentIds: strList(j.departmentIds),
    };
  });
  const nameOf = new Map(users.map((u) => [u.uid, u.name]));

  const projects: ProjectRec[] = projectsSnap.docs.map((d) => {
    const j = d.data();
    const managerUids = strList(j.managerUids);
    return {
      id: d.id,
      name: str(j.name),
      departmentId: str(j.departmentId),
      status: str(j.status),
      progressPercent: num(j.progressPercent),
      startDate: toDate(j.startDate, today),
      dueDate: toDate(j.dueDate, today),
      managerUids,
      managerNames: managerUids.map((uid) => nameOf.get(uid) ?? uid),
    };
  });
  const projectById = new Map(projects.map((p) => [p.id, p]));

  const closureOf = (j: Record<string, unknown>) => {
    const c = (j.closure ?? {}) as Record<string, unknown>;
    return {
      approverUid: str(c.approverUid),
      approverName: str(c.approverName),
      claimedByName: str(c.claimedByName),
      claimedAt: c.claimedAt instanceof admin.firestore.Timestamp ?
        c.claimedAt.toDate() :
        null,
    };
  };

  const tasks: ItemRec[] = tasksSnap.docs.map((d) => {
    const j = d.data();
    const projectId = str(j.projectId) || null;
    const p = projectId ? projectById.get(projectId) : undefined;
    return {
      id: d.id,
      kind: "task" as const,
      title: str(j.title),
      departmentId: str(j.departmentId),
      projectId,
      projectName: p?.name ?? null,
      projectManagerName: p && p.managerNames.length ? p.managerNames.join("، ") : null,
      assigneeUid: str(j.assigneeUid),
      assigneeName: str(j.assigneeName),
      status: str(j.status),
      progressPercent: num(j.progressPercent),
      dueDate: toDate(j.dueDate, today),
      lastUpdated: toDate(j.lastUpdated, today),
      // المهمة لا تحمل تاريخ إنشاء — راجع `ItemRec.createdAt`.
      createdAt: null,
      ...closureOf(j),
    };
  });

  const works: ItemRec[] = worksSnap.docs.map((d) => {
    const j = d.data();
    return {
      id: d.id,
      kind: "work" as const,
      title: str(j.title),
      departmentId: str(j.departmentId),
      // العمل التشغيلي لا يحمل مشروعاً في نموذج البيانات — راجع `ItemRec`.
      projectId: null,
      projectName: null,
      projectManagerName: null,
      assigneeUid: str(j.assigneeUid),
      assigneeName: str(j.assigneeName),
      status: str(j.status),
      progressPercent: num(j.progressPercent),
      dueDate: toDate(j.dueDate, today),
      lastUpdated: toDate(j.createdAt, today),
      createdAt: toDate(j.createdAt, today),
      ...closureOf(j),
    };
  });

  const blockers: BlockerRec[] = blockersSnap.docs.map((d) => {
    const j = d.data();
    return {
      id: d.id,
      projectId: str(j.projectId),
      departmentId: str(j.departmentId),
      description: str(j.description),
      status: str(j.status),
      dateRaised: toDate(j.dateRaised, today),
    };
  });

  const workById = new Map(works.map((w) => [w.id, w]));

  const updates: UpdateRec[] = [
    ...dailySnap.docs.map((d) => {
      const j = d.data();
      const refId = str(j.projectId);
      return {
        id: d.id,
        kind: "project" as const,
        refId,
        refName: projectById.get(refId)?.name ?? refId,
        departmentId: str(j.departmentId),
        authorName: str(j.authorName),
        date: toDate(j.date, today),
        progressPercent: num(j.progressPercent),
        achievements: str(j.achievements),
        blockers: strList(j.blockers),
        newRisks: strList(j.newRisks),
        decisionsRequired: strList(j.decisionsRequired),
      };
    }),
    ...workUpdatesSnap.docs.map((d) => {
      const j = d.data();
      const refId = str(j.workId);
      return {
        id: d.id,
        kind: "work" as const,
        refId,
        refName: workById.get(refId)?.title ?? refId,
        departmentId: str(j.departmentId),
        authorName: str(j.authorName),
        date: toDate(j.date, today),
        progressPercent: num(j.progressPercent),
        achievements: str(j.summary),
        // تحديث العمل حقلٌ حرّ واحد (`notes`)، فلا يُقسَّم إلى عوائق ومخاطر
        // وقرارات كتحديث المشروع. وتركُه فارغاً أصدق من نسبته إلى بابٍ لم
        // يكتبه صاحبه فيه.
        blockers: str(j.notes).trim() ? [str(j.notes).trim()] : [],
        newRisks: [],
        decisionsRequired: [],
      };
    }),
  ];

  // آخر تحديثٍ على العمل يأتي من `workUpdates` لا من حقلٍ على العمل نفسه:
  // `WorkItem` لا يحمل `lastUpdated` إطلاقاً، وتاريخُ إنشائه بديلٌ خاطئ
  // يجعل كل عملٍ قديمٍ يُحدَّث يومياً «بلا تحديث منذ شهور».
  for (const w of works) {
    let latest: Date | null = null;
    for (const u of updates) {
      if (u.kind !== "work" || u.refId !== w.id) continue;
      if (!latest || u.date.getTime() > latest.getTime()) latest = u.date;
    }
    if (latest) w.lastUpdated = latest;
  }

  return {
    snap: {today, projects, items: [...tasks, ...works], updates, blockers, thresholds},
    users,
  };
}

// ============================ الكتابة والإرسال ============================

export interface RunResult {
  dateKey: string;
  recipients: number;
  emailsSent: number;
  emailErrors: string[];
}

/**
 * يولّد تقرير اليوم ويكتبه ويرسله.
 *
 * ــــ حدود الاستثناء من بوابة البريد ــــ
 *
 * قرّر مسؤول النظام استثناءً **دائماً لهذا التقرير وحده**. وهو مبنيٌّ بحيث
 * لا يتّسع:
 *
 * - لا تقبل هذه الدالّة نصّاً من أحد: لا موضوعاً ولا جسماً ولا مستلماً حرّاً.
 *   كلُّ حرفٍ يخرج منها مبنيٌّ من الحساب.
 * - كلُّ مستلمٍ يأخذ **نطاقه هو** لا نطاق غيره.
 * - كلُّ تشغيلٍ يُكتب في سجل التدقيق: كم مستلماً، وأي يوم.
 * - و`sendUserNotification` وبوابة `notifySend` لم تُمسّا: كلُّ بريدٍ يكتبه
 *   إنسان يبقى باعتماد مسؤول النظام.
 */
export async function runDailyReport(
  nowMs: number,
  trigger: string,
  options: {forceEmailOff?: boolean} = {},
): Promise<RunResult> {
  const today = kuwaitToday(nowMs);
  const dateKey = dateKeyOf(today);

  const [settingsDoc, alertDoc] = await Promise.all([
    db().collection("settings").doc("dailyReport").get(),
    db().collection("settings").doc("alertRules").get(),
  ]);
  const projectId = admin.app().options.projectId ?? "";
  const settings = readSettings(settingsDoc.data(), alertDoc.data(), projectId);

  if (!settings.enabled) {
    logger.info("dailyReport: معطَّل من الإعدادات");
    return {dateKey, recipients: 0, emailsSent: 0, emailErrors: []};
  }

  const {snap, users} = await loadSnapshot(today, settings.thresholds);
  const scopes = scopesFor(users, snap.projects, settings);
  const emailOf = new Map(users.map((u) => [u.uid, u.email]));
  const generatedAt = new Date(nowMs).toISOString();

  const reports: DailyReport[] = scopes.map((scope) =>
    buildReport(snap, scope, dateKey, generatedAt),
  );

  // الكتابة بدفعات: حدّ الدفعة الواحدة ٥٠٠ عملية.
  const parent = db().collection("dailyReports").doc(dateKey);
  await parent.set({
    generatedAt,
    trigger,
    recipientCount: reports.length,
  });
  for (let i = 0; i < reports.length; i += 400) {
    const batch = db().batch();
    for (const report of reports.slice(i, i + 400)) {
      batch.set(parent.collection("recipients").doc(report.recipientUid), report);
    }
    await batch.commit();
  }

  let emailsSent = 0;
  const emailErrors: string[] = [];
  // قائمةُ السماح تُطبَّق هنا وحدها: التوليد يقع للجميع، والبريد وحده
  // يُحصَر. فمن له مدخل «التقرير اليومي» يبقى يقرؤه على الشاشة سواءٌ وصله
  // بريدٌ أم لا.
  const targets = emailTargets(reports, settings.emailRecipientUids);
  // التوليد اليدوي للتجربة لا يرسل بريداً إلا بطلبٍ صريح — وإلا صار كلُّ
  // ضغطٍ على «ولّد الآن» نسخةً ثانية في صناديق البريد كلها.
  if (settings.emailEnabled && options.forceEmailOff !== true) {
    for (const report of targets) {
      const to = emailOf.get(report.recipientUid) ?? "";
      if (!to) continue;
      try {
        await sendEmail(
          to,
          reportSubject(report),
          renderReportHtml(report, settings.baseUrl),
        );
        emailsSent++;
      } catch (e) {
        const msg = e instanceof Error ? e.message : "تعذر الإرسال";
        logger.error(`dailyReport: فشل إرسال البريد إلى ${report.recipientUid}`, e);
        emailErrors.push(`${report.recipientName}: ${msg}`);
      }
    }
  }

  await db().collection("auditLog").add({
    userName: "المنصة (تقرير آلي)",
    action: "التقرير التنفيذي اليومي",
    // ولا يُسكت عن الحصر: لولا ذكرُه لَمرّ يومٌ يُظنّ فيه أن البريد وصل
    // الجميع وهو محصورٌ بواحد — والسجل هو الموضع الوحيد الذي يُكشف فيه ذلك.
    details: `وُلِّد تقرير ${dateKey} لـ${reports.length} مستلماً، وأُرسل منه ${emailsSent} بريداً` +
      (settings.emailRecipientUids.length > 0 ?
        ` (البريد محصورٌ بـ${settings.emailRecipientUids.length} مستلماً بقرار مسؤول النظام)` :
        "") +
      (emailErrors.length ? ` — وأخفق ${emailErrors.length}` : "") +
      ` (${trigger})`,
    timestamp: admin.firestore.Timestamp.now(),
  });

  return {dateKey, recipients: reports.length, emailsSent, emailErrors};
}
