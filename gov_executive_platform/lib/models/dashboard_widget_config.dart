import 'custom_widget_spec.dart';
import 'dashboard_metric.dart';
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

  /// المقياس الذي يُرتَّب به هذا الودجت — للأنواع الحاملة للمقياس وحدها
  /// ([DashboardWidgetType.hasMetric]).
  ///
  /// والافتراض [DashboardMetric.avgProgress] عمداً: هو ما كانت اللوحة تعرضه
  /// قبل وجود هذا الحقل، فكل لوحة محفوظة اليوم تُقرأ بعد النشر كما كانت
  /// حرفياً.
  final DashboardMetric metric;

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.custom,
    this.width = DashboardWidgetWidth.half,
    this.metric = DashboardMetric.avgProgress,
  });

  DashboardWidgetConfig copyWith({DashboardWidgetWidth? width, DashboardMetric? metric}) =>
      DashboardWidgetConfig(
        id: id,
        type: type,
        custom: custom,
        width: width ?? this.width,
        metric: metric ?? this.metric,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'width': width.name,
        if (type.hasMetric) 'metric': metric.name,
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
      metric: DashboardMetric.fromName(map['metric'] as String?),
    );
  }

  /// التخطيط الافتراضي المعروض قبل أن يخصّص مسؤول النظام لوحة القيادة —
  /// مطابق لتقسيمات التصميم المرجعي المعتمد (دائري + أعلى المشاريع + جدول
  /// + أعمدة الإدارات). القوائم الأخرى (القرارات المعلّقة، آخر التحديثات)
  /// تبقى متاحة للإضافة يدوياً عبر "تخصيص اللوحة".
  static List<DashboardWidgetConfig> defaults() => [
        ...kpiDefaults(),
        const DashboardWidgetConfig(id: 'default_1', type: DashboardWidgetType.topProjectsList),
        const DashboardWidgetConfig(id: 'default_2', type: DashboardWidgetType.statusPieChart),
        // الجدول يحتاج السطر كاملاً: أعمدته لا تُقرأ في نصف عرض الشاشة.
        const DashboardWidgetConfig(
            id: 'default_3', type: DashboardWidgetType.projectsTable, width: DashboardWidgetWidth.full),
        const DashboardWidgetConfig(id: 'default_4', type: DashboardWidgetType.deptBarChart),
        // «من عليه أكثر المشاريع» سؤالٌ تُسأله القيادة أولاً، فيظهر جوابه بلا
        // أن يضيفه أحد. ومقياسه الافتراضي العدد لا النسبة: هذا هو السؤال نفسه.
        const DashboardWidgetConfig(
            id: 'default_5',
            type: DashboardWidgetType.topUsersChart,
            metric: DashboardMetric.projectCount),
      ];

  /// صفّ المؤشرات الافتراضي — الخمسة التي كانت مثبَّتة في الصفحة، ومعها
  /// «إجمالي عدد المشاريع» و«المشاريع عالية الأولوية» ولم يكن لهما مؤشر.
  static List<DashboardWidgetConfig> kpiDefaults() => const [
        DashboardWidgetConfig(id: 'kpi_progress', type: DashboardWidgetType.kpiAvgProgress, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_count', type: DashboardWidgetType.kpiProjectCount, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_priority', type: DashboardWidgetType.kpiHighPriority, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_delay', type: DashboardWidgetType.kpiAvgDelay, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_risks', type: DashboardWidgetType.kpiOpenRisks, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_blockers', type: DashboardWidgetType.kpiOpenBlockers, width: DashboardWidgetWidth.third),
        DashboardWidgetConfig(id: 'kpi_approvals', type: DashboardWidgetType.kpiPendingApprovals, width: DashboardWidgetWidth.third),
      ];

  /// مفتاح يُكتب على مستند اللوحة عند أول حفظ من الواجهة الجديدة.
  static const String kpiMigrationKey = 'kpiMigrated';

  /// يُضيف صفّ المؤشرات إلى تخطيطٍ **حُفظ قبل** أن تصير المؤشرات ودجات.
  ///
  /// بغير هذا يفقد كلُّ من خصّص لوحته سابقاً الصفَّ العلوي كاملاً بعد النشر،
  /// ويقرأها عطلاً لا ميزة. والعلامة على المستند لا على قائمة الودجات: من
  /// حَذَف المؤشرات عمداً وحَفِظ، تُكتب العلامة فيبقى حذفه — ولا تعود
  /// البطاقات في كل تحميل تُصارعه.
  ///
  /// والقائمة الفارغة تُعاد كما هي: الفراغ يعني «هذه الطبقة لم تُضبط» فتتخطاها
  /// [resolveLayers]، وحشوُها بالمؤشرات يجعل طبقةً غير مضبوطة تبدو مضبوطة.
  static List<DashboardWidgetConfig> withKpiRow(
    List<DashboardWidgetConfig> stored, {
    required bool migrated,
  }) {
    if (migrated || stored.isEmpty) return stored;
    if (stored.any((w) => w.type.isKpi)) return stored;
    return [...kpiDefaults(), ...stored];
  }

  /// يُبقي أول ظهور فقط لكل نوع جاهز ويحذف أي تكرار، مع إبقاء كل الودجات
  /// المخصصة كما هي (يمكن تكرارها بمواصفات مختلفة). يُطبَّق عند كل قراءة
  /// وحفظ لتنظيف أي تكرار تراكم من نسخ سابقة كانت تسمح بإضافة نفس النوع
  /// أكثر من مرة — تراكم عشرات الودجات كان يجعل الصفحة طويلة جداً بشكل غير
  /// طبيعي عند التمرير للأسفل.
  ///
  /// **والنوع الحامل لمقياس يُميَّز بنوعه ومقياسه معاً**: «ترتيب الإدارات حسب
  /// الإنجاز» و«ترتيب الإدارات حسب التأخير» رقمان مختلفان يُقارَنان جنباً إلى
  /// جنب، فلا يجوز أن يبتلع أحدهما الآخر لمجرّد اشتراكهما في النوع. أما
  /// نسختان بالمقياس نفسه فهما تكرارٌ حقيقي وتُطويان.
  static List<DashboardWidgetConfig> dedupe(List<DashboardWidgetConfig> list) {
    final seen = <String>{};
    final result = <DashboardWidgetConfig>[];
    for (final w in list) {
      if (w.type == DashboardWidgetType.custom) {
        result.add(w);
      } else if (seen.add(w.type.hasMetric ? '${w.type.name}/${w.metric.name}' : w.type.name)) {
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
  ///
  /// و[personalAllowed] هو الفرق بين «لم يخصّص» و«لا يملك التخصيص»:
  ///
  /// كان زرّ «تخصيص اللوحة» معروضاً لكل مستخدم بلا استثناء، فالمستخدم
  /// التنفيذي — ولو لم تُمنح له صلاحية «تخصيص لوحة القيادة» — يخصّص لوحته
  /// مرةً واحدة، فتُحفظ طبقتُه الشخصية وتعلو أبداً على لوحة الدور. ومسؤول
  /// النظام يضبط لوحة الدور فلا يقع منها شيء، ولا يعرف لماذا.
  ///
  /// فمن لا يملك الصلاحية لا يُقرأ له تخصيصٌ سابق: هو ليس اختياراً قائماً
  /// بل أثرٌ لبابٍ كان مفتوحاً. ولا يُحذف من قاعدة البيانات — فإن أعاد
  /// مسؤول النظام منحَه الصلاحية عادت لوحته كما تركها.
  static List<DashboardWidgetConfig> resolveLayers({
    List<DashboardWidgetConfig>? personal,
    List<DashboardWidgetConfig>? role,
    List<DashboardWidgetConfig>? global,
    bool personalAllowed = true,
  }) {
    if (personalAllowed && personal != null && personal.isNotEmpty) return personal;
    if (role != null && role.isNotEmpty) return role;
    if (global != null && global.isNotEmpty) return global;
    return defaults();
  }
}
