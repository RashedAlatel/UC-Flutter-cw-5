import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/executors_field.dart';

/// نموذج إضافة مشروع: لمسؤول النظام يُنشئ المشروع مباشرة (موافقته الذاتية
/// كافية)، ولأي دور آخر يُرسل "طلب إضافة مشروع" ينتظر اعتماد مسؤول النظام
/// من مركز القرارات التنفيذية. إن لم تُحدَّد [departmentId] (الاستدعاء من
/// شاشة "المشاريع" الموحّدة بدل شاشة إدارة بعينها) يظهر حقل اختيار إدارة
/// اختياري يشمل خيار "بدون إدارة" — لا يتوفر هذا المسار إلا لمسؤول النظام.
class RequestProjectDialog extends StatefulWidget {
  final String? departmentId;
  const RequestProjectDialog({super.key, this.departmentId});

  @override
  State<RequestProjectDialog> createState() => _RequestProjectDialogState();
}

class _RequestProjectDialogState extends State<RequestProjectDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<String> _executorNames = [];
  PriorityLevel _priority = PriorityLevel.medium;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 60));
  String? _managerUid;
  late String? _selectedDepartmentId = widget.departmentId;
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
    final store = context.read<AppStore>();
    final isAdmin = store.isAdmin;
    final departmentId = _selectedDepartmentId ?? '';
    if (isAdmin) {
      await store.createProjectDirect(
        departmentId: departmentId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
        executorNames: _executorNames,
        managerUid: _managerUid,
      );
    } else {
      await store.submitProjectRequest(
        departmentId: departmentId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
        executorNames: _executorNames,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAdmin ? 'تمت إضافة المشروع بنجاح' : 'تم إرسال طلب إضافة المشروع لمسؤول النظام للاعتماد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isAdmin = store.isAdmin;
    final officers = store.users.where((u) => u.role == UserRole.projectOfficer).toList();
    return AlertDialog(
      title: Text(isAdmin ? 'إضافة مشروع جديد' : 'طلب إضافة مشروع جديد'),
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
              ExecutorsField(initial: _executorNames, onChanged: (v) => _executorNames = v),
              const SizedBox(height: 12),
              if (widget.departmentId == null) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedDepartmentId,
                  decoration: const InputDecoration(labelText: 'الإدارة (اختياري)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون إدارة')),
                    ...store.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedDepartmentId = v),
                ),
                const SizedBox(height: 12),
              ],
              if (isAdmin) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _managerUid,
                  decoration: const InputDecoration(labelText: 'مدير المشروع (اختياري، يمكن تعيينه لاحقاً)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون تعيين الآن')),
                    ...officers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                  ],
                  onChanged: (v) => setState(() => _managerUid = v),
                ),
                const SizedBox(height: 12),
              ],
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
              : Text(isAdmin ? 'إضافة المشروع' : 'إرسال الطلب'),
        ),
      ],
    );
  }
}
