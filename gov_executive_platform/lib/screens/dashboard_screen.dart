import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/dashboard_widget_config.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/custom_widget_view.dart';
import '../widgets/kpi_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'customize_dashboard_dialog.dart';
import 'decision_center_screen.dart';
import 'department_detail_screen.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // فلاتر سريعة تؤثر على "أعلى المشاريع" وجدول التفاصيل فقط، بينما تبقى
  // المؤشرات الرئيسية والرسوم البيانية تعرض إجمالي النطاق المرئي كاملاً.
  ProjectStatus? _statusFilter;
  String? _deptFilter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scoped = !store.canViewAllDepartments;
    final ranking = store.departmentRanking
        .where((e) => store.canViewDepartment(e.key.id))
        .toList();
    final projects = store.visibleProjects;

    final filteredProjects = projects
        .where((p) => _statusFilter == null || p.status == _statusFilter)
        .where((p) => _deptFilter == null || p.departmentId == _deptFilter)
        .toList();

    final statusCounts = <String, int>{
      for (final s in ProjectStatus.values) s.label: projects.where((p) => p.status == s).length,
    };
    final statusColors = {
      for (final s in ProjectStatus.values) s.label: AppColors.statusColor(s.name),
    };
    final filterDepartments = store.visibleDepartments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scoped ? 'لوحة قيادة إدارتي' : 'لوحة القيادة المركزية',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoped
                          ? 'مؤشرات فورية على أداء مشاريع إدارتك'
                          : 'مؤشرات فورية على أداء الخطة الاستراتيجية ومشاريع الوزارة',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (store.canManageDashboard)
                OutlinedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const CustomizeDashboardDialog()),
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('تخصيص اللوحة'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _LastUpdatedBar(),
          if (!store.isAdmin) ...[
            const SizedBox(height: 16),
            const _BootstrapAdminBanner(),
          ],
          if (store.isAdmin && store.projects.isEmpty) ...[
            const SizedBox(height: 16),
            const _DemoDataBanner(),
          ],
          const SizedBox(height: 18),
          _FilterBar(
            statusFilter: _statusFilter,
            deptFilter: _deptFilter,
            departments: filterDepartments,
            onStatusChanged: (s) => setState(() => _statusFilter = s),
            onDeptChanged: (d) => setState(() => _deptFilter = d),
          ),
          const SizedBox(height: 18),
          _KpiGrid(store: store, projects: projects),
          const SizedBox(height: 20),
          ...store.dashboardWidgets.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildWidget(context, w, store, scoped, ranking, statusCounts, statusColors, filteredProjects),
              )),
        ],
      ),
    );
  }

  Widget _buildWidget(
    BuildContext context,
    DashboardWidgetConfig config,
    AppStore store,
    bool scoped,
    List<MapEntry<Department, double>> ranking,
    Map<String, int> statusCounts,
    Map<String, Color> statusColors,
    List<Project> filteredProjects,
  ) {
    switch (config.type) {
      case DashboardWidgetType.deptBarChart:
        return _ChartCard(
          title: scoped ? 'أداء إدارتي' : 'ترتيب الإدارات حسب الأداء',
          subtitle: 'اضغط على أي إدارة لعرض مشاريعها المتأخرة',
          height: 300,
          child: ranking.isEmpty
              ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)))
              : DepartmentBarChart(
                  ranking: ranking,
                  onDepartmentTap: (dept) => _showProjectsPeek(
                    context,
                    title: 'مشاريع "${dept.name}" المتأخرة',
                    projects: store.visibleProjects
                        .where((p) => p.departmentId == dept.id && p.status == ProjectStatus.delayed)
                        .toList(),
                  ),
                ),
        );
      case DashboardWidgetType.statusPieChart:
        return _ChartCard(
          title: 'توزيع حالة المشاريع',
          subtitle: 'اضغط على أي قطاع أو تسمية لعرض مشاريعها',
          height: 260,
          child: StatusDonutChart(
            data: statusCounts,
            colors: statusColors,
            onSectionTap: (label) {
              final status = ProjectStatus.values.firstWhere((s) => s.label == label, orElse: () => ProjectStatus.onTrack);
              _showProjectsPeek(
                context,
                title: 'مشاريع بحالة "$label"',
                projects: store.visibleProjects.where((p) => p.status == status).toList(),
              );
            },
          ),
        );
      case DashboardWidgetType.pendingApprovalsList:
        return _PendingDecisionsCard(store: store);
      case DashboardWidgetType.departmentRankingList:
        return _DepartmentRankingList(store: store, ranking: ranking);
      case DashboardWidgetType.recentUpdatesList:
        return _RecentUpdatesCard(store: store);
      case DashboardWidgetType.topProjectsList:
        return _TopProjectsCard(store: store, projects: filteredProjects);
      case DashboardWidgetType.projectsTable:
        return _ProjectsTableCard(store: store, projects: filteredProjects);
      case DashboardWidgetType.custom:
        final spec = config.custom;
        return spec == null ? const SizedBox.shrink() : CustomWidgetCard(store: store, spec: spec);
    }
  }
}

