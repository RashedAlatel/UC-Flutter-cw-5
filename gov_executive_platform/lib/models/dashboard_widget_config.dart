import 'custom_widget_spec.dart';
import 'enums.dart';

/// عرض الودجت على اللوحة.
///
/// النِسَب لا البكسلات: اللوحة تُعرض على شاشة قيادة عريضة وعلى جوال، والعرض
/// الثابت يكسر أحدهما حتماً. و[full] تعني «سطراً كاملاً» لا عرضاً بعينه.
enum DashboardWidgetWidth {
  third('ثلث العرض', 3),
  half('نصف العرض', 2),
  full('العرض كاملاً', 1);

  final String label;

  /// مقام الكسر: كم بطاقةً من هذا العرض تملأ السطر الواحد.
  ///
  /// وهذا هو المقياس الصحيح لا «كم عموداً من ثلاثة»: بشبكة من ثلاثة أعمدة
  /// يصير النصف عمودين، فبطاقتان بنصف العرض تحتاجان أربعة أعمدة ولا تجتمعان
  /// في سطر — فتنزل الثانية تحت الأولى ويبقى نصف السطر فارغاً. وهو ما ظهر
  /// في معاينة التصيير: اختار المستخدم «نصف العرض» لبطاقتين فلم تصطفّا.
  final int denominator;

  const DashboardWidgetWidth(this.label, this.denominator);

  static DashboardWidgetWidth fromName(String? name) => DashboardWidgetWidth.values
      .firstWhere((e) => e.name == name, orElse: () => DashboardWidgetWidth.half);
}

/// عنصر ودجت واحد ضمن تخطيط لوحة القيادة القابل للتخصيص. [custom] غير فارغ
/// فقط عندما يكون [type] هو [DashboardWidgetType.custom] — ودجت بناه مسؤول
/// النظام بنفسه عبر "منشئ الودجت" بدل الاختيار من الأنواع الجاهزة.
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final CustomWidgetSpec? custom;

  /// عرض الودجت على اللوحة. تخطيطٌ محفوظ قبل وجود هذا الحقل يُقرأ بالقيمة
  /// المبدئية، فلا تنكسر لوحة ضبطها أحد قبل اليوم.
  final DashboardWidgetWidth width;

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.custom,
    this.width = DashboardWidgetWidth.half,
  });

  DashboardWidgetConfig copyWith({DashboardWidgetWidth? width}) => DashboardWidgetConfig(
        id: id,
        type: type,
        custom: custom,
        width: width ?? this.width,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'width': width.name,
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
      width: DashboardWidgetWidth.fromName(map['width'] as String?),
    );
  }

  /// التخطيط الافتراضي المعروض قبل أن يخصّص مسؤول النظام لوحة القيادة —
  /// مطابق لتقسيمات التصميم المرجعي المعتمد (دائري + أعلى المشاريع + جدول
  /// + أعمدة الإدارات). القوائم الأخرى (القرارات المعلّقة، آخر التحديثات)
  /// تبقى متاحة للإضافة يدوياً عبر "تخصيص اللوحة".
  static List<DashboardWidgetConfig> defaults() => const [
        DashboardWidgetConfig(id: 'default_1', type: DashboardWidgetType.topProjectsList),
        DashboardWidgetConfig(id: 'default_2', type: DashboardWidgetType.statusPieChart),
        // الجدول يحتاج السطر كاملاً: أعمدته لا تُقرأ في نصف عرض الشاشة.
        DashboardWidgetConfig(
            id: 'default_3', type: DashboardWidgetType.projectsTable, width: DashboardWidgetWidth.full),
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

  /// يختار التخطيط الذي يراه المستخدم من طبقات التخصيص الثلاث: لوحته
  /// الشخصية، ثم لوحة دوره التي ضبطها مسؤول النظام، ثم اللوحة العامة، وأخيراً
  /// الودجات الافتراضية.
  ///
  /// القائمة الفارغة (أو null) تعني «هذه الطبقة لم تُضبط» لا «لوحة بلا
  /// ودجات»، فتُتخطّى إلى الطبقة التالية — لولا ذلك لظهرت لوحة خالية لأي
  /// مستخدم حُذف آخر ودجت من لوحته.
  static List<DashboardWidgetConfig> resolveLayers({
    List<DashboardWidgetConfig>? personal,
    List<DashboardWidgetConfig>? role,
    List<DashboardWidgetConfig>? global,
  }) {
    if (personal != null && personal.isNotEmpty) return personal;
    if (role != null && role.isNotEmpty) return role;
    if (global != null && global.isNotEmpty) return global;
    return defaults();
  }
}
