import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/custom_widget_spec.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';

/// يتحقق أن ودجت مخصصاً يُحفَظ عبر toMap() ثم يُعاد بناؤه عبر fromMap()
/// (تماماً كما يحدث فعلياً عبر Firestore: set() ثم snapshot listener)
/// يحافظ على حقل [DashboardWidgetConfig.custom] كاملاً وليس null، وهو ما
/// يقرر ظهور الودجت على اللوحة (config.custom == null يعني SizedBox.shrink).
void main() {
  test('custom widget survives a toMap/fromMap round trip', () {
    const spec = CustomWidgetSpec(
      title: 'اختبار',
      source: CustomWidgetSource.tasks,
      groupBy: 'status',
      display: CustomWidgetDisplay.bar,
      filterField: 'priority',
      filterValue: 'high',
    );
    const original = DashboardWidgetConfig(id: 'w1', type: DashboardWidgetType.custom, custom: spec);

    final map = original.toMap();

    final rebuilt = DashboardWidgetConfig.fromMap(map);
    expect(rebuilt.type, DashboardWidgetType.custom);
    expect(rebuilt.custom, isNotNull);
    expect(rebuilt.custom!.title, 'اختبار');
    expect(rebuilt.custom!.source, CustomWidgetSource.tasks);
    expect(rebuilt.custom!.groupBy, 'status');
    expect(rebuilt.custom!.display, CustomWidgetDisplay.bar);
  });

  test('a full widgets list (defaults + one custom) round-trips through the same shape saveDashboardWidgets writes', () {
    final widgets = [
      ...DashboardWidgetConfig.defaults(),
      const DashboardWidgetConfig(
        id: 'custom1',
        type: DashboardWidgetType.custom,
        custom: CustomWidgetSpec(title: 'ودجت جديد', source: CustomWidgetSource.projects, display: CustomWidgetDisplay.stat),
      ),
    ];

    // هذا بالضبط ما تكتبه saveDashboardWidgets إلى Firestore.
    final serialized = widgets.map((w) => w.toMap()).toList();

    // وهذا بالضبط ما يقرأه مستمع dashboardConfig/main عند وصول التحديث.
    final rebuilt = serialized.map((w) => DashboardWidgetConfig.fromMap(Map<String, dynamic>.from(w))).toList();

    expect(rebuilt.length, widgets.length);
    final customRebuilt = rebuilt.last;
    expect(customRebuilt.type, DashboardWidgetType.custom);
    expect(customRebuilt.custom, isNotNull, reason: 'custom spec was lost in the round trip — this is why the widget renders as SizedBox.shrink()');
    expect(customRebuilt.custom!.title, 'ودجت جديد');
  });
}
