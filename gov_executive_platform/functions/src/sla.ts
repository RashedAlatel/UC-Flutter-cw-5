/**
 * ساعةُ مدّةِ الخدمة (SLA) — **نظيرُ `lib/itsm/sla.dart` حرفاً بحرف**.
 *
 * ــــ ولماذا نسختان ــــ
 *
 * المتصفّحُ يعرض «تجاوز المدّة» على الشاشة، والخادمُ يعدّه في التقرير
 * اليوميّ. فلو افترق الحسابان لَقرأ المسؤولُ رقمين مختلفين لشيءٍ واحد،
 * ولا يعرف أيُّهما الصحيح — وهو أسوأ من ألّا يُعرض الرقمُ أصلاً.
 *
 * فالمنطقُ واحدٌ مكتوبٌ مرّتين، **ويُقاس أنّهما يُعطيان الناتجَ نفسَه**
 * بالمدخلات نفسِها. وهذا هو الانضباطُ القائم في `status_scope.ts`.
 *
 * ــــ ولا هدفَ يُخزَّن ــــ
 *
 * يُحسب من `createdAt` (تفرضه القاعدةُ `request.time`) والأولويّة
 * والسياسة. والتجاوزُ نتيجةُ مقارنةٍ لا علَمٌ مرفوع — فعلَمٌ يُقلب بكتابة.
 */

export interface SlaTarget {
  respondMinutes: number;
  resolveMinutes: number;
}

export interface SlaPolicy {
  byPriority: Record<string, SlaTarget>;
  atRiskFraction: number;
}

export type SlaOutcome = "met" | "missed" | "onTrack" | "atRisk" | "breached";

export const STANDARD_SLA: SlaPolicy = {
  byPriority: {
    critical: {respondMinutes: 15, resolveMinutes: 4 * 60},
    high: {respondMinutes: 60, resolveMinutes: 8 * 60},
    medium: {respondMinutes: 4 * 60, resolveMinutes: 24 * 60},
    low: {respondMinutes: 8 * 60, resolveMinutes: 72 * 60},
  },
  atRiskFraction: 0.25,
};

const PRIORITIES = ["critical", "high", "medium", "low"] as const;

/** رقمٌ موجبٌ صحيح، أو `null`. ومهلةٌ صفرٌ تجعل كلَّ بلاغٍ متجاوزاً لحظةَ فتحه. */
function positiveInt(raw: unknown): number | null {
  const n = typeof raw === "number" ? raw :
    (typeof raw === "string" ? Number(raw.trim()) : NaN);
  if (!Number.isFinite(n)) return null;
  const i = Math.round(n);
  return i > 0 ? i : null;
}

export function readSlaPolicy(raw: unknown): SlaPolicy {
  if (!raw || typeof raw !== "object") return STANDARD_SLA;
  const m = raw as Record<string, unknown>;
  const rawBy = m["byPriority"];
  const byPriority: Record<string, SlaTarget> = {};
  for (const p of PRIORITIES) {
    const fallback = STANDARD_SLA.byPriority[p];
    const entry = (rawBy && typeof rawBy === "object") ?
      (rawBy as Record<string, unknown>)[p] : null;
    const e = (entry && typeof entry === "object") ? entry as Record<string, unknown> : {};
    byPriority[p] = {
      respondMinutes: positiveInt(e["respondMinutes"]) ?? fallback.respondMinutes,
      resolveMinutes: positiveInt(e["resolveMinutes"]) ?? fallback.resolveMinutes,
    };
  }
  const f = m["atRiskFraction"];
  const fraction = typeof f === "number" ? f : STANDARD_SLA.atRiskFraction;
  return {
    byPriority,
    // وخارجُ المدى يُردّ: كسرٌ فوق الواحد يجعل كلَّ بلاغٍ «يوشك» لحظةَ
    // فتحه، وسالبٌ يُلغي التحذيرَ كلَّه بصمت.
    atRiskFraction: fraction > 0 && fraction < 1 ? fraction : STANDARD_SLA.atRiskFraction,
  };
}

export function targetFor(policy: SlaPolicy, priority: string): SlaTarget {
  return policy.byPriority[priority] ??
    STANDARD_SLA.byPriority[priority] ??
    {respondMinutes: 4 * 60, resolveMinutes: 24 * 60};
}

/** ما سُجِّل من انتظارٍ حتّى لحظةٍ بعينها — والسالبُ يُهمَل. */
export function waitingUpTo(
  waitingMs: number,
  waitingSince: number | null,
  instantMs: number,
): number {
  let ms = waitingMs > 0 ? waitingMs : 0;
  if (waitingSince !== null && instantMs > waitingSince) {
    ms += instantMs - waitingSince;
  }
  return ms;
}

function clockOutcome(
  dueAtMs: number,
  windowMs: number,
  stampMs: number | null,
  nowMs: number,
  atRiskFraction: number,
): SlaOutcome {
  // و«بعد» لا «ليس قبل»: الوقوعُ في اللحظة الأخيرة بالضبط وقوعٌ داخل
  // المهلة — والحدُّ لمن بلغه لا عليه.
  if (stampMs !== null) return stampMs > dueAtMs ? "missed" : "met";
  const remaining = dueAtMs - nowMs;
  if (remaining <= 0) return "breached";
  return remaining <= windowMs * atRiskFraction ? "atRisk" : "onTrack";
}

/** ساعةُ أوّلِ ردّ — ولا تتوقّف: المستفيدُ لم يُسأل بعد. */
export function respondOutcome(
  t: {createdAtMs: number; priority: string; firstResponseAtMs: number | null},
  policy: SlaPolicy,
  nowMs: number,
): SlaOutcome {
  const windowMs = targetFor(policy, t.priority).respondMinutes * 60000;
  return clockOutcome(
    t.createdAtMs + windowMs, windowMs, t.firstResponseAtMs, nowMs, policy.atRiskFraction,
  );
}

/** ساعةُ الحلّ — **وتتوقّف حين يكون الدورُ على المستفيد**. */
export function resolveOutcome(
  t: {
    createdAtMs: number;
    priority: string;
    resolvedAtMs: number | null;
    waitingMs: number;
    waitingSinceMs: number | null;
  },
  policy: SlaPolicy,
  nowMs: number,
): SlaOutcome {
  const windowMs = targetFor(policy, t.priority).resolveMinutes * 60000;
  // والمرجعُ وقتُ الحلّ إن حُلّ: انتظارٌ وقع بعده لا يُزيح موعداً انقضى أمرُه.
  const reference = t.resolvedAtMs ?? nowMs;
  const waited = waitingUpTo(t.waitingMs, t.waitingSinceMs, reference);
  return clockOutcome(
    t.createdAtMs + windowMs + waited, windowMs, t.resolvedAtMs, nowMs, policy.atRiskFraction,
  );
}
