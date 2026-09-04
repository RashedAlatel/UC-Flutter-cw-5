import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/custom_widget_spec.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

/// منشئ الودجت الحرّ: يختار المستخدم مصدر البيانات، تصفية اختيارية، تجميعاً
/// اختيارياً، ونوع العرض — دون الحاجة لأي كود، وتُبنى النتيجة حيّة من بيانات
/// المنصة الفعلية (مشاريع/مهام/مخاطر/عوائق) بدل قائمة ودجات جاهزة فقط.
/// يُستخدم من لوحة القيادة المركزية وصفحة المشاريع وصفحة المشروع، وحين
/// [scopeToProject] معطى تُفلتَر البيانات تلقائياً على ذلك المشروع فقط
/// (فلا تظهر خيارات "المشاريع" أو "الإدارة" غير المنطقية ضمن مشروع واحد).
class CustomWidgetBuilderDialog extends StatefulWidget {
  final CustomWidgetSpec? initial;
  final bool scopeToProject;
  const CustomWidgetBuilderDialog({super.key, this.initial, this.scopeToProject = false});

  @override
  State<CustomWidgetBuilderDialog> createState() => _CustomWidgetBuilderDialogState();
}

class _CustomWidgetBuilderDialogState extends State<CustomWidgetBuilderDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _filterTextCtrl;
  late List<CustomWidgetSource> _sources;
  late CustomWidgetSource _source;
  late CustomWidgetDisplay _display;
  String? _groupBy;
  String? _filterField;
  String? _filterValue;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sources = widget.scopeToProject
        ? const [CustomWidgetSource.tasks, CustomWidgetSource.risks, CustomWidgetSource.blockers]
        : CustomWidgetSource.values;
    final initial = widget.initial;
    _titleCtrl = TextEditingController(text: initial?.title ?? '');
    _source = initial?.source ?? _sources.first;
    _display = initial?.display ?? CustomWidgetDisplay.bar;
    _groupBy = initial?.groupBy ?? _source.fields.keys.first;
    _filterField = initial?.filterField;
    _filterValue = initial?.filterValue;
    _filterTextCtrl = TextEditingController(text: _filterField != null && _source.isFreeTextField(_filterField!) ? (_filterValue ?? '') : '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _filterTextCtrl.dispose();
    super.dispose();
  }

  void _onSourceChanged(CustomWidgetSource? s) {
    if (s == null) return;
    setState(() {
      _source = s;
      _groupBy = s.fields.keys.first;
      _filterField = null;
      _filterValue = null;
      _filterTextCtrl.clear();
    });
  }

  List<MapEntry<String, String>> _enumOptions(String field) {
    if (field == 'status') {
      switch (_source) {
        case CustomWidgetSource.tasks:
        case CustomWidgetSource.works:
          return TaskStatus.values.map((e) => MapEntry(e.name, e.label)).toList();
        case CustomWidgetSource.projects:
          return ProjectStatus.values.map((e) => MapEntry(e.name, e.label)).toList();
        case CustomWidgetSource.risks:
        case CustomWidgetSource.blockers:
          return ItemStatus.values.map((e) => MapEntry(e.name, e.label)).toList();
      }
    }
    if (field == 'priority') return PriorityLevel.values.map((e) => MapEntry(e.name, e.label)).toList();
    if (field == 'level') return RiskLevel.values.map((e) => MapEntry(e.name, e.label)).toList();
    if (field == 'department') {
      final departments = context.read<AppStore>().departments;
      return departments.map((d) => MapEntry(d.id, d.name)).toList();
    }
    return const [];
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء إدخال عنوان للودجت');
      return;
    }
    final filterValue = _filterField == null
        ? null
        : (_source.isFreeTextField(_filterField!) ? _filterTextCtrl.text.trim() : _filterValue);
    Navigator.of(context).pop(CustomWidgetSpec(
      title: _titleCtrl.text.trim(),
      source: _source,
      groupBy: _display == CustomWidgetDisplay.stat ? null : _groupBy,
      display: _display,
      filterField: (filterValue == null || filterValue.isEmpty) ? null : _filterField,
      filterValue: (filterValue == null || filterValue.isEmpty) ? null : filterValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fields = _source.fields;
    return AlertDialog(
      title: const Text('إنشاء ودجت مخصص'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'عنوان الودجت')),
              const SizedBox(height: 14),
              DropdownButtonFormField<CustomWidgetSource>(
                initialValue: _source,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'مصدر البيانات'),
                items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: _onSourceChanged,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<CustomWidgetDisplay>(
                initialValue: _display,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع العرض'),
                items: CustomWidgetDisplay.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
                onChanged: (d) => setState(() => _display = d ?? _display),
              ),
              if (_display != CustomWidgetDisplay.stat) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _groupBy,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'التجميع حسب'),
                  items: fields.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => _groupBy = v),
                ),
              ],
              const SizedBox(height: 18),
              const Align(alignment: AlignmentDirectional.centerStart, child: Text('تصفية اختيارية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _filterField,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'تصفية حسب حقل'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون تصفية')),
                  ...fields.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (v) => setState(() {
                  _filterField = v;
                  _filterValue = null;
                  _filterTextCtrl.clear();
                }),
              ),
              if (_filterField != null) ...[
                const SizedBox(height: 14),
                if (_source.isFreeTextField(_filterField!))
                  TextField(controller: _filterTextCtrl, decoration: InputDecoration(labelText: 'قيمة "${fields[_filterField]}" المطابقة'))
                else
                  DropdownButtonFormField<String>(
                    initialValue: _filterValue,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'قيمة "${fields[_filterField]}"'),
                    items: _enumOptions(_filterField!).map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _filterValue = v),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ الودجت')),
      ],
    );
  }
}
