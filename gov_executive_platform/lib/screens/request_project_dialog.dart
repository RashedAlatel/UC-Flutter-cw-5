import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

/// نموذج "طلب إضافة مشروع جديد" — لا يُنشئ المشروع مباشرة، بل يرسل طلباً
/// إلى مركز القرارات التنفيذية بانتظار اعتماد مسؤول النظام.
class RequestProjectDialog extends StatefulWidget {
  final String departmentId;
  const RequestProjectDialog({super.key, required this.departmentId});

  @override
  State<RequestProjectDialog> createState() => _RequestProjectDialogState();
}

class _RequestProjectDialogState extends State<RequestProjectDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  PriorityLevel _priority = PriorityLevel.medium;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 60));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء تعبئة اسم المشروع ووصفه');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await context.read<AppStore>().submitProjectRequest(
          departmentId: widget.departmentId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          startDate: _startDate,
          dueDate: _dueDate,
          priority: _priority,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال طلب إضافة المشروع لمسؤول النظام للاعتماد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('طلب إضافة مشروع جديد'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المشروع')),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف المشروع')),
              const SizedBox(height: 12),
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text('البدء: ${_startDate.year}/${_startDate.month}/${_startDate.day}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_available_outlined, size: 16),
                      label: Text('الاستحقاق: ${_dueDate.year}/${_dueDate.month}/${_dueDate.day}'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
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
