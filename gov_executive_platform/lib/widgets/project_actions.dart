import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// نافذة حذف مشروع، مشتركة بين صفحة المشاريع وصفحة المشروع نفسه.
///
/// ــــ الحذف صار منطقياً، والنهائي استثناء ــــ
///
/// كان الحذف **نهائياً متسلسلاً** بلا رجعة: يمحو المهام والمخاطر والعوائق
/// والتحديثات اليومية معه. وكان الطريق الوحيد.
///
/// فصار الطريق المعتاد حذفاً منطقياً: يختفي المشروع من كل قائمة، ويبقى كلُّ
/// ما يتبعه على حاله، ويستعيده مسؤول النظام من شاشة «المحذوفات». ويبقى
/// النهائي متاحاً له وحده، وبزرٍّ ثانٍ يُقال فيه صراحةً أنه بلا رجعة.
///
/// وسببُ الحذف مطلوب: قرارٌ في سجلٍّ حكومي بلا سبب لا يُراجَع بعد شهور.
///
/// تُعيد true إن حُذف المشروع فعلاً — بأي الطريقين.
Future<bool> confirmDeleteProject(BuildContext context, Project project) async {
  final store = context.read<AppStore>();
  final d = store.projectDependents(project.id);
  final total = d.tasks + d.risks + d.blockers;

  if (!store.canSoftDeleteProject(project)) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('لا تملك صلاحية حذف هذا المشروع — الحذف داخل إدارتك وحدها.'),
      backgroundColor: AppColors.danger,
    ));
    return false;
  }

  final reasonCtrl = TextEditingController();
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف المشروع'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيختفي مشروع "${project.name}" من كل القوائم'
              '${total > 0 ? '، ومعه $total من مهامّه ومخاطره وعوائقه' : ''}. '
              'ولا يُمحى شيء: يستعيده مسؤول النظام متى شاء.',
              style: const TextStyle(fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'سبب الحذف (مطلوب)',
                hintText: 'مثلاً: أُلغي المشروع، أو تكرّر إدخاله',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('إلغاء')),
        // النهائي لمسؤول النظام وحده — والقاعدة تردّه لغيره على أي حال.
        if (store.isAdmin)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, 'hard'),
            child: const Text('حذف نهائي بلا رجعة'),
          ),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'soft'), child: const Text('حذف')),
      ],
    ),
  );

  if (choice == null || choice == 'cancel' || !context.mounted) return false;
  final reason = reasonCtrl.text.trim();
  final messenger = ScaffoldMessenger.of(context);

  if (choice == 'soft') {
    if (reason.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('سبب الحذف مطلوب — يُقرأ في سجل التدقيق بعد شهور.'),
        backgroundColor: AppColors.warning,
      ));
      return false;
    }
    final error = await store.softDeleteProject(project, reason: reason);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'حُذف "${project.name}" — يمكن استعادته من «المحذوفات».'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
    return error == null;
  }

  return _confirmHardDelete(context, project, total, d);
}

/// الحذف النهائي — بتأكيدٍ ثانٍ، لأنه لا يُلغى بشيء.
Future<bool> _confirmHardDelete(
  BuildContext context,
  Project project,
  int total,
  dynamic d,
) async {

  final store = context.read<AppStore>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف نهائي بلا رجعة'),
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
