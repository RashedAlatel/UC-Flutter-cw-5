/**
 * ختمُ بطاقة الدخول — **وإعلامُ المتصفّح أنها خُتمت**.
 *
 * ــــ العطلُ الذي أوجب هذه الوحدة ــــ
 *
 * قواعدُ Firestore تحتكم إلى بطاقة الدخول (Custom Claims) لا إلى مستند
 * المستخدم. والبطاقةُ في متصفّح صاحبها لا تتجدّد إلا بانتهاء أجل رمزه — وقد
 * يبلغ ساعة. فمن غيّر مسؤولُ النظام دورَه أو إدارتَه يجلس أمام منصّةٍ
 * **تردّ قراءاتِه وكتاباتِه** بينما الشاشةُ تقول إنه يملكها، ولا شيء يفسّر
 * له ذلك. ووقع هذا في وزارة العدل فأخفى مشاريعَها يوماً كاملاً.
 *
 * فيُكتب `claimsUpdatedAt` على مستنده مع كل ختم، ومستمعُ `users/{uid}` في
 * المتصفّح قائمٌ أصلاً فيراه يتغيّر ويُجدّد الرمز فوراً.
 *
 * وهي وحدةٌ بتبعيّاتٍ مُحقَنة لتُقاس: `index.ts` لا يعمل إلا بـFirebase حيّ،
 * أي خارج مدى أي اختبار. وهو النمطُ القائم في هذا المجلّد
 * (`approval_stage.ts` و`work_create.ts` و`convert_record.ts`).
 */

/** ما تحتاجه الدالّة من العالم الخارجي. */
export type StampDeps = {
  /** يختم البطاقة فعلاً. */
  setClaims: (uid: string, claims: Record<string, unknown>) => Promise<void>;
  /** يكتب `claimsUpdatedAt` على مستند المستخدم. */
  markUser: (uid: string) => Promise<void>;
  /** يسجّل تحذيراً بلا إفشال. */
  warn: (message: string, err: unknown) => void;
  /** البطاقةُ كما هي قبل الختم — لتمييز ختمٍ غيَّر شيئاً من ختمٍ لم يُغيّر. */
  readClaims?: (uid: string) => Promise<Record<string, unknown> | undefined>;
};

/**
 * هل البطاقتان سواء؟ — مقارنةٌ لا تعبأ بترتيب المفاتيح.
 *
 * ومفاتيحُ الكائن ترتيبُها ترتيبُ إدخالها، فبطاقتان متطابقتان قد تخرجان
 * بترتيبين. ولو قِيستا بالترتيب لَقيل «تغيّرت» في كل ختم — وهو بعينه ما
 * تمنعه هذه الدالّة.
 *
 * @param {Record<string, unknown> | undefined} a إحداهما.
 * @param {Record<string, unknown> | undefined} b والأخرى.
 * @return {boolean} هل هما سواء؟
 */
export function sameClaims(
  a: Record<string, unknown> | undefined,
  b: Record<string, unknown> | undefined,
): boolean {
  if (a === undefined || b === undefined) return false;
  const keys = [...new Set([...Object.keys(a), ...Object.keys(b)])].sort();
  return keys.every((k) => JSON.stringify(a[k] ?? null) === JSON.stringify(b[k] ?? null));
}

/**
 * يختم البطاقة ثم يعلّم مستند المستخدم.
 *
 * والترتيبُ مقصود: **الختمُ أوّلاً**. فلو كُتب السطرُ الإعلامي أوّلاً ثم
 * أخفق الختم، لأيقظ المتصفّحَ ليقرأ بطاقةً لم تتغيّر — فيُجدّد رمزَه بلا
 * جدوى ويظنّ الأمر قد أُصلح.
 *
 * وإخفاقُ العلامة **لا يُسقط الختم**: الختمُ هو الفعل، والعلامةُ تُسرّع
 * وصولَه. ومنها تُنادى هذه الدالّة قبل إنشاء مستند المستخدم أحياناً.
 *
 * @param {string} uid صاحبُ البطاقة.
 * @param {Record<string, unknown>} claims البطاقةُ كاملةً كما تُختم.
 * @param {StampDeps} deps تبعيّاتُ العالم الخارجي.
 * @return {Promise<void>} لا شيء.
 */
