import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/custom_widget_spec.dart';
import '../models/dashboard_widget_config.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import 'custom_widget_builder_dialog.dart';

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
      builder: (_) => CustomWidgetBuilderDialog(initial: editing?.custom),
    );
    if (spec == null || !mounted) return;

    final updated = List<DashboardWidgetConfig>.of(_widgets);
    if (editing != null) {
      final i = updated.indexWhere((w) => w.id == editing.id);
      if (i != -1) updated[i] = DashboardWidgetConfig(id: editing.id, type: DashboardWidgetType.custom, custom: spec);
    } else {
      // يُدرَج في رأس القائمة لا في ذيلها: الإضافة في الذيل كانت تضع الودجت
      // الجديد أسفل بقية اللوحة، فلا يراه المستخدم إلا بعد تمرير طويل ويظن
      // أن الإضافة لم تنجح. الرأس يجعله أول ما يظهر فور إغلاق النافذة.
      updated.insert(0, DashboardWidgetConfig(id: const Uuid().v4(), type: DashboardWidgetType.custom, custom: spec));
    }

    // نحفظ الودجت المخصص فور إنشائه مباشرةً (بدل الاكتفاء بإضافته للقائمة
    // المحلية بانتظار "حفظ التخطيط" لاحقاً) لأن نموذج البناء نفسه يحمل زر
    // "حفظ الودجت" الذي يبدو للمستخدم إجراءً نهائياً. كما نغلق نافذة "تخصيص
    // اللوحة" بالكامل بعد نجاح الحفظ — رسالة التأكيد (أو الخطأ) كانت تظهر
    // خلف النافذة المفتوحة ولا يراها المستخدم إطلاقاً، فيبدو الأمر وكأن شيئاً
    // لم يحدث حتى لو نجح الحفظ فعلياً.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.saveDashboardWidgets(updated);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تمت إضافة الودجت المخصص وحفظه في اللوحة')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _widgets = updated);
      messenger.showSnackBar(SnackBar(content: Text('تعذر حفظ الودجت: $e'), backgroundColor: AppColors.danger));
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

