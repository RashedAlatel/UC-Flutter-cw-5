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
import '../theme/brand.dart';
import '../utils/formatters.dart';
import 'announcements_banner.dart';
import 'ministry_logo.dart';
import 'smart_alerts_banner.dart';

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
    final liveAlerts = store.liveProjectAlerts;
    final hasBanners = store.announcements.isNotEmpty || liveAlerts.isNotEmpty;

    final banners = Column(
      children: [
        AnnouncementsBanner(announcements: store.announcements),
        SmartAlertsBanner(alerts: liveAlerts),
      ],
    );

    final sidebar = _Sidebar(
      entries: entries,
      selected: selected,
      onSelect: (i) => setState(() => _selected = i),
    );

    // منطقة المحتوى مشتركة بين التخطيطين: شريط علوي رسمي يحمل عنوان الصفحة
    // والتاريخ، ثم التنبيهات، ثم الصفحة نفسها.
    Widget content({required bool showMenuButton}) => Column(
          children: [
            _TopBar(title: entries[selected].label, showMenuButton: showMenuButton),
            if (hasBanners)
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 14, wide ? 24 : 16, 0),
                child: banners,
              ),
            Expanded(
              child: wide
                  ? IndexedStack(index: selected, children: entries.map((e) => e.page).toList())
                  : entries[selected].page,
            ),
          ],
        );

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            sidebar,
            Expanded(child: content(showMenuButton: false)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.primary,
        child: sidebar,
      ),
      body: SafeArea(child: content(showMenuButton: true)),
    );
  }
}

/// الشريط العلوي الرسمي: عنوان الصفحة الحالية على اليمين، وهوية الوزارة
/// والتاريخ الهجري/الميلادي على اليسار — يمنح كل صفحة إطاراً رسمياً ثابتاً
/// بدل ظهور المحتوى مباشرة بلا ترويسة.
class _TopBar extends StatelessWidget {
  final String title;
  final bool showMenuButton;

  const _TopBar({required this.title, required this.showMenuButton});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 720;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 8 : 24, 12, compact ? 12 : 24, 12),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                tooltip: 'القائمة',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (!compact) ...[
            Text(
              Formatters.date(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 26, color: AppColors.border),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  Brand.ministry,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
                ),
                Text(
                  Brand.state,
                  style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          const MinistryLogo(size: 34),
        ],
      ),
    );
  }
}

/// الشريط الجانبي الرسمي: خلفية خضراء داكنة صلبة تحمل شعار الوزارة أعلاها،
/// عناصر التنقل بأيقونات، والعنصر المُحدَّد مميَّز بشريط ذهبي وخلفية فاتحة
/// شفافة — الطابع المعتمد في البوابات الحكومية.
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
      width: 252,
      decoration: BoxDecoration(gradient: AppColors.sidebarGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                children: [
                  const MinistryLogo(size: 54, onDark: true),
                  const SizedBox(height: 12),
                  const Text(
                    Brand.ministry,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Brand.state,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(height: 2, width: 44, color: AppColors.accent),
                  const SizedBox(height: 10),
                  Text(
                    Brand.platformShort,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final isSelected = i == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Material(
                      color: isSelected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          onSelect(i);
                          if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              // شريط ذهبي رفيع يميّز العنصر النشط.
                              Container(
                                width: 3,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                e.icon,
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.66),
                                size: 18,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  e.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.80),
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12.5,
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
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.accent,
                        radius: 16,
                        child: Text(
                          user != null && user.name.isNotEmpty ? user.name.substring(0, 1) : '؟',
                          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            Text(user?.role.label ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 10.5)),
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
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
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
