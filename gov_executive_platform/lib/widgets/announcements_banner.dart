import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../theme/app_theme.dart';

/// شريط الإشعارات العامة التي أنشأها مسؤول النظام — يظهر أعلى كل صفحة لكل
/// المستخدمين. يمكن لأي مستخدم إخفاء إشعار لجلسته الحالية فقط (لا يُحذف من
/// المنصة)؛ الحذف الفعلي حصراً لمسؤول النظام من "إعدادات المظهر".
class AnnouncementsBanner extends StatefulWidget {
  final List<PlatformAnnouncement> announcements;
  const AnnouncementsBanner({super.key, required this.announcements});

  @override
  State<AnnouncementsBanner> createState() => _AnnouncementsBannerState();
}

class _AnnouncementsBannerState extends State<AnnouncementsBanner> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.announcements.where((a) => !_dismissed.contains(a.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      children: visible
          .map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AnnouncementBar(announcement: a, onDismiss: () => setState(() => _dismissed.add(a.id))),
              ))
          .toList(),
    );
  }
}

class _AnnouncementBar extends StatelessWidget {
  final PlatformAnnouncement announcement;
  final VoidCallback onDismiss;
  const _AnnouncementBar({required this.announcement, required this.onDismiss});

  Color get _color {
    switch (announcement.style) {
      case AnnouncementStyle.info:
        return AppColors.info;
      case AnnouncementStyle.success:
        return AppColors.success;
      case AnnouncementStyle.warning:
        return AppColors.warning;
      case AnnouncementStyle.danger:
        return AppColors.danger;
    }
  }

  IconData get _icon {
    switch (announcement.style) {
      case AnnouncementStyle.info:
        return Icons.info_outline_rounded;
      case AnnouncementStyle.success:
        return Icons.check_circle_outline_rounded;
      case AnnouncementStyle.warning:
        return Icons.warning_amber_rounded;
      case AnnouncementStyle.danger:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(announcement.message, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onDismiss,
            child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.close_rounded, color: color, size: 16)),
          ),
        ],
      ),
    );
  }
}