export async function stampClaims(
  uid: string,
  claims: Record<string, unknown>,
  deps: StampDeps,
): Promise<void> {
  const before = deps.readClaims ? await deps.readClaims(uid) : undefined;
  // ــ ما لا رأيَ للمُستدعي فيه يُحمَل لا يُمحى — راجع [CARRIED_CLAIM_KEYS] ــ
  const full = withCarriedClaims(claims, before);
  await deps.setClaims(uid, full);

  // ــ ولا تُكتب العلامةُ لختمٍ لم يُغيّر شيئاً ــ
  //
  // وهذه هي **الفرملة التي أوقفت حلقةً عطّلت المنصّة**: `syncMyClaims`
  // تُعيد ختمَ البطاقة نفسِها، فكانت تكتب `claimsUpdatedAt` فتوقظ متصفّح
  // صاحبها، فيفحص بطاقتَه، فينادي `syncMyClaims` من جديد — دورةٌ لا تنتهي
  // تُلغي كلَّ اشتراكات المستخدم وتُعيدها في كل لفّة، فتبدو المنصّةُ
  // تُعيد التحميل بلا توقّف.
  //
  // فالعلامةُ خبرُ **تغيُّر**، ولا خبر في ختمٍ أعاد ما كان.
  if (sameClaims(before, full)) return;

  try {
    await deps.markUser(uid);
  } catch (err) {
    deps.warn(`تعذّرت كتابة claimsUpdatedAt للمستخدم ${uid}`, err);
  }
}

/**
 * المفاتيحُ التي **تُحمل** من البطاقة السابقة متى لم يذكرها الخاتم.
 *
 * ــــ لماذا هذه القائمةُ بالذات ــــ
 *
 * `setCustomUserClaims` تستبدل البطاقةَ كلَّها ولا تدمج. وفي `index.ts`
 * خمسةُ مواضعَ تختم بطاقةَ مستخدمٍ قائم بيدها — اعتمادُ تسجيل، ونقلٌ بين
 * إدارتين، وتعديلُ دور، وتغييرُ حالة، وحفظُ شاشة صلاحيات الأدوار. وكلٌّ
 * منها يعرف ما جاء ليغيّره **ولا رأيَ له** في البقيّة، فيمحوها بلا أن يقصد.
 *
 * فـ`hs` (الأقسامُ التي يرأسها) و`w` (من يراقبهم) كانتا تُمحيان في كلّ
 * واحدٍ منها: يبقى الرجلُ رئيسَ قسمه في السجلّ، وتكفّ القواعدُ عن معرفته.
 * وأسوأُها حفظُ شاشة الأدوار — يمحوها **لكلّ حاملي الدور دفعةً**.
 *
 * وعلاجُها في خمسة مواضعَ علاجٌ يُنسى عند السادس. فالحملُ هنا، في الخاتم
 * الواحد الذي تمرّ به كلُّها.
 *
 * **والصريحُ يَغلِب المحمول**: `restampClaims` تمرّرهما دائماً، فهي وحدَها
 * صاحبةُ الرأي فيهما — ومن عُزل عن رئاسته تُنزع برسالتها لا تبقى أبداً.
 */
export const CARRIED_CLAIM_KEYS = ["hs", "w"] as const;

/**
 * يُلحق بالبطاقة ما غاب عنها من [CARRIED_CLAIM_KEYS] ممّا كان في سابقتها.
 *
 * @param {Record<string, unknown>} claims البطاقةُ كما جاء بها المُستدعي.
 * @param {Record<string, unknown> | undefined} before البطاقةُ السابقة.
 * @return {Record<string, unknown>} البطاقةُ بعد الحمل.
 */
export function withCarriedClaims(
  claims: Record<string, unknown>,
  before: Record<string, unknown> | undefined,
): Record<string, unknown> {
  if (!before) return claims;
  const next = {...claims};
  for (const key of CARRIED_CLAIM_KEYS) {
    // `in` لا `!== undefined`: من مرّر `hs: undefined` صراحةً قاصدٌ نزعَها،
    // ولا يُعاد إليه ما نزع.
    if (!(key in next) && key in before) next[key] = before[key];
  }
  return next;
}
