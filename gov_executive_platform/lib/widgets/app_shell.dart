import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../screens/audit_log_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/decision_center_screen.dart';
import '../screens/department_detail_screen.dart';
import '../screens/departments_list_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/user_management_screen.dart';
import '../theme/app_theme.dart';

class _NavEntry {
  final String label;
  final IconData icon;
  final Widget page;
  const _NavEntry({required this.label, required this.icon, required this.page});
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  List<_NavEntry> _buildEntries(AppStore store) {
    final entries = <_NavEntry>[
      const _NavEntry(label: 'لوحة القيادة', icon: Icons.dashboard_rounded, page: DashboardScreen()),
    ];

    if (store.canViewAllDepartments) {
      entries.add(const _NavEntry(
        label: 'الإدارات',
        icon: Icons.account_balance_rounded,
        page: DepartmentsListScreen(),
      ));
    } else if (store.currentUser?.departmentId != null) {
      entries.add(_NavEntry(
        label: 'إدارتي',
        icon: Icons.account_balance_rounded,
        page: DepartmentDetailScreen(departmentId: store.currentUser!.departmentId!),
      ));
    }

    if (store.currentUser?.role != UserRole.projectOfficer) {
      entries.add(const _NavEntry(
        label: 'مركز القرارات',
        icon: Icons.gavel_rounded,
        page: DecisionCenterScreen(),
      ));
      entries.add(const _NavEntry(
        label: 'التقارير',
        icon: Icons.assessment_rounded,
        page: ReportsScreen(),
      ));
    }

    if (store.canViewAuditLog) {
      entries.add(const _NavEntry(label: 'سجل التدقيق', icon: Icons.history_rounded, page: AuditLogScreen()));
    }
    if (store.canManageUsers) {
      entries.add(const _NavEntry(label: 'المستخدمون', icon: Icons.manage_accounts_rounded, page: UserManagementScreen()));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = _buildEntries(store);
    final selected = _selected.clamp(0, entries.length - 1);
    final wide = MediaQuery.of(context).size.width >= 980;

    final sidebar = _Sidebar(
      entries: entries,
      selected: selected,
      onSelect: (i) => setState(() => _selected = i),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: IndexedStack(
                      index: selected,
                      children: entries.map((e) => e.page).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(entries[selected].label)),
      drawer: Drawer(child: sidebar),
      body: entries[selected].page,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavEntry> entries;
  final int selected;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.entries, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    return Container(
      width: 260,
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المنصة التنفيذية الحكومية',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final isSelected = i == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          onSelect(i);
                          if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Icon(e.icon, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                e.label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accent,
                    radius: 18,
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name.substring(0, 1) : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(user?.role.label ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تسجيل الخروج',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                    onPressed: () => store.logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(_todayLabel(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(store.currentUser?.role.label ?? '',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
