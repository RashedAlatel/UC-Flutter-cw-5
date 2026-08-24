// حساب موقوف لم يعد له زرّ «إعادة تفعيل» — لأنه سيُردّ دائماً بعد هذه
// الجولة (التوقيف يحذف حساب الدخول). والعودة تمرّ بتسجيلٍ جديد يُدمَج
// تلقائياً، لا بضغطةٍ هنا.
//
// وحين يقع الدمج فعلاً، يُقال ذلك — لا يبقى الحساب الموقوف صفّاً معلَّقاً
// بلا تفسير في قائمة مئتَي موظف.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/user_management_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

AppUser _admin() => AppUser(
      id: 'u-admin',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '',
      role: UserRole.systemAdmin,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

AppUser _suspended({String? mergedIntoUid}) => AppUser(
      id: 'u-suspended',
      name: 'موظف موقوف',
      email: 'suspended@moj.gov.kw',
      phone: '',
      role: UserRole.employee,
      departmentId: 'd-1',
      status: UserStatus.suspended,
      createdAt: DateTime(2026, 1, 1),
      mergedIntoUid: mergedIntoUid,
    );

AppUser _approved() => AppUser(
      id: 'u-active',
      name: 'موظف مفعَّل',
      email: 'active@moj.gov.kw',
      phone: '',
      role: UserRole.employee,
      departmentId: 'd-1',
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, List<AppUser> users) async {
  final store = AppStore()
    ..currentUser = _admin()
    ..users = users;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: UserManagementScreen()),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('الموقوف بلا زرّ إعادة تفعيل، وبتلميحٍ يشرح طريق العودة', (tester) async {
    await _pump(tester, [_admin(), _suspended()]);
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('إعادة التفعيل'), findsNothing);
    expect(
      find.byTooltip(
        'حُذف حساب دخوله عند التوقيف. ليعود، يُسجَّل من جديد بنفس '
        'بريده — يُسمح له فوراً، وتُنقل أعماله ومهامّه تلقائياً '
        'إلى حسابه الجديد عند اعتماد تسجيله.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ودُمج بالفعل — يُقال بدل تلميح الانتظار', (tester) async {
    await _pump(tester, [_admin(), _suspended(mergedIntoUid: 'u-new')]);
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('إعادة التفعيل'), findsNothing);
    expect(
      find.byTooltip('دُمج مع حسابٍ جديد سُجِّل بالبريد نفسه — أعماله ومهامّه نُقلت إليه.'),
      findsOneWidget,
    );
  });

  testWidgets('والحساب المفعَّل يحتفظ بزرّ الإيقاف كما كان', (tester) async {
    await _pump(tester, [_admin(), _approved()]);
    expect(tester.takeException(), isNull);

    // `findsWidgets` لا `findsOneWidget`: مسؤول النظام نفسه معتمَدٌ أيضاً،
    // فيحمل صفّه زرّ الإيقاف نفسه — والمقصود هنا أن الزرّ **موجود** لا عدّه.
    expect(find.byTooltip('إيقاف الحساب'), findsWidgets);
    expect(find.byTooltip('إعادة التفعيل'), findsNothing);
  });
}
