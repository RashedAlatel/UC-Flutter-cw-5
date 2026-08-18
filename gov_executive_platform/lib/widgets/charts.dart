import 'package:flutter/material.dart';

import '../models/department.dart';
import '../theme/app_theme.dart';

/// قائمة أعمدة أفقية مسطّحة (بلا ظل، بطراز أدوات BI) لترتيب الإدارات حسب
/// الأداء. كل صف قابل للضغط لعرض مشاريع تلك الإدارة المتأخرة.
class DepartmentBarChart extends StatelessWidget {
  final List<MapEntry<Department, double>> ranking;
  final ValueChanged<Department>? onDepartmentTap;
  const DepartmentBarChart({super.key, required this.ranking, this.onDepartmentTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: ranking.length,
      separatorBuilder: (context, i) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final entry = ranking[i];
        final dept = entry.key;
        final value = entry.value.clamp(0, 100);
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onDepartmentTap == null ? null : () => onDepartmentTap!(dept),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  dept.name,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    Container(height: 18, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: value / 100,
                      child: Container(height: 18, decoration: BoxDecoration(color: dept.color, borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text('${value.toStringAsFixed(0)}٪', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// شريط أفقي واحد بنسبة ١٠٠٪ (Stacked Bar) لتوزيع حالة المشاريع، مع صف
/// وسائل إيضاح أعلاه يحمل النسبة المئوية لكل حالة. اضغط أي شريحة/تسمية
/// لعرض مشاريع تلك الحالة.
class StatusStackedBar extends StatelessWidget {
  final Map<String, int> data; // label -> count
  final Map<String, Color> colors;
  final ValueChanged<String>? onSectionTap;
  const StatusStackedBar({super.key, required this.data, required this.colors, this.onSectionTap});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);
    if (total == 0) {
      return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: entries.map((e) {
            final pct = e.value / total * 100;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onSectionTap == null ? null : () => onSectionTap!(e.key),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${e.key} · ${pct.toStringAsFixed(0)}٪',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 28,
            child: Row(
              children: entries
                  .map((e) => Expanded(
                        flex: e.value,
                        child: InkWell(
                          onTap: onSectionTap == null ? null : () => onSectionTap!(e.key),
                          child: Container(color: colors[e.key]),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('$total مشروعاً بالإجمالي', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ],
    );
  }
}
