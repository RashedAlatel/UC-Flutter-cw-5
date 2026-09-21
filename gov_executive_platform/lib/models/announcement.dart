import 'package:cloud_firestore/cloud_firestore.dart';

/// شكل تنبيه الإشعار المعروض لكل المستخدمين — يحدّد لونه وأيقونته.
enum AnnouncementStyle { info, success, warning, danger }

extension AnnouncementStyleX on AnnouncementStyle {
  String get label {
    switch (this) {
      case AnnouncementStyle.info:
        return 'معلومة';
      case AnnouncementStyle.success:
        return 'نجاح';
      case AnnouncementStyle.warning:
        return 'تحذير';
      case AnnouncementStyle.danger:
        return 'عاجل';
    }
  }

  static AnnouncementStyle fromName(String name) =>
      AnnouncementStyle.values.firstWhere((e) => e.name == name, orElse: () => AnnouncementStyle.info);
}

/// إشعار عام يُنشئه مسؤول النظام ويظهر لكل المستخدمين أعلى كل صفحات
/// المنصة، إلى أن يحذفه مسؤول النظام (أو يُخفيه المستخدم لجلسته الحالية).
class PlatformAnnouncement {
  final String id;
  final String message;
  final AnnouncementStyle style;
  final DateTime createdAt;
  final String createdByName;

  const PlatformAnnouncement({
    required this.id,
    required this.message,
    required this.style,
    required this.createdAt,
    this.createdByName = '',
  });

  Map<String, dynamic> toMap() => {
        'message': message,
        'style': style.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdByName': createdByName,
      };

  factory PlatformAnnouncement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return PlatformAnnouncement(
      id: doc.id,
      message: json['message'] as String? ?? '',
      style: AnnouncementStyleX.fromName(json['style'] as String? ?? 'info'),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByName: json['createdByName'] as String? ?? '',
    );
  }
}