/// نافذة سفلية تعرض قائمة مشاريع مُصفّاة (بالضغط على قطاع/عمود برسم بياني)،
/// مع إمكانية فتح أي مشروع منها مباشرة.
void _showProjectsPeek(BuildContext context, {required String title, required List<Project> projects}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                  Text('${projects.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: projects.isEmpty
                  ? const Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(p.name)),
                                  body: ProjectDetailScreen(projectId: p.id),
                                ),
                              ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                      StatusChip(status: p.status),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LabeledProgressBar(value: p.progressPercent, label: 'نسبة الإنجاز'),
                                  if (p.executorLabel.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('المنفذ: ${p.executorLabel}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  final AppStore store;
  final List projects;
  const _KpiGrid({required this.store, required this.projects});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 1150
          ? 5
          : constraints.maxWidth > 820
              ? 3
              : constraints.maxWidth > 520
                  ? 2
                  : 1;
      final items = [
        KpiCard(
          title: 'نسبة الإنجاز العام',
          value: Formatters.percent(store.overallProgress),
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
        ),
        KpiCard(
          title: 'متوسط التأخير عن الخطة',
          value: '${store.overallAvgDelay.toStringAsFixed(1)} يوم',
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
        ),
        KpiCard(
          title: 'المخاطر القائمة',
          value: '${store.openRisksCount}',
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
        ),
        KpiCard(
          title: 'العوائق النشطة',
          value: '${store.openBlockersCount}',
          icon: Icons.block_rounded,
          color: const Color(0xFFE0692B),
        ),
        KpiCard(
          title: 'طلبات بانتظار القيادة',
          value: '${store.pendingApprovalsCount}',
          icon: Icons.gavel_rounded,
          color: AppColors.info,
        ),
      ];
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
        children: items,
      );
    });
  }
}

/// شريط فلاتر سريعة (حالة المشروع كأزرار كبسولية + الإدارة كقائمة منسدلة)
/// بحسب التصميم المرجعي المعتمد. يؤثر فقط على "أعلى المشاريع" وجدول
/// التفاصيل، بينما تبقى المؤشرات والرسوم البيانية تعرض النطاق الكامل.
class _FilterBar extends StatelessWidget {
  final ProjectStatus? statusFilter;
  final String? deptFilter;
  final List<Department> departments;
  final ValueChanged<ProjectStatus?> onStatusChanged;
  final ValueChanged<String?> onDeptChanged;

