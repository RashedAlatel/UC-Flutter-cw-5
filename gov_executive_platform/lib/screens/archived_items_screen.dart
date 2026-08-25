// ما حُذف منطقياً — يُقرأ ويُستعاد، ولمسؤول النظام وحده.
//
// ــــ لماذا شاشةٌ قائمة بذاتها؟ ــــ
//
// الحذف المنطقي بلا شاشةٍ تُقرأ منها المحذوفاتُ ليس حذفاً منطقياً بل
// إخفاءً: السجل موجودٌ في قاعدة البيانات ولا سبيل إلى أحدٍ يراه أو
// يستعيده. فالشاشة هي نصف الميزة لا زينتُها.
//
// ولمسؤول النظام وحده: من حذف لا يُعيد ما حذف بنفسه — وإلا صار الحذف
// والاستعادة معاً بيدٍ واحدة، فيُمحى السجل ويُعاد بلا أن يمرّ بأحد.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/command_band.dart';

class ArchivedItemsScreen extends StatelessWidget {
  const ArchivedItemsScreen({super.key});

  Future<void> _restore(
    BuildContext context, {
    required String collection,
    required String id,
    required String targetType,
    required String name,
  }) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة السجل؟'),
        content: Text(
          'سيعود "$name" إلى مكانه، ومعه كل ما يتبعه من مهامّ وتحديثات '
          'ومرفقات — فهي لم تُمحَ، بل اختفت باختفائه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (yes != true) return;

    final error = await store.restoreItem(
      collection: collection,
      id: id,
      targetType: targetType,
      targetName: name,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'استُعيد "$name".'),
      backgroundColor: error == null ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // القاعدة هي الحَكَم، وهذه مرآتُها: شاشةٌ تَعِد بزرٍّ يُردّ عند الضغط
    // أسوأ من شاشةٍ لا تُعرض.
    if (!store.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'استعادة المحذوفات لمسؤول النظام وحده.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final projects = store.archivedProjects;
    final works = store.archivedWorks;
    final total = projects.length + works.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'المحذوفات',
            subtitle: total == 0
                ? 'لا يوجد شيء محذوف'
                : '$total سجلاً محذوفاً منطقياً — لم يُمحَ شيء، ويُستعاد بضغطة',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (total == 0)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'لا توجد سجلات محذوفة.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                if (projects.isNotEmpty) ...[
                  const _SectionTitle('المشاريع المحذوفة'),
                  for (final p in projects)
                    _ArchivedCard(
                      name: p.name,
                      subtitle: store.departmentById(p.departmentId)?.name ?? '',
                      deletedAt: p.deletedAt,
                      deletedByName: store.userNameOf(p.deletedBy),
                      reason: p.deletedReason,
                      onRestore: () => _restore(
                        context,
                        collection: 'projects',
                        id: p.id,
                        targetType: 'project',
                        name: p.name,
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
                if (works.isNotEmpty) ...[
                  const _SectionTitle('الأعمال المحذوفة'),
                  for (final w in works)
                    _ArchivedCard(
                      name: w.title,
                      subtitle: store.departmentById(w.departmentId)?.name ?? '',
                      deletedAt: w.deletedAt,
                      deletedByName: store.userNameOf(w.deletedBy),
                      reason: w.deletedReason,
                      onRestore: () => _restore(
                        context,
                        collection: 'works',
                        id: w.id,
                        targetType: 'work',
                        name: w.title,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      );
}

class _ArchivedCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final DateTime? deletedAt;
  final String deletedByName;
  final String? reason;
  final VoidCallback onRestore;

  const _ArchivedCard({
    required this.name,
    required this.subtitle,
    required this.deletedAt,
    required this.deletedByName,
    required this.reason,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  // «من ومتى ولماذا» — الثلاثة معاً، فالحذف قرارٌ له صاحب.
                  Text(
                    'حذفه $deletedByName'
                    '${deletedAt == null ? '' : ' في ${Formatters.date(deletedAt!)}'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if ((reason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('السبب: ${reason!}',
                        style: const TextStyle(fontSize: 12, height: 1.6)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded, size: 17),
              label: const Text('استعادة'),
            ),
          ],
        ),
      ),
    );
  }
}
