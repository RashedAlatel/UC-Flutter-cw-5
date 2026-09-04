import 'announcement.dart';
import 'project.dart';

/// إعدادات التنبيهات الذكية التلقائية (يتحكم بها مسؤول النظام) — تُحسب
/// حيّة من بيانات المشاريع الفعلية بدل أن تُكتب يدوياً، خلافاً للإشعارات
/// العامة النصية في [PlatformAnnouncement].
class AlertRulesConfig {
  final bool dueSoonEnabled;
  final int dueSoonDays;
  final bool delayedEnabled;

  /// «بلا تحديث حديث»: عمر آخر تحديث بالأيام قبل أن يُعدّ العنصر مهملاً.
  ///
  /// يقرؤها **التقرير التنفيذي اليومي** على الخادم من هذا المستند نفسه
  /// (`settings/alertRules`)، فتُضبط من الشاشة التي تُضبط منها بقية عتبات
  /// التنبيه بدل أن تكون رقماً مدفوناً في شيفرة الدالّة.
  final int staleUpdateDays;

  const AlertRulesConfig({
    this.dueSoonEnabled = true,
    this.dueSoonDays = 3,
    this.delayedEnabled = true,
    this.staleUpdateDays = 7,
  });

  Map<String, dynamic> toMap() => {
        'dueSoonEnabled': dueSoonEnabled,
        'dueSoonDays': dueSoonDays,
        'delayedEnabled': delayedEnabled,
        'staleUpdateDays': staleUpdateDays,
      };

  factory AlertRulesConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AlertRulesConfig();
    return AlertRulesConfig(
      dueSoonEnabled: map['dueSoonEnabled'] as bool? ?? true,
      dueSoonDays: (map['dueSoonDays'] as num?)?.toInt() ?? 3,
      delayedEnabled: map['delayedEnabled'] as bool? ?? true,
      staleUpdateDays: (map['staleUpdateDays'] as num?)?.toInt() ?? 7,
    );
  }
}

/// مجموعة مشاريع تطابق قاعدة تنبيه واحدة (مثلاً: كل المشاريع المتأخرة)،
/// جاهزة للعرض كشريط تنبيه قابل للضغط لعرض قائمة المشاريع نفسها.
class ProjectAlertGroup {
  final String title;
  final AnnouncementStyle style;
  final List<Project> projects;
  const ProjectAlertGroup({required this.title, required this.style, required this.projects});
}
