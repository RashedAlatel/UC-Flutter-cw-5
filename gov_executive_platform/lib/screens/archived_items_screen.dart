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
    /// اسمُ النسخة التي حُوّل إليها هذا الأصل — أو null إن كان محذوفاً لا
    /// محوَّلاً. والفرق يغيّر النافذة كلَّها لا نصَّها.
    String? convertedTo,
  }) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final converted = convertedTo != null;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(converted ? 'استعادة أصلٍ محوَّل؟' : 'استعادة السجل؟'),
        content: Text(
          converted
              ? 'هذا السجل لم يُحذف، بل حُوّل إلى "$convertedTo" — وتلك '
                  'نسخةٌ حيّة تحمل بياناته.\n\n'
                  'واستعادتُه تُبقي الاثنين معاً، فيظهر الشيء الواحد مرّتين في '
                  'كل قائمة وتقرير، ولا شيء في الشاشة يقول إن أحدهما صورةٌ عن '
                  'الآخر.\n\n'
                  'فإن أردتَ التراجع عن التحويل: احذف النسخة المحوَّلة أولاً، '
                  'ثم استعِد هذا الأصل.'
              : 'سيعود "$name" إلى مكانه، ومعه كل ما يتبعه من مهامّ وتحديثات '
                  'ومرفقات — فهي لم تُمحَ، بل اختفت باختفائه.',
          style: const TextStyle(fontSize: 13, height: 1.75),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          if (converted)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعِده رغم ذلك'),
            )
          else
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (yes != true) return;

    // والمحوَّل يمرّ بفكّ الارتباط أولاً: القاعدة تمنع استعادته ما دام
    // قائماً، فزرٌّ يستدعي الاستعادة مباشرةً يُردّ عند الضغط.
    final error = converted
        ? await store.detachAndRestore(
            collection: collection,
            id: id,
            targetType: targetType,
            targetName: name,
          )
        : await store.restoreItem(
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
                : '$total سجلاً مؤرشفاً — محذوفاً أو محوَّلاً. ولم يُمحَ شيء.',
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
                    Builder(builder: (_) {
                      final to = store.convertedTargetName(p.convertedToType, p.convertedToId);
                      return _ArchivedCard(
                        name: p.name,
                        subtitle: store.departmentById(p.departmentId)?.name ?? '',
                        deletedAt: p.deletedAt,
                        deletedByName: store.userNameOf(p.deletedBy),
                        reason: p.deletedReason,
                        convertedTo: p.wasConverted ? to : null,
                        onRestore: () => _restore(
                          context,
                          collection: 'projects',
                          id: p.id,
                          targetType: 'project',
                          name: p.name,
                          convertedTo: p.wasConverted ? to : null,
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                ],
                if (works.isNotEmpty) ...[
                  const _SectionTitle('الأعمال المحذوفة'),
                  for (final w in works)
                    Builder(builder: (_) {
                      final to = store.convertedTargetName(w.convertedToType, w.convertedToId);
                      return _ArchivedCard(
                        name: w.title,
                        subtitle: store.departmentById(w.departmentId)?.name ?? '',
                        deletedAt: w.deletedAt,
                        deletedByName: store.userNameOf(w.deletedBy),
                        reason: w.deletedReason,
                        convertedTo: w.wasConverted ? to : null,
                        onRestore: () => _restore(
                          context,
                          collection: 'works',
                          id: w.id,
                          targetType: 'work',
                          name: w.title,
                          convertedTo: w.wasConverted ? to : null,
                        ),
                      );
                    }),
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

  /// اسم ما حُوّل إليه هذا السجل — null إن كان محذوفاً لا محوَّلاً.
  final String? convertedTo;

  final VoidCallback onRestore;

  const _ArchivedCard({
    required this.name,
    required this.subtitle,
    required this.deletedAt,
    required this.deletedByName,
    required this.reason,
    required this.convertedTo,
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
                  if (convertedTo != null) ...[
                    const SizedBox(height: 5),
                    // ــ والمحوَّل يُعرض محوَّلاً لا محذوفاً ــ
                    //
                    // عرضُه كمحذوفٍ بزرّ استعادةٍ عاديّ يجعل ضغطةً واحدة
                    // تُنتج الشيء الواحد مرّتين في كل قائمة وتقرير.
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 15, color: AppColors.info),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'حُوّل إلى: $convertedTo',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ] else if ((reason ?? '').trim().isNotEmpty) ...[
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
              icon: Icon(convertedTo == null ? Icons.restore_rounded : Icons.info_outline_rounded,
                  size: 17),
              label: Text(convertedTo == null ? 'استعادة' : 'الاستعادة؟'),
            ),
          ],
        ),
      ),
    );
  }
}
