import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/report.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
import '../utils/formatters.dart';
import '../utils/report_export.dart';
import '../widgets/kpi_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canGenerate = store.canManageReports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('التقارير التنفيذية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('تقارير أسبوعية وشهرية مُولّدة تلقائياً مع ملخص تنفيذي وتحليلات',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'التقارير الأسبوعية'), Tab(text: 'التقارير الشهرية')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ReportsList(period: ReportPeriod.weekly, canGenerate: canGenerate),
              _ReportsList(period: ReportPeriod.monthly, canGenerate: canGenerate),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportsList extends StatelessWidget {
  final ReportPeriod period;
  final bool canGenerate;
  const _ReportsList({required this.period, required this.canGenerate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final reports = store.reports.where((r) => r.period == period).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canGenerate)
            ElevatedButton.icon(
              onPressed: () async => context.read<AppStore>().generateReport(period),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('توليد تقرير ${period.label} جديد'),
            ),
          const SizedBox(height: 20),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد تقارير مُولّدة بعد', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...reports.map((r) => _ReportCard(report: r, editable: canGenerate)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  final ReportSnapshot report;
  final bool editable;
  const _ReportCard({required this.report, required this.editable});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  late TextEditingController _commentCtrl;
  bool _dirty = false;
  bool _saving = false;
  bool _exportingExcel = false;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController(text: widget.report.manualComment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    setState(() => _saving = true);
    await context.read<AppStore>().updateReportComment(widget.report, _commentCtrl.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
  }

  Future<void> _exportExcel() => _runExport(
        label: 'Excel',
        setBusy: (v) => setState(() => _exportingExcel = v),
        export: ReportExporter.exportExcel,
      );

  Future<void> _exportPdf() => _runExport(
        label: 'PDF',
        setBusy: (v) => setState(() => _exportingPdf = v),
        export: ReportExporter.exportPdf,
      );

  /// مسار التصدير المشترك للصيغتين.
  ///
  /// كان هنا `try { } finally { }` **بلا `catch`**: فأي استثناء — خط ناقص،
  /// متصفح يمنع التنزيل، أي سبب — يختفي بلا أثر، فيرى المستخدم الدوّار يدور
  /// لحظة ثم يعود كل شيء كما كان: لا ملف ولا رسالة ولا سبب. وهذا أسوأ من
  /// العطل نفسه لأنه لا يترك ما يُشخَّص به. الآن يُمسك الخطأ ويُعرض بنصّه.
  Future<void> _runExport({
    required String label,
    required void Function(bool) setBusy,
    required Future<String> Function({
      required ReportSnapshot report,
      required List<Project> projects,
      required Department? Function(String id) departmentById,
      List<WorkItem> works,
    }) export,
  }) async {
    setBusy(true);
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await export(
        report: widget.report,
        projects: store.visibleProjects,
        departmentById: store.departmentById,
        works: store.visibleWorks,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم إنشاء ملف $label وبدأ تنزيله.'),
          duration: const Duration(seconds: 12),
          // مخرج بديل: بعض المتصفحات — وسفاري على الآيفون خاصةً — تمنع
          // التنزيل التلقائي الذي يقع بعد انتظار غير متزامن، وتمنعه صامتةً.
          // هذا الزر يفتح الملف **داخل لمسة المستخدم مباشرة** بلا انتظار
          // بينهما، وهو الشرط الذي تقبله تلك المتصفحات.
          action: SnackBarAction(
            label: 'لم يبدأ التنزيل؟ افتح الملف',
            onPressed: () => openDownloadedUrl(url),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ExportErrorDialog(label: label, details: e.toString()),
      );
    } finally {
      if (mounted) setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('تقرير ${r.period.label} · ${Formatters.date(r.generatedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                IconButton(
                  tooltip: 'تصدير Excel',
                  onPressed: _exportingExcel ? null : _exportExcel,
                  icon: _exportingExcel
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.grid_on_rounded, size: 19, color: AppColors.success),
                ),
                IconButton(
                  tooltip: 'تصدير PDF',
                  onPressed: _exportingPdf ? null : _exportPdf,
                  icon: _exportingPdf
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 19, color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Text(r.executiveSummary, style: const TextStyle(fontSize: 13, height: 1.8)),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 700 ? 5 : (constraints.maxWidth > 420 ? 3 : 2);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  KpiCard(title: 'متوسط الإنجاز', value: Formatters.percent(r.avgProgress), icon: Icons.trending_up_rounded, color: AppColors.success),
                  KpiCard(title: 'متوسط التأخير', value: '${r.avgDelayDays.toStringAsFixed(1)} يوم', icon: Icons.schedule_rounded, color: AppColors.warning),
                  KpiCard(title: 'المخاطر', value: '${r.totalRisks}', icon: Icons.warning_amber_rounded, color: AppColors.danger),
                  KpiCard(title: 'العوائق', value: '${r.totalBlockers}', icon: Icons.block_rounded, color: const Color(0xFFE0692B)),
                  KpiCard(title: 'قرارات معلقة', value: '${r.pendingDecisions}', icon: Icons.gavel_rounded, color: AppColors.info),
                ],
              );
            }),
            const SizedBox(height: 16),
            const Text('ترتيب الإدارات حسب الأداء', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            ...r.departmentRanking.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(e.key, style: const TextStyle(fontSize: 12.5))),
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: e.value / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 40, child: Text(Formatters.percent(e.value), textAlign: TextAlign.end, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            const Text('تعليق تنفيذي يدوي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              enabled: widget.editable,
              decoration: const InputDecoration(hintText: 'أضف ملاحظات أو توجيهات تنفيذية على هذا التقرير...'),
              onChanged: (v) => setState(() => _dirty = true),
            ),
            if (widget.editable && _dirty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveComment,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('حفظ التعليق'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// رسالة فشل التصدير — ونصّها التقني قابل للنسخ.
///
/// المستخدم غير تقني، لكن تفاصيل الخطأ هي كل ما نملكه لتشخيص عطل يقع على
/// جهازه لا على أجهزتنا. فالحوار يقول له بالعربية ما جرى، ويمنحه زراً واحداً
/// ينسخ التفاصيل ليرسلها كما هي — بدل أن يصف عطلاً صامتاً بكلماته.
class _ExportErrorDialog extends StatelessWidget {
  final String label;
  final String details;
  const _ExportErrorDialog({required this.label, required this.details});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('تعذّر إنشاء ملف $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'لم يكتمل إنشاء التقرير. أعد المحاولة، وإن تكرّر الأمر فانسخ '
                'التفاصيل التقنية أدناه وأرسلها لمسؤول النظام — فهي تحدّد السبب.',
                style: TextStyle(fontSize: 13, height: 1.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  details,
                  style: const TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: details));
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('نسخ التفاصيل'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      ],
    );
  }
}
