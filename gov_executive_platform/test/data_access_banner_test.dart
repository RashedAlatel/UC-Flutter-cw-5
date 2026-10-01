// اللافتةُ تقول أيَّ الأعطال وقع — وما يُفعل به.
//
// ــــ الحادثةُ ــــ
//
// اختفت مشاريعُ وزارة العدل، وكانت اللافتة — إن ظهرت — تقول عبارةً واحدة
// تصلح لأربعة أعطالٍ علاجُها مختلف. ولم تكن تقول رقماً واحداً يُبنى عليه
// تشخيص. فمضى يومٌ في التخمين.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/data_access_banner.dart';

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: DataAccessBanner())),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('بلا عطلٍ لا لافتة', (tester) async {
    await _pump(tester, AppStore());
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('تعذّر'), findsNothing);
  });

  testWidgets('وبطاقةٌ ميتة: يُقال إن الخادم يحتكم إليها، ويُعرض بابا الخروج',
      (tester) async {
    final store = AppStore()
      ..dataErrors[AppStore.claimsErrorLabel] = 'تعذّر الختم (unavailable)';
    await _pump(tester, store);
    expect(find.textContaining('يحتكم إلى البطاقة'), findsOneWidget);
    // بابان: ختمٌ من الخادم، ورمزٌ جديد بخروجٍ ودخول — والثاني لا يحتاج خادماً.
    expect(find.widgetWithText(OutlinedButton, 'مزامنة صلاحيات حسابي'), findsOneWidget);
    expect(find.textContaining('سجّل خروجاً ثم دخولاً'), findsOneWidget);
  });

  // ــ والرقمان هما التشخيص ــ
  testWidgets('ومستنداتٌ وصلت ولم تُقرأ: بالعددين وباسم المستند', (tester) async {
    final store = AppStore()
      ..dataErrors['projects'] = 'تعذّرت قراءة 177: p-14: TypeError'
      ..docCounts['projects'] = (received: 181, parsed: 4);
    await _pump(tester, store);
    expect(find.textContaining('وصل 181 مستنداً وقُرئ 4'), findsOneWidget);
    expect(find.textContaining('p-14'), findsOneWidget);
    // ولا يُلام الخادمُ على ما لم يفعل.
    expect(find.textContaining('سجّل خروجاً ثم دخولاً'), findsNothing);
  });

  testWidgets('وصلاحيةٌ ناقصة تبقى على نصّها ومعها زرُّ المزامنة', (tester) async {
    final store = AppStore()
      ..dataErrors['projects'] = '[cloud_firestore/permission-denied] Missing';
    await _pump(tester, store);
    expect(find.textContaining('صلاحيات حسابك غير مكتملة'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'مزامنة صلاحيات حسابي'), findsOneWidget);
  });
}
