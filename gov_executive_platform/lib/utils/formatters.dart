/// دوال تنسيق مشتركة (تواريخ، أرقام) بالعربية بدون الاعتماد على حزم إضافية
class Formatters {
  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// اسم الشهر بالعربية — للتقويم الشهري ولترويسات التقارير.
  static String monthName(int month) => _months[(month - 1) % 12];

  static String shortDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  static String percent(double v) => '${v.toStringAsFixed(0)}٪';

  /// مبلغٌ بالدينار الكويتي — بثلاث خانات كسرية وفواصل للآلاف.
  ///
  /// والدينار **ثلاثُ خاناتٍ لا خانتان**: هو أعلى العملات قيمةً، ووحدتُه
  /// الصغرى الفلس (١/١٠٠٠). فعقدٌ قيمتُه ١٢٥٠٠٠٫٥٠٠ يُكتب كما هو في العقد.
  ///
  /// و**لا تُستدعى بقيمةٍ غير مسجّلة**: `null` تعني «غير مسجّل» وتُعرض نصّاً
  /// صريحاً في الشاشة، لا «٠٫٠٠٠ د.ك» — راجع [Project.contractValue].
  static String money(double v) {
    final parts = v.abs().toStringAsFixed(3).split('.');
    final digits = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('٬');
      buffer.write(digits[i]);
    }
    return '${v < 0 ? '-' : ''}$buffer٫${parts[1]} د.ك';
  }

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// يحوّل رقماً صحيحاً موجباً إلى رقم عربي بصيغة ترتيبية بحرفين على الأقل
  /// (مثل ٠١، ٠٢...٩٩)، للاستخدام في قوائم مرقّمة رسمية.
  static String arabicOrdinal(int n) {
    final padded = n.toString().padLeft(2, '0');
    return padded.split('').map((d) => _arabicDigits[int.parse(d)]).join();
  }

  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
    return date(d);
  }
}
