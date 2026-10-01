import 'dart:typed_data';

/// ملف اختاره المستخدم من جهازه.
class PickedFile {
  final String name;
  final String contentType;
  final Uint8List bytes;

  const PickedFile({required this.name, required this.contentType, required this.bytes});

  int get sizeBytes => bytes.length;
}

/// خارج المتصفح لا نافذة اختيار — تُعيد null فتبقى الاختبارات تعمل.
Future<PickedFile?> pickFile({List<String> accept = const []}) async => null;
