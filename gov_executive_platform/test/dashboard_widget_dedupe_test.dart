import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';

/// يتحقق أن dedupe() يزيل تكرار الأنواع الجاهزة (السبب الذي جعل لوحة
/// القيادة تتراكم عشرات الودجات وتصبح طويلة بشكل غير طبيعي عند التمرير)
/// مع إبقاء كل الودجات المخصصة، حتى لو تكررت.
void main() {
  test('dedupe keeps one of each built-in type but all custom widgets', () {
    final list = [
      const DashboardWidgetConfig(id: '1', type: DashboardWidgetType.topProjectsList),
      const DashboardWidgetConfig(id: '2', type: DashboardWidgetType.statusPieChart),
      const DashboardWidgetConfig(id: '3', type: DashboardWidgetType.topProjectsList), // مكرر
      const DashboardWidgetConfig(id: '4', type: DashboardWidgetType.deptBarChart),
      const DashboardWidgetConfig(id: '5', type: DashboardWidgetType.topProjectsList), // مكرر
      const DashboardWidgetConfig(
        id: '6',
        type: DashboardWidgetType.custom,
        custom: CustomWidgetSpec(title: 'أ', source: CustomWidgetSource.projects, display: CustomWidgetDisplay.stat),
      ),
      const DashboardWidgetConfig(
        id: '7',
        type: DashboardWidgetType.custom,
        custom: CustomWidgetSpec(title: 'ب', source: CustomWidgetSource.tasks, display: CustomWidgetDisplay.bar),
      ),
    ];

    final result = DashboardWidgetConfig.dedupe(list);

    expect(result.map((w) => w.id).toList(), ['1', '2', '4', '6', '7']);
    expect(result.where((w) => w.type == DashboardWidgetType.topProjectsList).length, 1);
    expect(result.where((w) => w.type == DashboardWidgetType.custom).length, 2);
  });

  test('dedupe on an empty list returns an empty list', () {
    expect(DashboardWidgetConfig.dedupe(const []), isEmpty);
  });
}
