import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_bar.dart';
import 'department_detail_screen.dart';

class DepartmentsListScreen extends StatelessWidget {
  const DepartmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final departments = store.visibleDepartments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الإدارات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('عرض جميع الإدارات ومؤشرات أداء مشاريعها', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 1150 ? 3 : (constraints.maxWidth > 720 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.35,
              children: departments.map((dept) {
                final progress = store.departmentProgress(dept.id);
                final delay = store.departmentAvgDelay(dept.id);
                final projectCount = store.projectsForDepartment(dept.id).length;
                final risks = store.departmentRiskCount(dept.id);
                final blockers = store.departmentBlockerCount(dept.id);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(dept.name)),
                        body: DepartmentDetailScreen(departmentId: dept.id),
                      ),
                    )),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: dept.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(dept.icon, color: dept.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), maxLines: 2),
                                    Text('مسؤول الإدارة: ${dept.headName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LabeledProgressBar(value: progress, label: 'نسبة الإنجاز', color: dept.color),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MiniStat(icon: Icons.folder_copy_outlined, label: 'مشاريع', value: '$projectCount'),
                              _MiniStat(icon: Icons.schedule_rounded, label: 'تأخير', value: '${delay.toStringAsFixed(0)} يوم'),
                              _MiniStat(icon: Icons.warning_amber_rounded, label: 'مخاطر', value: '$risks'),
                              _MiniStat(icon: Icons.block_rounded, label: 'عوائق', value: '$blockers'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
