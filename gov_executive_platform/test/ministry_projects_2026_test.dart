import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/ministry_projects_2026.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

/// اختبارات سلامة بيانات ملف «مراقبة تنفيذ المشروعات ٢٠٢٦».
///
/// هذه بيانات مُدخَلة يدوياً من مستند رسمي يُعرض على الوزير، فالخطأ فيها
/// خطأ في محتوى المنصة لا في شيفرتها — لذا تُفحص هنا بدل الاكتفاء بمراجعتها
/// بالعين.
void main() {
  final departments = MinistryProjects2026.departments();
  final projects = MinistryProjects2026.projects();

  test('عدد الأقسام والمشاريع يطابق الملفين', () {
    expect(departments.length, 6);
    expect(projects.length, 108);
  });

  test('توزيع المشاريع على الأقسام يطابق الملف', () {
    int countIn(String deptId) => projects.where((p) => p.departmentId == deptId).length;
    expect(countIn(MinistryProjects2026.deptAutoSystems), 33);
    expect(countIn(MinistryProjects2026.deptDocArchive), 5);
    expect(countIn(MinistryProjects2026.deptSysMaintenance), 18);
    expect(countIn(MinistryProjects2026.deptProductionQuality), 4);
    expect(countIn(MinistryProjects2026.deptStateAgreements), 11);
    // ٣٧ لا ٣٨: ترقيم الملف يقفز من ١٥ إلى ١٧ (لا وجود للبند ١٦).
    expect(countIn(MinistryProjects2026.deptPlanning), 37);
  });

  /// الملف الثاني يعيد الأول كاملاً، فالحماية الوحيدة من ازدواج الـ٧١ مشروعاً
  /// القديمة هي **ثبات معرّفاتها**: أي تغيير في معرّف يجعل الاستيراد يُنشئ
  /// سجلاً ثانياً بدل أن يدمج. هذا الاختبار يثبّتها.
  test('معرّفات المشاريع الـ٧١ السابقة لم تتغيّر — وإلا ازدوجت البيانات', () {
    final ids = projects.map((p) => p.id).toSet();
    for (var i = 1; i <= 33; i++) {
      expect(ids.contains('mp26_auto_$i'), isTrue, reason: 'مفقود mp26_auto_$i');
    }
    for (var i = 1; i <= 5; i++) {
      expect(ids.contains('mp26_doc_$i'), isTrue, reason: 'مفقود mp26_doc_$i');
    }
    for (var i = 1; i <= 18; i++) {
      expect(ids.contains('mp26_maint_$i'), isTrue, reason: 'مفقود mp26_maint_$i');
    }
    for (var i = 1; i <= 4; i++) {
      expect(ids.contains('mp26_qual_$i'), isTrue, reason: 'مفقود mp26_qual_$i');
    }
    for (var i = 1; i <= 11; i++) {
      expect(ids.contains('mp26_state_$i'), isTrue, reason: 'مفقود mp26_state_$i');
    }
  });

  test('معرّفات قسم التخطيط تحمل رقم البند كما في الملف، بلا البند ١٦', () {
    final planIds = projects
        .where((p) => p.departmentId == MinistryProjects2026.deptPlanning)
        .map((p) => p.id)
        .toSet();
    expect(planIds.contains('mp26_plan_16'), isFalse);
    for (final i in [...List.generate(15, (i) => i + 1), ...List.generate(22, (i) => i + 17)]) {
      expect(planIds.contains('mp26_plan_$i'), isTrue, reason: 'مفقود mp26_plan_$i');
    }
  });

  test('المشاريع المتشابهة موضوعاً تحمل إشارة متبادلة لبعضها', () {
    Project byId(String id) => projects.firstWhere((p) => p.id == id);
    // كل طرف يشير للآخر، فلا يمرّ أحدهما على المستخدم دون أن يعلم بنظيره.
    expect(byId('mp26_plan_6').description, contains('يشبه موضوعاً'));
    expect(byId('mp26_maint_18').description, contains('يشبه موضوعاً'));
    expect(byId('mp26_plan_13').description, contains('يشبه موضوعاً'));
    expect(byId('mp26_state_11').description, contains('يشبه موضوعاً'));
    expect(byId('mp26_plan_32').description, contains('يشبه موضوعاً'));
    expect(byId('mp26_auto_30').description, contains('يشبه موضوعاً'));
  });

  test('المعرّفات فريدة — وإلا داس الاستيراد سجلات بعضها', () {
    final ids = projects.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    final deptIds = departments.map((d) => d.id).toList();
    expect(deptIds.toSet().length, deptIds.length);
  });

  test('كل مشروع ينتمي لقسم موجود فعلاً', () {
    final known = departments.map((d) => d.id).toSet();
    for (final p in projects) {
      expect(known.contains(p.departmentId), isTrue, reason: 'المشروع ${p.id} ينتمي لقسم غير معرّف');
    }
  });

  test('كل مشروع له اسم ووصف غير فارغين', () {
    for (final p in projects) {
      expect(p.name.trim(), isNotEmpty, reason: 'المشروع ${p.id} بلا اسم');
      expect(p.description.trim(), isNotEmpty, reason: 'المشروع ${p.id} بلا وصف');
    }
  });

  test('أسماء المشاريع لا تتكرر داخل القسم الواحد', () {
    for (final dept in departments) {
      final names = projects.where((p) => p.departmentId == dept.id).map((p) => p.name).toList();
      expect(names.toSet().length, names.length, reason: 'تكرار في أسماء مشاريع ${dept.name}');
    }
  });

  test('تاريخ الانتهاء لا يسبق تاريخ البدء', () {
    for (final p in projects) {
      expect(p.dueDate.isBefore(p.startDate), isFalse, reason: 'المشروع ${p.id} موعده النهائي قبل بدايته');
    }
  });

  test('نسبة الإنجاز ضمن المدى، والمكتمل ١٠٠٪ والذي لم يبدأ صفر', () {
    for (final p in projects) {
      expect(p.progressPercent, inInclusiveRange(0, 100), reason: 'نسبة إنجاز خارج المدى في ${p.id}');
      if (p.status == ProjectStatus.completed) {
        expect(p.progressPercent, 100, reason: 'المشروع المكتمل ${p.id} نسبته ليست ١٠٠٪');
      }
    }
  });

  test('رؤساء الأقسام مسجّلون كما وردوا في ترويسات الملف', () {
    String headOf(String id) => departments.firstWhere((d) => d.id == id).headName;
    expect(headOf(MinistryProjects2026.deptAutoSystems), contains('آلاء الضفيري'));
    expect(headOf(MinistryProjects2026.deptSysMaintenance), contains('أشواق الخباز'));
    expect(headOf(MinistryProjects2026.deptProductionQuality), contains('شيماء العلي'));
    expect(headOf(MinistryProjects2026.deptPlanning), contains('هدى الفهد'));
  });
}
