// اختبار تشغيل أساسي: يتأكد أن التطبيق يقلع ويعرض شاشة تسجيل الدخول.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gov_exec_platform/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('يعرض التطبيق شاشة تسجيل الدخول عند الإقلاع', (WidgetTester tester) async {
    await tester.pumpWidget(const GovExecutivePlatformApp());
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('يسمح تسجيل الدخول بحساب تجريبي بالوصول إلى لوحة القيادة', (WidgetTester tester) async {
    await tester.pumpWidget(const GovExecutivePlatformApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'اسم المستخدم'), 'admin');
    await tester.enterText(find.widgetWithText(TextField, 'كلمة المرور'), 'admin123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'دخول'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة القيادة المركزية'), findsOneWidget);
  });
}
