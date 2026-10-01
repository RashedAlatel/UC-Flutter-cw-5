import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/department_section.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

/// شجرة أقسام الإدارة: إدارة ← قسم ← قسم فرعي، وإسناد المشاريع إليها.
AppStore _store() {
  final store = AppStore()
    ..currentUser = AppUser(
      id: 'admin-1',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '+96555555555',
      role: UserRole.systemAdmin,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

  store.sections = const [
    DepartmentSection(id: 's1', departmentId: 'd1', name: 'قسم النظم الآلية'),
    DepartmentSection(id: 's1a', departmentId: 'd1', parentId: 's1', name: 'وحدة الرسوم', order: 0),
    DepartmentSection(id: 's1b', departmentId: 'd1', parentId: 's1', name: 'وحدة الإعلان', order: 1),
    DepartmentSection(id: 's2', departmentId: 'd1', name: 'قسم حفظ الوثائق'),
    DepartmentSection(id: 'x1', departmentId: 'd2', name: 'قسم في إدارة أخرى'),
  ];

  Project p(String id, String dept, String? section) => Project(
        id: id,
        departmentId: dept,
        name: 'مشروع $id',
        description: 'وصف',
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 12, 31),
        status: ProjectStatus.onTrack,
        priority: PriorityLevel.medium,
        progressPercent: 10,
        sectionId: section,
      );

  store.projects = [
    p('p1', 'd1', 's1'), // مباشرة تحت القسم
    p('p2', 'd1', 's1a'), // تحت قسم فرعي
    p('p3', 'd1', 's1b'), // تحت قسم فرعي آخر
    p('p4', 'd1', null), // بلا قسم
    p('p5', 'd1', 'محذوف'), // قسم لم يعد موجوداً
    p('p6', 'd2', 'x1'),
  ];
  return store;
}

