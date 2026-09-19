/**
 * حالاتُ الموظفين اليومية: **من يكتب، ومن يصحّح، وما الذي يُكتب** — القرارُ
 * وحدَه، بلا Firebase ولا شبكة.
 *
 * ــــ لماذا وحدةٌ نقيّة ــــ
 *
 * `index.ts` لا تقرؤه أي مجموعة اختبارات (لا محاكي دوالّ في هذه المنصة).
 * وهذا قرارُ **خصوصيّة** لا تفصيلُ تنفيذ: خطأٌ فيه يجعل موظّفاً يقرأ متى
 * مرض زميلُه، أو يجعل سجلَّ حضورٍ يُكتب بأثرٍ رجعيّ فيفقد معناه. وهو نمطُ
 * `user_scope.ts` و`procedure_scope.ts` و`approval_stage.ts`.
 *
 * ــــ والقراراتُ المكتوبة هنا ــــ
 *
 * ١. **الموظّفُ يسجّل ليومه وحدَه** — لا أمسٍ ولا غد.
 * ٢. **ولا يصحّح ما حُفظ** — التصحيحُ للمسؤول، وبأثرٍ مُسجَّل.
 * ٣. **واليومُ حالةٌ واحدةٌ تشغله**، ويجوز أن يُضاف إليها **خروجٌ بوقته**.
 * ٤. **والأحدُ إلى الخميس أيامُ عمل**، وما عداها وما سُجِّل عطلةً فلا.
 */

/** ما تعرفه بطاقةُ الدخول عن المتصل. */
export interface StatusActor {
  uid: string;
  isAdmin: boolean;
  role?: string;
  /** الإداراتُ التي يديرها — **من البطاقة لا من الحمولة**. */
  departmentIds?: string[];
  /** الأقسامُ التي يرأسها — مفتاحُ `hs` في البطاقة. */
  headedSectionIds?: string[];
}

/** ما يُقرأ من مستند الحالة المستهدَفة. */
export interface StatusDoc {
  uid?: string;
  departmentId?: string | null;
  sectionId?: string | null;
}

/**
 * نوعُ السجلّ: حالةُ اليوم كلِّه، أو خروجٌ بوقتٍ داخله.
 *
 * و«خروج» لا «جزئيّ»: الموظّفُ **يخرج من الوزارة** لاجتماعٍ أو استئذان،
 * وهذا ما وُصف. وسجلُّ الخروج لا يقوم وحدَه — هو استثناءٌ على يوم حضور.
 */
export type StatusKind = "day" | "outing";

/**
 * مفتاحُ اليوم `yyyy-mm-dd` **بتوقيت الكويت**.
 *
 * ــ ولماذا لا `toISOString()` ــ
 *
 * لأنّها تعطي التوقيتَ العالميّ، والكويتُ تسبقه بثلاث ساعات. فمن سجّل
 * حالتَه الساعةَ العاشرة ليلاً يُكتب سجلُّه **في اليوم التالي** بحساب
 * `toISOString` — ويظهر في تقرير الغد حاضراً وفي تقرير اليوم غائباً.
 *
 * @param {Date} at اللحظةُ كما هي.
 * @return {string} مفتاحُ يومها المحليّ.
 */
