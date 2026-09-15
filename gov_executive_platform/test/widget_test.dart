// اختبار واجهة أساسي لا يتطلب اتصالاً حقيقياً بـ Firebase: يتحقق من أن شاشة
// تسجيل الدخول تُبنى بنجاح وتعرض عناصرها الأساسية. اختبار التكامل الكامل مع
// Firebase (مصادقة/قاعدة بيانات فعلية) يتطلب مشروع Firebase حقيقي أو حزم محاكاة
// إضافية (firebase_auth_mocks / fake_cloud_firestore) خارج نطاق هذا الاختبار.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/screens/login_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

void main() {
  testWidgets('تعرض شاشة تسجيل الدخول الحقول الأساسية', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('ليس لديك حساب؟ إنشاء حساب جديد'), findsOneWidget);
  });

  testWidgets('يظهر خطأ عند محاولة الدخول بدون تعبئة الحقول', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'دخول'));
    await tester.pump();

    expect(find.text('الرجاء إدخال البريد الإلكتروني وكلمة المرور'), findsOneWidget);
  });
}
