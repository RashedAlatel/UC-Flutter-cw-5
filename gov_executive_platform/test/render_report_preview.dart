// أداة معاينة (وليست اختباراً تعاقدياً): تولّد تقرير PDF ببيانات تجريبية
// وتحفظه لمراجعة الترويسة والإطار الزخرفي الرسمي بصرياً قبل النشر.
// تُشغَّل يدوياً عبر: flutter test test/render_report_preview.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/report.dart';
import 'package:gov_exec_platform/theme/department_icons.dart';
import 'package:gov_exec_platform/utils/report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render report pdf preview', () async {
    final dept = Department(
      id: 'd1',
      name: 'إدارة تقنية المعلومات',
      headName: 'م. عبدالله الفهد',
      colorValue: 0xFF0E4D3C,
      iconKey: DepartmentIcons.defaultKey,
    );

    final projects = List.generate(
      14,
      (i) => Project(
        id: 'p$i',
        departmentId: 'd1',
        name: 'مشروع تطوير الخدمة الإلكترونية رقم ${i + 1}',
        description: 'وصف مختصر للمشروع',
        startDate: DateTime(2026, 1, 10),
        dueDate: DateTime(2026, 9, 30),
        status: ProjectStatus.values[i % ProjectStatus.values.length],
        priority: PriorityLevel.values[i % PriorityLevel.values.length],
        progressPercent: (i * 7) % 100,
        executorNames: const ['فهد المطيري', 'نورة العنزي'],
      ),
    );

    final report = ReportSnapshot(
      id: 'r1',
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
        const MapEntry('إدارة تقنية المعلومات', 71.0),
        const MapEntry('إدارة التشغيل', 54.0),
        const MapEntry('إدارة الدعم الفني', 38.5),
      ],
      manualComment: 'يوصى بعقد اجتماع تنفيذي لمراجعة المشاريع المتأخرة.',
    );

    final bytes = await ReportExporter.buildPdfBytes(
      report: report,
      projects: projects,
      departmentById: (id) => id == 'd1' ? dept : null,
    );

    final out = File('build/report_preview.pdf');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('WROTE ${out.absolute.path} (${bytes.length} bytes)');
    expect(bytes.length, greaterThan(1000));
  });
}
