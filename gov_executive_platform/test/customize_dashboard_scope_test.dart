import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/customize_dashboard_dialog.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

/// نافذة «تخصيص لوحة القيادة» متاحة لكل مستخدم ليعدّل لوحته هو، بينما لوحات
/// الأدوار واللوحة العامة لا تظهر إلا لمن يملك صلاحية التحكم باللوحة.
/// هذا الاختبار يحرس هذا الفرق: لو ظهر منتقي النطاق لموظف عادي لصار بإمكانه
/// تغيير لوحة كل من يحمل دوره.
AppStore _storeFor(UserRole role) => AppStore()
  ..currentUser = AppUser(
    id: 'u-1',
    name: 'مستخدم',
    email: 'user@moj.gov.kw',
    phone: '+96555555555',
    role: role,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  );

Future<void> _pumpDialog(WidgetTester tester, UserRole role) async {
  await tester.binding.setSurfaceSize(const Size(560, 800));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: _storeFor(role),
      child: MaterialApp(
        theme: AppTheme.theme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: CustomizeDashboardDialog()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('مسؤول النظام يرى منتقي نطاق التخصيص', (tester) async {
    await _pumpDialog(tester, UserRole.systemAdmin);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    // النطاق المبدئي لوحة المستخدم نفسه حتى لمسؤول النظام، فلا يعدّل لوحة
    // الجميع بالخطأ وهو يظن أنه يرتّب لوحته.
    expect(find.text('لوحتي أنا'), findsWidgets);

    // عناصر القائمة لا تُبنى إلا عند فتحها، لذا نفتحها ثم نتحقق.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('لوحة دور: مستخدم تنفيذي'), findsWidgets);
    expect(find.text('لوحة دور: مدير إدارة'), findsWidgets);
    expect(find.text('اللوحة العامة'), findsWidgets);
  });

  testWidgets('الموظف لا يرى منتقي النطاق ويعدّل لوحته وحدها', (tester) async {
    await _pumpDialog(tester, UserRole.employee);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('حفظ لوحتي'), findsOneWidget);
  });

  testWidgets('المستخدم التنفيذي بلا صلاحية التحكم باللوحة لا يرى منتقي النطاق', (tester) async {
    await _pumpDialog(tester, UserRole.executiveViewer);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });
}