  const _FilterBar({
    required this.statusFilter,
    required this.deptFilter,
    required this.departments,
    required this.onStatusChanged,
    required this.onDeptChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 20,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(label: 'الكل', selected: statusFilter == null, onTap: () => onStatusChanged(null)),
                ...ProjectStatus.values.map(
                  (s) => _StatusPill(label: s.label, selected: statusFilter == s, onTap: () => onStatusChanged(s)),
                ),
              ],
            ),
            if (departments.length > 1)
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: deptFilter,
                  decoration: const InputDecoration(labelText: 'الإدارة', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                    ...departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: onDeptChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// قائمة "أعلى المشاريع تقدماً" بأعمدة أفقية (بنفس أسلوب DepartmentBarChart)،
/// تُبنى من نفس نطاق المشاريع بعد تطبيق الفلاتر السريعة.
class _TopProjectsCard extends StatelessWidget {
  final AppStore store;
  final List<Project> projects;
  const _TopProjectsCard({required this.store, required this.projects});

  @override
  Widget build(BuildContext context) {
    final top = projects.toList()..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    final items = top.take(3).toList();
    return _ChartCard(
      title: 'أعلى المشاريع تقدماً',
      height: 210,
      child: items.isEmpty
          ? const Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final p = items[i];
                final value = p.progressPercent.clamp(0, 100);
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text(p.name)), body: ProjectDetailScreen(projectId: p.id)),
                  )),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(p.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: [
                            Container(height: 18, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                            FractionallySizedBox(
                              widthFactor: value / 100,
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 36, child: Text('${value.toStringAsFixed(0)}٪', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// جدول تفصيلي بالمشاريع (بحسب النطاق المفلتَر)، بنفس أسلوب جداول أدوات BI.
class _ProjectsTableCard extends StatelessWidget {
  final AppStore store;
  final List<Project> projects;
  const _ProjectsTableCard({required this.store, required this.projects});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل المشاريع (${projects.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 44,
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(label: Text('اسم المشروع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الإدارة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('التقدم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الاستحقاق', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('المنفذ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                  ],
                  rows: projects.map((p) {
                    final dept = store.departmentById(p.departmentId);
                    return DataRow(
                      onSelectChanged: (_) => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(appBar: AppBar(title: Text(p.name)), body: ProjectDetailScreen(projectId: p.id)),
                      )),
                      cells: [
                        DataCell(SizedBox(width: 190, child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(dept?.name ?? 'بدون إدارة', style: const TextStyle(fontSize: 11.5))),
                        DataCell(StatusChip(status: p.status)),
                        DataCell(Text(Formatters.percent(p.progressPercent), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                        DataCell(Text(Formatters.shortDate(p.dueDate), style: const TextStyle(fontSize: 11.5))),
                        DataCell(SizedBox(width: 120, child: Text(p.executorLabel, style: const TextStyle(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;
  const _ChartCard({required this.title, this.subtitle, required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 14),
            SizedBox(height: subtitle != null ? height - 68 : height - 50, child: child),
          ],
        ),
      ),
    );
  }
}

class _PendingDecisionsCard extends StatelessWidget {
  final AppStore store;
  const _PendingDecisionsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final decisions = store.pendingApprovalsSorted.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('قرارات مطلوبة من القيادة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('مركز القرارات التنفيذية')),
                      body: const DecisionCenterScreen(),
                    ),
                  )),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const Divider(height: 20),
            if (decisions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد قرارات معلقة حالياً', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...List.generate(decisions.length, (i) {
                final d = decisions[i];
                final dept = d.departmentId != null ? store.departmentById(d.departmentId!) : null;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: i == decisions.length - 1 ? 0 : 1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          Formatters.arabicOrdinal(i + 1),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${d.type.label}] ${d.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                PriorityChip(priority: d.priority),
                                Text(
                                  '${dept?.name ?? 'عام'}${d.delayImpactDays > 0 ? ' · أثر التأخير: ${d.delayImpactDays} يوم' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DepartmentRankingList extends StatelessWidget {
  final AppStore store;
  final List ranking;
  const _DepartmentRankingList({required this.store, required this.ranking});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل ترتيب الإدارات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Divider(height: 20),
            ...List.generate(ranking.length, (i) {
              final entry = ranking[i];
              final dept = entry.key;
              final value = entry.value as double;
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(dept.name)),
                    body: DepartmentDetailScreen(departmentId: dept.id),
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: i == ranking.length - 1 ? 0 : 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: dept.color.withValues(alpha: 0.15),
                        child: Text('${i + 1}', style: TextStyle(color: dept.color, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: value / 100,
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(dept.color),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        child: Text(Formatters.percent(value),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RecentUpdatesCard extends StatelessWidget {
  final AppStore store;
  const _RecentUpdatesCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final updates = store.recentUpdates;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أحدث التحديثات اليومية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Divider(height: 20),
            if (updates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد تحديثات بعد', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...List.generate(updates.length, (i) {
                final u = updates[i];
                final project = store.projectById(u.projectId);
                return InkWell(
                  onTap: project == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(project.name)),
                              body: ProjectDetailScreen(projectId: project.id),
                            ),
                          )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: i == updates.length - 1 ? 0 : 1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 3, margin: const EdgeInsets.only(left: 10), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3))),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(u.authorName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(Formatters.timeAgo(u.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(u.achievements, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (project != null) ...[
                                const SizedBox(height: 5),
                                Text(project.name, style: TextStyle(fontSize: 10.5, color: AppColors.accent, fontWeight: FontWeight.w700)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// شريط "آخر تحديث" أعلى اللوحة: البيانات محدّثة لحظياً أصلاً عبر Firestore،
/// وزر التحديث هنا يعيد ختم الوقت المعروض ليؤكد للمستخدم حداثة الصفحة.
class _LastUpdatedBar extends StatefulWidget {
  const _LastUpdatedBar();

  @override
  State<_LastUpdatedBar> createState() => _LastUpdatedBarState();
}

class _LastUpdatedBarState extends State<_LastUpdatedBar> {
  DateTime _time = DateTime.now();

  String _label() {
    final h = _time.hour % 12 == 0 ? 12 : _time.hour % 12;
    final m = _time.minute.toString().padLeft(2, '0');
    final period = _time.hour >= 12 ? 'م' : 'ص';
    return '${Formatters.date(_time)} — $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sync_rounded, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('آخر تحديث: ${_label()}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _time = DateTime.now());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('البيانات محدّثة لحظياً بشكل تلقائي'), duration: Duration(seconds: 2)),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// شريط استرجاع يظهر لأي مستخدم مفعّل ليس مسؤول نظام، طالما لم يُعيَّن أي
/// مسؤول نظام للمنصة بعد. يعالج الحالة التي قد يعلق فيها أول مستخدم بدور
/// مختلف عن "مسؤول نظام" (مثلاً بسبب خطأ اتصال مؤقت أثناء أول محاولة)، لأن
/// شاشة "بانتظار الموافقة" التي تحتوي زر التعيين لا تظهر بعد تفعيل الحساب.
class _BootstrapAdminBanner extends StatefulWidget {
  const _BootstrapAdminBanner();

  @override
  State<_BootstrapAdminBanner> createState() => _BootstrapAdminBannerState();
}

class _BootstrapAdminBannerState extends State<_BootstrapAdminBanner> {
  bool _checking = true;
  bool _needed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final needed = await context.read<AppStore>().checkBootstrapNeeded();
    if (!mounted) return;
    setState(() {
      _needed = needed;
      _checking = false;
    });
  }

  Future<void> _becomeAdmin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().bootstrapFirstAdmin();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _needed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_needed) return const SizedBox.shrink();
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لا يوجد مسؤول نظام مُفعّل بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك تعيين نفسك كأول مسؤول نظام لمرة واحدة، ثم إدارة باقي الحسابات والصلاحيات من مركز القرارات.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _becomeAdmin,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.admin_panel_settings_rounded, size: 16),
                    label: const Text('تعيين نفسي كأول مسؤول نظام'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط يظهر لمسؤول النظام فقط طالما لا توجد أي مشاريع بعد، لتوليد بيانات
/// تجريبية كاملة (إدارات + مشاريع + مهام + مخاطر/عوائق + تحديثات + قرار
/// تنفيذي واحد) بضغطة واحدة، حتى يمكن معاينة لوحة القيادة وبقية الشاشات
/// فوراً دون انتظار إدخال بيانات حقيقية.
class _DemoDataBanner extends StatefulWidget {
  const _DemoDataBanner();

  @override
  State<_DemoDataBanner> createState() => _DemoDataBannerState();
}

class _DemoDataBannerState extends State<_DemoDataBanner> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppStore>().seedDemoData();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر توليد البيانات التجريبية، حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return Card(
      color: AppColors.info.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.dataset_outlined, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لا توجد مشاريع بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك توليد بيانات تجريبية (إدارات ومشاريع ومهام وتحديثات) بضغطة واحدة، لمعاينة لوحة القيادة وبقية الشاشات فوراً.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.dataset_outlined, size: 16),
                    label: const Text('توليد بيانات تجريبية للاختبار'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
