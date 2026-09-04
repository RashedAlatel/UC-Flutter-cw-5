import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../screens/project_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'progress_bar.dart';
import 'status_chip.dart';

/// بطاقة مشروع "تحت التركيز": تُعرض بجانب بطاقات الإدارات وأعلى لوحة القيادة،
/// مميّزة بحدّ ذهبي وشارة نجمة لتنفصل بصرياً عن بطاقات الإدارات المحيطة بها.
class FocusedProjectCard extends StatelessWidget {
  final Project project;

  /// عند true تُعرض نسخة مضغوطة تناسب شبكة الإدارات؛ وإلا نسخة أعرض للوحة.
  final bool compact;

  const FocusedProjectCard({super.key, required this.project, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(project.departmentId);
    final delay = project.delayDays;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.accent, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(project.name)),
            body: ProjectDetailScreen(projectId: project.id),
          ),
        )),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text('تحت التركيز',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  StatusChip(status: project.status),
                  if (store.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.star_border_rounded, size: 18, color: AppColors.textSecondary),
                      tooltip: 'إزالة من التركيز',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => store.toggleFocusedProject(project),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(project.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(dept?.name ?? 'بدون إدارة',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز', color: AppColors.accent),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Bit(icon: Icons.event_outlined, text: Formatters.shortDate(project.dueDate)),
                  if (delay > 0)
                    _Bit(icon: Icons.schedule_rounded, text: 'متأخر $delay يوم', color: AppColors.danger),
                  if (project.executorNames.isNotEmpty)
                    _Bit(icon: Icons.person_outline_rounded, text: project.executorLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Bit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
