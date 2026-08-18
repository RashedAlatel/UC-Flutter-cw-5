import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/audit_log_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/decision_center_screen.dart';
import '../screens/department_detail_screen.dart';
import '../screens/departments_list_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/projects_list_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/roles_management_screen.dart';
import '../screens/user_management_screen.dart';
import '../theme/app_theme.dart';
import 'announcements_banner.dart';

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
    // "مدير المشروع" مقيَّد بمشروعه المُسنَد إليه فقط: لا لوحة قيادة، ولا
    // إدارات، ولا بقية المشاريع — فقط مشروعه (أو مشاريعه إن أُسنِد أكثر من واحد).
    if (store.isOfficer) {
      final myProjects = store.visibleProjects;
      if (myProjects.isEmpty) {
        return const [
          _NavEntry(label: 'مشروعي', icon: Icons.folder_off_outlined, page: _NoProjectAssignedView()),
        ];
      }
      return myProjects
          .map((p) => _NavEntry(
                label: p.name,
                icon: Icons.folder_copy_rounded,
                page: ProjectDetailScreen(projectId: p.id),
              ))
          .toList();
    }

    final entries = <_NavEntry>[
      const _NavEntry(label: 'لوحة القيادة', icon: Icons.dashboard_rounded, page: DashboardScreen()),
    ];

    if (store.canViewAllDepartments) {
      entries.add(const _NavEntry(
        label: 'الإدارات',
        icon: Icons.account_balance_rounded,
        page: DepartmentsListScreen(),
      ));
    } else if (store.isManager) {
      // مدير الإدارة قد يدير أكثر من إدارة واحدة، فنعرض له نفس شاشة "الإدارات"
      // (تُصفَّى تلقائياً عبر store.visibleDepartments) بدل صفحة إدارة واحدة ثابتة.
      entries.add(_NavEntry(
        label: store.myDepartmentIds.length > 1 ? 'إداراتي' : 'إدارتي',
        icon: Icons.account_balance_rounded,
        page: const DepartmentsListScreen(),
      ));
    } else if (store.currentUser?.departmentId != null) {
      entries.add(_NavEntry(
        label: 'إدارتي',
        icon: Icons.account_balance_rounded,
        page: DepartmentDetailScreen(departmentId: store.currentUser!.departmentId!),
      ));
    }

    entries.add(const _NavEntry(label: 'المشاريع', icon: Icons.folder_copy_rounded, page: ProjectsListScreen()));

    // مركز القرارات مخصص لمن يملك فعلياً صلاحية اعتماد قرار فيه (مسؤول النظام،
    // المستخدم التنفيذي، أو دور مخصص بصلاحية اعتماد القرارات العامة) — مدير
    // الإدارة ومدير المشروع يقدّمان الطلبات فقط ولا يعتمدان شيئاً هناك.
    if (store.isAdmin || store.isExecutive || (store.myCustomRole?.approveGeneralDecisions ?? false)) {
      entries.add(const _NavEntry(
        label: 'مركز القرارات',
        icon: Icons.gavel_rounded,
        page: DecisionCenterScreen(),
      ));
    }
    if (store.currentUser?.role != UserRole.projectOfficer) {
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
      entries.add(const _NavEntry(label: 'إدارة الأدوار', icon: Icons.badge_outlined, page: RolesManagementScreen()));
    }
    if (store.isAdmin) {
      entries.add(const _NavEntry(label: 'إعدادات المظهر', icon: Icons.palette_outlined, page: AppearanceSettingsScreen()));
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
      floating: wide,
    );

    if (wide) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.pageGradient),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: sidebar,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: AppColors.background,
                      child: Column(
                        children: [
                          if (store.announcements.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: AnnouncementsBanner(announcements: store.announcements),
                            ),
                          Expanded(
                            child: IndexedStack(
                              index: selected,
                              children: entries.map((e) => e.page).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(entries[selected].label),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      drawer: Drawer(child: sidebar),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: AppColors.background,
                child: Column(
                  children: [
                    if (store.announcements.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: AnnouncementsBanner(announcements: store.announcements),
                      ),
                    Expanded(child: entries[selected].page),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة بيضاء عائمة (بدل شريط جانبي داكن ملتصق بالحافة)، بحسب التصميم
/// المرجعي المعتمد: شعار المنصة أعلاها، عناصر التنقل بأيقونات، العنصر
/// المُحدَّد بخلفية داكنة صلبة بلون الهوية، وزر تسجيل الخروج أسفلها.
class _Sidebar extends StatelessWidget {
  final List<_NavEntry> entries;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool floating;

  const _Sidebar({required this.entries, required this.selected, required this.onSelect, required this.floating});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: floating ? BorderRadius.circular(22) : null,
        boxShadow: floating
            ? [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 8))]
            : null,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: AppColors.pageGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'المنصة التنفيذية',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final isSelected = i == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          onSelect(i);
                          if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(e.icon, color: isSelected ? Colors.white : AppColors.textSecondary, size: 19),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13,
                                  ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.accent,
                        radius: 16,
                        child: Text(
                          user != null && user.name.isNotEmpty ? user.name.substring(0, 1) : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            Text(user?.role.label ?? '',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => store.logout(),
                      icon: const Icon(Icons.logout_rounded, size: 15),
                      label: const Text('تسجيل الخروج'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
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

class _NoProjectAssignedView extends StatelessWidget {
  const _NoProjectAssignedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 40, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('لم يتم تعيينك مديراً لأي مشروع بعد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            SizedBox(height: 6),
            Text('تواصل مع مسؤول النظام ليعيّنك على مشروع.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
