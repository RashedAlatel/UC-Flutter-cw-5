// ما جرى في يومٍ واحد على مشروع — يُقرأ، ويُحذف منه، ويُضاف إليه.
//
// ــــ ما كان قبل هذا الملف ــــ
//
// الضغط على يومٍ في تقويم التحديثات كان يفعل شيئين متعاكسين بحسب من ضغط:
//
//   • من يملك التحرير — أي **مدير المشروع نفسه** — يُقذف إلى نموذج إضافةٍ
//     فارغ ولا يرى ما كُتب في ذلك اليوم إطلاقاً.
//   • ومن لا يملكه يرى سردَ اليوم.
//
// فصاحبُ المشروع وحده هو المحروم من رؤية سجلّه. وهذا ما اشتُكي منه: «يجب
// أن يظهر له التحديث الذي قام بإضافته ويكون قادراً على عرضه وحذفه».
//
// فصار اليومُ **يُعرض للجميع**، ومن له حقٌّ يجد فيه أزراره.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/attachment.dart';
import '../models/daily_update.dart';
import '../models/project.dart';
import '../screens/daily_update_form.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
import '../utils/formatters.dart';

/// مرفقٌ يُفتح بضغطة — تعريفٌ واحد تقرؤه صفحة المشروع ونافذة اليوم.
class AttachmentChip extends StatelessWidget {
  final Attachment attachment;

  const AttachmentChip({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        attachment.kind == AttachmentKind.link ? Icons.link_rounded : Icons.attach_file_rounded,
        size: 16,
      ),
      label: Text(
        [attachment.name, if (attachment.readableSize.isNotEmpty) attachment.readableSize]
            .join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () => openDownloadedUrl(attachment.url),
      tooltip: attachment.kind.label,
    );
  }
}

/// نافذة يومٍ من تقويم التحديثات.
class DayUpdatesDialog extends StatelessWidget {
  final Project project;
  final DateTime day;

  const DayUpdatesDialog({super.key, required this.project, required this.day});

  Future<void> _confirmDelete(BuildContext context, DailyUpdate update) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    // الحذف لا يُلغى بـ«تراجع»، فيُسأل عنه ويُسمّى ما سيُحذف بالضبط.
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التحديث اليومي؟'),
        content: Text(
          'سيُحذف تحديث ${Formatters.date(update.date)} بقلم ${update.authorName}'
          '${update.attachments.isEmpty ? '' : '، ومعه ${update.attachments.length} مرفقاً'}. '
          'ولا يمكن التراجع عن الحذف — ويُسجَّل في سجل التدقيق باسمك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    final error = await store.deleteDailyUpdate(update, project: project);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'حُذف التحديث اليومي.'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // `watch` لا `read`: بعد الحذف تُخطر المتجرُ مستمعيه، فتختفي البطاقة من
    // النافذة نفسها بلا إغلاقٍ وإعادة فتح.
    final store = context.watch<AppStore>();
    final updates = store.updatesOnDay(project.id, day)
      ..sort((a, b) => b.date.compareTo(a.date));
    final canAdd = store.canSubmitDailyUpdate(project);

    return AlertDialog(
      title: Text(Formatters.date(day)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (updates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا يوجد تحديث مسجَّل لهذا اليوم.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                for (final u in updates)
                  _UpdateCard(
                    update: u,
                    canDelete: store.canDeleteDailyUpdate(u, project),
                    onDelete: () => _confirmDelete(context, u),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        if (canAdd)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (_) => DailyUpdateForm(project: project, initialDay: day),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('أضِف تحديثاً لهذا اليوم'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final DailyUpdate update;
  final bool canDelete;
  final VoidCallback onDelete;

  const _UpdateCard({
    required this.update,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  update.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
              Text(
                '${update.progressPercent.toStringAsFixed(0)}٪',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.danger,
                  tooltip: 'حذف هذا التحديث',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            update.achievements.trim().isEmpty ? 'بلا ملخّص إنجازات' : update.achievements,
            style: const TextStyle(fontSize: 12.5, height: 1.7),
          ),
          if (update.blockers.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'عوائق: ${update.blockers.join('، ')}',
              style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.6),
            ),
          ],
          if (update.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              update.notes,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
            ),
          ],
          if (update.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final a in update.attachments) AttachmentChip(attachment: a)],
            ),
          ],
        ],
      ),
    );
  }
}
