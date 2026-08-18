import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/department.dart';
import '../theme/app_theme.dart';

class DepartmentBarChart extends StatefulWidget {
  final List<MapEntry<Department, double>> ranking;
  final ValueChanged<Department>? onDepartmentTap;
  const DepartmentBarChart({super.key, required this.ranking, this.onDepartmentTap});

  @override
  State<DepartmentBarChart> createState() => _DepartmentBarChartState();
}

class _DepartmentBarChartState extends State<DepartmentBarChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final data = widget.ranking;
    return BarChart(
      BarChartData(
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${data[group.x].key.name}\n${rod.toY.toStringAsFixed(0)}٪',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          touchCallback: (event, response) {
            final groupIndex = response?.spot?.touchedBarGroupIndex;
            setState(() => _touched = groupIndex);
            if (event is FlTapUpEvent && groupIndex != null && groupIndex >= 0 && groupIndex < data.length) {
              widget.onDepartmentTap?.call(data[groupIndex].key);
            }
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (v, meta) =>
                  Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final short = data[i].key.name.replaceFirst('إدارة ', '');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final isTouched = i == _touched;
          final value = data[i].value;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: value,
              width: isTouched ? 26 : 20,
              color: data[i].key.color,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: AppColors.background),
            ),
          ]);
        }),
      ),
    );
  }
}

class StatusPieChart extends StatefulWidget {
  final Map<String, int> data; // label -> count
  final Map<String, Color> colors;
  final ValueChanged<String>? onSectionTap; // يُستدعى بلَبَل الحالة المضغوطة
  const StatusPieChart({super.key, required this.data, required this.colors, this.onSectionTap});

  @override
  State<StatusPieChart> createState() => _StatusPieChartState();
}

class _StatusPieChartState extends State<StatusPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);
    if (total == 0) {
      return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final sectionIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                  setState(() => _touched = sectionIndex);
                  if (event is FlTapUpEvent && sectionIndex >= 0 && sectionIndex < entries.length) {
                    widget.onSectionTap?.call(entries[sectionIndex].key);
                  }
                },
              ),
              sections: List.generate(entries.length, (i) {
                final e = entries[i];
                final isTouched = i == _touched;
                final radius = isTouched ? 62.0 : 54.0;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: widget.colors[e.key] ?? AppColors.textSecondary,
                  radius: radius,
                  title: '${e.value}',
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.colors[e.key], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
