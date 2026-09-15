import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/attachment.dart';
import '../models/procedure.dart';
import '../theme/app_theme.dart';
import '../utils/file_picker.dart';
import '../widgets/command_band.dart';
import '../widgets/day_updates_dialog.dart' show AttachmentChip;

/// دليلُ الإجراءات: كيف يسير عملٌ في الوزارة، خطوةً خطوة.
///
/// ــــ ما تعرضه وما لا تعرضه ــــ
///
/// **مرجعٌ يُقرأ**: لا إسنادَ فيه ولا متابعةَ إنجاز ولا مواعيد. من احتاج
/// ذلك فله المشاريعُ والأعمال. وخلطُ الاثنين يجعل الدليلَ خطّةً ناقصةً بدل
/// أن يكون مرجعاً تامّاً.
///
/// **ولا حذف**: الأرشفةُ تُخرج الإجراءَ من السارية وتُبقيه مقروءاً. فمن
/// وعد بحفظ النسخ لا يمحو أصلَها.
class ProceduresScreen extends StatefulWidget {
  const ProceduresScreen({super.key});

  @override
  State<ProceduresScreen> createState() => _ProceduresScreenState();
}

class _ProceduresScreenState extends State<ProceduresScreen> {
  String _query = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canEdit = store.canEditProcedures;

    final all = _showArchived ? store.procedures : store.activeProcedures;
    final q = _query.trim();
    final shown = q.isEmpty
        ? all
        : all
            .where((p) =>
                p.title.contains(q) ||
                p.summary.contains(q) ||
                p.steps.any((s) => s.title.contains(q) || s.description.contains(q)))
            .toList();

