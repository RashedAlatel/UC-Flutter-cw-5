import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'safe_file_name.dart';

/// ينشئ ملفاً في ذاكرة المتصفح ويطلب تنزيله، ويعيد عنوانه حتى يستطيع
/// المتصل عرض مخرج بديل للمستخدم.
String downloadBytes(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  // التنقية هنا لا عند المتصل: هذا هو المعبر الوحيد لكل تنزيل في المنصة،
  // فحراسته تكفي — راجع `safe_file_name.dart` لسبب سقوط الأسماء العربية.
  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = safeFileName(filename);
  link.style.display = 'none';
  web.document.body!.appendChild(link);
  link.click();
  link.remove();

  // لا نُحرّر العنوان فور النقرة: بعض المتصفحات تقرأ محتوى الـBlob بعدها
  // بلحظات، فالتحرير الفوري يُلغي التنزيل نصفه. ولا نتركه بلا تحرير كما تفعل
  // حزمة printing، فيتراكم حجم كل تقرير في الذاكرة إلى أن تُغلق الصفحة.
  // خمس دقائق تكفي التنزيل وتكفي المستخدم ليضغط المخرج البديل.
  Timer(const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));

  return url;
}

/// يفتح ملفاً سبق تنزيله في تبويب جديد.
///
/// يجب أن يُستدعى **داخل لمسة المستخدم مباشرة** بلا `await` قبله: سفاري على
/// الآيفون يمنع أي فتح يقع خارج نافذة اللمسة، ويمنعه بلا رسالة.
void openDownloadedUrl(String url) {
  web.window.open(url, '_blank');
}
