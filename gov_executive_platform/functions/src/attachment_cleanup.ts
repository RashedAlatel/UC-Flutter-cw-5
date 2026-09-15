/**
 * أيُّ ملفاتٍ تُمحى من التخزين حين يُحذف تحديثٌ يومي.
 *
 * ــــ لماذا على الخادم لا في المتصفح؟ ــــ
 *
 * لأن قواعد التخزين **لا تستطيع قراءة Firestore**: لا سبيل فيها إلى معرفة
 * من يملك المشروع. ففتحُ الحذف للعميل يعني فتحَه لكل موظفٍ معتمد على كل
 * مرفقٍ في الوزارة متى عرف مساره. فبقيت قاعدة التخزين `delete: if false`
 * كما هي، ويقع المحو هنا — بعد أن تكون قاعدةُ Firestore قد بتّت في **حقّ
 * الحذف** أصلاً بحذف المستند.
 *
 * ــــ ولماذا يُفحص المسار وقد جاء من مستندٍ حُذف بحقّ؟ ــــ
 *
 * لأن `attachments[].storagePath` **يكتبه العميل**، وهذه الدالّة تعمل
 * بصلاحية المدير (تتجاوز كل القواعد). فلولا الفحص لَأمكن لموظفٍ معتمد أن
 * يكتب تحديثاً يومياً على مشروعه ويضع في مرفقه مسارَ ملفٍ **لا يخصّه**، ثم
 * يحذف تحديثه — فيمحو الخادمُ عنه ملفَ غيره طائعاً.
 *
 * فالمسار يجب أن يكون حرفياً `projects/{هذا المشروع}/dailyUpdates/{اسم}`،
 * واسمُ الملف جزءٌ واحد لا يحوي شرطة مائلة ولا صعوداً بـ`..`.
 */

/** بادئة المسار المسموح للمرفق، مبنيّةً على مشروع التحديث نفسه. */
export function attachmentPrefix(projectId: string): string {
  return `projects/${projectId}/dailyUpdates/`;
}

/**
 * مسارات التخزين التي تُمحى فعلاً — من مرفقات مستندٍ محذوف.
 *
 * يُسقط: الروابط الخارجية (لا تملك المنصة ملفَّها)، وما لا مسار له، وكلَّ
 * مسارٍ خارج مجلّد هذا المشروع. ويُنقّي المكرّر.
 */
export function storagePathsToDelete(raw: unknown, projectId: string): string[] {
  if (!Array.isArray(raw) || !projectId) return [];
  const prefix = attachmentPrefix(projectId);
  const out: string[] = [];

  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const a = item as {kind?: unknown; storagePath?: unknown};

    // الرابط الخارجي ليس ملفاً عندنا — وحذفُ ما لا نملك لا معنى له.
    if (a.kind !== "upload") continue;

    const path = typeof a.storagePath === "string" ? a.storagePath : "";
    if (!path.startsWith(prefix)) continue;

    // اسم الملف جزءٌ واحد: لا شرطة مائلة تُخرجه من المجلّد، ولا `..` تصعد به.
    const name = path.slice(prefix.length);
    if (!name || name.includes("/") || name === "." || name === "..") continue;

    if (!out.includes(path)) out.push(path);
  }

  return out;
}
