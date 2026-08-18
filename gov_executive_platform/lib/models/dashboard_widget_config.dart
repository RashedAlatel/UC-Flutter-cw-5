import 'custom_widget_spec.dart';
import 'enums.dart';

/// عنصر ودجت واحد ضمن تخطيط لوحة القيادة القابل للتخصيص. [custom] غير فارغ
/// فقط عندما يكون [type] هو [DashboardWidgetType.custom] — ودجت بناه مسؤول
/// النظام بنفسه عبر "منشئ الودجت" بدل الاختيار من الأنواع الجاهزة.
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final CustomWidgetSpec? custom;

  const DashboardWidgetConfig({required this.id, required this.type, this.custom});

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        if (custom != null) 'custom': custom!.toMap(),
      };

  factory DashboardWidgetConfig.fromMap(Map<String, dynamic> map) {
    final type = DashboardWidgetType.fromName(map['type'] as String? ?? DashboardWidgetType.deptBarChart.name);
    final customMap = map['custom'];
    return DashboardWidgetConfig(
      id: map['id'] as String? ?? '',
      type: type,
      custom: type == DashboardWidgetType.custom && customMap is Map
          ? CustomWidgetSpec.fromMap(Map<String, dynamic>.from(customMap))
          : null,
    );
  }

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

  /// يُبقي أول ظهور فقط لكل نوع جاهز (غير مخصص) ويحذف أي تكرار، مع إبقاء
  /// كل الودجات المخصصة كما هي (يمكن تكرارها بمواصفات مختلفة). يُطبَّق عند
  /// كل قراءة وحفظ لتنظيف أي تكرار تراكم من نسخ سابقة كانت تسمح بإضافة نفس
  /// النوع الجاهز أكثر من مرة — تراكم عشرات الودجات كان يجعل الصفحة طويلة
  /// جداً بشكل غير طبيعي عند التمرير للأسفل.
  static List<DashboardWidgetConfig> dedupe(List<DashboardWidgetConfig> list) {
    final seenTypes = <DashboardWidgetType>{};
    final result = <DashboardWidgetConfig>[];
    for (final w in list) {
      if (w.type == DashboardWidgetType.custom) {
        result.add(w);
      } else if (seenTypes.add(w.type)) {
        result.add(w);
      }
    }
    return result;
  }
}
