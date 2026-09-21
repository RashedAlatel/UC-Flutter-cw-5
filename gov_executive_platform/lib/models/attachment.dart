/// مرفق على تحديث يومي: ملف مرفوع، أو رابط إلى ملف على نظام آخر.
///
/// **نموذج واحد للنوعين عمداً.** الوزارة قد تُفعّل التخزين وقد لا تفعله،
/// وقد يكون الملف أصلاً على SharePoint أو Drive. ولو فُصل النوعان لتضاعف
/// كل موضع يعرض المرفقات ويصدّرها ويحذفها، ولاختلف سلوكهما بلا سبب. فما
/// يهمّ العارضَ واحد: **اسم يُقرأ ورابط يُفتح**؛ وما عدا ذلك تفصيل تخزين.
library;

enum AttachmentKind {
  /// ملف رفعه المستخدم من جهازه إلى تخزين المنصة.
  upload,

  /// رابط إلى ملف على نظام خارجي — لا تملك المنصة الملف ولا تحذفه.
  link;

  String get label => this == AttachmentKind.upload ? 'ملف مرفوع' : 'رابط خارجي';

  static AttachmentKind fromName(String? name) =>
      name == AttachmentKind.upload.name ? AttachmentKind.upload : AttachmentKind.link;
}

class Attachment {
  final String name;
  final String url;
  final AttachmentKind kind;
  final String contentType;
  final int sizeBytes;

  /// مسار الملف في التخزين — للمرفوع وحده، ويلزم لحذفه لاحقاً.
  final String? storagePath;

  const Attachment({
    required this.name,
    required this.url,
    required this.kind,
    this.contentType = '',
    this.sizeBytes = 0,
    this.storagePath,
  });

  /// حجم مقروء بالعربية. الصفر يعني «غير معروف» لا «ملف فارغ» — وهو حال كل
  /// رابط خارجي، فلا يُعرض له حجم كاذب.
  String get readableSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} ك.ب';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }

  /// تصنيف مبسّط يكفي لاختيار أيقونة — لا يُبنى عليه أمان.
  String get typeLabel {
    final n = name.toLowerCase();
    if (contentType.startsWith('image/') || n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return 'صورة';
    }
    if (n.endsWith('.pdf') || contentType == 'application/pdf') return 'PDF';
    if (n.endsWith('.xlsx') || n.endsWith('.xls') || contentType.contains('spreadsheet')) return 'إكسل';
    if (n.endsWith('.docx') || n.endsWith('.doc') || contentType.contains('word')) return 'وورد';
    return 'ملف';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'kind': kind.name,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        if (storagePath != null) 'storagePath': storagePath,
      };

  factory Attachment.fromMap(Map<String, dynamic> map) => Attachment(
        name: map['name'] as String? ?? '',
        url: map['url'] as String? ?? '',
        kind: AttachmentKind.fromName(map['kind'] as String?),
        contentType: map['contentType'] as String? ?? '',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        storagePath: map['storagePath'] as String?,
      );

  /// يقرأ قائمة مرفقات من مستند قد يكون كُتب قبل وجود الحقل.
  static List<Attachment> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Attachment.fromMap(Map<String, dynamic>.from(item)),
    ];
  }
}
