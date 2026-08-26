import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// نموذج "طلب تعديل الموعد النهائي" — لا يُعدَّل الموعد مباشرة (ممنوع حتى على مستوى
/// قواعد أمان قاعدة البيانات)، بل يُرسل طلباً لمسؤول النظام للاعتماد.
class RequestDeadlineChangeDialog extends StatefulWidget {
  final Project project;
  const RequestDeadlineChangeDialog({super.key, required this.project});

  @override
  State<RequestDeadlineChangeDialog> createState() => _RequestDeadlineChangeDialogState();
}

class _RequestDeadlineChangeDialogState extends State<RequestDeadlineChangeDialog> {
  final _reasonCtrl = TextEditingController();
  late DateTime _newDueDate = widget.project.dueDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _newDueDate = picked);
  }

  Future<void> _submit() async {
    if (_newDueDate.difference(widget.project.dueDate).inDays == 0) {
      setState(() => _error = 'الرجاء اختيار موعد نهائي مختلف عن الحالي');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء توضيح سبب التعديل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // نافذةٌ بلا `try` تجمد على دوّارة عند أي فشل، وقد كُتب الطلب قبله —
    // فيعيدها صاحبها فيصير طلبين. راجع `request_project_dialog`.
    try {
      final blocked = await context.read<AppStore>().submitDeadlineChangeRequest(
            project: widget.project,
            newDueDate: _newDueDate,
            reason: _reasonCtrl.text.trim(),
          );
      if (blocked != null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = blocked;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر إرسال الطلب: $e';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال طلب تعديل الموعد النهائي لمسؤول النظام للاعتماد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('طلب تعديل الموعد النهائي'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموعد الحالي: ${widget.project.dueDate.year}/${widget.project.dueDate.month}/${widget.project.dueDate.day}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text('الموعد الجديد: ${_newDueDate.year}/${_newDueDate.month}/${_newDueDate.day}'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _reasonCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'سبب التعديل')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إرسال الطلب'),
        ),
      ],
    );
  }
}
