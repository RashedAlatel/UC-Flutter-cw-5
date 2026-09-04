// ضمُّ موظّفٍ إلى إدارة بعد التسجيل.
//
// ــــ العطلُ الذي أوجد هذا الملفّ ــــ
//
// طلب مسؤول النظام أن يُضمّ مستخدمٌ إلى إدارةٍ إن لم يخترها عند التسجيل.
// وقِيس فوُجد أنه **متعذّرٌ تماماً**، ومعه ما هو أسوأ:
//
// نافذةُ «تعديل الدور» تعرض حقلَ الإدارة لدورين فقط — «مدير مشروع»
// الموروث و«الدور المخصص». ودورُ **«موظف»**، وهو الدور المفتوح عند
// التسجيل وأكثرُ الحسابات عليه، **لا حقلَ إدارةٍ له إطلاقاً**.
//
// وعند الحفظ تُرسل `departmentId: null` لكل دورٍ سواهما، والخادمُ يكتبها
// كما هي. **فكلُّ تعديلِ دورٍ على موظّف كان يمحو إدارته صامتاً** — من
// المستند ومن بطاقة الدخول معاً، فيفقد رؤية مشاريع إدارته ولا يُقال له
// لماذا.
//
// وما يُقاس هنا: أن الحقل يُعرض لكل دور، وأن الحمولة تحمل ما اختاره
// المسؤول لا `null` مشتقّاً من الدور.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/screens/user_management_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _d1 = 'd-1';
const _d2 = 'd-2';

const _departments = [
  Department(id: _d1, name: 'إدارة النظم', headName: 'أ', colorValue: 0xFF0B6E4F, iconKey: 'work'),
  Department(id: _d2, name: 'إدارة الشؤون', headName: 'ب', colorValue: 0xFF0B6E4F, iconKey: 'work'),
];

AppUser _user(UserRole role, {String? dept = _d1}) => AppUser(
      id: 'u-1',
      name: 'موظف الاختبار',
      email: 'u@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: const [],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store() => AppStore()
  ..currentUser = AppUser(
    id: 'admin',
    name: 'مسؤول النظام',
    email: 'a@moj.gov.kw',
    phone: '',
    role: UserRole.systemAdmin,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  )
  ..departments = _departments;

Future<void> _pump(WidgetTester tester, AppStore store, AppUser user) async {
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: EditRoleDialog(user: user)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('حقلُ الإدارة يُعرض لكل دور', () {
    // هذا هو ما بلّغ عنه: الموظفُ بلا حقلِ إدارةٍ إطلاقاً.
    testWidgets('للموظف', (tester) async {
      await _pump(tester, _store(), _user(UserRole.employee));
      expect(find.text('الإدارة (اختياري)'), findsOneWidget);
    });

    testWidgets('ولمدير المشروع الموروث — مطلوبةً', (tester) async {
      await _pump(tester, _store(), _user(UserRole.projectOfficer));
      expect(find.text('الإدارة'), findsOneWidget);
    });

    // ومديرُ الإدارة له قائمةُ إداراتٍ متعدّدة لا حقلٌ مفرد — وتبقى كما هي.
    testWidgets('ومديرُ الإدارة يبقى على قائمة الإدارات', (tester) async {
      await _pump(tester, _store(), _user(UserRole.departmentManager));
      expect(find.text('الإدارات (يمكن اختيار أكثر من إدارة)'), findsOneWidget);
    });
  });

  group('والحمولةُ تحمل ما اختاره المسؤول', () {
    // ــ العطلُ في صورته المقيسة ــ
    //
    // موظفٌ له إدارةٌ مسجّلة، يُفتح له تعديلُ الدور ويُحفظ بلا مساسٍ
    // بالإدارة — فيجب أن تخرج الحمولةُ بإدارته لا بـ`null`.
    test('موظفٌ له إدارةٌ يُحفظ دورُه فتبقى إدارتُه', () {
      expect(
        departmentIdForSubmit(role: UserRole.employee, departmentId: _d1),
        _d1,
      );
    });

    test('وتُبدَّل إلى أخرى إن اختارها', () {
      expect(
        departmentIdForSubmit(role: UserRole.employee, departmentId: _d2),
        _d2,
      );
    });

    // ونزعُها فعلٌ صريح: من اختار «بلا إدارة» يُرسل `null` ويُقرأ نزعاً.
    test('و«بلا إدارة» تُرسل نزعاً صريحاً', () {
      expect(
        departmentIdForSubmit(role: UserRole.employee, departmentId: null),
        isNull,
      );
    });

    // ومديرُ الإدارة إدارتُه في القائمة لا في المفرد، فلا يُرسل المفرد.
    test('ومديرُ الإدارة لا يُرسل المفرد', () {
      expect(
        departmentIdForSubmit(role: UserRole.departmentManager, departmentId: _d1),
        isNull,
      );
    });
  });
}
