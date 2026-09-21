/// مصدر بيانات الودجت المخصص الذي يبنيه مسؤول النظام (أو من يملك صلاحية
/// "تخصيص اللوحة") بنفسه، بدل الاختيار من قائمة ثابتة فقط.
enum CustomWidgetSource { projects, tasks, risks, blockers, works }

extension CustomWidgetSourceX on CustomWidgetSource {
  String get label {
    switch (this) {
      case CustomWidgetSource.projects:
        return 'المشاريع';
      case CustomWidgetSource.tasks:
        return 'المهام';
      case CustomWidgetSource.risks:
        return 'المخاطر';
      case CustomWidgetSource.blockers:
        return 'العوائق';
      case CustomWidgetSource.works:
        return 'الأعمال';
    }
  }

  /// الحقول القابلة للتجميع/التصفية لهذا المصدر: المفتاح الداخلي ← التسمية
  /// المعروضة. الترتيب هنا هو ترتيب ظهورها في نموذج بناء الودجت.
  Map<String, String> get fields {
    switch (this) {
      case CustomWidgetSource.projects:
        return const {'status': 'الحالة', 'priority': 'الأولوية', 'department': 'الإدارة', 'executor': 'المنفذ'};
      case CustomWidgetSource.tasks:
        return const {'status': 'الحالة', 'priority': 'الأولوية', 'assignee': 'المسؤول عن التنفيذ'};
      case CustomWidgetSource.risks:
        return const {'level': 'مستوى الخطورة', 'status': 'الحالة'};
      case CustomWidgetSource.blockers:
        return const {'status': 'الحالة'};
      case CustomWidgetSource.works:
        return const {'status': 'الحالة', 'priority': 'الأولوية', 'department': 'الإدارة', 'assignee': 'المسؤول عن التنفيذ'};
    }
  }

  /// الحقول النصية الحرة (بلا قائمة قيم ثابتة) التي تُصفّى بإدخال نص مطابق،
  /// خلافاً لبقية الحقول (حالة/أولوية/إدارة) التي تُصفّى من قائمة منسدلة.
  bool isFreeTextField(String field) => field == 'executor' || field == 'assignee';

  static CustomWidgetSource fromName(String name) =>
      CustomWidgetSource.values.firstWhere((e) => e.name == name, orElse: () => CustomWidgetSource.projects);
}

enum CustomWidgetDisplay { stat, bar, donut, table }

extension CustomWidgetDisplayX on CustomWidgetDisplay {
  String get label {
    switch (this) {
      case CustomWidgetDisplay.stat:
        return 'رقم إحصائي';
      case CustomWidgetDisplay.bar:
        return 'رسم أعمدة';
      case CustomWidgetDisplay.donut:
        return 'رسم دائري';
      case CustomWidgetDisplay.table:
        return 'جدول';
    }
  }

  static CustomWidgetDisplay fromName(String name) =>
      CustomWidgetDisplay.values.firstWhere((e) => e.name == name, orElse: () => CustomWidgetDisplay.bar);
}

/// تعريف ودجت حرّ بالكامل: مصدر بيانات + تجميع اختياري + تصفية اختيارية +
/// نوع عرض، يُبنى من واجهة "منشئ الودجت" ويُخزَّن ضمن [DashboardWidgetConfig].
class CustomWidgetSpec {
  final String title;
  final CustomWidgetSource source;
  final String? groupBy; // مفتاح من CustomWidgetSource.fields، أو null لعرض "stat" فقط
  final CustomWidgetDisplay display;
  final String? filterField; // مفتاح من CustomWidgetSource.fields
  final String? filterValue;

  const CustomWidgetSpec({
    required this.title,
    required this.source,
    this.groupBy,
    required this.display,
    this.filterField,
    this.filterValue,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'source': source.name,
        'groupBy': groupBy,
        'display': display.name,
        'filterField': filterField,
        'filterValue': filterValue,
      };

  factory CustomWidgetSpec.fromMap(Map<String, dynamic> map) => CustomWidgetSpec(
        title: map['title'] as String? ?? 'ودجت مخصص',
        source: CustomWidgetSourceX.fromName(map['source'] as String? ?? 'projects'),
        groupBy: map['groupBy'] as String?,
        display: CustomWidgetDisplayX.fromName(map['display'] as String? ?? 'bar'),
        filterField: map['filterField'] as String?,
        filterValue: map['filterValue'] as String?,
      );
}
