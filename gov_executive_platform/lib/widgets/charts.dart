import 'package:fl_chart/fl_chart.dart';
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

  /// علامات المحور: خمس درجات من الصفر إلى السقف.
  ///
  /// وهي ما ينقص الرسم اليوم: أعمدةٌ بلا مسطرة تُقارَن ببعضها فقط، فلا يعرف
  /// القارئ أين يقف العمود من المدى كله.
  List<double> get _ticks {
    final ceiling = _ceiling;
    return [for (var i = 0; i <= 4; i++) ceiling * i / 4];
  }

  static const double _labelWidth = 100;
  static const double _valueWidth = 40;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final ceiling = _ceiling;
    final ticks = _ticks;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // خطوط الشبكة خلف الأعمدة — بمحاذاة منطقة الرسم نفسها لا الصفّ
              // كله، وإلا مرّت تحت التسميات فبدت شخبطة.
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: _labelWidth + _gap,
                end: _valueWidth + 8,
                child: _GridLines(count: ticks.length),
              ),
              ListView.separated(
                itemCount: bars.length,
                separatorBuilder: (context, i) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final bar = bars[i];
                  final value = bar.value < 0 ? 0.0 : bar.value;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _labelWidth,
                          child: Text(
                            bar.label,
                            style: AppText.label.copyWith(fontSize: 11.5, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: _gap),
                        Expanded(
                          child: Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [
                              Container(height: 18, decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.sm))),
                              FractionallySizedBox(
                                widthFactor: (value / ceiling).clamp(0.0, 1.0),
                                child: Container(height: 18, decoration: BoxDecoration(color: bar.color, borderRadius: BorderRadius.circular(AppRadius.sm))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: _valueWidth,
                          child: Text(_format(value), style: AppText.label.copyWith(fontSize: 11, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // أرقام المحور تحت منطقة الرسم بنفس محاذاتها.
        Padding(
          padding: EdgeInsetsDirectional.only(start: _labelWidth + _gap, end: _valueWidth + 8),
          child: Row(
            children: [
              for (var i = 0; i < ticks.length; i++)
                Expanded(
                  flex: i == 0 || i == ticks.length - 1 ? 1 : 2,
                  child: Align(
                    alignment: i == 0
                        ? AlignmentDirectional.centerStart
                        : (i == ticks.length - 1 ? AlignmentDirectional.centerEnd : Alignment.center),
                    child: Text(_format(ticks[i]), style: AppText.micro.copyWith(color: AppColors.textSecondary)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// خطوط رأسية رفيعة خلف الأعمدة، بعدد علامات المحور.
class _GridLines extends StatelessWidget {
  final int count;
  const _GridLines({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const Expanded(child: SizedBox.shrink()),
          Container(width: 1, color: AppColors.border.withValues(alpha: 0.9)),
        ],
      ],
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
/// اضغط أي قطاع أو عنصر بالقائمة لعرض مشاريع تلك الحالة.
///
/// مبنيٌّ على `fl_chart`. وكان قبلها `CustomPainter` مكتوباً يدوياً ومعه كشفُ
/// موضع الضغط بحساب الزاوية (`atan2` ونصف قطر وهامش ثمانية بكسل) — نحو تسعين
/// سطراً من هندسة تُصان يدوياً، استبدلها المحرّك بلمسٍ يعرف قطاعه.
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
            child: SizedBox(
              width: _diameter,
              height: _diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: _diameter / 2 - _stroke,
                      sectionsSpace: entries.length > 1 ? 2 : 0,
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: colors[e.key] ?? AppColors.textSecondary,
                            radius: _stroke,
                            showTitle: false,
                          ),
                      ],
                      pieTouchData: PieTouchData(
                        enabled: onSectionTap != null,
                        touchCallback: (event, response) {
                          if (onSectionTap == null || !event.isInterestedForInteractions) return;
                          final index = response?.touchedSection?.touchedSectionIndex ?? -1;
                          if (index < 0 || index >= entries.length) return;
                          onSectionTap!(entries[index].key);
                        },
                      ),
                    ),
                    // بلا حركة: أداة معاينة اللوحة تستعمل `pumpAndSettle`، وهو
                    // لا يستقرّ أبداً مع أي حركة لا تنتهي فتتجاوز مهلته
                    // الأداة — وهي عينُنا الوحيدة على الشكل قبل النشر.
                    duration: Duration.zero,
                  ),
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
                      Text('${pct.toStringAsFixed(0)}\u066a', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
}
