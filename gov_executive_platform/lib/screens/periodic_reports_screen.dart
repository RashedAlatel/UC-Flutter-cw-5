// قسم «التقارير الدورية» — أسبوعيٌّ وشهريٌّ بفترةٍ تُختار.
//
// ــــ لماذا الحسابُ ليس هنا ــــ
//
// كلُّ رقمٍ في هذه الشاشة يُحسب في `lib/reports/periodic_report.dart` —
// وحدةٌ نقيّة بلا Firestore ولا `BuildContext`، لكل مقياسٍ فيها اختبارٌ
// وطفرةٌ تُثبت أن الاختبار يمسكه. وهذه الشاشة **عرضٌ خالص**: تختار الفترة،
// وتستدعي المحرّك، وترسم ما أعاده.
//
// ــــ والنطاق يأتي من المتجر لا يُكتب هنا ــــ
//
// `store.periodicReportInput` هو من يقرّر ماذا يدخل التقرير، وهو نفسُه الذي
// يُبنى منه شرطُ ظهور المدخل في القائمة. فلا يقع أن يظهر مدخلٌ لمن لا بيانات
// له، ولا أن يُحجب عمّن يملكها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../reports/periodic_report.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
import '../utils/formatters.dart';
import '../utils/report_export.dart';
import '../widgets/command_band.dart';
import '../widgets/filter_bar.dart';
import '../widgets/kpi_card.dart';
import 'periodic_report_settings_dialog.dart';

class PeriodicReportsScreen extends StatefulWidget {
  const PeriodicReportsScreen({super.key});

  @override
  State<PeriodicReportsScreen> createState() => _PeriodicReportsScreenState();
}

class _PeriodicReportsScreenState extends State<PeriodicReportsScreen> {
  ReportPeriod _period = ReportPeriod.weekly;

  /// اليومُ الذي تُبنى عليه الفترة: آخرُ الأسبوع، أو أيُّ يومٍ من الشهر.
  DateTime _anchor = DateTime.now();

  bool _exportingExcel = false;
  bool _exportingPdf = false;

  /// الفلاتر الثمانية — والتاسع هو الفترة أعلاه.
  ReportFilters _filters = ReportFilters.none;

