import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/attachment.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/file_picker.dart';

class DailyUpdateForm extends StatefulWidget {
  final Project project;
  const DailyUpdateForm({super.key, required this.project});

  @override
  State<DailyUpdateForm> createState() => _DailyUpdateFormState();
}

class _DailyUpdateFormState extends State<DailyUpdateForm> {
  final _achievementsCtrl = TextEditingController();
  final List<String> _completedTasks = [];
  final List<String> _newRisks = [];
  final List<String> _blockers = [];
  final List<String> _decisions = [];
  final _notesCtrl = TextEditingController();
  final List<Attachment> _attachments = [];
  late double _progress;
  bool _busy = false;
  bool _uploading = false;
  String? _attachError;

  @override
  void initState() {
    super.initState();
    _progress = widget.project.progressPercent;
  }

  @override
  void dispose() {
    _achievementsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ملخص الإنجازات لم يعد إلزامياً بقرار من مسؤول النظام: يومٌ بلا إنجاز
    // يُذكر واقعةٌ عادية، وإجبار الموظف على كتابة شيء يُنتج نصّاً بلا معنى
    // يملأ السجل ولا يُقرأ.
    //
    // والشرط الباقي أن يقول التحديث **شيئاً**: بلا إنجاز ولا مهمة منجزة ولا
    // خطر ولا عائق ولا قرار ولا ملاحظة ولا تغيّر في النسبة، فهو مستند فارغ
    // يُثقل السجل ويُوهم بمتابعة لم تقع.
    final saysSomething = _achievementsCtrl.text.trim().isNotEmpty ||
        _notesCtrl.text.trim().isNotEmpty ||
        _completedTasks.isNotEmpty ||
        _newRisks.isNotEmpty ||
        _blockers.isNotEmpty ||
        _decisions.isNotEmpty ||
        _attachments.isNotEmpty ||
        _progress != widget.project.progressPercent;
    if (!saysSomething) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التحديث فارغ. اكتب إنجازاً أو ملاحظة، أو حرّك نسبة الإنجاز.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().addDailyUpdate(
            project: widget.project,
            achievements: _achievementsCtrl.text.trim(),
            completedTasks: _completedTasks,
            newRisks: _newRisks,
            blockersText: _blockers,
            decisionsRequired: _decisions,
            progressPercent: _progress,
            notes: _notesCtrl.text.trim(),
            attachments: _attachments,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التحديث اليومي بنجاح')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التحديث، حاول مرة أخرى')));
    }
  }

  /// الاختيار **قبل** أي انتظار: المتصفحات تمنع فتح نافذة الملفات إن جاءت
  /// بعد عملية غير متزامنة، فلا تُفتح ولا رسالة — راجع `file_picker_web.dart`.
  Future<void> _pickAndUpload() async {
    final picked = await pickFile(accept: const [
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', 'image/*',
    ]);
    if (picked == null || !mounted) return;
    setState(() {
      _uploading = true;
      _attachError = null;
    });
    final result = await context.read<AppStore>().uploadAttachment(
          projectId: widget.project.id,
          picked: picked,
        );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _attachError = result.error;
      if (result.file != null) _attachments.add(result.file!);
    });
  }

  Future<void> _addLink() async {
    final added = await showDialog<Attachment>(
      context: context,
      builder: (_) => const _LinkAttachmentDialog(),
    );
    if (added == null || !mounted) return;
    setState(() {
      _attachments.add(added);
      _attachError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تحديث يومي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(widget.project.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الإنجازات (اختياري)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _achievementsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'صف أبرز إنجازات اليوم...'),
                    ),
                    const SizedBox(height: 18),
                    Text('نسبة التقدم في المشروع: ${_progress.toStringAsFixed(0)}٪', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Slider(
                      value: _progress,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${_progress.toStringAsFixed(0)}٪',
                      onChanged: (v) => setState(() => _progress = v),
                    ),
                    const SizedBox(height: 8),
                    _ListInput(
                      label: 'المهام المنجزة اليوم',
                      hint: 'أضف مهمة منجزة واضغط إدخال',
                      items: _completedTasks,
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _ListInput(
                      label: 'مخاطر جديدة',
                      hint: 'أضف خطر جديد واضغط إدخال',
                      items: _newRisks,
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _ListInput(
                      label: 'عوائق',
                      hint: 'أضف عائقاً واضغط إدخال',
                      items: _blockers,
                      icon: Icons.block_rounded,
                      color: const Color(0xFFE0692B),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _ListInput(
                      label: 'قرارات مطلوبة من القيادة',
                      hint: 'أضف قراراً مطلوباً واضغط إدخال',
                      items: _decisions,
                      icon: Icons.gavel_rounded,
                      color: AppColors.info,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'ما لا يقع تحت الإنجازات ولا العوائق — سياق أو تنبيه أو توضيح…',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AttachmentsField(
                      attachments: _attachments,
                      uploading: _uploading,
                      error: _attachError,
                      onPickFile: _pickAndUpload,
                      onAddLink: _addLink,
                      onRemove: (a) => setState(() => _attachments.remove(a)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ التحديث'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListInput extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> items;
  final IconData icon;
  final Color color;
  final VoidCallback onChanged;

  const _ListInput({
    required this.label,
    required this.hint,
    required this.items,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  State<_ListInput> createState() => _ListInputState();
}

class _ListInputState extends State<_ListInput> {
  final _ctrl = TextEditingController();

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.items.add(text);
      _ctrl.clear();
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(hintText: widget.hint, isDense: true),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 18),
              style: IconButton.styleFrom(backgroundColor: widget.color),
            ),
          ],
        ),
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.items.map((item) {
              return Chip(
                avatar: Icon(widget.icon, size: 14, color: widget.color),
                label: Text(item, style: const TextStyle(fontSize: 11.5)),
                onDeleted: () => setState(() {
                  widget.items.remove(item);
                  widget.onChanged();
                }),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// حقل المرفقات: رفع ملف، أو إضافة رابط.
///
/// المساران معروضان معاً عمداً. رفع الملفات يحتاج تفعيل التخزين في مشروع
/// Firebase، وقد لا يكون مفعَّلاً — ولو عُرض الرفع وحده لبدت الميزة معطّلة.
/// والرابط يعمل في كل حال، فيبقى مخرجاً حاضراً لا بديلاً مخبوءاً.
class _AttachmentsField extends StatelessWidget {
  final List<Attachment> attachments;
  final bool uploading;
  final String? error;
  final VoidCallback onPickFile;
  final VoidCallback onAddLink;
  final void Function(Attachment) onRemove;

  const _AttachmentsField({
    required this.attachments,
    required this.uploading,
    required this.error,
    required this.onPickFile,
    required this.onAddLink,
    required this.onRemove,
  });

  IconData _iconFor(Attachment a) {
    switch (a.typeLabel) {
      case 'صورة':
        return Icons.image_outlined;
      case 'PDF':
        return Icons.picture_as_pdf_outlined;
      case 'إكسل':
        return Icons.table_chart_outlined;
      case 'وورد':
        return Icons.description_outlined;
      default:
        return a.kind == AttachmentKind.link ? Icons.link_rounded : Icons.attach_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مرفقات اليوم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 2),
        const Text(
          'PDF أو وورد أو إكسل أو صورة — حتى ١٠ ميغابايت للملف الواحد.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : onPickFile,
              icon: uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, size: 17),
              label: Text(uploading ? 'جارٍ الرفع…' : 'رفع ملف'),
            ),
            OutlinedButton.icon(
              onPressed: uploading ? null : onAddLink,
              icon: const Icon(Icons.link_rounded, size: 17),
              label: const Text('إضافة رابط'),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.07),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(error!,
                style: const TextStyle(fontSize: 12, height: 1.7, color: AppColors.textPrimary)),
          ),
        ],
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...attachments.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(_iconFor(a), size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          Text(
                            [a.kind.label, if (a.readableSize.isNotEmpty) a.readableSize].join(' · '),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 17),
                      tooltip: 'إزالة',
                      onPressed: () => onRemove(a),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}

/// إضافة مرفق برابط خارجي (SharePoint، Drive، أو أي نظام للوزارة).
class _LinkAttachmentDialog extends StatefulWidget {
  const _LinkAttachmentDialog();

  @override
  State<_LinkAttachmentDialog> createState() => _LinkAttachmentDialogState();
}

class _LinkAttachmentDialogState extends State<_LinkAttachmentDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم يُعرف به الملف');
      return;
    }
    // الرابط يُفحص هنا لطفاً بالمستخدم: رابطٌ بلا بروتوكول لا يفتح شيئاً،
    // ويكتشف ذلك بعد أيام حين يحتاجه أحد.
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() => _error = 'الرابط يجب أن يبدأ بـ http:// أو https://');
      return;
    }
    Navigator.of(context).pop(Attachment(name: name, url: url, kind: AttachmentKind.link));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة رابط ملف'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الملف'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'الرابط',
                hintText: 'https://…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _add, child: const Text('إضافة')),
      ],
    );
  }
}
