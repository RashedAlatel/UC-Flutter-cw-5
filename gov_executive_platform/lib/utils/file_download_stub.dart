import 'dart:typed_data';

/// خارج المتصفح لا يوجد "تنزيل". نرمي خطأً صريحاً بدل الصمت حتى ينكشف أي
/// استدعاء في غير موضعه فوراً بدل أن يبدو ناجحاً وهو لم يفعل شيئاً.
String downloadBytes(Uint8List bytes, String filename, String mimeType) {
  throw UnsupportedError('تنزيل الملفات متاح داخل المتصفح فقط.');
}

/// فتح ملف سبق تنزيله في تبويب جديد — لا معنى له خارج المتصفح.
void openDownloadedUrl(String url) {}
