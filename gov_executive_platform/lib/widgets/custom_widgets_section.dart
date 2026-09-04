import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/custom_widget_spec.dart';
import '../models/dashboard_widget_config.dart';
import '../models/enums.dart';
import '../screens/custom_widget_builder_dialog.dart';
import '../theme/app_theme.dart';
import 'custom_widget_view.dart';

/// قسم "ودجات مخصصة" قابل لإعادة الاستخدام في أي شاشة: يعرض الودجات
/// المخصصة الحالية، ويتيح لمن يملك [canManage] إضافة/حذف ودجت عبر منشئ
/// الودجت الحرّ. [scopeProjectId] يقصر بيانات كل ودجت على مشروع واحد
/// (صفحة المشروع) بدل نطاق المنصة الكامل (لوحة القيادة وصفحة المشاريع).
class CustomWidgetsSection extends StatelessWidget {
  final AppStore store;
  final List<DashboardWidgetConfig> widgets;
  final Future<void> Function(List<DashboardWidgetConfig>) onSave;
  final bool canManage;
  final String? scopeProjectId;
  final String title;

  const CustomWidgetsSection({
    super.key,
    required this.store,
    required this.widgets,
    required this.onSave,
    required this.canManage,
    this.scopeProjectId,
    this.title = 'ودجات مخصصة',
  });

  Future<void> _add(BuildContext context) async {
    final spec = await showDialog<CustomWidgetSpec>(
      context: context,
      builder: (_) => CustomWidgetBuilderDialog(scopeToProject: scopeProjectId != null),
    );
    if (spec == null) return;
    final updated = List<DashboardWidgetConfig>.of(widgets)
      ..add(DashboardWidgetConfig(id: const Uuid().v4(), type: DashboardWidgetType.custom, custom: spec));
    await onSave(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الودجت المخصص')));
    }
  }

  Future<void> _delete(BuildContext context, DashboardWidgetConfig w) async {
    final updated = widgets.where((x) => x.id != w.id).toList();
    await onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (widgets.isEmpty && !canManage) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `Wrap` لا `Row` مع `Spacer`: على شاشة الهاتف لا يتّسع السطر
        // للعنوان والزر معاً، فينزل الزر سطراً بدل أن يخرج من الصفحة.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (canManage)
              OutlinedButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة ودجت مخصص'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('لا توجد ودجات مخصصة بعد', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...widgets.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: w.custom == null
                    ? const SizedBox.shrink()
                    : CustomWidgetCard(
                        store: store,
                        spec: w.custom!,
                        scopeProjectId: scopeProjectId,
                        onDelete: canManage ? () => _delete(context, w) : null,
                      ),
              )),
      ],
    );
  }
}
