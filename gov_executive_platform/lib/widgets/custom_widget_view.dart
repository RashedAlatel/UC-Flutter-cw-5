import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/blocker.dart';
import '../models/custom_widget_spec.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/risk.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import 'charts.dart';

/// محرك بيانات الودجت المخصص: يجلب مصدر البيانات، يطبّق التصفية الاختيارية،
/// ثم يجمّع النتائج حسب الحقل المختار (أو يحسب إجمالياً واحداً لعرض "stat").
class CustomWidgetEngine {
  /// [scopeProjectId] يقصر البيانات على مشروع واحد فقط (ودجات صفحة المشروع)
  /// بدل النطاق الكامل للمنصة (ودجات لوحة القيادة وصفحة المشاريع).
  static List<dynamic> _baseList(AppStore store, CustomWidgetSource source, String? scopeProjectId) {
    switch (source) {
      case CustomWidgetSource.projects:
        final all = store.visibleProjects;
        return scopeProjectId == null ? all : all.where((p) => p.id == scopeProjectId).toList();
      case CustomWidgetSource.tasks:
        return scopeProjectId == null ? store.tasks : store.tasks.where((t) => t.projectId == scopeProjectId).toList();
      case CustomWidgetSource.risks:
        return scopeProjectId == null ? store.risks : store.risks.where((r) => r.projectId == scopeProjectId).toList();
      case CustomWidgetSource.blockers:
        return scopeProjectId == null ? store.blockers : store.blockers.where((b) => b.projectId == scopeProjectId).toList();
      case CustomWidgetSource.works:
        // الأعمال مستقلة عن المشاريع، فلا معنى لتقييدها بمشروع: ودجت أعمال
        // داخل صفحة مشروع يبقى فارغاً بدل عرض أعمال لا علاقة لها به.
        return scopeProjectId == null ? store.visibleWorks : const [];
    }
  }

  /// القيمة الخام لحقل معيّن من عنصر بيانات — تُستخدم للمقارنة عند التصفية.
  static String _rawValue(AppStore store, CustomWidgetSource source, dynamic item, String field) {
    switch (source) {
      case CustomWidgetSource.projects:
        final p = item as Project;
        switch (field) {
          case 'status':
            return p.status.name;
          case 'priority':
            return p.priority.name;
          case 'department':
            return p.departmentId;
          case 'executor':
            return p.executorLabel.trim().toLowerCase();
        }
      case CustomWidgetSource.tasks:
        final t = item as ProjectTask;
        switch (field) {
          case 'status':
            return t.status.name;
          case 'priority':
            return t.priority.name;
          case 'assignee':
            return t.assigneeName.trim().toLowerCase();
        }
      case CustomWidgetSource.risks:
        final r = item as ProjectRisk;
        switch (field) {
          case 'level':
            return r.level.name;
          case 'status':
            return r.status.name;
        }
      case CustomWidgetSource.blockers:
        final b = item as ProjectBlocker;
        if (field == 'status') return b.status.name;
      case CustomWidgetSource.works:
        final w = item as WorkItem;
        switch (field) {
          case 'status':
            return w.status.name;
          case 'priority':
            return w.priority.name;
          case 'department':
            return w.departmentId;
          case 'assignee':
            return w.assigneeName.trim().toLowerCase();
        }
    }
    return '';
  }

