import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// الفحص هو فحص `firebase_core_web` نفسه، معكوساً على خدمة التخزين:
/// الحقن يضع الحزمة في `window.firebase_<الخدمة>`
/// (راجع `injectSrcScript`: `globalContext[windowVar] = module`)، والمُحمِّل
/// المُولَّد في `web/firebase_sdk/loader.js` يضعها في الموضع نفسه. فغيابُ
/// المتغيّر يعني أن الحزمة لم تصل بأي من الطريقين.
bool storageSdkReady() => globalContext.getProperty<JSAny?>('firebase_storage'.toJS) != null;
