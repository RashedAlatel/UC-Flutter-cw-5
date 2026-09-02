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
};

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
  await deps.setClaims(uid, claims);
  try {
    await deps.markUser(uid);
  } catch (err) {
    deps.warn(`تعذّرت كتابة claimsUpdatedAt للمستخدم ${uid}`, err);
  }
}
