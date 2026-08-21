import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../utils/formatters.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = store.auditLog;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommandBand(
            title: 'سجل التدقيق',
            subtitle: 'سجل كامل لجميع العمليات والإجراءات التي تمت على المنصة',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: entries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد سجلات بعد', style: TextStyle(color: AppColors.textSecondary))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                          ),
                          title: Text(e.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(e.details, style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(e.userName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              Text(Formatters.timeAgo(e.timestamp), style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
