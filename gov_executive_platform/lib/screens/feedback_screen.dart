import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/feedback_item.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../utils/formatters.dart';

/// الشكاوى والاقتراحات: ما يرفعه الموظف، وما يرده لمن يتابعها.
///
/// الصلاحيتان منفصلتان عمداً: قد تُندب موظفاً لمتابعة الوارد دون أن يكون هو
/// من يرفع، وقد تفتح الرفع لدور كامل دون أن تُطلعهم على شكاوى غيرهم.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _showIncoming = false;
  FeedbackStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canManage = store.canManageFeedback;
    final canSubmit = store.canSubmitFeedback;
    // من يتابع الوارد يبدأ عليه؛ ومن يرفع فقط لا يرى تبويب الوارد أصلاً.
    final showingIncoming = canManage && _showIncoming;
    var items = showingIncoming ? store.incomingFeedback : store.myFeedback;
    if (_statusFilter != null) {
      items = items.where((f) => f.status == _statusFilter).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'الشكاوى والاقتراحات',
            subtitle: 'قناة مباشرة لرفع ما يعترض العمل وما يقترحه الموظفون لتحسينه',
            actions: [
              if (canSubmit)
                BandButton(
                  label: 'رفع شكوى أو اقتراح',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const _SubmitDialog()),
                ),
            ],
          ),
          const SizedBox(height: 18),

          if (canManage) ...[
            // التسمية تقصر على الشاشة الضيّقة: «الوارد (٣ مفتوحة)» مع أيقونتها
            // ومع الخانة المجاورة أعرض من شاشة الهاتف، فكان المفتاح يتجاوزها.
            LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 420;
              return SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: const Text('ما رفعتُه'),
                    icon: narrow ? null : const Icon(Icons.outbox_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(narrow
                        ? 'الوارد (${store.openFeedbackCount})'
                        : 'الوارد (${store.openFeedbackCount} مفتوحة)'),
                    icon: narrow ? null : const Icon(Icons.inbox_rounded, size: 16),
                  ),
                ],
                selected: {_showIncoming},
                onSelectionChanged: (s) => setState(() => _showIncoming = s.first),
              );
            }),
            const SizedBox(height: 14),
          ],

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'الكل', selected: _statusFilter == null, onTap: () => setState(() => _statusFilter = null)),
              for (final s in FeedbackStatus.values)
                _Chip(
                  label: s.label,
                  selected: _statusFilter == s,
                  onTap: () => setState(() => _statusFilter = s),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.forum_outlined, size: 34, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      _statusFilter != null
                          ? 'لا شيء ضمن هذا التصنيف'
                          : (showingIncoming ? 'لم يرد شيء بعد' : 'لم ترفع شيئاً بعد'),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    if (_statusFilter == null && !showingIncoming && !canSubmit) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'رفع الشكاوى والاقتراحات صلاحية يمنحها مسؤول النظام. اطلبها منه إن احتجتها.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...items.map((f) => _FeedbackCard(item: f, canManage: showingIncoming)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackItem item;
  final bool canManage;
  const _FeedbackCard({required this.item, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = item.departmentId == null ? null : store.departmentById(item.departmentId!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.kind.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.status.label,
                      style: TextStyle(color: item.status.color, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.body, style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Meta(icon: Icons.label_outline_rounded, text: item.kind.label),
                if (canManage) _Meta(icon: Icons.person_outline_rounded, text: item.submittedByName),
                if (dept != null) _Meta(icon: Icons.account_balance_rounded, text: dept.name),
                _Meta(icon: Icons.event_outlined, text: Formatters.shortDate(item.createdAt)),
              ],
            ),
            if (item.responseNote != null && item.responseNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الردّ${item.handledByName == null ? '' : ' — ${item.handledByName}'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(item.responseNote!,
                        style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
            if (canManage) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => _ResolveDialog(item: item)),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('البتّ والردّ'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SubmitDialog extends StatefulWidget {
  const _SubmitDialog();

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  FeedbackKind _kind = FeedbackKind.suggestion;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء كتابة العنوان والتفاصيل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await context.read<AppStore>().submitFeedback(
          kind: _kind,
          title: _titleCtrl.text,
          body: _bodyCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('وصلت ${_kind.label} إلى مسؤول النظام.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رفع شكوى أو اقتراح', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<FeedbackKind>(
                segments: [
                  for (final k in FeedbackKind.values)
                    ButtonSegment(value: k, label: Text(k.label), icon: Icon(k.icon, size: 16)),
                ],
                selected: {_kind},
                onSelectionChanged: _busy ? null : (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'التفاصيل',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              // شفافية مقصودة: من يرفع يجب أن يعرف أن اسمه يظهر، فلا يظنّها
              // قناة مجهولة ثم يفاجأ.
              const Text(
                'يظهر اسمك وإدارتك مع ما ترفعه، ويطّلع عليه مسؤول النظام ومن يندبه لمتابعة الوارد.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.7),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إرسال'),
        ),
      ],
    );
  }
}

class _ResolveDialog extends StatefulWidget {
  final FeedbackItem item;
  const _ResolveDialog({required this.item});

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  late final TextEditingController _noteCtrl = TextEditingController(text: widget.item.responseNote ?? '');
  late FeedbackStatus _status = widget.item.status;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final error = await context.read<AppStore>().resolveFeedback(
          widget.item,
          status: _status,
          note: _noteCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('من: ${widget.item.submittedByName}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<FeedbackStatus>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: [
                  for (final s in FeedbackStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'الردّ (يراه صاحبها)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
