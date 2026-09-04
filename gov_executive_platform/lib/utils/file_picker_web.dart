import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// ملف اختاره المستخدم من جهازه.
class PickedFile {
  final String name;
  final String contentType;
  final Uint8List bytes;

  const PickedFile({required this.name, required this.contentType, required this.bytes});

  int get sizeBytes => bytes.length;
}

/// يفتح نافذة اختيار ملف ويعيد محتواه، أو null إن ألغى المستخدم.
///
/// **يجب أن تُستدعى داخل لمسة المستخدم مباشرة.** المتصفحات تمنع فتح نافذة
/// الملفات بعد أي انتظار غير متزامن — وهو المنع نفسه الذي واجهناه في فتح
/// الملف المنزَّل على سفاري.
Future<PickedFile?> pickFile({List<String> accept = const []}) {
  final completer = Completer<PickedFile?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..multiple = false;
  if (accept.isNotEmpty) input.accept = accept.join(',');
  input.style.display = 'none';
  web.document.body!.appendChild(input);

  void finish(PickedFile? file) {
    if (!completer.isCompleted) completer.complete(file);
    input.remove();
  }

  // الإلغاء لا يُطلق `change` في كل المتصفحات، فيبقى الوعد معلّقاً إلى
  // الأبد ويظل الزر يدور. و`cancel` مدعوم حديثاً، ويبقى `focus` على النافذة
  // حارساً أخيراً — فلا ينتظر المستخدم شيئاً لن يأتي.
  input.oncancel = ((web.Event _) => finish(null)).toJS;

  // المعالج **متزامن** والقراءة تُطلق منه.
  //
  // `toJS` لا يقبل دالةً تعيد `Future`: التحويل يفشل عند البناء للويب بخطأ
  // «invalid types in its function signature». وهذا لا يظهر في `flutter test`
  // ولا في `flutter analyze` — بل عند بناء النسخة المنشورة وحدها.
  void readSelected() {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0)!;
    file.arrayBuffer().toDart.then((buffer) {
      finish(PickedFile(
        name: file.name,
        contentType: file.type,
        bytes: buffer.toDart.asUint8List(),
      ));
    }).catchError((Object _) {
      finish(null);
      return null;
    });
  }

  input.onchange = ((web.Event _) => readSelected()).toJS;

  input.click();
  return completer.future;
}