    final archivedCount = store.procedures.length - store.activeProcedures.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'دليل الإجراءات',
            subtitle: 'كيف يسير العمل خطوةً خطوة: لكلٍّ صاحبُها وإدارتُها ومدّتُها. '
                'وكلُّ تعديلٍ يحفظ نسخةً كاملةً مما كان قبله.',
            actions: [
              if (canEdit)
                BandButton(
                  label: 'إضافة إجراء',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const ProcedureFormDialog(),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'بحث في الإجراءات وخطواتها',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    // ــ ولا يُعرض مفتاحُ المؤرشف حتى يوجد مؤرشف ــ
                    //
                    // مفتاحٌ لا يُغيّر شيئاً يُجرّب فيُظنّ معطّلاً.
                    if (archivedCount > 0) ...[
                      const SizedBox(width: AppSpace.md),
                      FilterChip(
                        label: Text('مع المؤرشفة ($archivedCount)'),
                        selected: _showArchived,
                        onSelected: (v) => setState(() => _showArchived = v),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(
                        store.procedures.isEmpty
                            ? (canEdit
                                ? 'لا إجراءات بعد — ابدأ بإضافة أوّلها.'
                                : 'لا إجراءات في الدليل بعد.')
                            : 'لا إجراء يطابق البحث',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...shown.map((p) => _ProcedureCard(procedure: p, canEdit: canEdit)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcedureCard extends StatelessWidget {
  final Procedure procedure;
  final bool canEdit;

  const _ProcedureCard({required this.procedure, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final dept = store.departmentById(procedure.departmentId ?? '');
    final total = procedure.totalDurationDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => showDialog(
          context: context,
          builder: (_) => ProcedureViewDialog(procedureId: procedure.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.list_alt_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            procedure.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        if (!procedure.isActive) ...[
                          const SizedBox(width: AppSpace.xs),
                          const Chip(
                            label: Text('مؤرشف', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    if (procedure.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        procedure.summary,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Tag('${procedure.steps.length} خطوة'),
                        if (dept != null) _Tag(dept.name),
                        // ــ ومجموعٌ ناقصٌ يُقال ناقصاً ــ
                        //
                        // فقارئٌ يرى «١٢ يوماً» ولا يعلم أنّ ثلاث خطواتٍ بلا
                        // مدّةٍ يبني عليها موعداً لم تقله المنصة.
                        if (total != null)
                          _Tag(procedure.hasCompleteDurations
                              ? '$total يوماً'
                              : '$total يوماً على الأقل'),
                        _Tag('النسخة ${procedure.version}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ProcedureFormDialog(existing: procedure),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      );
}

/// قراءةُ الإجراء: خطواتُه مرقّمةً، ونسخُه السابقة.
class ProcedureViewDialog extends StatefulWidget {
  final String procedureId;

  /// نسخةٌ سابقةٌ تُعرض بدل السارية — تُمرَّر من قائمة النسخ.
  final Procedure? snapshot;
  final int? snapshotVersion;

  const ProcedureViewDialog({
    super.key,
    required this.procedureId,
    this.snapshot,
    this.snapshotVersion,
  });

  @override
  State<ProcedureViewDialog> createState() => _ProcedureViewDialogState();
}

class _ProcedureViewDialogState extends State<ProcedureViewDialog> {
  List<ProcedureVersion>? _versions;
  bool _loadingVersions = false;
  String? _versionsError;

  Future<void> _loadVersions() async {
    setState(() {
      _loadingVersions = true;
      _versionsError = null;
    });
    try {
      final list = await context.read<AppStore>().procedureVersions(widget.procedureId);
      if (!mounted) return;
      setState(() {
        _versions = list;
        _loadingVersions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVersions = false;
        _versionsError = 'تعذّر قراءة النسخ السابقة: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final live = store.procedureById(widget.procedureId);
    final p = widget.snapshot ?? live;

    if (p == null) {
      return AlertDialog(
        content: const Text('لم يعد هذا الإجراء متاحاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      );
    }

    final isSnapshot = widget.snapshot != null;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title),
          if (isSnapshot)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'نسخةٌ سابقة (${widget.snapshotVersion ?? p.version}) — تُعرض كما كانت، ولا تُعدَّل',
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.summary.isNotEmpty) ...[
                Text(p.summary, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpace.md),
              ],
              if (p.steps.isEmpty)
                const Text('لا خطوات في هذا الإجراء بعد.',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                for (var i = 0; i < p.steps.length; i++)
                  _StepTile(index: i + 1, step: p.steps[i]),
              if (!isSnapshot) ...[
                const Divider(height: 32),
                _VersionsSection(
                  versions: _versions,
                  loading: _loadingVersions,
                  error: _versionsError,
                  onLoad: _loadVersions,
                  onOpen: (v) => showDialog(
                    context: context,
                    builder: (_) => ProcedureViewDialog(
                      procedureId: widget.procedureId,
                      snapshot: v.snapshot,
                      snapshotVersion: v.versionNumber,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!isSnapshot && store.canEditProcedures && live != null)
          TextButton(
            onPressed: () async {
              final next = !live.isActive;
              final error = await store.setProcedureActive(live, next);
              if (!context.mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error),
                  backgroundColor: AppColors.danger,
                ));
              }
            },
            child: Text(live.isActive ? 'أرشفة' : 'إعادة إلى السارية'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final ProcedureStep step;

  const _StepTile({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final dept = store.departmentById(step.departmentId ?? '');
    final meta = [
      if (step.ownerTitle.isNotEmpty) step.ownerTitle,
      if (dept != null) dept.name,
      // ــ ومدّةٌ لم تُسجَّل لا تُعرض صفراً ــ
      if (step.durationDays != null) '${step.durationDays} يوماً',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            // و`primary` لونٌ يضبطه مسؤولُ النظام فليس ثابتاً — فلا `const`.
            child: Text('$index',
                style: const TextStyle(fontSize: 12).copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty)
                  Text(meta.join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (step.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(step.description, style: const TextStyle(fontSize: 13)),
                  ),
                if (step.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ملاحظة: ${step.notes}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                if (step.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final a in step.attachments) AttachmentChip(attachment: a),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// النسخُ السابقة — **تُقرأ عند الطلب لا مع كل فتح**.
///
/// وعددُها ينمو مع كل تعديلٍ لكل إجراء، فقراءتُها دائماً تحمل تاريخَ
/// الدليل كلِّه إلى من يريد صفحةً واحدة.
class _VersionsSection extends StatelessWidget {
  final List<ProcedureVersion>? versions;
  final bool loading;
  final String? error;
  final VoidCallback onLoad;
  final void Function(ProcedureVersion) onOpen;

  const _VersionsSection({
    required this.versions,
    required this.loading,
    required this.error,
    required this.onLoad,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (error != null) {
      return Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12));
    }
    if (versions == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('النسخ السابقة'),
          onPressed: onLoad,
        ),
      );
    }
    if (versions!.isEmpty) {
      return const Text('لم يُعدَّل هذا الإجراء بعد — هذه نسختُه الأولى.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('النسخ السابقة', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final v in versions!)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.background,
              child: Text('${v.versionNumber}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(
              v.note.isEmpty ? 'بلا سببٍ مكتوب' : v.note,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              [
                if (v.savedByName.isNotEmpty) v.savedByName,
                if (v.savedAt != null)
                  '${v.savedAt!.year}/${v.savedAt!.month}/${v.savedAt!.day}',
              ].join(' · '),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: TextButton(onPressed: () => onOpen(v), child: const Text('عرض')),
          ),
      ],
    );
  }
}

/// إضافةُ إجراءٍ أو تعديلُه — نافذةٌ واحدة للحالين.
class ProcedureFormDialog extends StatefulWidget {
  final Procedure? existing;
  const ProcedureFormDialog({super.key, this.existing});

  @override
  State<ProcedureFormDialog> createState() => _ProcedureFormDialogState();
}

class _ProcedureFormDialogState extends State<ProcedureFormDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _summary =
      TextEditingController(text: widget.existing?.summary ?? '');
  late final TextEditingController _note = TextEditingController();
  late String? _departmentId = widget.existing?.departmentId;
  late List<ProcedureStep> _steps = [...(widget.existing?.steps ?? const [])];

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _note.dispose();
    super.dispose();
  }

  /// قيمةٌ ليست في القائمة تُقرأ عدماً — و`DropdownButtonFormField` **يرمي**
  /// إن كانت قيمتُه ليست في عناصره. وذلك يقع: إدارةٌ حُذفت بعد أن اختيرت.
  String? _amongOptions(String? value, Iterable<String> ids) =>
      value != null && ids.contains(value) ? value : null;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final error = await store.saveProcedure(
      id: widget.existing?.id ?? '',
      title: _title.text,
      summary: _summary.text,
      departmentId: _departmentId,
      steps: _steps,
      note: _note.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final departments = store.departments;
    final isNew = widget.existing == null;

    return AlertDialog(
      title: Text(isNew ? 'إضافة إجراء' : 'تعديل إجراء'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان الإجراء'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _summary,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصفٌ موجز (اختياري)'),
              ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<String?>(
                initialValue: _amongOptions(_departmentId, departments.map((d) => d.id)),
                decoration: const InputDecoration(labelText: 'الإدارة صاحبة الإجراء'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('إجراءٌ عامّ للوزارة')),
                  for (final d in departments)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  const Text('الخطوات', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('خطوة'),
                    onPressed: () async {
                      final step = await showDialog<ProcedureStep>(
                        context: context,
                        builder: (_) => _StepFormDialog(
                          procedureId: widget.existing?.id ?? '',
                        ),
                      );
                      if (step != null) setState(() => _steps = [..._steps, step]);
                    },
                  ),
                ],
              ),
              if (_steps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا خطوات بعد — أضف أولاها.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                )
              else
                // ــ والترتيبُ ترتيبُ القائمة، يُغيَّر بالسحب ــ
                //
                // ولا حقلَ رقميّ يُصان: مصفوفةٌ واحدة لا تحتاجه، وحقلٌ منفصل
                // يفتح حالةَ رقمين متساويين وهي لا معنى لها هنا.
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _steps.length,
                  // `onReorderItem` لا `onReorder`: تلك تُسلّم فهرساً يحتاج
                  // تصحيحاً يدوياً بعد إزالة العنصر، وهو موضعُ خطأٍ شائع
                  // صارت المكتبةُ تتولّاه.
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    final next = [..._steps];
                    next.insert(newIndex, next.removeAt(oldIndex));
                    _steps = next;
                  }),
                  itemBuilder: (context, i) {
                    final s = _steps[i];
                    return Card(
                      key: ValueKey('step-$i-${s.title}'),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle_rounded),
                        ),
                        title: Text('${i + 1}. ${s.title}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          [
                            if (s.ownerTitle.isNotEmpty) s.ownerTitle,
                            if (s.durationDays != null) '${s.durationDays} يوماً',
                            if (s.attachments.isNotEmpty) '${s.attachments.length} مرفق',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'تعديل الخطوة',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final edited = await showDialog<ProcedureStep>(
                                  context: context,
                                  builder: (_) => _StepFormDialog(
                                    existing: s,
                                    procedureId: widget.existing?.id ?? '',
                                  ),
                                );
                                if (edited != null) {
                                  setState(() {
                                    final next = [..._steps];
                                    next[i] = edited;
                                    _steps = next;
                                  });
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'حذف الخطوة',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() {
                                final next = [..._steps]..removeAt(i);
                                _steps = next;
                              }),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (!isNew) ...[
                const Divider(height: 32),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'سبب التعديل',
                    helperText: 'يُقرأ في قائمة النسخ السابقة — فيُعرف لماذا تغيّر الإجراء',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

class _StepFormDialog extends StatefulWidget {
  final ProcedureStep? existing;

  /// معرّفُ الإجراء — بادئةُ مسار المرفقات. وفارغاً لإجراءٍ لم يُحفظ بعد.
  final String procedureId;

  const _StepFormDialog({this.existing, required this.procedureId});

  @override
  State<_StepFormDialog> createState() => _StepFormDialogState();
}

class _StepFormDialogState extends State<_StepFormDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _owner =
      TextEditingController(text: widget.existing?.ownerTitle ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late final TextEditingController _days =
      TextEditingController(text: widget.existing?.durationDays?.toString() ?? '');
  late String? _departmentId = widget.existing?.departmentId;
  late List<Attachment> _attachments = [...(widget.existing?.attachments ?? const [])];

  bool _uploading = false;
  String? _attachError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _owner.dispose();
    _notes.dispose();
    _days.dispose();
    super.dispose();
  }

  String? _amongOptions(String? value, Iterable<String> ids) =>
      value != null && ids.contains(value) ? value : null;

  /// الاختيار **قبل** أي انتظار: المتصفحات تمنع فتح نافذة الملفات إن جاءت
  /// بعد عملية غير متزامنة — راجع `file_picker_web.dart`.
  Future<void> _pickAndUpload() async {
    final picked = await pickFile(accept: const [
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', 'image/*',
    ]);
    if (picked == null || !mounted) return;
    setState(() {
      _uploading = true;
      _attachError = null;
    });
    final result = await context.read<AppStore>().uploadProcedureAttachment(
          // إجراءٌ لم يُحفظ بعدُ لا معرّفَ له، فتُوضع مرفقاتُه تحت `new`
          // ويبقى الرابطُ صحيحاً بعد الحفظ: المسارُ مجرّدُ موضعِ ملفّ.
          procedureId: widget.procedureId.isEmpty ? 'new' : widget.procedureId,
          picked: picked,
        );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _attachError = result.error;
      if (result.file != null) _attachments = [..._attachments, result.file!];
    });
  }

  @override
  Widget build(BuildContext context) {
    final departments = context.watch<AppStore>().departments;

    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة خطوة' : 'تعديل خطوة'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان الخطوة'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ماذا يُعمل فيها'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _owner,
                decoration: const InputDecoration(
                  labelText: 'صاحب الخطوة',
                  helperText: 'مسمّىً وظيفيّ — «مدير إدارة العقود» — لا اسمَ شخص',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<String?>(
                initialValue: _amongOptions(_departmentId, departments.map((d) => d.id)),
                decoration: const InputDecoration(labelText: 'الإدارة'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بلا إدارة محدّدة')),
                  for (final d in departments)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المدّة بالأيام',
                  helperText: 'اتركه فارغاً إن لم تُحدَّد — ولا يُقرأ صفراً',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  const Text('المرفقات', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('رفع ملف'),
                    onPressed: _uploading ? null : _pickAndUpload,
                  ),
                ],
              ),
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_attachError != null)
                Text(_attachError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              if (_attachments.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _attachments.length; i++)
                      InputChip(
                        label: Text(_attachments[i].name,
                            style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() {
                          final next = [..._attachments]..removeAt(i);
                          _attachments = next;
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            // مدّةٌ لم تُكتب، أو كُتبت بما ليس رقماً موجباً، تُقرأ «غير
            // مسجّلة» — لا صفراً. والخادمُ يفحص المثلَ في `normalizeSteps`.
            final parsed = int.tryParse(_days.text.trim());
            Navigator.pop(
              context,
              ProcedureStep(
                title: title,
                description: _description.text.trim(),
                ownerTitle: _owner.text.trim(),
                departmentId: _departmentId,
                durationDays: parsed != null && parsed >= 0 ? parsed : null,
                notes: _notes.text.trim(),
                attachments: _attachments,
              ),
            );
          },
          child: const Text('تم'),
        ),
      ],
    );
  }
}
