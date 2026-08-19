import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
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

  test('العمق محدود بمستويين: لا قسم فرعي تحت قسم فرعي', () {
    final store = _store();
    final top = store.sections.firstWhere((s) => s.id == 's1');
    final child = store.sections.firstWhere((s) => s.id == 's1a');
    expect(store.canAddChildSection(top), isTrue);
    expect(store.canAddChildSection(child), isFalse);
    expect(top.levelIn(store.sections), 1);
    expect(child.levelIn(store.sections), 2);
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
}
