// ملف مؤقت (Placeholder) — يجب استبداله تلقائياً بتشغيل الأمر التالي من جهازك
// بعد إنشاء مشروع Firebase وربطه (راجع قسم "ربط المنصة بـ Firebase والنشر" في README):
//
//   firebase login
//   flutterfire configure --project=<project-id>
//
// الأمر أعلاه يولّد هذا الملف تلقائياً بالمفاتيح الحقيقية لمشروعك ولن تحتاج لتعديله يدوياً.
// أي محاولة لتشغيل التطبيق قبل تشغيل flutterfire configure ستفشل بخطأ واضح أدناه.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'لم يتم إعداد Firebase لهذه المنصة بعد. '
          'شغّل الأمر التالي من جذر المشروع: flutterfire configure',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'REPLACE_ME',
  );
}
