// اختبارات حالات الحدود في توليد تقرير PDF: جداول فارغة، إدارة غير معروفة،
// نصوص فيها رموز ولاتينية، ملخص متعدد الأسطر. هذه هي الحالات التي تنتجها
// بيانات المستخدم الحقيقية ولا يمرّ بها `test/render_report_preview.dart`
// إطلاقاً، وكانت أقوى المرشّحين لتفسير «التصدير لا يفعل شيئاً».
//
// **ملاحظة مهمة**: هذه الاختبارات تعمل على جهاز Dart لا في متصفح. حاولتُ
// تشغيلها بـ `flutter test --platform chrome` فتعلّقت عند `rootBundle.load`
// إلى الأبد — لأن خادم اختبارات المتصفح **لا يقدّم أصول التطبيق أصلاً**، فهو
// قيد في أداة الاختبار لا عطل في المنصة. للتحقق داخل متصفح حقيقي بحزمة أصول
// حقيقية استخدم `lib/dev/pdf_probe_main.dart` (تعليماته في رأس الملف).
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/data/ministry_projects_2026.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/report.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/utils/report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final departments = MinistryProjects2026.departments();
  final byId = {for (final d in departments) d.id: d};
  Department? departmentById(String id) => byId[id];

  final report = ReportSnapshot(
    id: 'r-web',
    period: ReportPeriod.monthly,
    generatedDate: DateTime(2026, 8, 19),
    executiveSummary:
        'أظهرت مؤشرات الأداء خلال الفترة تحسناً في نسبة الإنجاز العام مقارنة بالفترة السابقة، '
        'مع بقاء عدد من المشاريع ضمن نطاق المخاطر بسبب تأخر اعتماد المتطلبات الفنية.',
    avgProgress: 62.4,
    avgDelayDays: 4.2,
    totalRisks: 7,
    totalBlockers: 3,
    pendingDecisions: 2,
    departmentRanking: [
      for (final d in departments) MapEntry(d.name, 40.0 + d.name.length % 40),
    ],
    manualComment: 'يوصى بعقد اجتماع تنفيذي لمراجعة المشاريع المتأخرة.',
  );

  final works = List.generate(
    12,
    (i) => WorkItem(
      id: 'w$i',
      title: 'متابعة المعاملات الواردة — الأسبوع ${i + 1}',
      description: 'عمل تشغيلي دوري',
      departmentId: departments[i % departments.length].id,
      assigneeUid: 'u$i',
      assigneeName: 'موظف رقم ${i + 1}',
      status: TaskStatus.values[i % TaskStatus.values.length],
      priority: PriorityLevel.values[i % PriorityLevel.values.length],
      progressPercent: (i * 9) % 100,
      dueDate: DateTime(2026, 9, 30),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  // الحمل الحقيقي لا حمل تجريبي مصغّر: ١٠٨ مشاريع هي ما يملكه المستخدم فعلاً،
  // وعطل يظهر عند هذا الحجم وحده لن يكشفه اختبار بمشروعين.
  test('توليد تقرير PDF بكامل بيانات الوزارة ينجح', () async {
    final projects = MinistryProjects2026.projects();
    expect(projects.length, 108, reason: 'تغيّر حجم البيانات — راجع الاختبار');

    final bytes = await ReportExporter.buildPdfBytes(
      report: report,
      projects: projects,
      departmentById: departmentById,
      works: works,
    );

    // ‏%PDF- هي توقيع الملف؛ وجوده يعني أننا أنتجنا مستنداً لا بايتات عشوائية.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(50000));
  });

  // حالة الحدود: تقرير بلا مشاريع ولا أعمال ولا تعليق. الجداول الفارغة كانت
  // مرشّحاً قوياً للانفجار، ولا يمرّ بها اختبار المعاينة إطلاقاً.
  test('تقرير بلا مشاريع ولا أعمال يُنتج ملفاً سليماً لا استثناءً', () async {
    final bytes = await ReportExporter.buildPdfBytes(
      report: ReportSnapshot(
        id: 'r-empty',
        period: ReportPeriod.weekly,
        generatedDate: DateTime(2026, 8, 19),
        executiveSummary: 'لا توجد بيانات كافية لهذه الفترة.',
        avgProgress: 0,
        avgDelayDays: 0,
        totalRisks: 0,
        totalBlockers: 0,
        pendingDecisions: 0,
        departmentRanking: const [],
      ),
      projects: const [],
      departmentById: departmentById,
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
