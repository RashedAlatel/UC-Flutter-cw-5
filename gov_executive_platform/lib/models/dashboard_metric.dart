/// وحدة قياس الرقم المعروض — تقرّر شكل العمود وتسميته معاً.
///
/// التمييز ليس تجميلاً: عمود «نسبة» يُقاس على ١٠٠ دائماً فيصحّ أن يُقرأ
/// مستقلاً، أما عمود «عدد» فلا سقف له، ويجب أن يُقاس على أكبر قيمة في نفس
/// الرسم وإلا صار كل عمود ممتلئاً. وطباعة `٪` بعد عددٍ مطلق تجعل «١٢ مشروعاً»
/// تُقرأ «١٢٪» — رقمٌ لا معنى له.
enum DashboardMetricUnit { percent, count }

/// المقياس الذي يُرتَّب به الرسم البياني — للإدارات وللأشخاص سواءً.
///
/// كان «الأداء» معنىً واحداً مثبَّتاً في الشيفرة (متوسط نسبة الإنجاز)، فكان
/// عنوان البطاقة يقول «حسب الأداء» ولا يقول أيّ أداء. صار المقياس اختياراً
/// يُحفظ مع الودجت نفسه، ويُذكَر في عنوانه.
enum DashboardMetric {
  /// متوسط `progressPercent` — وهو ما كانت اللوحة تعرضه دائماً، فبقي افتراضاً.
  avgProgress,

  /// نسبة المشاريع المتأخرة عن موعدها ولم تكتمل.
  delayedRate,

  /// نسبة المشاريع المكتملة.
  completedRate,

  /// عدد المشاريع — لا نسبة.
  projectCount;

  String get label {
    switch (this) {
      case DashboardMetric.avgProgress:
        return 'متوسط نسبة الإنجاز';
      case DashboardMetric.delayedRate:
        return 'نسبة المشاريع المتأخرة';
      case DashboardMetric.completedRate:
        return 'نسبة المشاريع المكتملة';
      case DashboardMetric.projectCount:
        return 'عدد المشاريع';
    }
  }

  DashboardMetricUnit get unit =>
      this == DashboardMetric.projectCount ? DashboardMetricUnit.count : DashboardMetricUnit.percent;

  /// هل ارتفاع الرقم خبرٌ حسن؟
  ///
  /// «نسبة التأخير» وحدها يسوء ارتفاعُها. والترتيب يبقى تنازلياً في الحالتين
  /// عمداً: القيادة تريد الأسوأ في الأعلى حين يكون المقياس تأخّراً، والأفضل
  /// في الأعلى حين يكون إنجازاً — وكلاهما «الأكبر أولاً». ما يتغيّر هو
  /// **اللون** وشرحُ البطاقة، لا الترتيب.
  bool get higherIsBetter => this != DashboardMetric.delayedRate;

  /// شرح سطر واحد يظهر تحت عنوان البطاقة، فيعرف القارئ ما يقيسه العمود
  /// وماذا يفتح الضغط عليه.
  String get hint {
    switch (this) {
      case DashboardMetric.avgProgress:
        return 'متوسط نسبة إنجاز المشاريع — اضغط لعرض مشاريع الصف';
      case DashboardMetric.delayedRate:
        return 'كلما ارتفع العمود ساء الحال — اضغط لعرض المشاريع المتأخرة';
      case DashboardMetric.completedRate:
        return 'نصيب المكتمل من المشاريع — اضغط لعرض المشاريع المكتملة';
      case DashboardMetric.projectCount:
        return 'إجمالي عدد المشاريع — اضغط لعرضها';
    }
  }

  static DashboardMetric fromName(String? name) => DashboardMetric.values
      .firstWhere((e) => e.name == name, orElse: () => DashboardMetric.avgProgress);
}
