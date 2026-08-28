import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/department.dart';
import '../models/project.dart';
import '../models/report.dart';
import '../models/work_item.dart';
import '../reports/periodic_report.dart';
import '../theme/brand.dart';
import 'file_download.dart';
import 'formatters.dart';
import 'pdf_safe_text.dart';

/// تصدير التقارير التنفيذية إلى ملفات Excel أو PDF قابلة للتنزيل مباشرة من
/// المتصفح. تُستدعى دوال هذا الملف عند ضغط المستخدم أزرار "تصدير" في شاشة
/// التقارير، وتحمل نفس بيانات التقرير المعروضة على الشاشة (الملخص، المؤشرات،
/// ترتيب الإدارات) بالإضافة إلى قائمة المشاريع الحالية ضمن نطاق المستخدم.
class ReportExporter {
  // ألوان الهوية الرسمية للمنصة (أخضر كويتي + ذهبي). يبقى الاسم navy
  // للتوافق مع مواضع الاستخدام أدناه دون تغييرها جميعاً.
  static const _navy = PdfColor.fromInt(0xFF0E4D3C);
  static const _gold = PdfColor.fromInt(0xFFC9A227);
  static const _grey = PdfColor.fromInt(0xFF5F6B7A);
  static const _border = PdfColor.fromInt(0xFFE3E8EF);

  /// اسم ملف التقرير — **لاتيني عمداً**.
  ///
  /// كان `تقرير_...`، وقياسٌ في متصفح حقيقي أثبت أن كروم يُسقط أي اسم تنزيل
  /// فيه حرف عربي فيحفظ الملف باسم `download` بلا امتداد، فلا يفتحه عارض
  /// PDF ويبدو للمستخدم أن شيئاً لم يحدث. تفصيل القياس في
  /// `lib/utils/safe_file_name.dart`.
  static String _fileBaseName(ReportSnapshot report) =>
      'MOJ-report-${report.period.name}-'
      '${Formatters.shortDate(report.generatedDate).replaceAll('/', '-')}';

  // ------------------------- Excel -------------------------

