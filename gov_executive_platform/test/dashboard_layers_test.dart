import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';

/// اختبارات ترتيب طبقات لوحة القيادة: لوحة المستخدم ← لوحة دوره ← اللوحة
/// العامة ← الافتراضية. هذا هو ما يجعل المستخدم التنفيذي ومدير الإدارة يريان
/// لوحتين مختلفتين دون أن يؤثر أحدهما على الآخر.
void main() {
  DashboardWidgetConfig w(String id, DashboardWidgetType type) => DashboardWidgetConfig(id: id, type: type);

  final personal = [w('p1', DashboardWidgetType.projectsTable)];
  final role = [w('r1', DashboardWidgetType.deptBarChart)];
  final global = [w('g1', DashboardWidgetType.statusPieChart)];

  group('ترتيب الطبقات', () {
    test('لوحة المستخدم تسبق لوحة دوره واللوحة العامة', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: personal, role: role, global: global);
      expect(result.single.id, 'p1');
    });

    test('بلا لوحة شخصية تظهر لوحة الدور', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: null, role: role, global: global);
      expect(result.single.id, 'r1');
    });

    test('بلا لوحة شخصية ولا لوحة دور تظهر اللوحة العامة', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: null, role: null, global: global);
      expect(result.single.id, 'g1');
    });

    test('بلا أي طبقة مضبوطة تظهر الودجات الافتراضية', () {
      final result = DashboardWidgetConfig.resolveLayers();
      expect(result.map((e) => e.id), DashboardWidgetConfig.defaults().map((e) => e.id));
    });
  });

  group('الطبقة الفارغة تعني غير مضبوطة', () {
    test('لوحة شخصية فارغة تتخطّى إلى لوحة الدور لا إلى لوحة خالية', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: const [], role: role, global: global);
      expect(result.single.id, 'r1');
    });

    test('لوحة دور فارغة تتخطّى إلى اللوحة العامة', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: const [], role: const [], global: global);
      expect(result.single.id, 'g1');
    });

    test('كل الطبقات فارغة تعود للافتراضية لا لقائمة خالية', () {
      final result = DashboardWidgetConfig.resolveLayers(personal: const [], role: const [], global: const []);
      expect(result, isNotEmpty);
      expect(result.map((e) => e.id), DashboardWidgetConfig.defaults().map((e) => e.id));
    });
  });
}
