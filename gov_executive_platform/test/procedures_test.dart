// دليلُ الإجراءات في العميل: من يراه، ومن يحرّره، وما يُردّ قبل الخادم.
//
// ــــ ما يُقاس هنا ــــ
//
// (١) **مغلقٌ حتى يُمنح**: لا يظهر المدخلُ لأحد يوم النشر — ولا للتنفيذي
//     ولا لمدير الإدارة بحكم دورِه. وهو ما قرّره مسؤول النظام.
//
// (٢) **ومن يحرّر يقرأ**: `canViewProcedures` تعني `vpc || epc`، ونصُّها
//     نفسُه في قاعدة `procedures`. ولو افترقا لَرأى من مُنح التحريرَ وحدَه
//     شاشةً فارغةً يظنّها عطلاً — وهو العطلُ الذي تكرّر مرّتين في المنصة.
//
// (٣) **والأرشفةُ لا حذف**: من وعد بحفظ النسخ لا يمحو أصلَها.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/procedure.dart';
import 'package:gov_exec_platform/models/role_permissions.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-1';

AppUser _user(
  UserRole role, {
  String id = 'u-1',
  Map<String, bool> overrides = const {},
}) =>
    AppUser(
      id: id,
      name: 'مستخدم',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      departmentIds: role == UserRole.departmentManager ? const [_dept] : const [],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
      permissionOverrides: overrides,
    );

/// متجرٌ يحمل مستخدماً، وصلاحياتِ الأدوار كما تُقرأ من المستند.
AppStore _store(AppUser me, {RolePermissionsConfig? config}) => AppStore()
  ..currentUser = me
  ..users = [me]
  ..rolePermissions = config ?? RolePermissionsConfig.defaults();

/// من مُنح مفتاحاً بعينه بالاستثناء الفردي — وهو أحدُ بابَي المنح.
AppStore _withGrant(String key, {UserRole role = UserRole.employee}) =>
    _store(_user(role, overrides: {key: true}));

Procedure _procedure({bool isActive = true, String id = 'p-1'}) =>
    Procedure(id: id, title: 'توثيق عقد', isActive: isActive);