  /// يبني ملف Excel وينزّله، ويعيد عنوان الملف داخل المتصفح ليُعرض للمستخدم
  /// مخرج بديل إن لم يبدأ التنزيل تلقائياً.
  static Future<String> exportExcel({
    required ReportSnapshot report,
    required List<Project> projects,
    required Department? Function(String id) departmentById,
    List<WorkItem> works = const [],
  }) async {
    final workbook = xls.Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet();

    final summarySheet = workbook['الملخص التنفيذي'];
    summarySheet.appendRow([xls.TextCellValue('المؤشر'), xls.TextCellValue('القيمة')]);
    summarySheet.appendRow([xls.TextCellValue('نوع التقرير'), xls.TextCellValue(report.period.label)]);
    summarySheet.appendRow([xls.TextCellValue('تاريخ التوليد'), xls.TextCellValue(Formatters.date(report.generatedDate))]);
    summarySheet.appendRow([xls.TextCellValue('متوسط نسبة الإنجاز'), xls.DoubleCellValue(report.avgProgress)]);
    summarySheet.appendRow([xls.TextCellValue('متوسط التأخير (يوم)'), xls.DoubleCellValue(report.avgDelayDays)]);
    summarySheet.appendRow([xls.TextCellValue('المخاطر القائمة'), xls.IntCellValue(report.totalRisks)]);
    summarySheet.appendRow([xls.TextCellValue('العوائق النشطة'), xls.IntCellValue(report.totalBlockers)]);
    summarySheet.appendRow([xls.TextCellValue('طلبات بانتظار القيادة'), xls.IntCellValue(report.pendingDecisions)]);
    summarySheet.appendRow([xls.TextCellValue('')]);
    summarySheet.appendRow([xls.TextCellValue('الملخص التنفيذي')]);
    for (final line in report.executiveSummary.split('\n')) {
      if (line.trim().isNotEmpty) summarySheet.appendRow([xls.TextCellValue(line.trim())]);
    }
    if (report.manualComment.trim().isNotEmpty) {
      summarySheet.appendRow([xls.TextCellValue('')]);
      summarySheet.appendRow([xls.TextCellValue('تعليق تنفيذي')]);
      summarySheet.appendRow([xls.TextCellValue(report.manualComment.trim())]);
    }

    final rankingSheet = workbook['ترتيب الإدارات'];
    rankingSheet.appendRow([xls.TextCellValue('الإدارة'), xls.TextCellValue('نسبة الإنجاز')]);
    for (final e in report.departmentRanking) {
      rankingSheet.appendRow([xls.TextCellValue(e.key), xls.DoubleCellValue(e.value)]);
    }

    final projectsSheet = workbook['المشاريع'];
    projectsSheet.appendRow([
      xls.TextCellValue('اسم المشروع'),
      xls.TextCellValue('الإدارة'),
      xls.TextCellValue('الحالة'),
      xls.TextCellValue('نسبة الإنجاز'),
      xls.TextCellValue('أيام التأخير'),
      xls.TextCellValue('المنفذ'),
      xls.TextCellValue('تاريخ الاستحقاق'),
    ]);
    for (final p in projects) {
      projectsSheet.appendRow([
        xls.TextCellValue(p.name),
        xls.TextCellValue(departmentById(p.departmentId)?.name ?? ''),
        xls.TextCellValue(p.effectiveStatus.label),
        xls.DoubleCellValue(p.progressPercent),
        xls.IntCellValue(p.delayDays),
        xls.TextCellValue(p.executorLabel),
        xls.TextCellValue(Formatters.shortDate(p.dueDate)),
      ]);
    }

    if (works.isNotEmpty) {
      final worksSheet = workbook['الأعمال التشغيلية'];
      worksSheet.appendRow([
        xls.TextCellValue('العمل'),
        xls.TextCellValue('الإدارة'),
        xls.TextCellValue('المسؤول'),
        xls.TextCellValue('الحالة'),
        xls.TextCellValue('نسبة الإنجاز'),
        xls.TextCellValue('الموعد'),
        xls.TextCellValue('تاريخ الإنجاز'),
      ]);
      for (final w in works) {
        worksSheet.appendRow([
          xls.TextCellValue(w.title),
          xls.TextCellValue(departmentById(w.departmentId)?.name ?? ''),
          xls.TextCellValue(w.assigneeName),
          xls.TextCellValue(w.status.label),
          xls.DoubleCellValue(w.progressPercent),
          xls.TextCellValue(Formatters.shortDate(w.dueDate)),
          xls.TextCellValue(w.completedDate == null ? '' : Formatters.shortDate(w.completedDate!)),
        ]);
      }
    }

    if (defaultSheetName != null) workbook.delete(defaultSheetName);

    // `encode()` لا `save()`: الأخيرة تُنزّل الملف بنفسها عبر مسارها الخاص،
    // فيصير للمنصة مساران مختلفان للتنزيل — أحدهما لا نملكه ولا نعرف سبب
    // فشله ولا يعطينا عنوان الملف. `encode()` تعطينا البايتات فحسب، فيمرّ
    // التصديران كلاهما من مسار واحد نملكه ونشخّصه.
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('تعذّر ترميز ملف Excel — لم تُنتج المكتبة أي بايتات.');
    }
    return downloadBytes(
      Uint8List.fromList(bytes),
      '${_fileBaseName(report)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ------------------------- PDF -------------------------

  /// يبني تقرير PDF وينزّله، ويعيد عنوان الملف داخل المتصفح.
  static Future<String> exportPdf({
    required ReportSnapshot report,
    required List<Project> projects,
    required Department? Function(String id) departmentById,
    List<WorkItem> works = const [],
  }) async {
    final bytes = await buildPdfBytes(report: report, projects: projects, departmentById: departmentById, works: works);
    return downloadBytes(bytes, '${_fileBaseName(report)}.pdf', 'application/pdf');
  }

  /// يبني ملف التقرير ويعيد بايتاته دون مشاركته. مفصول عن [exportPdf] حتى
  /// يمكن توليد التقرير والتحقق من شكله في الاختبارات (مشاركة الملف تحتاج
  /// منصة فعلية ولا تعمل داخل بيئة الاختبار).
  static Future<Uint8List> buildPdfBytes({
    required ReportSnapshot report,
    required List<Project> projects,
    required Department? Function(String id) departmentById,
    List<WorkItem> works = const [],
  }) async {
    final regular = await _loadFont('assets/fonts/Tajawal-Regular.ttf');
    final medium = await _loadFont('assets/fonts/Tajawal-Medium.ttf');
    final bold = await _loadFont('assets/fonts/Tajawal-Bold.ttf');
    final emblem = await _loadImage('assets/images/logo.png');
    final ornament = await _loadImage('assets/images/frame_border.png');

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(regular: regular, bold: bold, ornament: ornament),
        header: (context) => _header(
          regular: regular,
          medium: medium,
          bold: bold,
          emblem: emblem,
          caption: 'تقرير ${report.period.label}',
        ),
        footer: (context) => _footer(regular: regular, context: context),
        build: (context) => [
          pw.Text('تقرير ${report.period.label} — ${Formatters.date(report.generatedDate)}',
              style: pw.TextStyle(font: bold, fontSize: 18, color: _navy)),
          pw.SizedBox(height: 16),
          pw.Text('الملخص التنفيذي', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(pdfSafeText(report.executiveSummary), style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3)),
          ),
          pw.SizedBox(height: 18),
          pw.Text('المؤشرات الرئيسية', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headers: _safeRow(['متوسط الإنجاز', 'متوسط التأخير', 'المخاطر', 'العوائق', 'قرارات معلقة']),
            data: [
              [
                '${report.avgProgress.toStringAsFixed(1)}٪',
                '${report.avgDelayDays.toStringAsFixed(1)} يوم',
                '${report.totalRisks}',
                '${report.totalBlockers}',
                '${report.pendingDecisions}',
              ],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('ترتيب الإدارات حسب الأداء', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headers: _safeRow(['الإدارة', 'نسبة الإنجاز']),
            data: _safeRows(report.departmentRanking.map((e) => [e.key, '${e.value.toStringAsFixed(1)}٪']).toList()),
          ),
          pw.SizedBox(height: 18),
          pw.Text('المشاريع (${projects.length})', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
            cellAlignment: pw.Alignment.centerRight,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.6),
            },
            headers: _safeRow(['اسم المشروع', 'الإدارة', 'الحالة', 'التقدم', 'المنفذ']),
            data: _safeRows(projects
                .map((p) => [
                      p.name,
                      departmentById(p.departmentId)?.name ?? '',
                      p.effectiveStatus.label,
                      '${p.progressPercent.toStringAsFixed(0)}٪',
                      p.executorLabel,
                    ])
                .toList()),
          ),
          if (works.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('الأعمال التشغيلية (${works.length})', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: pw.TextStyle(font: regular, fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: _border, width: 0.5),
              headers: _safeRow(['العمل', 'الإدارة', 'المسؤول', 'الحالة', 'الإنجاز']),
              data: _safeRows(works
                  .map((w) => [
                        w.title,
                        departmentById(w.departmentId)?.name ?? 'بدون إدارة',
                        w.assigneeName.isEmpty ? '—' : w.assigneeName,
                        w.status.label,
                        '${w.progressPercent.toStringAsFixed(0)}٪',
                      ])
                  .toList()),
            ),
          ],
          if (report.manualComment.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('تعليق تنفيذي', style: pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
            pw.SizedBox(height: 6),
            pw.Text(pdfSafeText(report.manualComment.trim()), style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3)),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ــــ زينةُ الصفحة: ترويسةٌ وتذييلٌ وإطارٌ واحدٌ لكل تقارير المنصة ــــ
  //
  // كانت مكتوبةً داخل [buildPdfBytes] وحدها، فأيُّ تقريرٍ جديد إما أن يُعيد
  // كتابتها فيفترق شكلُه بعد حين، أو يخرج بلا ترويسةٍ رسمية. فأُخرجت هنا:
  // التقرير الدوري والتقرير التنفيذي يخرجان بالورقة نفسها حرفاً بحرف.

  static pw.PageTheme _pageTheme({
    required pw.Font regular,
    required pw.Font bold,
    required pw.MemoryImage? ornament,
  }) =>
      // buildBackground متاح عبر PageTheme فقط، لذا تُجمَّع إعدادات الصفحة
      // كلها هنا بدل تمريرها مفردة إلى MultiPage.
      pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        // الهوامش الجانبية موسّعة لإفساح مكان الإطار الزخرفي الرسمي.
        margin: const pw.EdgeInsets.fromLTRB(46, 32, 46, 32),
        buildBackground: (context) => _ornamentFrame(ornament),
      );

  static pw.Widget _header({
    required pw.Font regular,
    required pw.Font medium,
    required pw.Font bold,
    required pw.MemoryImage? emblem,
    required String caption,
  }) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (emblem != null) ...[
                    pw.Image(emblem, width: 34, height: 34),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(Brand.state, style: pw.TextStyle(font: medium, fontSize: 9, color: _grey)),
                      pw.Text(Brand.ministry, style: pw.TextStyle(font: bold, fontSize: 12, color: _navy)),
                      pw.Text(Brand.platformShort, style: pw.TextStyle(font: regular, fontSize: 8.5, color: _grey)),
                    ],
                  ),
                ],
              ),
              pw.Text(caption, style: pw.TextStyle(font: medium, fontSize: 11, color: _grey)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: _gold),
          pw.SizedBox(height: 14),
        ],
      );

  static pw.Widget _footer({required pw.Font regular, required pw.Context context}) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${Brand.ministry} — ${Brand.state}',
                style: pw.TextStyle(font: regular, fontSize: 8.5, color: _grey)),
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(font: regular, fontSize: 9, color: _grey)),
          ],
        ),
      );

  // ------------------------- التقرير الدوري -------------------------

  /// اسمُ ملف التقرير الدوري — لاتينيٌّ للسبب نفسه أعلاه، وفيه حدَّا الفترة
  /// لا تاريخُ التوليد: ملفّان لفترتين مختلفتين لا يجوز أن يتشابه اسمُهما.
  static String _periodicFileBaseName(PeriodicReport report) {
    String stamp(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'MOJ-periodic-${report.range.period.name}-'
        '${stamp(report.range.start)}_${stamp(report.range.end)}';
  }

  /// ملفُّ Excel للتقرير الدوري: ثلاثُ أوراقٍ بأسمائها العربية.
  ///
  /// و[includeDepartments] ليست تجميلاً: مديرُ الإدارة لا يقرأ مقارنةَ
  /// الإدارات على الشاشة، فلا تخرج له في ملفٍّ يُرسَل. النطاق واحدٌ في
  /// الاثنين.
  static Future<String> exportPeriodicExcel({
    required PeriodicReport report,
    required bool includeDepartments,
  }) async {
    return downloadBytes(
      buildPeriodicExcelBytes(report: report, includeDepartments: includeDepartments),
      '${_periodicFileBaseName(report)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// مفصولةٌ عن التنزيل ليُفتح الملفُّ في اختبارٍ وتُقرأ أوراقُه بأسمائها —
  /// كما هو حال [buildPdfBytes] مع PDF.
  static Uint8List buildPeriodicExcelBytes({
    required PeriodicReport report,
    required bool includeDepartments,
  }) {
    final workbook = xls.Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet();
    final d = report.digest;

    final summary = workbook['الملخص التنفيذي'];
    summary.appendRow([xls.TextCellValue('المؤشر'), xls.TextCellValue('القيمة')]);
    summary.appendRow([xls.TextCellValue('نوع التقرير'), xls.TextCellValue(report.range.period.label)]);
    summary.appendRow([xls.TextCellValue('من'), xls.TextCellValue(Formatters.date(report.range.start))]);
    summary.appendRow([xls.TextCellValue('إلى'), xls.TextCellValue(Formatters.date(report.range.end))]);
    summary.appendRow([xls.TextCellValue('عدد الأيام'), xls.IntCellValue(report.range.days)]);
    summary.appendRow([xls.TextCellValue('إجمالي المشاريع'), xls.IntCellValue(d.totalProjects)]);
    summary.appendRow([xls.TextCellValue('مشاريع متأخرة'), xls.IntCellValue(d.lateProjects)]);
    summary.appendRow([xls.TextCellValue('مشاريع تحتاج تدخّلاً'), xls.IntCellValue(d.projectsNeedingIntervention)]);
    summary.appendRow([xls.TextCellValue('مشاريع بلا تحديث في الفترة'), xls.IntCellValue(d.projectsNotUpdated)]);
    summary.appendRow([xls.TextCellValue('مهام أُنجزت'), xls.IntCellValue(d.tasksCompleted)]);
    summary.appendRow([xls.TextCellValue('مهام متأخرة'), xls.IntCellValue(d.lateTasks)]);
    _appendLines(summary, 'أبرز الإنجازات', d.topAchievements);
    _appendLines(summary, 'أبرز العوائق', d.topBlockers);
    _appendLines(summary, 'الأكثر نشاطاً', d.mostActivePeople);
    _appendLines(summary, 'بلا نشاط مسجَّل', d.idlePeople);
    _appendLines(summary, 'إدارات تحتاج متابعة', d.departmentsNeedingFollowUp);

    final people = workbook['أداء الأشخاص'];
    people.appendRow([
      xls.TextCellValue('الاسم'),
      xls.TextCellValue('مستوى النشاط'),
      xls.TextCellValue('عدد الأنشطة'),
      xls.TextCellValue('مهام أُنجزت'),
      xls.TextCellValue('مهام أضافها'),
      xls.TextCellValue('تحديثات يومية'),
      xls.TextCellValue('تحديثات أعمال'),
      xls.TextCellValue('مرفقات'),
      xls.TextCellValue('مخاطر سجّلها'),
      xls.TextCellValue('عوائق سجّلها'),
      xls.TextCellValue('مهام متأخرة مسندة إليه'),
      xls.TextCellValue('أُنجزت في موعدها'),
      xls.TextCellValue('أُنجزت متأخرة'),
      xls.TextCellValue('منجَزة بلا تاريخ'),
      xls.TextCellValue('مشاريع'),
      xls.TextCellValue('أعمال'),
      xls.TextCellValue('آخر نشاط'),
    ]);
    for (final p in report.people) {
      people.appendRow([
        xls.TextCellValue(p.name),
        xls.TextCellValue(p.activity.label),
        xls.IntCellValue(p.totalActivities),
        xls.IntCellValue(p.tasksCompleted),
        xls.IntCellValue(p.tasksAdded),
        xls.IntCellValue(p.dailyUpdates),
        xls.IntCellValue(p.workUpdates),
        xls.IntCellValue(p.attachmentsUploaded),
        xls.IntCellValue(p.risksRaised),
        xls.IntCellValue(p.blockersRaised),
        xls.IntCellValue(p.lateTasksAssigned),
        xls.IntCellValue(p.finishedOnTime),
        xls.IntCellValue(p.finishedLate),
        // «غير مسجّل» نصّاً لا صفراً: الخلية الفارغة تُقرأ صفراً في Excel،
        // فيعود النقصُ في البيان تقصيراً منسوباً إلى الموظف.
        xls.TextCellValue(p.tasksWithoutCompletionDate == 0
            ? '—'
            : '${p.tasksWithoutCompletionDate} (غير مسجّل)'),
        xls.IntCellValue(p.projectNames.length),
        xls.IntCellValue(p.workTitles.length),
        xls.TextCellValue(
            p.lastActivity == null ? 'لا يوجد' : Formatters.shortDate(p.lastActivity!)),
      ]);
    }
    people.appendRow([xls.TextCellValue('')]);
    people.appendRow([xls.TextCellValue(kActivityDisclaimer)]);

    if (includeDepartments) {
      final depts = workbook['أداء الإدارات'];
      depts.appendRow([
        xls.TextCellValue('الإدارة'),
        xls.TextCellValue('نسبة الإنجاز'),
        xls.TextCellValue('مشاريع'),
        xls.TextCellValue('أعمال'),
        xls.TextCellValue('مهام أُنجزت'),
        xls.TextCellValue('مهام جديدة'),
        xls.TextCellValue('مهام متأخرة'),
        xls.TextCellValue('مشاريع متأخرة'),
        xls.TextCellValue('بلا تحديث'),
        xls.TextCellValue('تحتاج تدخّلاً'),
        xls.TextCellValue('موظفون نشطون'),
        xls.TextCellValue('موظفون بلا نشاط'),
        xls.TextCellValue('تحديثات لكل مشروع'),
        xls.TextCellValue('أبرز الإنجازات'),
        xls.TextCellValue('أبرز العوائق'),
      ]);
      for (final x in report.departments) {
        depts.appendRow([
          xls.TextCellValue(x.name),
          xls.DoubleCellValue(x.avgProgress),
          xls.IntCellValue(x.projectCount),
          xls.IntCellValue(x.workCount),
          xls.IntCellValue(x.tasksCompleted),
          xls.IntCellValue(x.tasksAdded),
          xls.IntCellValue(x.lateTasks),
          xls.IntCellValue(x.lateProjects),
          xls.IntCellValue(x.projectsWithoutRecentUpdate),
          xls.IntCellValue(x.projectsNeedingIntervention),
          xls.IntCellValue(x.activePeople),
          xls.IntCellValue(x.idlePeople),
          xls.DoubleCellValue(x.avgUpdatesPerProject),
          xls.TextCellValue(x.topAchievements.join(' · ')),
          xls.TextCellValue(x.topBlockers.join(' · ')),
        ]);
      }
    }

    if (defaultSheetName != null) workbook.delete(defaultSheetName);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('تعذّر ترميز ملف Excel — لم تُنتج المكتبة أي بايتات.');
    }
    return Uint8List.fromList(bytes);
  }

  static void _appendLines(xls.Sheet sheet, String title, List<String> lines) {
    sheet.appendRow([xls.TextCellValue('')]);
    sheet.appendRow([xls.TextCellValue(title)]);
    if (lines.isEmpty) {
      sheet.appendRow([xls.TextCellValue('لا يوجد')]);
      return;
    }
    for (final l in lines) {
      sheet.appendRow([xls.TextCellValue(l)]);
    }
  }

  static Future<String> exportPeriodicPdf({
    required PeriodicReport report,
    required bool includeDepartments,
  }) async {
    final bytes = await buildPeriodicPdfBytes(
      report: report,
      includeDepartments: includeDepartments,
    );
    return downloadBytes(bytes, '${_periodicFileBaseName(report)}.pdf', 'application/pdf');
  }

  /// مفصولةٌ عن [exportPeriodicPdf] ليُقاس الملفُّ في اختبارٍ بلا تنزيل —
  /// كما في `report_pdf_test.dart`.
  static Future<Uint8List> buildPeriodicPdfBytes({
    required PeriodicReport report,
    required bool includeDepartments,
  }) async {
    final regular = await _loadFont('assets/fonts/Tajawal-Regular.ttf');
    final medium = await _loadFont('assets/fonts/Tajawal-Medium.ttf');
    final bold = await _loadFont('assets/fonts/Tajawal-Bold.ttf');
    final emblem = await _loadImage('assets/images/logo.png');
    final ornament = await _loadImage('assets/images/frame_border.png');

    final d = report.digest;
    final doc = pw.Document();

    pw.Widget heading(String text) =>
        pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 13, color: _navy));

    pw.Widget lines(String title, List<String> items) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: medium, fontSize: 11, color: _navy)),
            pw.SizedBox(height: 3),
            if (items.isEmpty)
              pw.Text('لا يوجد', style: pw.TextStyle(font: regular, fontSize: 9.5, color: _grey))
            else
              ...items.map((l) => pw.Text(pdfSafeText('• $l'),
                  style: pw.TextStyle(font: regular, fontSize: 9.5, lineSpacing: 2))),
            pw.SizedBox(height: 8),
          ],
        );

    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(regular: regular, bold: bold, ornament: ornament),
        header: (context) => _header(
          regular: regular,
          medium: medium,
          bold: bold,
          emblem: emblem,
          caption: 'التقرير الدوري — ${report.range.period.label}',
        ),
        footer: (context) => _footer(regular: regular, context: context),
        build: (context) => [
          pw.Text(
            'التقرير الدوري ${report.range.period.label} — '
            '${Formatters.date(report.range.start)} إلى ${Formatters.date(report.range.end)}',
            style: pw.TextStyle(font: bold, fontSize: 17, color: _navy),
          ),
          pw.SizedBox(height: 14),
          heading('الملخص التنفيذي'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 9.5),
            cellAlignment: pw.Alignment.center,
            headers: _safeRow(const [
              'المشاريع',
              'متأخرة',
              'تحتاج تدخّلاً',
              'بلا تحديث',
              'مهام أُنجزت',
              'مهام متأخرة',
            ]),
            data: [
              [
                '${d.totalProjects}',
                '${d.lateProjects}',
                '${d.projectsNeedingIntervention}',
                '${d.projectsNotUpdated}',
                '${d.tasksCompleted}',
                '${d.lateTasks}',
              ],
            ],
          ),
          pw.SizedBox(height: 14),
          lines('أبرز الإنجازات', d.topAchievements),
          lines('أبرز العوائق', d.topBlockers),
          lines('الأكثر نشاطاً', d.mostActivePeople),
          lines('بلا نشاط مسجَّل في الفترة', d.idlePeople),
          lines('إدارات تحتاج متابعة', d.departmentsNeedingFollowUp),
          pw.SizedBox(height: 6),
          heading('أولاً: أداء الأشخاص'),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(kActivityDisclaimer,
                style: pw.TextStyle(font: regular, fontSize: 9, color: _grey, lineSpacing: 2)),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: _border, width: 0.5),
            headers: _safeRow(const [
              'الاسم',
              'النشاط',
              'أُنجزت',
              'أُضيفت',
              'تحديثات',
              'مرفقات',
              'عوائق',
              'متأخرة عليه',
              'في موعدها',
              'متأخرة',
              'آخر نشاط',
            ]),
            data: _safeRows(report.people
                .map((p) => [
                      p.name,
                      p.activity.label,
                      '${p.tasksCompleted}',
                      '${p.tasksAdded}',
                      '${p.dailyUpdates + p.workUpdates}',
                      '${p.attachmentsUploaded}',
                      '${p.blockersRaised}',
                      '${p.lateTasksAssigned}',
                      _withUndated(p.finishedOnTime, p.tasksWithoutCompletionDate),
                      _withUndated(p.finishedLate, p.tasksWithoutCompletionDate),
                      p.lastActivity == null ? 'لا يوجد' : Formatters.shortDate(p.lastActivity!),
                    ])
                .toList()),
          ),
          if (includeDepartments) ...[
            pw.SizedBox(height: 16),
            heading('ثانياً: أداء الإدارات'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: pw.TextStyle(font: regular, fontSize: 8),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: _border, width: 0.5),
              headers: _safeRow(const [
                'الإدارة',
                'الإنجاز',
                'مشاريع',
                'أعمال',
                'أُنجزت',
                'جديدة',
                'متأخرة',
                'مشاريع متأخرة',
                'بلا تحديث',
                'تحتاج تدخّلاً',
                'نشطون',
                'بلا نشاط',
              ]),
              data: _safeRows(report.departments
                  .map((x) => [
                        x.name,
                        '${x.avgProgress.toStringAsFixed(0)}٪',
                        '${x.projectCount}',
                        '${x.workCount}',
                        '${x.tasksCompleted}',
                        '${x.tasksAdded}',
                        '${x.lateTasks}',
                        '${x.lateProjects}',
                        '${x.projectsWithoutRecentUpdate}',
                        '${x.projectsNeedingIntervention}',
                        '${x.activePeople}',
                        '${x.idlePeople}',
                      ])
                  .toList()),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// صفوفُ جدولٍ نقيّةٌ من النصّ الذي يكسر مولّد PDF — راجع [pdfSafeText].
  ///
  /// تُطبَّق على **كل** صفٍّ لا على ما نظنّه خطراً: أسماءُ المشاريع
  /// والإدارات والموظفين يكتبها المستخدم، ومشروعٌ واحدٌ اسمه «أُفق العدالة»
  /// كان يُسقط الملفَّ كلَّه.
  static List<List<String>> _safeRows(List<List<String>> rows) =>
      [for (final r in rows) _safeRow(r)];

  /// وكذلك ترويسةُ الجدول: «أُنجزت» عنوانُ عمودٍ من كتابتنا، وهي بعينها
  /// النصُّ الذي أسقط الملفَّ أوّل مرّة. فلا يُترك موضعٌ يمرّ منه نصٌّ خام.
  static List<String> _safeRow(List<String> row) => [for (final c in row) pdfSafeText(c)];

  /// «٣ + غير مسجّل ٢» — العددُ المعروف ومعه ما لا يُعرف، لا جمعُهما.
  static String _withUndated(int value, int undated) =>
      undated == 0 ? '$value' : '$value + $undated غير مسجّل';

  /// يحمّل خط التقرير من الأصول برسالة مفهومة عند الفشل.
  ///
  /// الخط ليس تفصيلاً تجميلياً هنا: بدونه لا يُكتب حرف عربي واحد في الملف،
  /// فلا مجال لتجاوز فشله بصمت كما نفعل مع الشعار. والرسالة تسمّي الملف
  /// المفقود صراحةً، لأن سبب الفشل الأرجح على شبكة الوزارة هو حجب أو تلف في
  /// تحميل أصل بعينه — لا عطل عام في التوليد.
  static Future<pw.Font> _loadFont(String path) async {
    try {
      return pw.Font.ttf(await rootBundle.load(path));
    } catch (e) {
      throw StateError('تعذّر تحميل خط التقرير «$path» من ملفات المنصة: $e');
    }
  }

  /// يحمّل صورة من الأصول، ويعيد null إن لم تكن موجودة — حتى يبقى تصدير
  /// التقرير عاملاً بشكل سليم لو حُذف ملف الشعار أو الزخرفة لاحقاً.
  static Future<pw.MemoryImage?> _loadImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// الإطار الزخرفي الرسمي على حافتَي كل صفحة، مطابق للإطار المعتمد في
  /// وثائق الوزارة. تُكرَّر البلاطة رأسياً بعدد كافٍ لتغطية ارتفاع A4 بدل
  /// تمديد صورة واحدة (التمديد يشوّه الزخرفة).
  ///
  /// يُلَف بـ FullPage(ignoreMargins: true) لأن خلفية الصفحة تُخطَّط افتراضياً
  /// داخل الهوامش، فكانت الزخرفة تنزل فوق النص والجداول بدل أن تلتصق بحافة
  /// الورقة.
  static pw.Widget _ornamentFrame(pw.MemoryImage? ornament) {
    if (ornament == null) return pw.SizedBox();
    const stripWidth = 24.0;
    const edgeInset = 9.0;
    // البلاطة الأصلية ٥٣×١٩٤ بكسل؛ ارتفاعها المعروض يحفظ نفس النسبة.
    const tileHeight = stripWidth * 194 / 53;
    final tileCount = (PdfPageFormat.a4.height / tileHeight).ceil();

    pw.Widget strip() => pw.SizedBox(
          width: stripWidth,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: List.generate(
              tileCount,
              (_) => pw.Image(ornament, width: stripWidth, height: tileHeight),
            ),
          ),
        );

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Positioned(left: edgeInset, top: 0, child: strip()),
          pw.Positioned(right: edgeInset, top: 0, child: strip()),
        ],
      ),
    );
  }
}
