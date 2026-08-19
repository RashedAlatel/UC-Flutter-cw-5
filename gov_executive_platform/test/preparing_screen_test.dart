import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/screens/preparing_screen.dart';

/// شاشة الانتظار بين إقلاع التطبيق ووصول أول بيانات من الخادم.
///
/// كانت دوّاراً أبيض على خلفية خضراء بلا نص ولا مهلة ولا زر، فبدت للمستخدم
/// على الجوال «شاشة خضراء فارغة» يظنها عطلاً تاماً. هذه الاختبارات تحرس أن
/// الشاشة **تتكلّم**: نص يشرح ما يجري، وبصمة بناء تُعرَف بها النسخة المنشورة،
/// وبعد المهلة رسالة سبب ومخرج.
void main() {
  Widget wrap(Widget child) => ChangeNotifierProvider<AppStore>.value(
        value: AppStore(),
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      );

  testWidgets('الانتظار الأول يشرح ما يجري ولا يكتفي بدوّار صامت', (tester) async {
    await tester.pumpWidget(wrap(const PreparingScreen()));
    await tester.pump();

    expect(find.text('جارٍ تحضير بياناتك…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // بصمة البناء تظهر منذ اللحظة الأولى: بها يُعرف أي إصدار منشور فعلاً حتى
    // لو تعذّر على المستخدم الوصول إلى داخل المنصة.
    expect(find.textContaining('إصدار'), findsOneWidget);
  });

  testWidgets('بعد المهلة تظهر رسالة سبب ومخرجان بدل الانتظار الأبدي', (tester) async {
    await tester.pumpWidget(wrap(const PreparingScreen()));
    await tester.pump();
    expect(find.text('تعذّر إكمال الاتصال بخدمات المنصة'), findsNothing);

    // تجاوز المهلة بالمؤقّت الوهمي بدل انتظار حقيقي.
    await tester.pump(const Duration(seconds: 16));

    expect(find.text('تعذّر إكمال الاتصال بخدمات المنصة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    // لم يعد ثمة دوّار يدور بلا نهاية.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // ونص السبب يسمّي النطاقات التي قد تحجبها شبكة الوزارة.
    expect(find.textContaining('www.gstatic.com'), findsOneWidget);
  });
}
