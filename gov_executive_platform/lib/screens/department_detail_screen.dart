import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/kpi_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'daily_update_form.dart';
import 'project_detail_screen.dart';
import 'request_project_dialog.dart';

class DepartmentDetailScreen extends StatelessWidget {
  final String departmentId;
  const DepartmentDetailScreen({super.key, required this.departmentId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(departmentId);
    if (dept == null) {
      return const Center(child: Text('الإدارة غير موجودة'));
    }
    final projects = store.projectsForDepartment(departmentId);
    final progress = store.departmentProgress(departmentId);
    final delay = store.departmentAvgDelay(departmentId);
    final risks = store.departmentRiskCount(departmentId);
    final blockers = store.departmentBlockerCount(departmentId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: dept.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(dept.icon, color: dept.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('مسؤول الإدارة: ${dept.headName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              if (store.canRequestNewProject(departmentId))
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => RequestProjectDialog(departmentId: departmentId),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(store.isAdmin ? 'إضافة مشروع' : 'طلب إضافة مشروع'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 520 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.6,
              children: [
                KpiCard(title: 'نسبة الإنجاز', value: Formatters.percent(progress), icon: Icons.trending_up_rounded, color: AppColors.success),
                KpiCard(title: 'متوسط التأخير', value: '${delay.toStringAsFixed(1)} يوم', icon: Icons.schedule_rounded, color: AppColors.warning),
                KpiCard(title: 'مخاطر قائمة', value: '$risks', icon: Icons.warning_amber_rounded, color: AppColors.danger),
                KpiCard(title: 'عوائق نشطة', value: '$blockers', icon: Icons.block_rounded, color: const Color(0xFFE0692B)),
              ],
            );
          }),
          const SizedBox(height: 24),
          const Text('المشاريع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('لا توجد مشاريع لهذه الإدارة بعد', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...projects.map((p) => _ProjectCard(project: p, dept: dept)),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final dynamic dept;
  const _ProjectCard({required this.project, required this.dept});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canEdit = store.canEditProject(project);
    final taskCount = store.tasksForProject(project.id).length;
    final doneCount = store.tasksForProject(project.id).where((t) => t.status.name == 'done').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(project.name)),
            body: ProjectDetailScreen(projectId: project.id),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(project.description,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(status: project.status),
                ],
              ),
              const SizedBox(height: 14),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoBit(icon: Icons.flag_outlined, text: project.priority.label),
                  if (project.executorNames.isNotEmpty)
                    _InfoBit(icon: Icons.badge_outlined, text: 'المنفذ: ${project.executorLabel}'),
                  _InfoBit(icon: Icons.event_outlined, text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  _InfoBit(
                    icon: Icons.schedule_rounded,
                    text: project.delayDays > 0 ? 'متأخر ${project.delayDays} يوم' : 'ضمن الجدول الزمني',
                    color: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                  ),
                  _InfoBit(icon: Icons.checklist_rounded, text: 'المهام: $doneCount / $taskCount'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(project.name)),
                        body: ProjectDetailScreen(projectId: project.id),
                      ),
                    )),
                    icon: const Icon(Icons.view_kanban_outlined, size: 18),
                    label: const Text('لوحة المهام'),
                  ),
                  const SizedBox(width: 10),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => DailyUpdateForm(project: project),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('تحديث يومي'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoBit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