export function dayKeyOf(at: Date): string {
  const kuwait = new Date(at.getTime() + KUWAIT_OFFSET_MS);
  const y = kuwait.getUTCFullYear();
  const m = String(kuwait.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kuwait.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** الكويتُ تسبق التوقيتَ العالميّ بثلاث ساعاتٍ ثابتةٍ بلا توقيتٍ صيفيّ. */
const KUWAIT_OFFSET_MS = 3 * 60 * 60 * 1000;

/**
 * معرّفُ سجلِّ يومٍ — **محسوبٌ لا عشوائيّ**.
 *
 * وبه تُفرض «حالةٌ واحدةٌ لليوم»: كتابةٌ ثانيةٌ تقع على المعرّف نفسِه
 * فتحلّ محلّ الأولى ولا تصطفّ معها. ولو كان المعرّفُ عشوائيّاً لَاحتاج
 * الفرضُ استعلاماً قبل كلّ كتابة — واستعلامٌ قبل كتابة لا يمنع كتابتين
 * تقعان معاً.
 *
 * @param {string} uid صاحبُ السجلّ.
 * @param {string} dayKey مفتاحُ اليوم.
 * @return {string} المعرّف.
 */
export function dayDocId(uid: string, dayKey: string): string {
  return `${uid}_${dayKey}`;
}

/**
 * أيامُ العمل: الأحدُ إلى الخميس.
 *
 * و`getUTCDay()` على يومٍ أُزيح إلى توقيت الكويت: صفرٌ الأحد وستّةٌ السبت.
 * فالجمعةُ (٥) والسبتُ (٦) عطلةُ الأسبوع.
 */
const WEEKEND_DAYS = new Set([5, 6]);

/**
 * أهذا يومُ عملٍ في الوزارة؟
 *
 * ــ ولماذا يلزم أصلاً ــ
 *
 * لأنّ عدّ «من لم يسجّل» بلا هذا السؤال يجعل كلَّ جمعةٍ وسبتٍ غياباً
 * جماعيّاً، وكلَّ عيدٍ كذلك. فيصير التقريرُ الأسبوعيّ يقول إنّ مئتي موظّفٍ
 * تغيّبوا يومين في كلّ أسبوع.
 *
 * @param {string} dayKey مفتاحُ اليوم `yyyy-mm-dd`.
 * @param {readonly string[]} holidays مفاتيحُ الأيام المسجَّلة عطلاً رسميّة.
 * @return {boolean} أيومُ عملٍ هو؟
 */
export function isWorkingDay(dayKey: string, holidays: readonly string[]): boolean {
  if (holidays.includes(dayKey)) return false;
  // `T00:00:00Z` صريحاً: `new Date('2026-09-20')` تُقرأ عالميّةً في بعض
  // المحرّكات ومحليّةً في بعضها، فيختلف اليومُ باختلاف الخادم.
  const at = new Date(`${dayKey}T00:00:00Z`);
  if (Number.isNaN(at.getTime())) return false;
  return !WEEKEND_DAYS.has(at.getUTCDay());
}

/**
 * هل يسجّل هذا المتصلُ حالةَ هذا اليوم؟
 *
 * **اليومُ وحدَه** — كما طُلب. وسجلُّ حضورٍ يُكتب بأثرٍ رجعيّ ليس سجلّاً:
 * يمكن ملءُ شهرٍ كاملٍ حضوراً في آخره. ومن نسي يومَه يصحّحه له مسؤولُه،
 * فيبقى لكلّ سطرٍ قائلٌ يُسأل عنه.
 *
 * @param {string} dayKey اليومُ المطلوب تسجيلُه.
 * @param {Date} now اللحظةُ الآن.
 * @return {boolean} أيُقبل؟
 */
export function mayRecordOn(dayKey: string, now: Date): boolean {
  return dayKey === dayKeyOf(now);
}

/**
 * هل يصحّح هذا المتصلُ سجلَّ هذا الموظّف؟
 *
 * ــ والمسؤولُ وحدَه يصحّح ــ
 *
 * مسؤولُ النظام في كلّ الوزارة، ومديرُ الإدارة في إداراته، ورئيسُ القسم في
 * أقسامه. **ولا الموظّفُ نفسُه** ولو كان اليومَ: هو قرارُك، وأثرُه أنّ كلّ
 * تعديلٍ على سجلٍّ محفوظٍ يحمل اسمَ مسؤولٍ يُسأل عنه.
 *
 * ــ ولا يصحّح المراقبُ (`vds`) ــ
 *
 * منحتُه **نافذةٌ لا يد**: يرى ولا يغيّر. ولو صحّح لَصار سجلُّ الحضور
 * يُكتب من خارج خطّ المسؤوليّة.
 *
 * @param {StatusActor} actor المتصلُ كما تصفه بطاقتُه.
 * @param {StatusDoc} target السجلُّ المستهدَف.
 * @return {boolean} أيحقّ له؟
 */
export function mayCorrectStatus(actor: StatusActor, target: StatusDoc): boolean {
  if (actor.isAdmin) return true;

  const dept = (target.departmentId ?? "").trim();
  if (dept !== "" && (actor.departmentIds ?? []).includes(dept)) {
    // ومديرُ الإدارة وحدَه من بين من يحملون إداراتٍ في بطاقتهم: المستخدمُ
    // التنفيذيّ يحمل نطاقاً واسعاً ويرى كلَّ شيء **ولا يغيّر شيئاً** —
    // قاعدةٌ قائمةٌ في المنصة كلِّها.
    if (actor.role === "departmentManager") return true;
  }

  const section = (target.sectionId ?? "").trim();
  if (section === "") return false;
  return (actor.headedSectionIds ?? []).includes(section);
}

/**
 * الحقولُ التي يقبلها التصحيح — **قائمةٌ مغلقة**.
 *
 * ومغلقةٌ لا قائمةَ منع: الدالّةُ تُطبَّق بصلاحية المدير فتتجاوز كلَّ
 * قاعدة، فحقلٌ غريبٌ يُدسّ في الحمولة يُكتب بلا مانع لو لم تُغلق. ووقع ذلك
 * في المنصة من قبل — في تعديل العمل وفي تسمية المشروع.
 *
 * و`uid` و`day` ليسا منها: تصحيحُ صاحب السجلّ أو يومِه ليس تصحيحاً بل
 * اختلاقُ سجلٍّ آخر — ويُكتب سجلّاً جديداً بمعرّفه.
 */
export const STATUS_FIELDS: readonly string[] = [
  "typeId", "typeName", "toneKey", "fromMinutes", "toMinutes", "place", "note",
];

/** دقائقُ اليوم: من منتصف الليل إلى منتصف الليل. */
const MINUTES_IN_DAY = 24 * 60;

/**
 * ما يُكتب فعلاً من هذه الحمولة — وما عداه يُهمَل بلا ضجيج.
 *
 * @param {Record<string, unknown>} data الحمولةُ كما وصلت.
 * @return {Record<string, unknown>} ما يُكتب.
 */
export function statusPatch(data: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};

  for (const key of ["typeId", "typeName", "toneKey", "place", "note"]) {
    const raw = data[key];
    if (typeof raw !== "string") continue;
    const value = raw.trim();
    // النوعُ لا يُمحى: سجلٌّ بلا نوعٍ لا يُقرأ ولا يُعدّ. أمّا المكانُ
    // والملاحظةُ فيُمحيان صراحةً — ومحوُهما تصحيحٌ مقصود.
    if (value === "" && (key === "typeId" || key === "typeName" || key === "toneKey")) continue;
    patch[key] = value;
  }

  for (const key of ["fromMinutes", "toMinutes"]) {
    const raw = data[key];
    if (raw === null) {
      patch[key] = null;
      continue;
    }
    if (typeof raw !== "number" || !Number.isFinite(raw)) continue;
    const minutes = Math.round(raw);
    // خارجَ اليوم ليس وقتاً: يُهمَل ولا يُقصّ إلى الحدّ — قصُّ «٢٥:٠٠» إلى
    // «٢٣:٥٩» يخترع وقتاً لم يقله أحد.
    if (minutes < 0 || minutes > MINUTES_IN_DAY) continue;
    patch[key] = minutes;
  }

  return patch;
}

/**
 * هل يصلح هذا السجلُّ خروجاً؟ — **من وإلى، وإلى بعد من**.
 *
 * وخروجٌ بلا وقتٍ ليس خروجاً بل حالةَ يوم. وخروجٌ ينتهي قبل أن يبدأ خطأُ
 * إدخالٍ يُردّ عند بابه — لا يُصحَّح بالمبادلة بينهما، فلا أحد يعلم أيَّهما
 * قصد.
 *
 * @param {Record<string, unknown>} data الحمولةُ بعد التنقية.
 * @return {string} رسالةُ الخطأ، أو نصٌّ فارغٌ إن صلَح.
 */
export function outingProblem(data: Record<string, unknown>): string {
  const from = data.fromMinutes;
  const to = data.toMinutes;
  if (typeof from !== "number" || typeof to !== "number") {
    return "الخروجُ يحتاج وقتَ بدايةٍ ونهاية";
  }
  if (to <= from) return "وقتُ العودة بعد وقتِ الخروج";
  return "";
}
