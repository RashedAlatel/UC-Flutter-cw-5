import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/blocker.dart';
import '../models/custom_widget_spec.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/risk.dart';
import '../theme/app_theme.dart';
import 'charts.dart';

/// محرك بيانات الودجت المخصص: يجلب مصدر البيانات، يطبّق التصفية الاختيارية،
/// ثم يجمّع النتائج حسب الحقل المختار (أو يحسب إجمالياً واحداً لعرض "stat").
class CustomWidgetEngine {
  static List<dynamic> _baseList(AppStore store, CustomWidgetSource source) {
    switch (source) {
      case CustomWidgetSource.projects:
        return store.visibleProjects;
      case CustomWidgetSource.tasks:
        return store.tasks;
      case CustomWidgetSource.risks:
        return store.risks;
      case CustomWidgetSource.blockers:
        return store.blockers;
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
            return p.executorName.trim().toLowerCase();
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
            return p.executorName.isEmpty ? 'غير محدد' : p.executorName;
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
    }
    return '—';
  }

  static List<dynamic> filtered(AppStore store, CustomWidgetSpec spec) {
    final base = _baseList(store, spec.source);
    final field = spec.filterField;
    final value = spec.filterValue;
    if (field == null || value == null || value.isEmpty) return base;
    return base.where((item) => _rawValue(store, spec.source, item, field) == value.trim().toLowerCase()).toList();
  }

  /// تعداد العناصر مجمّعة حسب [CustomWidgetSpec.groupBy]، أو إجمالي واحد
  /// ("الإجمالي") إن لم يُحدَّد تجميع (يُستخدم لعرض "stat").
  static Map<String, int> compute(AppStore store, CustomWidgetSpec spec) {
    final base = filtered(store, spec);
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
  const CustomWidgetCard({super.key, required this.store, required this.spec});

  @override
  Widget build(BuildContext context) {
    final counts = CustomWidgetEngine.compute(store, spec);
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
