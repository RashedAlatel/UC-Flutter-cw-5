import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/custom_widget_spec.dart';
import '../models/dashboard_metric.dart';
import '../models/dashboard_widget_config.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import 'custom_widget_builder_dialog.dart';

/// نطاق التخصيص: لوحة المستخدم نفسه، أو لوحة دور كامل، أو اللوحة العامة.
///
/// الأخصّ يفوز عند العرض (لوحتي ← لوحة دوري ← اللوحة العامة)، فالمستخدم
/// التنفيذي ومدير الإدارة يمكن أن يكون لكل منهما تخطيط مختلف دون أن يؤثر
/// أحدهما على الآخر.
class _DashboardScope {
  /// `mine` أو `global` أو مفتاح الدور.
  final String id;
  final String label;
  final String hint;
  const _DashboardScope(this.id, this.label, this.hint);

  static const String mine = 'mine';
  static const String global = 'global';

  bool get isMine => id == mine;
  bool get isGlobal => id == global;
}

/// محرر لوحة القيادة: إضافة/حذف/إعادة ترتيب الودجات (الرسوم البيانية
/// والقوائم) المعروضة أسفل مؤشرات الأداء الرئيسية.
///
/// كل مستخدم يعدّل لوحته الخاصة. ومن يملك صلاحية "التحكم بلوحة القيادة"
/// (ومسؤول النظام دائماً) يستطيع إضافةً لذلك ضبط لوحة افتراضية لكل دور
/// وللمنصة كاملةً.
class CustomizeDashboardDialog extends StatefulWidget {
  const CustomizeDashboardDialog({super.key});

  @override
  State<CustomizeDashboardDialog> createState() => _CustomizeDashboardDialogState();
}