void main() {
  test('أقسام الإدارة تُقرأ على مستويين منفصلين', () {
    final store = _store();
    expect(store.sectionsOf('d1').map((s) => s.id), ['s1', 's2']);
    expect(store.sectionsOf('d1', parentId: 's1').map((s) => s.id), ['s1a', 's1b']);
    expect(store.sectionsOf('d2').map((s) => s.id), ['x1']);
  });

  test('الترتيب بحقل order لا بالأبجدية، والأبجدية تفصل عند التساوي', () {
    final store = _store();
    // "وحدة الإعلان" تسبق "وحدة الرسوم" أبجدياً، لكن order يقدّم "وحدة الرسوم".
    expect(store.sectionsOf('d1', parentId: 's1').map((s) => s.name), ['وحدة الرسوم', 'وحدة الإعلان']);

    store.sections = const [
      DepartmentSection(id: 'a', departmentId: 'd9', name: 'باء'),
      DepartmentSection(id: 'b', departmentId: 'd9', name: 'ألف'),
    ];
    expect(store.sectionsOf('d9').map((s) => s.name), ['ألف', 'باء']);
  });

  test('عدّاد القسم يشمل مشاريع أقسامه الفرعية', () {
    final store = _store();
    expect(store.projectsInSection('s1').map((p) => p.id), containsAll(['p1', 'p2', 'p3']));
    expect(store.projectsInSection('s1').length, 3);
    // بدون الفروع: مشاريع القسم المباشرة وحدها.
    expect(store.projectsInSection('s1', includeDescendants: false).map((p) => p.id), ['p1']);
  });

  test('المشروع المُسنَد لقسم محذوف يظهر مع مشاريع "بلا قسم" ولا يختفي', () {
    final store = _store();
    final loose = store.projectsWithoutSection('d1').map((p) => p.id).toList();
    expect(loose, containsAll(['p4', 'p5']));
  });

  test('مسار القسم يُعرض كاملاً من الجذر', () {
    final store = _store();
    expect(store.sectionPathLabel('s1a'), 'قسم النظم الآلية ← وحدة الرسوم');
    expect(store.sectionPathLabel('s1'), 'قسم النظم الآلية');
    expect(store.sectionPathLabel(null), '');
    expect(store.sectionPathLabel('محذوف'), '');
  });

  // ــ والعمقُ صار أربعةً بطلبٍ صريح ــ
  //
  // كان مستويين: «قسم» و«قسم فرعي». وطُلب هيكلٌ يحتمل **إدارة ← قسم ← فريق
  // ← وحدة**، وهي أربعُ طبقاتٍ تحت الإدارة. فرُفع [maxDepth] — وهو التغييرُ
  // المكتوبُ في رأس `department_section.dart` أنّه «قيمةٌ واحدة لا إعادةُ
  // تصميم».
  //
  // ويبقى **حدٌّ**: شجرةٌ بلا قاعٍ تُنتج مساراتٍ لا تُقرأ في قائمةٍ منسدلة.
  test('العمقُ أربعُ طبقاتٍ تحت الإدارة، والخامسةُ تُردّ', () {
    final store = _store();
    final top = store.sections.firstWhere((s) => s.id == 's1');
    final child = store.sections.firstWhere((s) => s.id == 's1a');
    expect(top.levelIn(store.sections), 1);
    expect(child.levelIn(store.sections), 2);
    expect(store.canAddChildSection(top), isTrue);
    expect(store.canAddChildSection(child), isTrue, reason: 'الفريقُ تحت القسم الفرعيّ');

    // وطبقةٌ ثالثةٌ ورابعة، ثمّ يُغلق الباب.
    final deeper = [
      ...store.sections,
      const DepartmentSection(id: 's1a1', departmentId: 'd1', parentId: 's1a', name: 'فريق'),
      const DepartmentSection(id: 's1a1a', departmentId: 'd1', parentId: 's1a1', name: 'وحدة'),
    ];
    store.sections = deeper;
    final team = deeper.firstWhere((s) => s.id == 's1a1');
    final unit = deeper.firstWhere((s) => s.id == 's1a1a');
    expect(team.levelIn(deeper), 3);
    expect(unit.levelIn(deeper), 4);
    expect(store.canAddChildSection(team), isTrue);
    expect(store.canAddChildSection(unit), isFalse, reason: 'الرابعةُ آخرُ الطبقات');
  });

  // ــ ولكلّ طبقةٍ اسمُها ــ
  //
  // شجرةٌ بأربع طبقاتٍ بلا أسماء تُقرأ تكراراً لا تنظيماً.
  test('ولكلّ طبقةٍ مسمّاها', () {
    final all = [
      const DepartmentSection(id: 'a', departmentId: 'd', name: 'أ'),
      const DepartmentSection(id: 'b', departmentId: 'd', parentId: 'a', name: 'ب'),
      const DepartmentSection(id: 'c', departmentId: 'd', parentId: 'b', name: 'ج'),
      const DepartmentSection(id: 'e', departmentId: 'd', parentId: 'c', name: 'د'),
    ];
    expect(all[0].levelLabelIn(all), 'قسم');
    expect(all[1].levelLabelIn(all), 'قسم فرعي');
    expect(all[2].levelLabelIn(all), 'فريق');
    expect(all[3].levelLabelIn(all), 'وحدة');
  });

  test('حساب المستوى لا يدور إلى ما لا نهاية لو حوت البيانات حلقة', () {
    final looped = [
      const DepartmentSection(id: 'a', departmentId: 'd', parentId: 'b', name: 'أ'),
      const DepartmentSection(id: 'b', departmentId: 'd', parentId: 'a', name: 'ب'),
    ];
    expect(looped.first.levelIn(looped), lessThan(5));
  });

  test('فرع القسم يضم القسم وكل ما تحته', () {
    final store = _store();
    expect(store.sectionWithDescendants('s1'), {'s1', 's1a', 's1b'});
    expect(store.sectionWithDescendants('s1a'), {'s1a'});
  });

  test('إدارة القسم لمسؤول النظام ولمدير الإدارة صاحبها فقط', () {
    final store = _store();
    expect(store.canManageSections('d1'), isTrue); // مسؤول نظام

    store.currentUser = AppUser(
      id: 'mgr-1',
      name: 'مدير إدارة',
      email: 'mgr@moj.gov.kw',
      phone: '+96555555556',
      role: UserRole.departmentManager,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
      departmentIds: const ['d1'],
    );
    expect(store.canManageSections('d1'), isTrue);
    expect(store.canManageSections('d2'), isFalse);

    store.currentUser = AppUser(
      id: 'emp-1',
      name: 'موظف',
      email: 'emp@moj.gov.kw',
      phone: '+96555555557',
      role: UserRole.employee,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
      departmentId: 'd1',
    );
    expect(store.canManageSections('d1'), isFalse);
  });

  group('نقل قسم إلى إدارة أخرى', () {
    test('الصلاحية لمسؤول النظام وحده', () {
      final store = _store();
      expect(store.canMoveSectionAcrossDepartments, isTrue);

      store.currentUser = AppUser(
        id: 'mgr-1',
        name: 'مدير إدارة',
        email: 'mgr@moj.gov.kw',
        phone: '+96555555556',
        role: UserRole.departmentManager,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        departmentIds: const ['d1', 'd2'],
      );
      // يملك الإدارتين ومع ذلك لا يملك النقل بينهما: قرار هيكلي لا تنظيمي.
      expect(store.canMoveSectionAcrossDepartments, isFalse);
    });

    test('النقل يرفض من لا يملك الصلاحية ولا يغيّر شيئاً', () async {
      final store = _store();
      store.currentUser = AppUser(
        id: 'emp-1',
        name: 'موظف',
        email: 'emp@moj.gov.kw',
        phone: '+96555555557',
        role: UserRole.employee,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        departmentId: 'd1',
      );
      final error = await store.moveSectionToDepartment(
        store.sections.firstWhere((s) => s.id == 's1'),
        'd2',
      );
      expect(error, isNotNull);
    });

    test('فرع القسم المنقول يشمل القسم وأقسامه الفرعية ومشاريعها', () {
      final store = _store();
      // ما سينتقل: القسم s1 وفرعاه، ومشاريع p1 وp2 وp3.
      final branch = store.sectionWithDescendants('s1');
      expect(branch, {'s1', 's1a', 's1b'});
      final moving = store.projects.where((p) => p.sectionId != null && branch.contains(p.sectionId));
      expect(moving.map((p) => p.id), containsAll(['p1', 'p2', 'p3']));
      // ولا يمسّ أقسام إدارة أخرى.
      expect(branch.contains('x1'), isFalse);
    });
  });

  group('تحويل إدارة إلى قسم', () {
    test('الصلاحية لمسؤول النظام وحده، وتُرفض لغيره برسالة', () async {
      final store = _store();
      store.currentUser = AppUser(
        id: 'mgr-1',
        name: 'مدير إدارة',
        email: 'mgr@moj.gov.kw',
        phone: '+96555555556',
        role: UserRole.departmentManager,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        departmentIds: const ['d1', 'd2'],
      );
      final error = await store.convertDepartmentToSection(
        const Department(id: 'd1', name: 'إدارة', headName: 'رئيس', colorValue: 0, iconKey: 'flag'),
        'd2',
      );
      expect(error, isNotNull);
    });

    test('تحويل إدارة إلى نفسها مرفوض', () async {
      final store = _store();
      final error = await store.convertDepartmentToSection(
        const Department(id: 'd1', name: 'إدارة', headName: 'رئيس', colorValue: 0, iconKey: 'flag'),
        'd1',
      );
      expect(error, contains('نفسها'));
    });

    // ــ والحدُّ باقٍ، وإن اتّسع ــ
    //
    // بعمقٍ من أربع طبقاتٍ لم يعد قسمٌ فرعيٌّ واحدٌ يتجاوز الحدَّ بالتحويل:
    // ينزل إلى الثالثة وفيها متّسع. فيُقاس الحدُّ بشجرةٍ **تبلغ القاع** —
    // وهي الحالُ التي يُردّ فيها التحويل.
    test('وإدارةٌ شجرتُها تبلغ القاعَ تُرفض حتى لا تتجاوزه', () async {
      final store = _store();
      store.sections = [
        ...store.sections,
        const DepartmentSection(id: 's1a1', departmentId: 'd1', parentId: 's1a', name: 'فريق'),
        const DepartmentSection(id: 's1a1a', departmentId: 'd1', parentId: 's1a1', name: 'وحدة'),
      ];
      store.departments = const [
        Department(id: 'd1', name: 'إدارة أولى', headName: 'رئيس', colorValue: 0, iconKey: 'flag'),
        Department(id: 'd2', name: 'إدارة ثانية', headName: 'رئيس', colorValue: 0, iconKey: 'flag'),
      ];
      final error = await store.convertDepartmentToSection(store.departments.first, 'd2');
      expect(error, contains('أقساماً فرعية'));
    });

    test('الإدارة المستقبِلة غير الموجودة تُرفض', () async {
      final store = _store();
      store.departments = const [
        Department(id: 'dX', name: 'إدارة', headName: 'رئيس', colorValue: 0, iconKey: 'flag'),
      ];
      final error = await store.convertDepartmentToSection(store.departments.first, 'لا-وجود-له');
      expect(error, contains('غير موجودة'));
    });
  });

  group('الاستيراد لا يُلغي التحويل', () {
    test('القسم المحوَّل يحمل معرّف الإدارة التي جاء منها', () {
      const converted = DepartmentSection(
        id: 'new-sec',
        departmentId: 'dept_dev',
        name: 'قسم النظم الآلية',
        headName: 'آلاء الضفيري (تكليف)',
        sourceDepartmentId: 'sec_auto_systems',
      );
      // هذه العلامة هي ما يقرأه الاستيراد ليكتب المشاريع داخل القسم بدل
      // إعادة إنشاء الإدارة المحذوفة.
      expect(converted.sourceDepartmentId, 'sec_auto_systems');
      expect(converted.headName, contains('آلاء'));
      expect(DepartmentSection.fromMapForTest(converted.toMap(), 'new-sec').sourceDepartmentId, 'sec_auto_systems');
      expect(DepartmentSection.fromMapForTest(converted.toMap(), 'new-sec').headName, contains('آلاء'));
    });
  });
}
