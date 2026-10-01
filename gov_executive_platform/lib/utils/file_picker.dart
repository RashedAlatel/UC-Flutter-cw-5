/// اختيار ملف من جهاز المستخدم داخل المتصفح، بشيفرتنا لا بحزمة خارجية.
///
/// التصدير شرطي حتى تبقى الاختبارات على جهاز Dart سليمة — على نمط
/// `lib/utils/file_download.dart` و`lib/boot_signal.dart`.
library;

export 'file_picker_stub.dart' if (dart.library.js_interop) 'file_picker_web.dart';
