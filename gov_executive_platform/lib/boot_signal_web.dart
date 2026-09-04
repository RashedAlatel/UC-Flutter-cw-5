import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// تستدعي `window.platformUiReady()` المعرَّفة في `web/index.html` لإخفاء
/// شاشة الإقلاع.
///
/// الاستدعاء محروس: لو غابت الدالة (نسخة index.html قديمة مخزّنة في المتصفح
/// مثلاً) لا يحدث شيء ولا يُرمى خطأ يُعطّل التطبيق — أسوأ ما يقع أن تبقى شاشة
/// الإقلاع حتى يُخفيها حارس المهلة.
void signalUiReady() => _call('platformUiReady', const []);

/// تُعلن أي شاشة يعرضها التطبيق الآن (`preparing` أو `login` أو `pending`
/// أو `shell`).
///
/// هذه أرخص معلومة وأثمنها حين تظهر شاشة صمّاء: تحسم إن كان التطبيق واقفاً
/// عند انتظار البيانات، أم أنه بلغ شاشة الدخول ورسمها فارغة. وتُكتب في
/// `window.platformStage` فتقرأها صفحة الفحص من الإطار بلا أي وسيط.
void signalStage(String stage) => _call('platformStage', [stage.toJS]);

/// تُمرّر نصّ خطأ Dart إلى الصفحة لتعرضه على شاشة الإقلاع.
///
/// بدون هذا يبقى استثناء Dart في الطرفية وحدها — ولا طرفية على الجوال، فيرى
/// المستخدم سطحاً صامتاً ولا يصلنا منه شيء.
void reportDartError(String message) => _call('platformError', [message.toJS]);

/// استدعاء دالة عالمية إن وُجدت. الحراسة مقصودة: نسخة `index.html` مخزّنة
/// قديمة تعني غياب الدالة، ولا يصحّ أن يُسقط ذلك التطبيق.
void _call(String name, List<JSAny?> args) {
  final fn = globalContext[name];
  if (!fn.isA<JSFunction>()) return;
  final f = fn as JSFunction;
  if (args.isEmpty) {
    f.callAsFunction();
  } else {
    f.callAsFunction(null, args.first);
  }
}
