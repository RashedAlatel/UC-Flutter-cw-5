/// التغييراتُ التقنيّة ولجنةُ CAB.
///
/// ــــ ولا زرَّ اعتمادٍ في هذه الشاشة ــــ
///
/// البتُّ يقع في **مركز القرارات** حيث تقع كلُّ قرارات المنصّة، عبر الدالّة
/// الخلفيّة التي تفحص البطاقةَ وتكتب السجلّ وتُخطر الطالب. وزرٌّ هنا يكتب
/// `status: 'approved'` مباشرةً تردُّه القاعدةُ — ولو مرّ لاعتمد كلُّ
/// رافعٍ تغييرَ نفسِه، ولصارت اللجنةُ اسماً في شاشة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/change_request.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';

class ChangesScreen extends StatelessWidget {
  const ChangesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.visibleChanges.toList()
      ..sort((a, b) {
        // وما ينتظر مراجعةً يتصدّر: تغييرٌ في الإنتاج بلا اعتماد.
        if (a.awaitingReview != b.awaitingReview) return a.awaitingReview ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final unreviewed = all.where((c) => c.awaitingReview).length;
    final waiting = all.where((c) => c.status == ChangeStatus.awaitingApproval).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showChangeFormDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('تغييرٌ جديد'),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          const SectionTitle('التغييرات التقنية', icon: Icons.published_with_changes_rounded),
          SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              SizedBox(
                width: 230,
                child: StatCard(
                  title: 'ينتظر الاعتماد',
                  value: '$waiting',
                  icon: Icons.pending_actions_rounded,
                  tone: StatusPalette.warning,
                ),
              ),
              SizedBox(
                width: 230,
                child: StatCard(
                  title: 'طارئٌ لم يُراجَع',
                  value: '$unreviewed',
                  icon: Icons.priority_high_rounded,
                  // والنغمةُ تتبع الرقم: صفرٌ ليس خطراً، وحمرةٌ دائمةٌ تُهمَل.
                  tone: unreviewed > 0 ? StatusPalette.danger : StatusPalette.success,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.md),
          Text(
            'الاعتمادُ والرفضُ يقعان من «مركز القرارات» — لا من هنا.',
            style: AppText.label,
          ),
          SizedBox(height: AppSpace.sm),
          if (all.isEmpty)
            const AppEmptyState(
              title: 'لا تغييراتٍ مسجّلة',
              message: 'كلُّ تعديلٍ على البنية التقنية يُسجَّل هنا قبل تنفيذه.',
              icon: Icons.published_with_changes_rounded,
            )
          else
            for (final c in all)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpace.sm),
                child: _ChangeRow(change: c),
              ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final ChangeRequest change;
  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return AppCard(
      shrinkToChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(change.title, style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              StatusPill(label: change.kind.label, tone: StatusPalette.neutral, dot: false),
              StatusPill(
                  label: change.status.label, tone: StatusPalette.changeTone(change.status.name)),
              StatusPill(
                  label: 'خطر ${change.risk.label}',
                  tone: StatusPalette.severityTone(change.risk.name),
                  dot: false),
              // ــ ووسمُ المراجعة إلى جانب الحالة لا مكانَها ــ
              //
              // «نُفِّذ» و«لم يُراجَع» خبران مختلفان، وجمعُهما في وسمٍ واحد
              // يُخفي أحدَهما.
              if (change.awaitingReview)
                StatusPill(label: 'ينتظر مراجعةً', tone: StatusPalette.danger),
            ],
          ),
          if (change.backoutPlan.isNotEmpty) ...[
            SizedBox(height: AppSpace.xs),
            Text('التراجع: ${change.backoutPlan}',
                style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (change.approvedByName.isNotEmpty) ...[
            SizedBox(height: AppSpace.xs),
            Text('بتَّ فيه ${change.approvedByName}', style: AppText.label),
          ],
          SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in [
                ChangeStatus.implemented,
                ChangeStatus.rolledBack,
                ChangeStatus.closed,
              ])
                if (s != change.status)
                  OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final err = await store.markChange(change, s);
                      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
                    },
                    child: Text(s.label),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showChangeFormDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _ChangeFormDialog());

class _ChangeFormDialog extends StatefulWidget {
  const _ChangeFormDialog();

  @override
  State<_ChangeFormDialog> createState() => _ChangeFormDialogState();
}

class _ChangeFormDialogState extends State<_ChangeFormDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _backout = TextEditingController();
  ChangeKind _kind = ChangeKind.normal;
  ChangeRisk _risk = ChangeRisk.medium;
  DateTime? _plannedStart;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _backout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final me = store.currentUser;
    return AlertDialog(
      title: const Text('تغييرٌ جديد'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'ما التغيير؟',
                  hintText: 'ترقيةُ خادم البريد إلى الإصدار الجديد',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'التفاصيل وأثرُه المتوقَّع'),
              ),
              SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<ChangeKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'الصنف'),
                items: [
                  for (final k in ChangeKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              if (_kind == ChangeKind.emergency) ...[
                SizedBox(height: AppSpace.xs),
                Text(
                  'الطارئُ يُسجَّل منفَّذاً فوراً، ويبقى «ينتظر مراجعةً» حتّى يبتّ فيه المعتمِد.',
                  style: AppText.label.copyWith(color: AppColors.danger),
                ),
              ],
              SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<ChangeRisk>(
                initialValue: _risk,
                decoration: const InputDecoration(labelText: 'الخطر'),
                items: [
                  for (final r in ChangeRisk.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => _risk = v ?? _risk),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _backout,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'خطّةُ التراجع',
                  hintText: 'ماذا نفعل إن ساء الأمر — تُكتب قبل التنفيذ لا بعده',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _plannedStart == null
                          ? 'موعدُ التنفيذ: غير محدَّد'
                          : 'موعدُ التنفيذ: ${_plannedStart!.year}/${_plannedStart!.month}/${_plannedStart!.day}',
                      style: AppText.label,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _plannedStart = picked);
                    },
                    child: const Text('اختر'),
                  ),
                ],
              ),
              if (_error != null) ...[
                SizedBox(height: AppSpace.sm),
                Text(_error!, style: AppText.label.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final err = await store.submitChange(ChangeRequest(
                    id: '',
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    kind: _kind,
                    risk: _risk,
                    status: ChangeStatus.draft,
                    plannedStart: _plannedStart,
                    backoutPlan: _backout.text.trim(),
                    implementerUid: me?.id ?? '',
                    implementerName: me?.name ?? '',
                    createdByUid: me?.id ?? '',
                    createdByName: me?.name ?? '',
                    createdAt: DateTime.now(),
                  ));
                  if (!mounted) return;
                  final nav = Navigator.of(this.context);
                  if (err != null) {
                    setState(() {
                      _saving = false;
                      _error = err;
                    });
                    return;
                  }
                  nav.pop();
                },
          child: Text(_saving ? 'يُرفَع…' : (_kind == ChangeKind.emergency ? 'سجّل ونفّذ' : 'ارفع للاعتماد')),
        ),
      ],
    );
  }
}
