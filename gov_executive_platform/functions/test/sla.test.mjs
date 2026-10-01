// ساعةُ المدّة على الخادم — **وتُقاس بالجدول الذي يقرؤه العميل**.
//
// فاتّفاقُ الطرفين على `test_fixtures/sla_cases.json` اتّفاقٌ بينهما. ولو
// كُتب لكلٍّ جدولُه لَاتّفق كلٌّ مع نفسه وافترقا — فيعرض المتصفّحُ رقماً
// ويعدّ التقريرُ غيرَه لشيءٍ واحد، ولا يعرف المسؤولُ أيُّهما الصحيح.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { STANDARD_SLA, readSlaPolicy, respondOutcome, resolveOutcome } from "../lib/sla.js";

const fixture = JSON.parse(
  readFileSync(new URL("../../test_fixtures/sla_cases.json", import.meta.url), "utf8"),
);
const opened = fixture.openedMs;
const min = (m) => m * 60000;

test("الجدولُ المشترك يُقرأ كما يقرؤه العميل", () => {
  for (const c of fixture.cases) {
    const nowMs = opened + min(c.nowOffsetMin);
    const t = {
      createdAtMs: opened,
      priority: c.priority,
      firstResponseAtMs:
        c.firstResponseOffsetMin === null ? null : opened + min(c.firstResponseOffsetMin),
      resolvedAtMs: c.resolvedOffsetMin === null ? null : opened + min(c.resolvedOffsetMin),
      waitingMs: c.waitingMs,
      waitingSinceMs:
        c.waitingSinceOffsetMin === null ? null : opened + min(c.waitingSinceOffsetMin),
    };
    assert.equal(respondOutcome(t, STANDARD_SLA, nowMs), c.respond, `${c.name} — أوّلُ ردّ`);
    assert.equal(resolveOutcome(t, STANDARD_SLA, nowMs), c.resolve, `${c.name} — الحلّ`);
  }
});

test("والجدولُ ليس فارغاً — حارسٌ لا يقرأ شيئاً يمرّ صامتاً", () => {
  assert.ok(fixture.cases.length >= 8);
});

test("ومهلةٌ صفرٌ أو سالبةٌ تُردّ إلى المبدئيّ", () => {
  const p = readSlaPolicy({ byPriority: { high: { respondMinutes: 0, resolveMinutes: -5 } } });
  assert.equal(p.byPriority.high.respondMinutes, 60);
  assert.equal(p.byPriority.high.resolveMinutes, 480);
});

test("وكسرُ «يوشك» خارج المدى يُردّ", () => {
  assert.equal(readSlaPolicy({ atRiskFraction: 5 }).atRiskFraction, 0.25);
  assert.equal(readSlaPolicy({ atRiskFraction: 0.5 }).atRiskFraction, 0.5);
});

test("ونصٌّ مكان السياسة لا يُسقط شيئاً", () => {
  assert.equal(readSlaPolicy("خطأ").byPriority.low.resolveMinutes, 4320);
});
