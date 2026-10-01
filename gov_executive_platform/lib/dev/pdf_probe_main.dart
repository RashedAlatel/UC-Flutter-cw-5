// أداة تشخيص: تبني تقرير PDF بنفس شيفرة المنصة **داخل متصفح حقيقي وبحزمة
// أصول حقيقية**، وتطبع نتيجة كل سيناريو على طرفية المتصفح.
//
// لماذا تلزم أداة مستقلة؟ لأن `flutter test --platform chrome` لا يقدّم أصول
// التطبيق، فيتعلّق `rootBundle.load` إلى الأبد وتصير نتيجته بلا معنى. وشاشة
// التقارير نفسها خلف تسجيل دخول، فلا يمكن بلوغها آلياً. هذا المدخل يجمع
// الاثنين: شيفرة الإنتاج نفسها، ومتصفح حقيقي، وأصول حقيقية، بلا تسجيل دخول.
//
// التشغيل:
//   flutter build web -t lib/dev/pdf_probe_main.dart -o build/pdfprobe \
//       --no-web-resources-cdn
//   (cd build/pdfprobe && python3 -m http.server 8163)
//   ثم افتح http://127.0.0.1:8163/ وراجع طرفية المتصفح — كل سطر يبدأ بـ PROBE.
//
// هذا الملف خارج مسار بناء المنصة (مدخلها `lib/main.dart`)، فلا يدخل حزمة
// الإصدار ولا يزيد حجمها.
import 'package:flutter/material.dart';

import '../data/ministry_projects_2026.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/report.dart';
import '../models/work_item.dart';
import '../utils/report_export.dart';

void log(String m) {
  // ignore: avoid_print
  print('PROBE $m');
}

final _departments = MinistryProjects2026.departments();
final _byId = {for (final d in _departments) d.id: d};
Department? _departmentById(String id) => _byId[id];

ReportSnapshot _report({
  List<MapEntry<String, double>> ranking = const [],
  String summary = 'ملخص تنفيذي تجريبي.',
  String comment = '',
}) =>
    ReportSnapshot(
      id: 'r',
      period: ReportPeriod.monthly,
      generatedDate: DateTime(2026, 8, 19),
      executiveSummary: summary,
      avgProgress: 62.4,
      avgDelayDays: 4.2,
      totalRisks: 7,
      totalBlockers: 3,
      pendingDecisions: 2,
      departmentRanking: ranking,
      manualComment: comment,
    );

Future<void> scenario(
  String name, {
  required ReportSnapshot report,
  required List<Project> projects,
  List<WorkItem> works = const [],
}) async {
  try {
    final bytes = await ReportExporter.buildPdfBytes(
      report: report,
      projects: projects,
      departmentById: _departmentById,
      works: works,
    );
    log('OK   $name → ${bytes.length} bytes');
  } catch (e) {
    log('FAIL $name → $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe')))));

  final all = MinistryProjects2026.projects();
  final ranking = [for (final d in _departments) MapEntry(d.name, 55.0)];

  final works = List.generate(
    8,
    (i) => WorkItem(
      id: 'w$i',
      title: 'متابعة المعاملات الواردة — الأسبوع ${i + 1}',
      description: 'عمل تشغيلي دوري',
      departmentId: _departments[i % _departments.length].id,
      assigneeUid: 'u$i',
      assigneeName: i == 0 ? '' : 'موظف رقم ${i + 1}',
      status: TaskStatus.values[i % TaskStatus.values.length],
      priority: PriorityLevel.values[i % PriorityLevel.values.length],
      progressPercent: (i * 9) % 100,
      dueDate: DateTime(2026, 9, 30),
      createdByUid: 'admin',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  log('=== scenarios begin ===');

  await scenario('كامل بلا أعمال',
      report: _report(ranking: ranking), projects: all);

  await scenario('كامل مع أعمال',
      report: _report(ranking: ranking, comment: 'تعليق تنفيذي.'),
      projects: all,
      works: works);

  await scenario('بلا مشاريع وبلا ترتيب إدارات',
      report: _report(), projects: const []);

  await scenario('ترتيب إدارات فارغ ومشاريع موجودة',
      report: _report(), projects: all);

  await scenario('مشاريع بلا منفّذين وبإدارة غير معروفة',
      report: _report(ranking: ranking),
      projects: [
        Project(
          id: 'x1',
          departmentId: 'لا-وجود-لها',
          name: 'مشروع بلا إدارة',
          description: '',
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 12, 31),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: 10,
        ),
      ]);

  await scenario('ملخص متعدد الأسطر وتعليق طويل',
      report: _report(
        ranking: ranking,
        summary: 'السطر الأول.\n\nالسطر الثالث بعد فراغ.\nالسطر الرابع.',
        comment: 'تعليق طويل جداً. ' * 60,
      ),
      projects: all);

  await scenario('اسم مشروع فيه رموز ولاتينية وأرقام',
      report: _report(ranking: ranking),
      projects: [
        Project(
          id: 'x2',
          departmentId: _departments.first.id,
          name: 'Migration نظام «التنفيذ» — 2026/2027 (مرحلة ١) 100%',
          description: 'وصف فيه <وسم> و&رمز و"اقتباس"',
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 12, 31),
          status: ProjectStatus.atRisk,
          priority: PriorityLevel.high,
          progressPercent: 45,
          executorNames: const ['فهد', 'Sarah Al-Ali'],
        ),
      ]);

  // وأخيراً مسار التسليم كاملاً: البناء ثم التنزيل الفعلي عبر المتصفح.
  try {
    final url = await ReportExporter.exportPdf(
      report: _report(ranking: ranking),
      projects: all,
      departmentById: _departmentById,
    );
    log('OK   تنزيل الملف → $url');
  } catch (e) {
    log('FAIL تنزيل الملف → $e');
  }

  log('=== scenarios end ===');
}
