import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/kpi_card.dart';
import '../widgets/status_chip.dart';
import 'customize_dashboard_dialog.dart';
import 'decision_center_screen.dart';
import 'department_detail_screen.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scoped = !store.canViewAllDepartments;
    final ranking = store.departmentRanking
        .where((e) => store.canViewDepartment(e.key.id))
        .toList();
    final projects = store.visibleProjects;

    final statusCounts = <String, int>{
      for (final s in ProjectStatus.values) s.label: projects.where((p) => p.status == s).length,
    };
    final statusColors = {
      for (final s in ProjectStatus.values) s.label: AppColors.statusColor(s.name),
    };

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
          if (!store.isAdmin) ...[
            const SizedBox(height: 16),
            const _BootstrapAdminBanner(),
          ],
          const SizedBox(height: 22),
          _KpiGrid(store: store, projects: projects.map((p) => p).toList()),
          const SizedBox(height: 24),
          ...store.dashboardWidgets.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildWidget(context, w.type, store, scoped, ranking, statusCounts, statusColors),
              )),
        ],
      ),
    );
  }

  Widget _buildWidget(
    BuildContext context,
    DashboardWidgetType type,
    AppStore store,
    bool scoped,
    List<MapEntry<Department, double>> ranking,
    Map<String, int> statusCounts,
    Map<String, Color> statusColors,
  ) {
    switch (type) {
      case DashboardWidgetType.deptBarChart:
        return _ChartCard(
          title: scoped ? 'أداء إدارتي' : 'ترتيب الإدارات حسب الأداء',
          height: 300,
          child: ranking.isEmpty
              ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)))
              : DepartmentBarChart(ranking: ranking),
        );
      case DashboardWidgetType.statusPieChart:
        return _ChartCard(
          title: 'توزيع حالة المشاريع',
          height: 300,
          child: StatusPieChart(data: statusCounts, colors: statusColors),
        );
      case DashboardWidgetType.pendingApprovalsList:
        return _PendingDecisionsCard(store: store);
      case DashboardWidgetType.departmentRankingList:
        return _DepartmentRankingList(store: store, ranking: ranking);
      case DashboardWidgetType.recentUpdatesList:
        return _RecentUpdatesCard(store: store);
    }
  }
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

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;
  const _ChartCard({required this.title, required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            SizedBox(height: height - 50, child: child),
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
              ...decisions.map((d) {
                final dept = d.departmentId != null ? store.departmentById(d.departmentId!) : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriorityChip(priority: d.priority),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${d.type.label}] ${d.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '${dept?.name ?? 'عام'}${d.delayImpactDays > 0 ? ' · أثر التأخير: ${d.delayImpactDays} يوم' : ''}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
              ...updates.map((u) {
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(u.authorName.isNotEmpty ? u.authorName.substring(0, 1) : '?',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('${u.authorName} · ${project?.name ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(Formatters.timeAgo(u.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(u.achievements, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
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
