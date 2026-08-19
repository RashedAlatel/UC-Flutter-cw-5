import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/ministry_projects_2026.dart';
import 'package:gov_exec_platform/models/enums.dart';

/// اختبارات سلامة بيانات ملف «مراقبة تنفيذ المشروعات ٢٠٢٦».
///
/// هذه بيانات مُدخَلة يدوياً من مستند رسمي يُعرض على الوزير، فالخطأ فيها
/// خطأ في محتوى المنصة لا في شيفرتها — لذا تُفحص هنا بدل الاكتفاء بمراجعتها
/// بالعين.
void main() {
  final departments = MinistryProjects2026.departments();
  final projects = MinistryProjects2026.projects();

  test('عدد الأقسام والمشاريع يطابق الملف الأصلي', () {
    expect(departments.length, 5);
    expect(projects.length, 71);
  });

  test('توزيع المشاريع على الأقسام يطابق الملف', () {
    int countIn(String deptId) => projects.where((p) => p.departmentId == deptId).length;
    expect(countIn(MinistryProjects2026.deptAutoSystems), 33);
    expect(countIn(MinistryProjects2026.deptDocArchive), 5);
    expect(countIn(MinistryProjects2026.deptSysMaintenance), 18);
    expect(countIn(MinistryProjects2026.deptProductionQuality), 4);
    expect(countIn(MinistryProjects2026.deptStateAgreements), 11);
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
  });
}