  ReportRange get _range => _period == ReportPeriod.weekly
      ? ReportRange.weekEnding(_anchor)
      : ReportRange.monthOf(_anchor);

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: _period == ReportPeriod.weekly
          ? 'اختر آخر يومٍ في الأسبوع'
          : 'اختر أيَّ يومٍ من الشهر',
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  Future<void> _export({
    required String label,
    required void Function(bool) setBusy,
    required Future<String> Function({
      required PeriodicReport report,
      required bool includeDepartments,
    }) run,
    required PeriodicReport report,
    required bool includeDepartments,
  }) async {
    setBusy(true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await run(report: report, includeDepartments: includeDepartments);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('تم إنشاء ملف $label وبدأ تنزيله.'),
        duration: const Duration(seconds: 12),
        // بعض المتصفحات تمنع تنزيلاً يقع بعد انتظارٍ غير متزامن، وتمنعه
        // صامتةً — فهذا مخرجٌ داخل لمسة المستخدم مباشرة.
        action: SnackBarAction(
          label: 'لم يبدأ التنزيل؟ افتح الملف',
          onPressed: () => openDownloadedUrl(url),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('تعذّر إنشاء ملف $label: $e'),
        duration: const Duration(seconds: 12),
      ));
    } finally {
      if (mounted) setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final range = _range;
    final report =
        buildPeriodicReport(store.periodicReportInput, range, filters: _filters);
    final compare = store.canCompareDepartments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommandBand(
          title: 'التقارير الدورية',
          subtitle: 'تقريرٌ ${_period.label} للفترة '
              '${Formatters.date(range.start)} — ${Formatters.date(range.end)}',
          actions: [
            BandButton(
              icon: Icons.grid_on_rounded,
              label: _exportingExcel ? 'جارٍ التصدير…' : 'Excel',
              // الحارس في الدالّة لا في الزرّ: `BandButton.onPressed` غير
              // قابل للعدم، فتعطيلُه بـnull لا يمرّ من نوعه — كما في شاشة
              // التقرير اليومي.
              onPressed: () {
                if (_exportingExcel) return;
                _export(
                  label: 'Excel',
                  setBusy: (v) => setState(() => _exportingExcel = v),
                  run: ReportExporter.exportPeriodicExcel,
                  report: report,
                  includeDepartments: compare,
                );
              },
            ),
            BandButton(
              icon: Icons.picture_as_pdf_rounded,
              label: _exportingPdf ? 'جارٍ التصدير…' : 'PDF',
              onPressed: () {
                if (_exportingPdf) return;
                _export(
                  label: 'PDF',
                  setBusy: (v) => setState(() => _exportingPdf = v),
                  run: ReportExporter.exportPeriodicPdf,
                  report: report,
                  includeDepartments: compare,
                );
              },
            ),
            if (store.isAdmin)
              BandButton(
                icon: Icons.tune_rounded,
                label: 'الإعدادات',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const PeriodicReportSettingsDialog(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _PeriodControls(
            period: _period,
            range: range,
            onPeriod: (p) => setState(() => _period = p),
            onPickDate: _pickAnchor,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _ReportFilterBar(
            filters: _filters,
            store: store,
            onChanged: (f) => setState(() => _filters = f),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 56),
            children: [
              _DigestSection(report: report),
              const SizedBox(height: 24),
              _PeopleSection(report: report),
              if (compare) ...[
                const SizedBox(height: 24),
                _DepartmentsSection(report: report),
              ],
              const SizedBox(height: 24),
              _ItemsSection(report: report),
              const SizedBox(height: 24),
              _InactiveSection(report: report),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodControls extends StatelessWidget {
  final ReportPeriod period;
  final ReportRange range;
  final ValueChanged<ReportPeriod> onPeriod;
  final VoidCallback onPickDate;
  const _PeriodControls({
    required this.period,
    required this.range,
    required this.onPeriod,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<ReportPeriod>(
          segments: const [
            ButtonSegment(
              value: ReportPeriod.weekly,
              label: Text('أسبوعي'),
              icon: Icon(Icons.view_week_rounded, size: 17),
            ),
            ButtonSegment(
              value: ReportPeriod.monthly,
              label: Text('شهري'),
              icon: Icon(Icons.calendar_month_rounded, size: 17),
            ),
          ],
          selected: {period},
          onSelectionChanged: (s) => onPeriod(s.first),
        ),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.event_rounded, size: 17),
          label: Text(period == ReportPeriod.weekly
              ? 'الأسبوع المنتهي في ${Formatters.shortDate(range.end)}'
              : 'شهر ${Formatters.monthName(range.start.month)} ${range.start.year}'),
        ),
        Text(
          '${range.days} يوماً',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ───────────────────────── الملخّص التنفيذي ─────────────────────────

class _DigestSection extends StatelessWidget {
  final PeriodicReport report;
  const _DigestSection({required this.report});

  @override
  Widget build(BuildContext context) {
    final d = report.digest;
    return _Section(
      title: 'الملخّص التنفيذي',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = CommandBand.columnsFor(c.maxWidth);
            const spacing = 10.0;
            final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: itemWidth / KpiCard.tileHeight,
              children: [
                KpiCard(
                  title: 'إجمالي المشاريع',
                  value: '${d.totalProjects}',
                  icon: Icons.folder_copy_rounded,
                  color: AppColors.primary,
                ),
                KpiCard(
                  title: 'مشاريع متأخرة',
                  value: '${d.lateProjects}',
                  icon: Icons.running_with_errors_rounded,
                  color: AppColors.danger,
                ),
                KpiCard(
                  title: 'تحتاج تدخّلاً',
                  value: '${d.projectsNeedingIntervention}',
                  icon: Icons.priority_high_rounded,
                  color: AppColors.warning,
                ),
                KpiCard(
                  title: 'بلا تحديثٍ في الفترة',
                  value: '${d.projectsNotUpdated}',
                  icon: Icons.update_disabled_rounded,
                  color: AppColors.warning,
                ),
                KpiCard(
                  title: 'مهامّ أُنجزت',
                  value: '${d.tasksCompleted}',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.success,
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          _Lines(title: 'أبرز الإنجازات', lines: d.topAchievements, icon: Icons.emoji_events_outlined),
          _Lines(title: 'أبرز العوائق', lines: d.topBlockers, icon: Icons.block_rounded),
          _Lines(
            title: 'الأكثر نشاطاً',
            lines: d.mostActivePeople,
            icon: Icons.local_fire_department_outlined,
          ),
          _Lines(
            title: 'بلا نشاطٍ مسجَّل في الفترة',
            lines: d.idlePeople,
            icon: Icons.person_off_outlined,
            // لا يُقرأ هذا السطر حكماً: قد يكون في إجازةٍ أو ندبٍ أو عملٍ
            // خارج المنصة. هو سؤالٌ يُطرح لا نتيجةٌ تُقرَّر.
            note: 'قائمةُ متابعةٍ لا قائمةُ مساءلة — تُراجَع أسبابُها قبل أي حكم.',
          ),
          _Lines(
            title: 'إداراتٌ تحتاج متابعة',
            lines: d.departmentsNeedingFollowUp,
            icon: Icons.flag_outlined,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── أداء الأشخاص ─────────────────────────

class _PeopleSection extends StatelessWidget {
  final PeriodicReport report;
  const _PeopleSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'أولاً: أداء الأشخاص',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ActivityNote(),
          const SizedBox(height: 12),
          if (report.people.isEmpty)
            const _Empty('لا يوجد أشخاصٌ ضمن نطاقك.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('النشاط')),
                  DataColumn(label: Text('أُنجزت')),
                  DataColumn(label: Text('أُضيفت')),
                  DataColumn(label: Text('تحديثات')),
                  DataColumn(label: Text('مرفقات')),
                  DataColumn(label: Text('مخاطر')),
                  DataColumn(label: Text('عوائق')),
                  DataColumn(label: Text('متأخرة عليه')),
                  DataColumn(label: Text('في موعدها')),
                  DataColumn(label: Text('متأخرة')),
                  DataColumn(label: Text('مشاريع')),
                  DataColumn(label: Text('أعمال')),
                  DataColumn(label: Text('آخر نشاط')),
                ],
                rows: [
                  for (final p in report.people)
                    DataRow(cells: [
                      DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(_ActivityChip(level: p.activity, total: p.totalActivities)),
                      DataCell(Text('${p.tasksCompleted}')),
                      DataCell(Text('${p.tasksAdded}')),
                      DataCell(Text('${p.dailyUpdates + p.workUpdates}')),
                      DataCell(Text('${p.attachmentsUploaded}')),
                      DataCell(Text('${p.risksRaised}')),
                      DataCell(Text('${p.blockersRaised}')),
                      DataCell(Text('${p.lateTasksAssigned}')),
                      DataCell(_Counted(p.finishedOnTime, p.tasksWithoutCompletionDate)),
                      DataCell(_Counted(p.finishedLate, p.tasksWithoutCompletionDate)),
                      DataCell(Text('${p.projectNames.length}')),
                      DataCell(Text('${p.workTitles.length}')),
                      DataCell(Text(
                        p.lastActivity == null ? 'لا يوجد' : Formatters.shortDate(p.lastActivity!),
                        style: TextStyle(
                          color: p.lastActivity == null ? AppColors.textSecondary : null,
                        ),
                      )),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// عدَدٌ ومعه ما لا يُعرف تاريخُه — «غير مسجّل» لا صفر.
///
/// مهمةٌ أُنجزت قبل أن يوجد حقلُ التاريخ لا يُعرف أوقعت في موعدها أم بعده.
/// فتُقال على حدة ولا تُضاف إلى أيٍّ من العمودين — وإلا قرأ المدير تأخّراً
/// سببُه نقصُ بيانٍ لا تقصيرُ موظف.
class _Counted extends StatelessWidget {
  final int value;
  final int undated;
  const _Counted(this.value, this.undated);

  @override
  Widget build(BuildContext context) {
    if (undated == 0) return Text('$value');
    return Tooltip(
      message: 'و$undated مهمةً منجَزةً لا يُعرف تاريخُ إنجازها — سابقةٌ لتسجيل التاريخ.',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$value'),
        const SizedBox(width: 4),
        const Text('+ غير مسجّل',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final ActivityLevel level;
  final int total;
  const _ActivityChip({required this.level, required this.total});

  Color get _color => switch (level) {
        ActivityLevel.high => AppColors.success,
        ActivityLevel.medium => AppColors.primary,
        ActivityLevel.low => AppColors.warning,
        ActivityLevel.none => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // السببُ مع الرقم دائماً: مؤشرٌ لا يُراجَع يُصدَّق، والمراجعة تبدأ
      // بمعرفة ممّ حُسب.
      message: 'محسوبٌ من $total نشاطاً مسجَّلاً في الفترة',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          level.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color),
        ),
      ),
    );
  }
}

/// النصُّ الذي طلبتَ أن يُكتب صراحةً تحت المؤشر.
class _ActivityNote extends StatelessWidget {
  const _ActivityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: const Text(
        kActivityDisclaimer,
        style: TextStyle(fontSize: 12, height: 1.7, color: AppColors.textSecondary),
      ),
    );
  }
}

// ───────────────────────── أداء الإدارات ─────────────────────────

class _DepartmentsSection extends StatelessWidget {
  final PeriodicReport report;
  const _DepartmentsSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'ثانياً: أداء الإدارات',
      icon: Icons.account_balance_rounded,
      child: report.departments.isEmpty
          ? const _Empty('لا توجد إداراتٌ ضمن نطاقك.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('الإدارة')),
                  DataColumn(label: Text('نسبة الإنجاز')),
                  DataColumn(label: Text('مشاريع')),
                  DataColumn(label: Text('أعمال')),
                  DataColumn(label: Text('مهامّ أُنجزت')),
                  DataColumn(label: Text('مهامّ جديدة')),
                  DataColumn(label: Text('مهامّ متأخرة')),
                  DataColumn(label: Text('مشاريع متأخرة')),
                  DataColumn(label: Text('بلا تحديث')),
                  DataColumn(label: Text('تحتاج تدخّلاً')),
                  DataColumn(label: Text('موظفون نشطون')),
                  DataColumn(label: Text('بلا نشاط')),
                  DataColumn(label: Text('تحديثات لكل مشروع')),
                ],
                rows: [
                  for (final d in report.departments)
                    DataRow(cells: [
                      DataCell(Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text(Formatters.percent(d.avgProgress))),
                      DataCell(Text('${d.projectCount}')),
                      DataCell(Text('${d.workCount}')),
                      DataCell(Text('${d.tasksCompleted}')),
                      DataCell(Text('${d.tasksAdded}')),
                      DataCell(Text('${d.lateTasks}')),
                      DataCell(Text('${d.lateProjects}')),
                      DataCell(Text('${d.projectsWithoutRecentUpdate}')),
                      DataCell(Text('${d.projectsNeedingIntervention}')),
                      DataCell(Text('${d.activePeople}')),
                      DataCell(Text('${d.idlePeople}')),
                      DataCell(Text(d.avgUpdatesPerProject.toStringAsFixed(1))),
                    ]),
                ],
              ),
            ),
    );
  }
}

// ───────────────────────── قطعٌ مشتركة ─────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  final String title;
  final List<String> lines;
  final IconData icon;
  final String? note;
  const _Lines({required this.title, required this.lines, required this.icon, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          if (lines.isEmpty)
            const Text('لا يوجد', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $l', style: const TextStyle(fontSize: 12, height: 1.6)),
                )),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
}

// ───────────────────────── الفلاتر التسعة ─────────────────────────

/// ثمانيةُ حقول — والتاسع الفترةُ في الشريط فوقها.
///
/// وتُبنى على [FilterBar] القائم لا على `Wrap` بعروضٍ مثبَّتة: ذاك يقيس
/// العرض المتاح فيُكدّس الحقول على الجوال، وإلا خرج عنوانُ الحقل عن الشاشة
/// **بلا أي خطأ** — عطلٌ لا يكشفه إلا من يفتحها على جواله.
class _ReportFilterBar extends StatelessWidget {
  final ReportFilters filters;
  final AppStore store;
  final ValueChanged<ReportFilters> onChanged;

  const _ReportFilterBar({
    required this.filters,
    required this.store,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final input = store.periodicReportInput;
    // المستخدمون من نطاق التقرير نفسه: لا يُعرض في منتقي المدير من لا
    // يظهر في جداوله.
    final people = input.users;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterBar(
          fields: [
            (
              preferredWidth: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: filters.departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الإدارة', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                  ...input.departments
                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearDepartment: true)
                    : filters.copyWith(departmentId: v)),
              ),
            ),
            (
              preferredWidth: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: filters.projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المشروع', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل المشاريع')),
                  ...input.projects.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearProject: true)
                    : filters.copyWith(projectId: v)),
              ),
            ),
            (
              preferredWidth: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: filters.managerUid,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'مدير المشروع', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل المديرين')),
                  ...people.map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearManager: true)
                    : filters.copyWith(managerUid: v)),
              ),
            ),
            (
              preferredWidth: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: filters.executorUid,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المنفّذ', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل المنفّذين')),
                  ...people.map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearExecutor: true)
                    : filters.copyWith(executorUid: v)),
              ),
            ),
            (
              preferredWidth: 180,
              child: DropdownButtonFormField<ProjectStatus?>(
                initialValue: filters.projectStatus,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'حالة المشروع', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                  ...ProjectStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearProjectStatus: true)
                    : filters.copyWith(projectStatus: v)),
              ),
            ),
            (
              preferredWidth: 180,
              child: DropdownButtonFormField<TaskStatus?>(
                initialValue: filters.taskStatus,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'حالة المهمة', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل المهام')),
                  ...TaskStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (v) => onChanged(v == null
                    ? filters.copyWith(clearTaskStatus: true)
                    : filters.copyWith(taskStatus: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('المتأخرة فقط'),
              selected: filters.lateOnly,
              onSelected: (v) => onChanged(filters.copyWith(lateOnly: v)),
            ),
            FilterChip(
              label: const Text('غير المحدَّثة فقط'),
              selected: filters.notUpdatedOnly,
              onSelected: (v) => onChanged(filters.copyWith(notUpdatedOnly: v)),
            ),
            // إعلانٌ صريح أن الفلتر يسري على التقرير كلِّه: بدونه يظنّ
            // القارئ أن الملخّص أعلاه لم يتأثّر، فيقرأ رقمين متناقضين.
            if (!filters.isEmpty) ...[
              TextButton.icon(
                onPressed: () => onChanged(ReportFilters.none),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                label: const Text('مسح التصفية'),
              ),
              const Text(
                'التصفية تسري على التقرير كلِّه — الملخّص والأشخاص والإدارات والمشاريع.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────── ثالثاً: المشاريع والأعمال ───────────────────

Color _statusColor(ReportItemStatus s) => switch (s) {
      ReportItemStatus.needsIntervention => AppColors.danger,
      ReportItemStatus.late_ => const Color(0xFFE0692B),
      ReportItemStatus.needsFollowUp => AppColors.warning,
      ReportItemStatus.normal => AppColors.success,
    };

/// عددٌ قد لا ينطبق — «—» لا صفر. راجع [ItemPerformance].
Widget _num(int? v) => Text(
      v == null ? '—' : '$v',
      style: TextStyle(color: v == null ? AppColors.textSecondary : null),
    );

class _ItemsSection extends StatelessWidget {
  final PeriodicReport report;
  const _ItemsSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'ثالثاً: أداء المشاريع والأعمال',
      icon: Icons.folder_copy_rounded,
      child: report.items.isEmpty
          ? const _Empty('لا توجد مشاريع أو أعمالٌ ضمن التصفية الحالية.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('الإدارة')),
                  DataColumn(label: Text('المدير')),
                  DataColumn(label: Text('المنفّذون')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('النشاط')),
                  DataColumn(label: Text('الإنجاز الآن')),
                  DataColumn(label: Text('عند البداية')),
                  DataColumn(label: Text('التقدّم')),
                  DataColumn(label: Text('مهام أُنجزت')),
                  DataColumn(label: Text('مهام جديدة')),
                  DataColumn(label: Text('مهام متأخرة')),
                  DataColumn(label: Text('آخر تحديث')),
                  DataColumn(label: Text('أيام منذه')),
                  DataColumn(label: Text('الاستحقاق')),
                  DataColumn(label: Text('المتبقي')),
                  DataColumn(label: Text('عوائق قائمة')),
                  DataColumn(label: Text('متطلبات')),
                  DataColumn(label: Text('ملفات')),
                ],
                rows: [
                  for (final it in report.items)
                    DataRow(cells: [
                      DataCell(SizedBox(
                        width: 200,
                        child: Text(it.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      )),
                      DataCell(Text(it.isWork ? 'عمل' : 'مشروع')),
                      DataCell(Text(it.departmentName)),
                      DataCell(Text(it.managerNames.isEmpty ? '—' : it.managerNames)),
                      DataCell(SizedBox(
                        width: 160,
                        child: Text(
                          it.executorNames.isEmpty ? '—' : it.executorNames,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(_StatusChip(status: it.status)),
                      DataCell(_ActivityChip(
                          level: it.activity, total: it.totalActivities)),
                      DataCell(Text(Formatters.percent(it.progressNow))),
                      // «لا أساس للمقارنة» لا صفر: مشروعٌ بلا تحديثٍ سابق
                      // لم يبدأ من الصفر، لا نعرف أين كان.
                      DataCell(it.progressAtStart == null
                          ? const Tooltip(
                              message: 'لا يوجد تحديثٌ قبل بداية الفترة، فلا أساس للمقارنة.',
                              child: Text('لا أساس للمقارنة',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary)),
                            )
                          : Text(Formatters.percent(it.progressAtStart!))),
                      DataCell(it.progressMade == null
                          ? const Text('—', style: TextStyle(color: AppColors.textSecondary))
                          : Text(
                              '${it.progressMade! >= 0 ? '+' : ''}'
                              '${it.progressMade!.toStringAsFixed(0)}٪',
                              style: TextStyle(
                                color: it.progressMade! > 0 ? AppColors.success : null,
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                      DataCell(_num(it.tasksCompleted)),
                      DataCell(_num(it.tasksAdded)),
                      DataCell(_num(it.tasksLate)),
                      DataCell(Text(it.lastUpdate == null
                          ? 'لا يوجد'
                          : Formatters.shortDate(it.lastUpdate!))),
                      DataCell(_num(it.daysSinceLastUpdate)),
                      DataCell(Text(Formatters.shortDate(it.dueDate))),
                      DataCell(Text(
                        '${it.remainingDays}',
                        style: TextStyle(
                          color: it.remainingDays < 0 ? AppColors.danger : null,
                        ),
                      )),
                      DataCell(_num(it.openBlockers)),
                      DataCell(Tooltip(
                        message: 'القرارات والمتطلبات المسجَّلة في تحديثات الفترة.',
                        child: _num(it.requirementsRaised),
                      )),
                      DataCell(Text('${it.filesAdded}')),
                    ]),
                ],
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReportItemStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ─────────────────── المشاريع والأعمال غير النشطة ───────────────────

class _InactiveSection extends StatelessWidget {
  final PeriodicReport report;
  const _InactiveSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return _Section(
      // المعيارُ في العنوان لا مخفيّاً: «١٢ غير نشط» بلا مدّته رقمٌ لا يُراجَع.
      title: 'المشاريع والأعمال غير النشطة — بلا تحديث منذ '
          '${report.inactiveAfterDays} أيام أو أكثر',
      icon: Icons.update_disabled_rounded,
      child: report.inactive.isEmpty
          ? const _Empty('لا يوجد ما توقّف عن الحركة — كلُّها محدَّثة ضمن المدّة.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('المسؤول')),
                  DataColumn(label: Text('آخر تحديث')),
                  DataColumn(label: Text('أيام بلا نشاط')),
                  DataColumn(label: Text('مهام مفتوحة')),
                  DataColumn(label: Text('الاستحقاق')),
                  DataColumn(label: Text('قريب من موعده؟')),
                ],
                rows: [
                  for (final it in report.inactive)
                    DataRow(cells: [
                      DataCell(SizedBox(
                        width: 220,
                        child: Text(it.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      )),
                      DataCell(Text(it.isWork ? 'عمل' : 'مشروع')),
                      DataCell(Text(it.ownerNames.isEmpty ? '—' : it.ownerNames)),
                      DataCell(Text(it.lastUpdate == null
                          ? 'لا يوجد'
                          : Formatters.shortDate(it.lastUpdate!))),
                      // بلا تحديثٍ إطلاقاً: يُقال صراحةً لا يُكتب رقمٌ مختلق.
                      DataCell(it.daysWithoutActivity == null
                          ? const Text('لا تحديث منذ الإنشاء',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary))
                          : Text('${it.daysWithoutActivity}',
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(_num(it.openTasks)),
                      DataCell(Text(Formatters.shortDate(it.dueDate))),
                      DataCell(it.dueSoon
                          ? Text(
                              it.remainingDays < 0
                                  ? 'تجاوز موعده'
                                  : 'نعم — ${it.remainingDays} يوم',
                              style: const TextStyle(
                                  color: AppColors.danger, fontWeight: FontWeight.w700),
                            )
                          : const Text('لا')),
                    ]),
                ],
              ),
            ),
    );
  }
}
