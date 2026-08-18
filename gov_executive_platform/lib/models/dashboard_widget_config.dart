import 'enums.dart';

/// عنصر ودجت واحد ضمن تخطيط لوحة القيادة القابل للتخصيص.
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;

  const DashboardWidgetConfig({required this.id, required this.type});

  Map<String, dynamic> toMap() => {'id': id, 'type': type.name};

  factory DashboardWidgetConfig.fromMap(Map<String, dynamic> map) => DashboardWidgetConfig(
        id: map['id'] as String? ?? '',
        type: DashboardWidgetType.fromName(map['type'] as String? ?? DashboardWidgetType.deptBarChart.name),
      );

  /// التخطيط الافتراضي المعروض قبل أن يخصّص مسؤول النظام لوحة القيادة —
  /// مطابق لتقسيمات التصميم المرجعي المعتمد (دائري + أعلى المشاريع + جدول
  /// + أعمدة الإدارات). القوائم الأخرى (القرارات المعلّقة، آخر التحديثات)
  /// تبقى متاحة للإضافة يدوياً عبر "تخصيص اللوحة".
  static List<DashboardWidgetConfig> defaults() => const [
        DashboardWidgetConfig(id: 'default_1', type: DashboardWidgetType.topProjectsList),
        DashboardWidgetConfig(id: 'default_2', type: DashboardWidgetType.statusPieChart),
        DashboardWidgetConfig(id: 'default_3', type: DashboardWidgetType.projectsTable),
        DashboardWidgetConfig(id: 'default_4', type: DashboardWidgetType.deptBarChart),
      ];
}