class _CustomizeDashboardDialogState extends State<CustomizeDashboardDialog> {
  late List<DashboardWidgetConfig> _widgets;
  late List<_DashboardScope> _scopes;
  late String _scopeId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _scopes = _buildScopes(store);
    _scopeId = _DashboardScope.mine;
    _widgets = List.of(store.dashboardWidgets);
  }

  List<_DashboardScope> _buildScopes(AppStore store) {
    final list = <_DashboardScope>[
      const _DashboardScope(_DashboardScope.mine, 'لوحتي أنا', 'تظهر لك وحدك ولا يراها أحد غيرك'),
    ];
    if (!store.canManageSharedDashboards) return list;
    for (final role in UserRole.configurable) {
      list.add(_DashboardScope(role.name, 'لوحة دور: ${role.label}', 'تظهر لكل من يحمل هذا الدور ولم يخصّص لوحته'));
    }
    for (final role in store.customRoles) {
      list.add(_DashboardScope('custom_${role.id}', 'لوحة دور: ${role.name}', 'تظهر لكل من يحمل هذا الدور ولم يخصّص لوحته'));
    }
    list.add(const _DashboardScope(_DashboardScope.global, 'اللوحة العامة', 'نقطة البداية لكل من لم يُضبط لدوره تخطيط'));
    return list;
  }

  _DashboardScope get _scope => _scopes.firstWhere((s) => s.id == _scopeId, orElse: () => _scopes.first);

  /// التخطيط المخزَّن للنطاق المختار. النطاق الفارغ يعرض الطبقة التي سيراها
  /// المستخدم فعلاً كنقطة بداية بدل لوحة خالية تُربكه.
  List<DashboardWidgetConfig> _widgetsForScope(AppStore store, String scopeId) {
    if (scopeId == _DashboardScope.mine) return List.of(store.dashboardWidgets);
    if (scopeId == _DashboardScope.global) return List.of(store.globalDashboardWidgets);
    final stored = store.roleDashboardWidgets(scopeId);
    return List.of(stored.isEmpty ? store.globalDashboardWidgets : stored);
  }

  void _switchScope(String scopeId) {
    final store = context.read<AppStore>();
    setState(() {
      _scopeId = scopeId;
      _widgets = _widgetsForScope(store, scopeId);
    });
  }

  Future<void> _persist(AppStore store, List<DashboardWidgetConfig> widgets) {
    switch (_scopeId) {
      case _DashboardScope.mine:
        return store.saveMyDashboardWidgets(widgets);
      case _DashboardScope.global:
        return store.saveDashboardWidgets(widgets);
      default:
        return store.saveRoleDashboardWidgets(_scopeId, widgets);
    }
  }

  Future<void> _resetMine() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await store.resetMyDashboardWidgets();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تمت العودة إلى اللوحة الافتراضية')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('تعذر الإلغاء: $e'), backgroundColor: AppColors.danger));
    }
  }

  void _addWidget(DashboardWidgetType type, {CustomWidgetSpec? custom, DashboardMetric? metric}) {
    setState(() => _widgets.add(DashboardWidgetConfig(
          id: const Uuid().v4(),
          type: type,
          custom: custom,
          metric: metric ?? DashboardMetric.avgProgress,
        )));
  }

  /// اختيار المقياس عند الإضافة مباشرةً.
  ///
  /// وضعُه هنا لا بعد الإضافة: النسخة الثانية من الرسم نفسه لا معنى لها إلا
  /// بمقياس مختلف، فلو أُضيفت بالمقياس الافتراضي لطواها [DashboardWidgetConfig.dedupe]
  /// بوصفها تكراراً، فيبدو للمستخدم أن «الإضافة لا تعمل».
  Future<void> _pickMetricThenAdd(DashboardWidgetType type) async {
    final metric = await showModalBottomSheet<DashboardMetric>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('على أي مقياس تُرتَّب البطاقة؟',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            ...DashboardMetric.values.map((m) => ListTile(
                  leading: Icon(Icons.straighten_rounded, color: AppColors.primary),
                  title: Text(m.label, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(m.hint,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  onTap: () => Navigator.of(ctx).pop(m),
                )),
          ],
        ),
      ),
    );
    if (metric == null || !mounted) return;
    _addWidget(type, metric: metric);
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
      await _persist(store, updated);
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
      await _persist(context.read<AppStore>(), _widgets);
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
    // والمحتوى — وهو ما كان يبدو وكأن "الحفظ لا يعمل". والمستثنى من الاستبعاد
    // اثنان: الودجت المخصص (يمكن تكراره بمواصفات مختلفة)، **والأنواع الحاملة
    // لمقياس** — فنسخةٌ لكل مقياس أمرٌ مقصود، ويُسأل عن المقياس عند الإضافة.
    final addedTypes = _widgets
        .where((w) => w.type != DashboardWidgetType.custom && !w.type.hasMetric)
        .map((w) => w.type)
        .toSet();
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
                      } else if (t.hasMetric) {
                        _pickMetricThenAdd(t);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_scopes.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _scopeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'أطبّق التخصيص على',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _scopes
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.label, style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: _busy ? null : (v) => v == null ? null : _switchScope(v),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    '${_scope.hint}. أعِد ترتيب الودجات بالسحب، احذف ما لا تحتاجه، وأضف رسوماً أو قوائم جديدة.',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.5),
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
                            subtitle: isCustom
                                ? const Text('ودجت مخصص — اضغط للتعديل',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary))
                                : w.type.hasMetric
                                    ? Text('المقياس: ${w.metric.label}',
                                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))
                                    : null,
                            onTap: isCustom ? () => _openCustomBuilder(editing: w) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // المقياس يُضبط هنا كما يُضبط من وضع الترتيب:
                                // من يضبط لوحة دور أو اللوحة العامة لا يراها
                                // أمامه، فلا سبيل له إلى المقياس إلا هنا.
                                if (w.type.hasMetric)
                                  PopupMenuButton<DashboardMetric>(
                                    tooltip: 'مقياس البطاقة',
                                    initialValue: w.metric,
                                    onSelected: (m) => setState(() => _widgets[i] = w.copyWith(metric: m)),
                                    itemBuilder: (_) => [
                                      for (final m in DashboardMetric.values)
                                        PopupMenuItem(value: m, child: Text(m.label)),
                                    ],
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      child: Icon(Icons.straighten_rounded, size: 18, color: AppColors.textSecondary),
                                    ),
                                  ),
                                // العرض يُضبط هنا كما يُضبط من وضع الترتيب على
                                // الصفحة: من ضبط لوحة دور أو اللوحة العامة لا
                                // يراها أمامه، فلا سبيل له إلى العرض إلا هنا.
                                //
                                // ويُخفى عن المؤشرات: هي تُعرض في الشريط
                                // القيادي الذي يوزّع أعمدته بنفسه، فـ«ثلث/نصف/
                                // كامل» خيارٌ بلا أثر — وعرضُه يَعِد بما لا يقع.
                                if (!w.type.isKpi)
                                PopupMenuButton<DashboardWidgetWidth>(
                                  tooltip: 'عرض البطاقة',
                                  initialValue: w.width,
                                  onSelected: (width) =>
                                      setState(() => _widgets[i] = w.copyWith(width: width)),
                                  itemBuilder: (_) => [
                                    for (final width in DashboardWidgetWidth.values)
                                      PopupMenuItem(value: width, child: Text(width.label)),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    child: Text(
                                      w.width.label,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
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
                          : Text(_scope.isMine ? 'حفظ لوحتي' : 'حفظ التخطيط'),
                    ),
                  ),
                  // يظهر فقط حين يكون للمستخدم تخصيص فعلي يمكن التراجع عنه.
                  if (_scope.isMine && context.watch<AppStore>().hasPersonalDashboard) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _busy ? null : _resetMine,
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 17),
                      label: const Text('العودة إلى اللوحة الافتراضية'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

