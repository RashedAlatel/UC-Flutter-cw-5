import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

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
  late double _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.project.progressPercent;
  }

  @override
  void dispose() {
    _achievementsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_achievementsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال ملخص الإنجازات')));
      return;
    }
    context.read<AppStore>().addDailyUpdate(
          project: widget.project,
          achievements: _achievementsCtrl.text.trim(),
          completedTasks: _completedTasks,
          newRisks: _newRisks,
          blockersText: _blockers,
          decisionsRequired: _decisions,
          progressPercent: _progress,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التحديث اليومي بنجاح')));
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
              decoration: const BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                    const Text('الإنجازات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                      onPressed: _submit,
                      child: const Text('حفظ التحديث'),
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
