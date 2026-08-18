import 'announcement.dart';
import 'project.dart';

/// إعدادات التنبيهات الذكية التلقائية (يتحكم بها مسؤول النظام) — تُحسب
/// حيّة من بيانات المشاريع الفعلية بدل أن تُكتب يدوياً، خلافاً للإشعارات
/// العامة النصية في [PlatformAnnouncement].
class AlertRulesConfig {
  final bool dueSoonEnabled;
  final int dueSoonDays;
  final bool delayedEnabled;

  const AlertRulesConfig({
    this.dueSoonEnabled = true,
    this.dueSoonDays = 3,
    this.delayedEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'dueSoonEnabled': dueSoonEnabled,
        'dueSoonDays': dueSoonDays,
        'delayedEnabled': delayedEnabled,
      };

  factory AlertRulesConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AlertRulesConfig();
    return AlertRulesConfig(
      dueSoonEnabled: map['dueSoonEnabled'] as bool? ?? true,
      dueSoonDays: (map['dueSoonDays'] as num?)?.toInt() ?? 3,
      delayedEnabled: map['delayedEnabled'] as bool? ?? true,
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
