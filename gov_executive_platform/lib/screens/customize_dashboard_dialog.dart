import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/custom_widget_spec.dart';
import '../models/dashboard_widget_config.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

/// محرر لوحة القيادة (مسؤول النظام فقط): إضافة/حذف/إعادة ترتيب الودجات
/// (الرسوم البيانية والقوائم) المعروضة أسفل مؤشرات الأداء الرئيسية.
class CustomizeDashboardDialog extends StatefulWidget {
  const CustomizeDashboardDialog({super.key});

  @override
  State<CustomizeDashboardDialog> createState() => _CustomizeDashboardDialogState();
}

class _CustomizeDashboardDialogState extends State<CustomizeDashboardDialog> {
  late List<DashboardWidgetConfig> _widgets;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _widgets = List.of(context.read<AppStore>().dashboardWidgets);
  }

  void _addWidget(DashboardWidgetType type, {CustomWidgetSpec? custom}) {
    setState(() => _widgets.add(DashboardWidgetConfig(id: const Uuid().v4(), type: type, custom: custom)));
  }

  Future<void> _openCustomBuilder({DashboardWidgetConfig? editing}) async {
    final store = context.read<AppStore>();
    final spec = await showDialog<CustomWidgetSpec>(
      context: context,
      builder: (_) => _CustomWidgetBuilderDialog(initial: editing?.custom),
    );
    if (spec == null) return;
    setState(() {
      if (editing != null) {
        final i = _widgets.indexWhere((w) => w.id == editing.id);
        if (i != -1) _widgets[i] = DashboardWidgetConfig(id: editing.id, type: DashboardWidgetType.custom, custom: spec);
      } else {
        _widgets.add(DashboardWidgetConfig(id: const Uuid().v4(), type: DashboardWidgetType.custom, custom: spec));
      }
    });
    // نحفظ الودجت المخصص فور إنشائه مباشرةً (بدل الاكتفاء بإضافته للقائمة
    // المحلية بانتظار "حفظ التخطيط" لاحقاً) لأن نموذج البناء نفسه يحمل زر
    // "حفظ الودجت" الذي يبدو للمستخدم إجراءً نهائياً — تركه معلّقاً بلا حفظ
    // فعلي كان يبدو وكأن الودجت "لا يظهر" رغم إنشائه بنجاح.
    try {
      await store.saveDashboardWidgets(_widgets);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الودجت المخصص وحفظه في اللوحة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الودجت: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().saveDashboardWidgets(_widgets);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تخطيط لوحة القيادة')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ التخطيط: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showAddWidgetSheet() {
    // نستبعد الأنواع المضافة أصلاً حتى لا يظن المستخدم أنه أضاف عنصراً
    // جديداً بينما هو في الواقع نسخة مطابقة لعنصر موجود مسبقاً بنفس الاسم
    // والمحتوى — وهو ما كان يبدو وكأن "الحفظ لا يعمل". الودجت المخصص مستثنى
    // من هذا الاستبعاد لأنه يمكن إضافة أكثر من ودجت مخصص بمواصفات مختلفة.
    final addedTypes = _widgets.where((w) => w.type != DashboardWidgetType.custom).map((w) => w.type).toSet();
    final available = DashboardWidgetType.values.where((t) => !addedTypes.contains(t)).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر نوع الودجت', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Text(
                  'كل الودجات المتاحة مضافة بالفعل إلى اللوحة.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              )
            else
              ...available.map((t) => ListTile(
                    leading: Icon(t.icon, color: AppColors.primary),
                    title: Text(t.label, style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      Navigator.of(context).pop(); // إغلاق قائمة الاختيار
                      if (t == DashboardWidgetType.custom) {
                        _openCustomBuilder();
                      } else {
                        _addWidget(t);
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('تخصيص لوحة القيادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'أعِد ترتيب الودجات بالسحب، احذف ما لا تحتاجه، وأضف رسوماً أو قوائم جديدة.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _widgets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('لا توجد ودجات — أضف واحدة من الزر أدناه', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ReorderableListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      itemCount: _widgets.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _widgets.removeAt(oldIndex);
                          _widgets.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, i) {
                        final w = _widgets[i];
                        final isCustom = w.type == DashboardWidgetType.custom;
                        return Card(
                          key: ValueKey(w.id),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(w.type.icon, color: AppColors.primary, size: 20),
                            title: Text(isCustom ? (w.custom?.title ?? w.type.label) : w.type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: isCustom ? const Text('ودجت مخصص — اضغط للتعديل', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)) : null,
                            onTap: isCustom ? () => _openCustomBuilder(editing: w) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                                  onPressed: () => setState(() => _widgets.removeAt(i)),
                                ),
                                const Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showAddWidgetSheet,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('إضافة ودجت'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ التخطيط'),
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

/// منشئ الودجت الحرّ: يختار المستخدم مصدر البيانات، تصفية اختيارية، تجميعاً
/// اختيارياً، ونوع العرض — دون الحاجة لأي كود، وتُبنى النتيجة حيّة من بيانات
/// المنصة الفعلية (مشاريع/مهام/مخاطر/عوائق) بدل قائمة ودجات جاهزة فقط.
class _CustomWidgetBuilderDialog extends StatefulWidget {
  final CustomWidgetSpec? initial;
  const _CustomWidgetBuilderDialog({this.initial});

  @override
  State<_CustomWidgetBuilderDialog> createState() => _CustomWidgetBuilderDialogState();
}

class _CustomWidgetBuilderDialogState extends State<_CustomWidgetBuilderDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _filterTextCtrl;
  late CustomWidgetSource _source;
  late CustomWidgetDisplay _display;
  String? _groupBy;
  String? _filterField;
  String? _filterValue;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleCtrl = TextEditingController(text: initial?.title ?? '');
    _source = initial?.source ?? CustomWidgetSource.projects;
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
                decoration: const InputDecoration(labelText: 'مصدر البيانات'),
                items: CustomWidgetSource.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: _onSourceChanged,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<CustomWidgetDisplay>(
                initialValue: _display,
                decoration: const InputDecoration(labelText: 'نوع العرض'),
                items: CustomWidgetDisplay.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
                onChanged: (d) => setState(() => _display = d ?? _display),
              ),
              if (_display != CustomWidgetDisplay.stat) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _groupBy,
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
