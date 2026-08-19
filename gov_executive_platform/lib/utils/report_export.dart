import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/department.dart';
import '../models/project.dart';
import '../models/report.dart';
import '../theme/brand.dart';
import 'formatters.dart';

/// تصدير التقارير التنفيذية إلى ملفات Excel أو PDF قابلة للتنزيل مباشرة من
/// المتصفح. تُستدعى دوال هذا الملف عند ضغط المستخدم أزرار "تصدير" في شاشة
/// التقارير، وتحمل نفس بيانات التقرير المعروضة على الشاشة (الملخص، المؤشرات،
/// ترتيب الإدارات) بالإضافة إلى قائمة المشاريع الحالية ضمن نطاق المستخدم.
class ReportExporter {
  static String _fileBaseName(ReportSnapshot report) =>
      'تقرير_${report.period.name}_${Formatters.shortDate(report.generatedDate).replaceAll('/', '-')}';

  // ------------------------- Excel -------------------------

  static Future<void> exportExcel({
    required ReportSnapshot report,
    required List<Project> projects,
    required Department? Function(String id) departmentById,
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
        xls.TextCellValue(p.status.label),
        xls.DoubleCellValue(p.progressPercent),
        xls.IntCellValue(p.delayDays),
        xls.TextCellValue(p.executorLabel),
        xls.TextCellValue(Formatters.shortDate(p.dueDate)),
      ]);
    }

    if (defaultSheetName != null) workbook.delete(defaultSheetName);
    workbook.save(fileName: '${_fileBaseName(report)}.xlsx');
  }

  // ------------------------- PDF -------------------------

  static Future<void> exportPdf({
    required ReportSnapshot report,
    required List<Project> projects,
    required Department? Function(String id) departmentById,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final medium = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Medium.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));

    final doc = pw.Document();
    // ألوان الهوية الرسمية للمنصة (أخضر كويتي + ذهبي). يبقى الاسم navy
    // للتوافق مع مواضع الاستخدام أدناه دون تغييرها جميعاً.
    const navy = PdfColor.fromInt(0xFF0E4D3C);
    const gold = PdfColor.fromInt(0xFFC9A227);
    const grey = PdfColor.fromInt(0xFF5F6B7A);
    const border = PdfColor.fromInt(0xFFE3E8EF);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(Brand.state, style: pw.TextStyle(font: medium, fontSize: 9, color: grey)),
                    pw.Text(Brand.ministry, style: pw.TextStyle(font: bold, fontSize: 12, color: navy)),
                    pw.Text(Brand.platformShort, style: pw.TextStyle(font: regular, fontSize: 8.5, color: grey)),
                  ],
                ),
                pw.Text('تقرير ${report.period.label}', style: pw.TextStyle(font: medium, fontSize: 11, color: grey)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: gold),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${Brand.ministry} — ${Brand.state}', style: pw.TextStyle(font: regular, fontSize: 8.5, color: grey)),
              pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: regular, fontSize: 9, color: grey)),
            ],
          ),
        ),
        build: (context) => [
          pw.Text('تقرير ${report.period.label} — ${Formatters.date(report.generatedDate)}',
              style: pw.TextStyle(font: bold, fontSize: 18, color: navy)),
          pw.SizedBox(height: 16),
          pw.Text('الملخص التنفيذي', style: pw.TextStyle(font: bold, fontSize: 13, color: navy)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: border), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(report.executiveSummary, style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3)),
          ),
          pw.SizedBox(height: 18),
          pw.Text('المؤشرات الرئيسية', style: pw.TextStyle(font: bold, fontSize: 13, color: navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['متوسط الإنجاز', 'متوسط التأخير', 'المخاطر', 'العوائق', 'قرارات معلقة'],
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
          pw.Text('ترتيب الإدارات حسب الأداء', style: pw.TextStyle(font: bold, fontSize: 13, color: navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['الإدارة', 'نسبة الإنجاز'],
            data: report.departmentRanking.map((e) => [e.key, '${e.value.toStringAsFixed(1)}٪']).toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text('المشاريع (${projects.length})', style: pw.TextStyle(font: bold, fontSize: 13, color: navy)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: navy),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8.5),
            cellAlignment: pw.Alignment.centerRight,
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.6),
            },
            headers: ['اسم المشروع', 'الإدارة', 'الحالة', 'التقدم', 'المنفذ'],
            data: projects
                .map((p) => [
                      p.name,
                      departmentById(p.departmentId)?.name ?? '',
                      p.status.label,
                      '${p.progressPercent.toStringAsFixed(0)}٪',
                      p.executorLabel,
                    ])
                .toList(),
          ),
          if (report.manualComment.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('تعليق تنفيذي', style: pw.TextStyle(font: bold, fontSize: 13, color: navy)),
            pw.SizedBox(height: 6),
            pw.Text(report.manualComment.trim(), style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 3)),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${_fileBaseName(report)}.pdf');
  }
}
