/// المشاكل — **السببُ تحت البلاغات المتكرّرة**.
///
/// وتُعرض معها **عدّةُ بلاغاتها**، وهي تُحسب من البلاغات نفسِها لا من قائمةٍ
/// مخزّنة: قائمةٌ في المستند تتناقض مع الحقل على البلاغ عند أوّل كتابةٍ
/// تخفق، والعدُّ من الأصل لا يكذب.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/problem.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/status_pill.dart';

class ProblemsScreen extends StatelessWidget {
  const ProblemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.visibleProblems.toList()
      ..sort((a, b) {
        // والنشطُ أوّلاً: ما أُغلق خبرٌ انتهى أمرُه.
        if (a.status.isActive != b.status.isActive) return a.status.isActive ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProblemDialog(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مشكلةٌ جديدة'),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          const SectionTitle('المشاكل', icon: Icons.troubleshoot_rounded),
          SizedBox(height: AppSpace.xs),
          Text(
            'بلاغٌ يتكرّر ليس بلاغاتٍ كثيرة، بل مشكلةً واحدةً لم يُعرف سببُها.',
            style: AppText.label,
          ),
          SizedBox(height: AppSpace.md),
          if (items.isEmpty)
            const AppEmptyState(
              title: 'لا مشاكلَ مسجّلة',
              message: 'حين تلاحظ بلاغاً يتكرّر، افتح له مشكلةً واربط بلاغاتِه بها.',
              icon: Icons.troubleshoot_rounded,
            )
          else
            for (final p in items)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpace.sm),
                child: _ProblemRow(problem: p),
              ),
        ],
      ),
    );
  }
}

class _ProblemRow extends StatelessWidget {
  final Problem problem;
  const _ProblemRow({required this.problem});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final linked = store.ticketsOfProblem(problem.id).length;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showProblemDialog(context, problem),
        child: AppCard(
          shrinkToChild: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(problem.title,
                  style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: AppSpace.xs),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  StatusPill(
                      label: problem.status.label,
                      tone: StatusPalette.problemTone(problem.status.name)),
                  StatusPill(
                      label: problem.priority.label,
                      tone: StatusPalette.priorityTone(problem.priority.name),
                      dot: false),
                  StatusPill(
                      label: linked == 0 ? 'بلا بلاغاتٍ مربوطة' : '$linked بلاغاً مربوطاً',
                      tone: StatusPalette.neutral,
                      dot: false),
                ],
              ),
              if (problem.rootCause.isNotEmpty) ...[
                SizedBox(height: AppSpace.xs),
                Text('السبب: ${problem.rootCause}',
                    style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showProblemDialog(BuildContext context, Problem? existing) =>
    showDialog(context: context, builder: (_) => _ProblemDialog(existing: existing));

class _ProblemDialog extends StatefulWidget {
  final Problem? existing;
  const _ProblemDialog({this.existing});

  @override
  State<_ProblemDialog> createState() => _ProblemDialogState();
}

class _ProblemDialogState extends State<_ProblemDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _statement =
      TextEditingController(text: widget.existing?.statement ?? '');
  late final TextEditingController _rootCause =
      TextEditingController(text: widget.existing?.rootCause ?? '');
  late final TextEditingController _workaround =
      TextEditingController(text: widget.existing?.workaround ?? '');
  late ProblemStatus _status = widget.existing?.status ?? ProblemStatus.investigating;
  late PriorityLevel _priority = widget.existing?.priority ?? PriorityLevel.medium;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _statement.dispose();
    _rootCause.dispose();
    _workaround.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final me = store.currentUser;
    return AlertDialog(
      title: Text(widget.existing == null ? 'مشكلةٌ جديدة' : 'تعديلُ مشكلة'),
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
                  labelText: 'ما الذي يتكرّر؟',
                  hintText: 'طابعاتُ الطابق الثاني تتعطّل أسبوعيّاً',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _statement,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'على مَن يقع، ومنذ متى'),
              ),
              SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<ProblemStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: [
                  for (final s in ProblemStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'الأولويّة'),
                items: [
                  for (final p in PriorityLevel.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _workaround,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'الحلُّ المؤقّت',
                  hintText: 'ما يُعمل به ريثما يُصلَح السبب',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _rootCause,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'السببُ الجذريّ',
                  hintText: 'يُترك فارغاً حتّى يُعرف — ولا يُختلق',
                ),
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
                  final isNew = widget.existing == null;
                  final p = (widget.existing ??
                          Problem(
                            id: '',
                            title: '',
                            priority: _priority,
                            status: _status,
                            ownerUid: me?.id ?? '',
                            ownerName: me?.name ?? '',
                            createdByUid: me?.id ?? '',
                            createdAt: DateTime.now(),
                          ))
                      .copyWith(
                    title: _title.text.trim(),
                    statement: _statement.text.trim(),
                    rootCause: _rootCause.text.trim(),
                    workaround: _workaround.text.trim(),
                    status: _status,
                    priority: _priority,
                  );
                  final err = await store.saveProblem(p, isNew: isNew);
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
          child: Text(_saving ? 'يُحفَظ…' : 'احفظ'),
        ),
      ],
    );
  }
}