  /// التسمية المعروضة (عربية) لحقل معيّن من عنصر بيانات — تُستخدم كمفتاح
  /// تجميع في الرسوم/الجداول.
  static String groupLabel(AppStore store, CustomWidgetSource source, dynamic item, String field) {
    switch (source) {
      case CustomWidgetSource.projects:
        final p = item as Project;
        switch (field) {
          case 'status':
            return p.status.label;
          case 'priority':
            return p.priority.label;
          case 'department':
            return store.departmentById(p.departmentId)?.name ?? 'غير محدد';
          case 'executor':
            return p.executorLabel.isEmpty ? 'غير محدد' : p.executorLabel;
        }
      case CustomWidgetSource.tasks:
        final t = item as ProjectTask;
        switch (field) {
          case 'status':
            return t.status.label;
          case 'priority':
            return t.priority.label;
          case 'assignee':
            return t.assigneeName.isEmpty ? 'غير محدد' : t.assigneeName;
        }
      case CustomWidgetSource.risks:
        final r = item as ProjectRisk;
        switch (field) {
          case 'level':
            return r.level.label;
          case 'status':
            return r.status.label;
        }
      case CustomWidgetSource.blockers:
        final b = item as ProjectBlocker;
        if (field == 'status') return b.status.label;
      case CustomWidgetSource.works:
        final w = item as WorkItem;
        switch (field) {
          case 'status':
            return w.status.label;
          case 'priority':
            return w.priority.label;
          case 'department':
            return store.departmentById(w.departmentId)?.name ?? 'غير محدد';
          case 'assignee':
            return w.assigneeName.isEmpty ? 'غير محدد' : w.assigneeName;
        }
    }
    return '—';
  }

  static List<dynamic> filtered(AppStore store, CustomWidgetSpec spec, {String? scopeProjectId}) {
    final base = _baseList(store, spec.source, scopeProjectId);
    final field = spec.filterField;
    final value = spec.filterValue;
    if (field == null || value == null || value.isEmpty) return base;
    return base.where((item) => _rawValue(store, spec.source, item, field) == value.trim().toLowerCase()).toList();
  }

  /// تعداد العناصر مجمّعة حسب [CustomWidgetSpec.groupBy]، أو إجمالي واحد
  /// ("الإجمالي") إن لم يُحدَّد تجميع (يُستخدم لعرض "stat").
  static Map<String, int> compute(AppStore store, CustomWidgetSpec spec, {String? scopeProjectId}) {
    final base = filtered(store, spec, scopeProjectId: scopeProjectId);
    if (spec.groupBy == null) return {'الإجمالي': base.length};
    final counts = <String, int>{};
    for (final item in base) {
      final label = groupLabel(store, spec.source, item, spec.groupBy!);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }
}

List<Color> get _palette => [
      AppColors.primary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
    ];

/// عرض الودجت المخصص بحسب نوع العرض المُختار عند إنشائه.
class CustomWidgetCard extends StatelessWidget {
  final AppStore store;
  final CustomWidgetSpec spec;
  final String? scopeProjectId;
  final VoidCallback? onDelete;
  const CustomWidgetCard({super.key, required this.store, required this.spec, this.scopeProjectId, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final counts = CustomWidgetEngine.compute(store, spec, scopeProjectId: scopeProjectId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_mosaic_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary))),
              if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                ),
            ]),
            const SizedBox(height: 14),
            SizedBox(height: spec.display == CustomWidgetDisplay.stat ? 70 : 220, child: _body(counts)),
          ],
        ),
      ),
    );
  }

  Widget _body(Map<String, int> counts) {
    if (counts.values.fold<int>(0, (a, b) => a + b) == 0) {
      return const Center(child: Text('لا توجد بيانات مطابقة', style: TextStyle(color: AppColors.textSecondary)));
    }
    switch (spec.display) {
      case CustomWidgetDisplay.stat:
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        return Center(
          child: Text('$total', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary)),
        );
      case CustomWidgetDisplay.donut:
        final colors = {for (var i = 0; i < counts.length; i++) counts.keys.elementAt(i): _palette[i % _palette.length]};
        return StatusDonutChart(data: counts, colors: colors);
      case CustomWidgetDisplay.bar:
        final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final maxVal = entries.first.value;
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final e = entries[i];
            final color = _palette[i % _palette.length];
            return Row(children: [
              SizedBox(width: 100, child: Text(e.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(alignment: AlignmentDirectional.centerStart, children: [
                  Container(height: 16, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: maxVal == 0 ? 0 : e.value / maxVal,
                    child: Container(height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            ]);
          },
        );
      case CustomWidgetDisplay.table:
        final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (context, i) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = entries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12.5))),
                Text('${e.value}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            );
          },
        );
    }
  }
}
