import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// نافذة تأكيد حذف مشروع، مشتركة بين صفحة المشاريع وصفحة المشروع نفسه.
///
/// تعرض عدد المهام والمخاطر والعوائق التي ستُحذف معه، حتى يعرف المستخدم حجم ما
/// سيفقده قبل التأكيد. تُعيد true إن حُذف المشروع فعلاً.
Future<bool> confirmDeleteProject(BuildContext context, Project project) async {
  final store = context.read<AppStore>();
  final d = store.projectDependents(project.id);
  final total = d.tasks + d.risks + d.blockers;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف المشروع'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سيُحذف مشروع "${project.name}" نهائياً.', style: const TextStyle(fontSize: 13, height: 1.6)),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'سيُحذف معه: ${d.tasks} مهمة، ${d.risks} خطر، ${d.blockers} عائق، '
                'إضافة إلى تحديثاته اليومية. لا يمكن التراجع عن هذا الإجراء.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.danger, height: 1.6),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف نهائياً'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final error = await store.deleteProject(project);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text('تم حذف "${project.name}"')));
  return true;
}
