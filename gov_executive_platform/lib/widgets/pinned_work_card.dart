import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'progress_bar.dart';

/// بطاقة عمل تشغيلي مثبَّت في لوحة قيادة مستخدم بعينه — نظيرة
/// [FocusedProjectCard] لكن للأعمال بدل المشاريع.
class PinnedWorkCard extends StatelessWidget {
  final WorkItem work;
  const PinnedWorkCard({super.key, required this.work});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(work.departmentId);
    final delay = work.delayDays;
    final statusColor = AppColors.taskStatusColor(work.status.name);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('عمل تشغيلي',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(work.status.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(work.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              '${dept?.name ?? 'بدون إدارة'} · ${work.assigneeName.isEmpty ? 'غير مُسنَد' : work.assigneeName}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            LabeledProgressBar(value: work.progressPercent, label: 'نسبة الإنجاز'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _Bit(icon: Icons.event_outlined, text: Formatters.shortDate(work.dueDate)),
                if (delay > 0) _Bit(icon: Icons.schedule_rounded, text: 'متأخر $delay يوم', color: AppColors.danger),
              ],
            ),
          ],
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
