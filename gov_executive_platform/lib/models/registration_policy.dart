/// سياسة التسجيل الذاتي — نطاقات البريد الوزاري المقبولة.
///
/// تُحفظ في `settings/registration`، وقاعدتها في `firestore.rules`: قراءة
/// للجميع وكتابة لمسؤول النظام وحده. القراءة العامة مقصودة: نموذج التسجيل
/// يحتاجها **قبل** تسجيل الدخول ليخبر الموظف بالنطاق المقبول بدل أن يرفض
/// بريده بلا تفسير.
class RegistrationPolicy {
  /// نطاقات البريد المقبولة، بلا علامة @ وبأحرف صغيرة (مثل `moj.gov.kw`).
  ///
  /// القائمة الفارغة تعني **لا قيد** — وهو سلوك مقصود: منصة لم يضبط مسؤولها
  /// النطاقات بعد يجب ألا تمنع كل الموظفين من التسجيل.
  final List<String> allowedEmailDomains;

  /// هل يلزم تأكيد البريد قبل عرض الطلب على مسؤول النظام؟
  final bool requireEmailVerification;

  const RegistrationPolicy({
    this.allowedEmailDomains = const [],
    this.requireEmailVerification = true,
  });

  Map<String, dynamic> toMap() => {
        'allowedEmailDomains': allowedEmailDomains,
        'requireEmailVerification': requireEmailVerification,
      };

  factory RegistrationPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const RegistrationPolicy();
    return RegistrationPolicy(
      allowedEmailDomains: ((map['allowedEmailDomains'] as List?) ?? const [])
          .map((e) => normalizeDomain(e.toString()))
          .where((e) => e.isNotEmpty)
          .toList(),
      requireEmailVerification: map['requireEmailVerification'] as bool? ?? true,
    );
  }

  /// يُنقّي نطاقاً مكتوباً بيد الإنسان: يقبل `@moj.gov.kw` و`MOJ.GOV.KW`
  /// و`user@moj.gov.kw` ويردّها جميعاً إلى `moj.gov.kw`. بدون هذا يُدخل
  /// مسؤول النظام نطاقاً بعلامة @ فيرفض النظام كل بريد صحيح بلا سبب ظاهر.
  static String normalizeDomain(String raw) {
    var d = raw.trim().toLowerCase();
    final at = d.lastIndexOf('@');
    if (at >= 0) d = d.substring(at + 1);
    return d.replaceAll(RegExp(r'^\.+|\.+$'), '').trim();
  }

  /// هل هذا البريد مقبول بهذه السياسة؟
  bool allows(String email) {
    if (allowedEmailDomains.isEmpty) return true;
    final at = email.trim().lastIndexOf('@');
    if (at < 0) return false;
    final domain = email.trim().toLowerCase().substring(at + 1);
    return allowedEmailDomains.contains(domain);
  }

  /// نص يشرح النطاقات المقبولة للموظف، بصيغة يقرؤها لا بقائمة تقنية.
  String get domainsLabel =>
      allowedEmailDomains.map((d) => '@$d').join(' أو ');
}
