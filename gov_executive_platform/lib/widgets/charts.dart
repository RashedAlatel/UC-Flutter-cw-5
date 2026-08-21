import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dashboard_metric.dart';
import '../models/department.dart';
import '../theme/app_theme.dart';

/// صفٌّ واحد في [RankedBarChart].
typedef RankedBar = ({String label, Color color, double value});

/// قائمة أعمدة أفقية مسطّحة (بلا ظل، بطراز أدوات BI) لترتيب أي شيء حسب أي
/// مقياس — إدارات أو أشخاص.
///
/// وهي تفهم **وحدة** المقياس، ولا تفترض أنه نسبة:
///
/// - `percent`: السقف ١٠٠ دائماً، فالعمود يُقرأ مستقلاً وتُطبع `٪`.
/// - `count`: لا سقف للعدد، فيُقاس كل عمود على **أكبر قيمة في الرسم نفسه**،
///   وتُطبع القيمة بلا وحدة. ولولا ذلك لظهرت إدارةٌ لها ١٢ مشروعاً بعمود
///   ممتلئ مكتوب عليه «١٢٪» — رقمٌ لا معنى له.
class RankedBarChart extends StatelessWidget {
  final List<RankedBar> bars;
  final DashboardMetricUnit unit;
  final ValueChanged<int>? onTap;

  const RankedBarChart({
    super.key,
    required this.bars,
    required this.unit,
    this.onTap,
  });

  /// السقف الذي تُقاس عليه الأعمدة. صفرٌ مستحيل هنا: القسمة عليه تعطي NaN
  /// فيرمي `FractionallySizedBox` استثناءً، ورسمٌ كله أصفار يجب أن يظهر
  /// بأعمدة فارغة لا أن ينهار.
  double get _ceiling {
    if (unit == DashboardMetricUnit.percent) return 100;
    final maxValue = bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
    return maxValue <= 0 ? 1 : maxValue;
  }

  String _format(double value) =>
      unit == DashboardMetricUnit.percent ? '${value.toStringAsFixed(0)}٪' : value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final ceiling = _ceiling;
    return ListView.separated(
      itemCount: bars.length,
      separatorBuilder: (context, i) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final bar = bars[i];
        final value = bar.value < 0 ? 0.0 : bar.value;
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap == null ? null : () => onTap!(i),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  bar.label,
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
                      widthFactor: (value / ceiling).clamp(0.0, 1.0),
                      child: Container(height: 18, decoration: BoxDecoration(color: bar.color, borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(_format(value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ترتيب الإدارات — غلافٌ رفيع فوق [RankedBarChart] يعطي كل صف لون إدارته.
class DepartmentBarChart extends StatelessWidget {
  final List<MapEntry<Department, double>> ranking;
  final DashboardMetricUnit unit;
  final ValueChanged<Department>? onDepartmentTap;

  const DepartmentBarChart({
    super.key,
    required this.ranking,
    this.unit = DashboardMetricUnit.percent,
    this.onDepartmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return RankedBarChart(
      bars: [
        for (final e in ranking) (label: e.key.name, color: e.key.color, value: e.value),
      ],
      unit: unit,
      onTap: onDepartmentTap == null ? null : (i) => onDepartmentTap!(ranking[i].key),
    );
  }
}

/// رسم دائري (Donut) لتوزيع حالة المشاريع مع قائمة وسائل إيضاح جانبية.
/// اضغط أي قطاع أو عنصر بالقائمة لعرض مشاريع تلك الحالة. مُنفَّذ بـ
/// CustomPainter مباشرة (بلا اعتماد خارجي) مع كشف موضع الضغط عبر حساب الزاوية.
class StatusDonutChart extends StatelessWidget {
  final Map<String, int> data; // label -> count
  final Map<String, Color> colors;
  final ValueChanged<String>? onSectionTap;
  const StatusDonutChart({super.key, required this.data, required this.colors, this.onSectionTap});

  static const double _diameter = 148;
  static const double _stroke = 24;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);
    if (total == 0) {
      return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details.localPosition, entries, total),
              child: SizedBox(
                width: _diameter,
                height: _diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: const Size(_diameter, _diameter), painter: _DonutPainter(entries: entries, colors: colors, total: total, stroke: _stroke)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const Text('مشروع', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              final pct = e.value / total * 100;
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onSectionTap == null ? null : () => onSectionTap!(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${pct.toStringAsFixed(0)}٪', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _handleTap(Offset local, List<MapEntry<String, int>> entries, int total) {
    if (onSectionTap == null) return;
    const center = Offset(_diameter / 2, _diameter / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final outer = _diameter / 2;
    final inner = outer - _stroke;
    if (radius < inner - 8 || radius > outer + 8) return;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final fraction = angle / (2 * math.pi);
    double acc = 0;
    for (final e in entries) {
      final share = e.value / total;
      if (fraction <= acc + share) {
        onSectionTap!(e.key);
        return;
      }
      acc += share;
    }
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final Map<String, Color> colors;
  final int total;
  final double stroke;
  _DonutPainter({required this.entries, required this.colors, required this.total, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - stroke / 2);
    var startAngle = -math.pi / 2;
    for (final e in entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[e.key] ?? AppColors.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      final gap = entries.length > 1 ? 0.028 : 0.0;
      canvas.drawArc(rect, startAngle + gap / 2, sweep - gap, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.colors != colors || oldDelegate.total != total;
}
