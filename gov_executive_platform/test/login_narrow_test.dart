// شاشة الدخول على شاشات الجوال.
//
// هذا الاختبار يحرس العطل الذي منع فتح المنصة على الجوال: لوحة الشعار كانت
// تستعمل `CrossAxisAlignment.stretch` داخل سياق ارتفاعه غير محدود (عمود داخل
// SingleChildScrollView في مسار الشاشة الضيّقة)، فيُطلب من الشريط الزخرفي
// ارتفاع لا نهائي فينهار التخطيط:
//   BoxConstraints forces an infinite height
//
// ولم يكشفه شيء لأن كل ما كان يُصيّر شاشة الدخول هو `render_login_preview.dart`
// وهو يعمل بمقاس ١٢٠٠×٧٦٠ فقط — أي بالمسار العريض وحده. وفي بناء الإصدار لا
// تظهر رسالة الانهيار بل يُرسم فراغ أخضر صامت، فبقي العطل مجهول السبب جولات.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/screens/login_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

Future<void> _pumpLogin(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Directionality(textDirection: TextDirection.rtl, child: LoginScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // مقاسات حقيقية: الأول هو جوال مسؤول النظام الذي وقع عليه العطل، والثاني
  // أعرض قليلاً، والثالث لوحي عند حدّ التبديل بين المسارين (٦٤٠).
  const sizes = <String, Size>{
    'آيفون ٤٠٢×٦٨٤': Size(402, 684),
    'أندرويد ٤١٢×٨٣٩': Size(412, 839),
    'لوحي ضيّق ٦٣٩×٨٠٠': Size(639, 800),
    'سطح مكتب ١٢٠٠×٧٦٠': Size(1200, 760),
  };

  sizes.forEach((label, size) {
    testWidgets('شاشة الدخول تُبنى بلا انهيار — $label', (tester) async {
      await _pumpLogin(tester, size);
      expect(tester.takeException(), isNull,
          reason: 'انهار تخطيط شاشة الدخول عند $label — وهو ما يظهر للمستخدم فراغاً أخضر');
      expect(find.text('تسجيل الدخول'), findsWidgets);
    });
  });
}
