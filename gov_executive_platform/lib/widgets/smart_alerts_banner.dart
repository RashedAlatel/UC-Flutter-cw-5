import 'package:flutter/material.dart';

import '../models/alert_rules.dart';
import '../models/announcement.dart';
import '../screens/project_detail_screen.dart';
import '../theme/app_theme.dart';
import 'progress_bar.dart';
import 'status_chip.dart';

/// شريط التنبيهات الذكية التلقائية (محسوبة حيّة من بيانات المشاريع حسب
/// إعدادات مسؤول النظام في "إعدادات المظهر") — يظهر أعلى كل صفحة، والضغط
/// على أي تنبيه يعرض قائمة المشاريع المطابقة له.
class SmartAlertsBanner extends StatelessWidget {
  final List<ProjectAlertGroup> alerts;
  const SmartAlertsBanner({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      children: alerts
          .map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertBar(group: g),
              ))
          .toList(),
    );
  }
}

class _AlertBar extends StatelessWidget {
  final ProjectAlertGroup group;
  const _AlertBar({required this.group});

  Color get _color {
    switch (group.style) {
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
    switch (group.style) {
      case AnnouncementStyle.info:
        return Icons.info_outline_rounded;
      case AnnouncementStyle.success:
        return Icons.check_circle_outline_rounded;
      case AnnouncementStyle.warning:
        return Icons.schedule_rounded;
      case AnnouncementStyle.danger:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showPeek(context),
      child: Container(
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
              child: Text(group.title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            Icon(Icons.chevron_left_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPeek(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Expanded(child: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: group.projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = group.projects[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(p.name)),
                              body: ProjectDetailScreen(projectId: p.id),
                            ),
                          ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                  StatusChip(status: p.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LabeledProgressBar(value: p.progressPercent, label: 'نسبة الإنجاز'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
