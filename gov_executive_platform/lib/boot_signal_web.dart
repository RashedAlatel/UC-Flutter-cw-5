import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// تستدعي `window.platformUiReady()` المعرَّفة في `web/index.html` لإخفاء
/// شاشة الإقلاع.
///
/// الاستدعاء محروس: لو غابت الدالة (نسخة index.html قديمة مخزّنة في المتصفح
/// مثلاً) لا يحدث شيء ولا يُرمى خطأ يُعطّل التطبيق — أسوأ ما يقع أن تبقى شاشة
/// الإقلاع حتى يُخفيها حارس المهلة.
void signalUiReady() {
  final fn = globalContext['platformUiReady'];
  if (fn.isA<JSFunction>()) {
    (fn as JSFunction).callAsFunction();
  }
}
