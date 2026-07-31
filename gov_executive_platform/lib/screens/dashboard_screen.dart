import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/kpi_card.dart';
import '../widgets/status_chip.dart';
import 'decision_center_screen.dart';
import 'department_detail_screen.dart';

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
          const SizedBox(height: 22),
          _KpiGrid(store: store, projects: projects.map((p) => p).toList()),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            final rankingCard = _ChartCard(
              title: scoped ? 'أداء إدارتي' : 'ترتيب الإدارات حسب الأداء',
              height: 300,
              child: ranking.isEmpty
                  ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)))
                  : DepartmentBarChart(ranking: ranking),
            );
            final statusCard = _ChartCard(
              title: 'توزيع حالة المشاريع',
              height: 300,
              child: StatusPieChart(data: statusCounts, colors: statusColors),
            );
            if (!wide) {
              return Column(children: [rankingCard, const SizedBox(height: 16), statusCard]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: rankingCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: statusCard),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          _PendingDecisionsCard(store: store),
          if (!scoped) ...[
            const SizedBox(height: 24),
            _DepartmentRankingList(store: store, ranking: ranking),
          ],
        ],
      ),
    );
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
          title: 'قرارات بانتظار القيادة',
          value: '${store.pendingDecisionsCount}',
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
    final decisions = store.pendingDecisionsSorted
        .where((d) => store.canViewDepartment(d.departmentId))
        .take(5)
        .toList();
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
                final dept = store.departmentById(d.departmentId);
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
                            Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${dept?.name ?? ''} · أثر التأخير: ${d.delayImpactDays} يوم',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
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