void main() {
  group('الدليلُ مغلقٌ حتى يُمنح', () {
    // ــ وهذا هو ما قرّرتَه: لا يراه أحدٌ يوم النشر ــ
    test('لا يُفتح لأيّ دورٍ في الإعداد المبدئي', () {
      final defaults = RolePermissionsConfig.defaults();
      for (final role in UserRole.values) {
        expect(defaults.has(role, RolePermission.viewProcedures), isFalse,
            reason: 'القراءة مفتوحةٌ لـ${role.name} في المبدئي — والدليلُ يُفتح بمنح');
        expect(defaults.has(role, RolePermission.editProcedures), isFalse,
            reason: 'التحرير مفتوحٌ لـ${role.name} في المبدئي');
      }
    });

    test('ولا يراه الموظفُ ولا التنفيذيُّ ولا مديرُ الإدارة بحكم دورِه', () {
      for (final role in [
        UserRole.employee,
        UserRole.executiveViewer,
        UserRole.departmentManager,
        UserRole.projectOfficer,
      ]) {
        expect(_store(_user(role)).canViewProcedures, isFalse, reason: role.name);
      }
    });

    test('ومسؤولُ النظام يراه دائماً', () {
      final store = _store(_user(UserRole.systemAdmin));
      expect(store.canViewProcedures, isTrue);
      expect(store.canEditProcedures, isTrue);
    });
  });

  group('والمنحُ بابان: الدورُ والفرد', () {
    test('صلاحيةُ دورٍ تفتح القراءة', () {
      final config = RolePermissionsConfig.defaults()
          .toggled(UserRole.employee, RolePermission.viewProcedures, true);
      expect(_store(_user(UserRole.employee), config: config).canViewProcedures, isTrue);
    });

    test('ومنحٌ فرديّ يفتحها لمن لا يحملها دورُه', () {
      expect(_withGrant('vpc').canViewProcedures, isTrue);
    });

    // ــ ومنعٌ فرديّ يعلو على الدور ــ
    //
    // فمن فُتحت له بالدور ومُنع بعينه يُمنع — وإلا لم يكن للمنع الفرديّ معنى.
    test('ومنعٌ فرديّ يغلقها على من يحملها دورُه', () {
      final config = RolePermissionsConfig.defaults()
          .toggled(UserRole.employee, RolePermission.viewProcedures, true);
      final me = _user(UserRole.employee, overrides: const {'vpc': false});
      expect(_store(me, config: config).canViewProcedures, isFalse);
    });
  });

  group('ومن يحرّر يقرأ', () {
    // ــ الحدُّ الذي يمنع شاشةً فارغةً تُظنّ عطلاً ــ
    test('من مُنح التحريرَ وحدَه يرى الدليل', () {
      final store = _withGrant('epc');
      expect(store.canEditProcedures, isTrue);
      expect(store.canViewProcedures, isTrue);
    });

    // ــ ولا عكس ــ
    test('ومن مُنح القراءةَ وحدَها لا يحرّر', () {
      final store = _withGrant('vpc');
      expect(store.canViewProcedures, isTrue);
      expect(store.canEditProcedures, isFalse);
    });
  });

  group('ومدخلُ القائمة الجانبية يتبع القراءة', () {
    test('يظهر لمن مُنح القراءة', () {
      expect(navKeysFor(_withGrant('vpc')), contains(NavKey.procedures));
    });

    test('ولمن مُنح التحرير وحدَه', () {
      expect(navKeysFor(_withGrant('epc')), contains(NavKey.procedures));
    });

    test('ولا يظهر لمن لم يُمنح شيئاً', () {
      expect(navKeysFor(_store(_user(UserRole.employee))),
          isNot(contains(NavKey.procedures)));
      expect(navKeysFor(_store(_user(UserRole.executiveViewer))),
          isNot(contains(NavKey.procedures)));
    });

    test('ويظهر لمسؤول النظام', () {
      expect(navKeysFor(_store(_user(UserRole.systemAdmin))), contains(NavKey.procedures));
    });
  });

  group('وما يُردّ قبل الوصول إلى الخادم', () {
    // والدالّتان تردّان نصَّ الردّ قبل أيّ اتصال — فتُقاسان بلا فايربيس.
    test('الحفظُ يُردّ على من لا يملك التحرير، بنصٍّ يقول ما ينقصه', () async {
      final message = await _withGrant('vpc').saveProcedure(
        title: 'إجراء',
        summary: '',
        steps: const [],
      );
      expect(message, contains('تحرير دليل الإجراءات'));
    });

    test('والأرشفةُ كذلك', () async {
      final message =
          await _withGrant('vpc').setProcedureActive(_procedure(), false);
      expect(message, contains('تحرير دليل الإجراءات'));
    });

    // عنوانٌ فارغ ليس إجراءً: هو كلُّ ما يظهر في القائمة.
    test('ولا يُحفظ إجراءٌ بلا عنوان', () async {
      final message = await _withGrant('epc').saveProcedure(
        title: '   ',
        summary: '',
        steps: const [],
      );
      expect(message, contains('عنوان'));
    });
  });

  group('والسارية تُفصل عن المؤرشفة', () {
    test('«السارية» لا تحمل المؤرشف', () {
      final store = _store(_user(UserRole.systemAdmin))
        ..procedures = [
          _procedure(id: 'p-1'),
          _procedure(id: 'p-2', isActive: false),
        ];
      expect(store.activeProcedures.map((p) => p.id).toList(), ['p-1']);
      // ــ والمؤرشفُ يبقى مقروءاً ــ
      //
      // فمن وعد بحفظ النسخ لا يمحو أصلَها، وما سار عليه الناسُ سنةً يبقى
      // مما يُرجع إليه.
      expect(store.procedures.length, 2);
      expect(store.procedureById('p-2'), isNotNull);
    });

    // ــ والقراءةُ بالمعرّف تُعيد صاحبَه ــ
    //
    // ونجت طفرةُ «تُعيد أوّلَ ما تجد» في أوّل جولةٍ لأنّي قِستُها على متجرٍ
    // فارغ: كلُّ شيءٍ يُعيد `null` هناك. فالحالةُ التي تقيس هي قائمةٌ فيها
    // أكثرُ من إجراء.
    test('والقراءةُ بالمعرّف تُعيد صاحبَه لا أوّلَ الموجودين', () {
      final store = _store(_user(UserRole.systemAdmin))
        ..procedures = [_procedure(id: 'p-1'), _procedure(id: 'p-2')];
      expect(store.procedureById('p-2')?.id, 'p-2');
      expect(store.procedureById('p-1')?.id, 'p-1');
    });

    test('وإجراءٌ لا وجود له يُقرأ عدماً لا رمياً', () {
      final store = _store(_user(UserRole.systemAdmin))
        ..procedures = [_procedure(id: 'p-1')];
      expect(store.procedureById('لا-شيء'), isNull);
      // ومعرّفٌ فارغٌ أو غائبٌ ليس «أوّلَ إجراءٍ في القائمة»: نافذةٌ فُتحت
      // بلا معرّفٍ يجب أن تقول «غير متاح» لا أن تعرض إجراءً آخر باسمه.
      expect(store.procedureById(null), isNull);
      expect(store.procedureById(''), isNull);
    });
  });

  // ــ والمفتاحان يظهران في شبكة الأدوار ــ
  //
  // فلو وقعا في `scoped` أو `baseline` لَما ظهرا فيها، ولَما كان لمسؤول
  // النظام سبيلٌ إلى منحهما لدور — وهو نصفُ ما طلبتَه.
  test('والصلاحيتان تُضبطان لكلّ دورٍ من الشبكة', () {
    expect(RolePermission.roleAssignable, contains(RolePermission.viewProcedures));
    expect(RolePermission.roleAssignable, contains(RolePermission.editProcedures));
  });

  // ولا يُخلط مفتاحُ التحرير بمفتاح إنشاء المشاريع: `epc` و`mpr` بوابتان
  // مختلفتان، والمتجاورُ في الاسم أوّلُ ما يُوقع في الخطأ.
  test('ومفاتيحُ الصلاحيات لا تتكرّر', () {
    final keys = RolePermission.values.map((p) => p.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(RolePermission.viewProcedures.key, 'vpc');
    expect(RolePermission.editProcedures.key, 'epc');
  });
}
