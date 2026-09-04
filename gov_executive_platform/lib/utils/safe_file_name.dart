/// اسم ملف يقبله المتصفح عند التنزيل.
///
/// **هذا ليس تحسيناً تجميلياً، بل إصلاح العطل نفسه.** كان اسم ملف التقرير
/// عربياً (`تقرير_monthly_2026-08-19.pdf`)، وقياسٌ في متصفح حقيقي أثبت أن
/// كروم **يرفض الاسم كلّه** إن حوى حرفاً عربياً واحداً — فيحفظ الملف باسم
/// `download` **بلا أي امتداد**. وملف بلا امتداد لا يفتحه أي عارض PDF على
/// ويندوز، فيرى المستخدم أن الضغط على «تصدير» لم يفعل شيئاً، بينما الملف
/// نزل فعلاً ولا يُفتح.
///
/// القياس (كروم، رابط blob، خاصية download):
/// * `report_2026-08-19.pdf` ← يُحفظ بالاسم نفسه.
/// * `تقرير.pdf` و`MOJ-تقرير.pdf` ← يُحفظان باسم `download` بلا امتداد.
///
/// لذلك تُنقّى الأسماء هنا في موضع واحد يمرّ به كل تنزيل، فلا يستطيع أي
/// استدعاء لاحق أن يُعيد العطل من باب آخر.
String safeFileName(String name, {String fallbackBase = 'report'}) {
  final dot = name.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < name.length - 1;

  // كل ما ليس حرفاً لاتينياً أو رقماً أو نقطةً أو شرطة يصير شرطة، ثم تُدمج
  // الشرطات المتتالية وتُقلَّم الفواصل من الطرفين — فلا يبقى اسم مثل
  // `_-monthly-` أو `---.pdf`.
  String clean(String s) => s
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^[-_.]+|[-_.]+$'), '');

  final base = clean(hasExtension ? name.substring(0, dot) : name);
  final extension = hasExtension ? clean(name.substring(dot + 1)) : '';

  final safeBase = base.isEmpty ? fallbackBase : base;
  return extension.isEmpty ? safeBase : '$safeBase.$extension';
}
