import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/archived_items_screen.dart';
import '../screens/audit_log_screen.dart';
import '../screens/daily_report_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/decision_center_screen.dart';
import '../screens/department_detail_screen.dart';
import '../screens/departments_list_screen.dart';
import '../screens/people_tracking_screen.dart';
import '../screens/my_assignments_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/projects_list_screen.dart';
import '../screens/registration_settings_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/role_permissions_screen.dart';
import '../screens/roles_management_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/work_detail_screen.dart';
import '../screens/works_list_screen.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../utils/formatters.dart';
import 'announcements_banner.dart';
import 'data_access_banner.dart';
import 'ministry_logo.dart';
import 'nav_entries.dart';
import 'smart_alerts_banner.dart';
import 'update_banner.dart';

class _NavEntry {
  final NavKey key;
  final Widget page;
  const _NavEntry({required this.key, required this.page});

  String get label => key.label;
  IconData get icon => _navIcons[key]!;
}

/// أيقونة كل مدخل. في خريطةٍ هنا لا في `NavKey` نفسه: تلك ملفٌّ خالٍ من
/// Flutter عمداً ليبقى قابلاً للاختبار.
const Map<NavKey, IconData> _navIcons = {
  NavKey.dashboard: Icons.dashboard_rounded,
  NavKey.departments: Icons.account_balance_rounded,
  NavKey.myDepartments: Icons.account_balance_rounded,
  NavKey.myDepartment: Icons.account_balance_rounded,
  NavKey.projects: Icons.folder_copy_rounded,
  NavKey.works: Icons.checklist_rounded,
  NavKey.myAssignments: Icons.assignment_ind_outlined,
  NavKey.decisions: Icons.gavel_rounded,
  NavKey.dailyReport: Icons.wb_twilight_rounded,
  NavKey.reports: Icons.assessment_rounded,
  NavKey.feedback: Icons.forum_outlined,
  NavKey.people: Icons.groups_rounded,
  NavKey.auditLog: Icons.history_rounded,
  NavKey.archived: Icons.restore_from_trash_rounded,
  NavKey.users: Icons.manage_accounts_rounded,
  NavKey.roles: Icons.badge_outlined,
  NavKey.rolePermissions: Icons.key_rounded,
  NavKey.registration: Icons.how_to_reg_outlined,
  NavKey.appearance: Icons.palette_outlined,
};

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  /// هل عولج رابط `?project=` الوارد من بريد التنبيه؟
  ///
  /// ــــ لماذا علَمٌ ومحاولةٌ واحدة؟ ــــ
  ///
  /// لأن `build` يُنادى مع كل تحديث من Firestore. وبلا علَم يُعاد فتح صفحة
  /// المشروع فوق نفسها عشرات المرات، فيجد المستخدم كومةً من الشاشات لا يخرج
  /// منها بزرّ الرجوع.
  ///
  /// وتُؤجَّل المحاولة حتى تصل المشاريع: الرابط يُفتح والتطبيق لم يُحمّل
  /// شيئاً بعد، فلو حُكم عليه لحظتها لقيل «المشروع غير موجود» وهو موجود.
  bool _deepLinkDone = false;

  /// يفتح المشروع أو العمل الوارد في عنوان الصفحة — رابط بريد التنبيه.
  void _openDeepLinkedProject(AppStore store) {
    if (_deepLinkDone) return;
    // `?work=` نظير `?project=`: إخطارات دورة الإغلاق تشير إلى **عمل** لا
    // مشروع، ورابطٌ يفتح الصفحة الرئيسة يترك المستخدم يبحث عمّا أُخطر به.
    final workId = Uri.base.queryParameters['work'];
    if (workId != null && workId.isNotEmpty) {
      if (store.works.isEmpty) return;
      _deepLinkDone = true;
      final work = store.works.where((w) => w.id == workId).firstOrNull;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (work == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              'العمل الذي يشير إليه الرابط غير متاح لك — قد يكون خارج نطاقك أو حُذف.',
            ),
          ));
          return;
        }
        openWorkDetail(context, work);
      });
      return;
    }
    final id = Uri.base.queryParameters['project'];
    if (id == null || id.isEmpty) {
      _deepLinkDone = true;
      return;
    }
    if (store.projects.isEmpty) return; // لم تصل البيانات بعد — تُعاد المحاولة.
    _deepLinkDone = true;
    final project = store.projects.where((p) => p.id == id).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (project == null) {
        // لا صمت: من فتح رابطاً من بريدٍ رسمي ولم يقع شيء يظنّ المنصة معطّلة.
        // والسبب الغالب أن المشروع خارج نطاقه لا أنه محذوف — فيُقال الاثنان.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'المشروع الذي يشير إليه الرابط غير متاح لك — قد يكون خارج نطاق '
            'إدارتك أو حُذف.',
          ),
        ));
        return;
      }
      openProjectDetail(context, project);
    });
  }

  /// يترجم مفاتيح القائمة إلى صفحاتها.
  ///
  /// والقرار — من يرى ماذا — في `nav_entries.dart` لا هنا: هذا الملف يستورد
  /// كل شاشة، ومنها ما يستورد `package:web`، فلا يُستورَد من اختبار. وترْكُ
  /// القرار فيه يجعل كل شرطٍ في القائمة خارج مدى أي حارس — وقد حجب ذلك
  /// «المُسنَد إليّ» عن مسؤول النظام دون أن يصيح شيء.
  List<_NavEntry> _buildEntries(AppStore store) {
    return [
      for (final key in navKeysFor(store)) _NavEntry(key: key, page: _pageFor(key, store)),
    ];
  }

  Widget _pageFor(NavKey key, AppStore store) {
    switch (key) {
      case NavKey.dashboard:
        return const DashboardScreen();
      case NavKey.departments:
      case NavKey.myDepartments:
        return const DepartmentsListScreen();
      case NavKey.myDepartment:
        // مدير إدارة واحدة يرى شاشة «الإدارات» مصفّاةً؛ وغيرُه يرى صفحة
        // إدارته مباشرةً.
        return store.isManager
            ? const DepartmentsListScreen()
            : DepartmentDetailScreen(departmentId: store.currentUser!.departmentId!);
      case NavKey.projects:
        return const ProjectsListScreen();
      case NavKey.works:
        return const WorksListScreen();
      case NavKey.myAssignments:
        return const MyAssignmentsScreen();
      case NavKey.decisions:
        return const DecisionCenterScreen();
      case NavKey.dailyReport:
        return const DailyReportScreen();
      case NavKey.reports:
        return const ReportsScreen();
      case NavKey.feedback:
        return const FeedbackScreen();
      case NavKey.people:
        return const PeopleTrackingScreen();
      case NavKey.auditLog:
        return const AuditLogScreen();
      case NavKey.archived:
        return const ArchivedItemsScreen();
      case NavKey.users:
        return const UserManagementScreen();
      case NavKey.roles:
        return const RolesManagementScreen();
      case NavKey.rolePermissions:
        return const RolePermissionsScreen();
      case NavKey.registration:
        return const RegistrationSettingsScreen();
      case NavKey.appearance:
        return const AppearanceSettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    _openDeepLinkedProject(store);
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
            // شريط التحديث يسبق بقية الأشرطة: إن كان المستخدم على نسخة قديمة
            // فقد يكون كل ما يراه قديماً، فالأولى أن ينتبه له أولاً. يُخفي
            // نفسه ويحمل هوامشه بنفسه، فلا يترك فراغاً حين لا يوجد تحديث.
            UpdateBanner(horizontalPadding: wide ? 24 : 16),
            // لافتة رفض القراءة تسبق كل شيء عدا التحديث: حين ترفض قواعد
            // الخادم قراءة بيانات المستخدم تظهر له المنصة **خاليةً بلا أي
            // رسالة**، فيظن أن لا بيانات بينما هي محجوبة عنه. وهذا ما وقع
            // لمدير إدارة لم يرَ مشاريعه ولا حتى التعميمات العامة.
            if (store.hasDataErrors)
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, wide ? 24 : 16, 0),
                child: const DataAccessBanner(),
              ),
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
          const MinistryLogo(size: 42),
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
                  const MinistryLogo(size: 68, onDark: true),
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
                  const SizedBox(height: 8),
                  // بصمة البناء: تجعل سؤال "هل النسخة محدّثة؟" قابلاً للإجابة
                  // بنظرة واحدة بدل التخمين.
                  Text('إصدار $buildLabel',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 9.5)),
                  const SizedBox(height: 8),
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

