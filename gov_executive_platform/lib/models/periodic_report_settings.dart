/// إعدادات التقارير الدورية — `settings/periodicReports`.
///
/// حقلٌ واحدٌ اليوم: **بعد كم يومٍ بلا تحديثٍ يصير المشروع «غير نشط»**.
/// طلبتَ ٣ و٧ و١٤ مثالاً، فصار الحقل عدداً حرّاً ضمن حدٍّ معقول بدل ثلاثة
/// خياراتٍ مغلقة — والمبدئيُّ سبعة كما اخترت.
///
/// ــــ ولماذا إعدادٌ لا رقمٌ مكتوبٌ في الشيفرة ــــ
///
/// لأن المدّة حكمٌ إداري لا حقيقة تقنية: إدارةٌ تُحدِّث يومياً يكون الجمودُ
/// عندها ثلاثةَ أيام، وأخرى مشاريعُها طويلةُ النَّفَس لا يعني فيها أسبوعان
/// شيئاً. ورقمٌ مكتوبٌ في الشيفرة يعني أن تغييرَه يحتاج نشر إصدار.
///
/// ويُخزَّن في `settings/{id}` — القراءة عامة والكتابة لمسؤول النظام
/// بقاعدةٍ قائمة، فلا يلزم تعديلُ القواعد.
library;

/// المبدئيُّ الذي اخترتَه: أسبوعٌ كامل.
const int kDefaultInactiveDays = 7;

/// حدودُ ما يُقبل — يومٌ واحد على الأقل، وتسعون على الأكثر.
///
/// والحدُّ الأدنى ليس تزيّداً: صفرٌ يجعل **كل** مشروعٍ غير نشط في اللحظة
/// التي يُحدَّث فيها، فتصير القائمة كلَّ المشاريع ولا تعني شيئاً.
const int kMinInactiveDays = 1;
const int kMaxInactiveDays = 90;

class PeriodicReportSettings {
  final int inactiveAfterDays;

  const PeriodicReportSettings({this.inactiveAfterDays = kDefaultInactiveDays});

  Map<String, dynamic> toMap() => {'inactiveAfterDays': inactiveAfterDays};

  /// مستندٌ ناقصٌ أو رقمٌ خارج الحدود يُقرأ **بالمبدئيّ** لا بما فيه: قيمةٌ
  /// فاسدة في مستندٍ لا يجوز أن تُخرج قائمةً فارغةً بلا تفسير.
  factory PeriodicReportSettings.fromMap(Map<String, dynamic>? m) {
    final raw = (m?['inactiveAfterDays'] as num?)?.toInt();
    if (raw == null || raw < kMinInactiveDays || raw > kMaxInactiveDays) {
      return const PeriodicReportSettings();
    }
    return PeriodicReportSettings(inactiveAfterDays: raw);
  }
}
