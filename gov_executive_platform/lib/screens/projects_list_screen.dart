import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets_section.dart';
import '../widgets/progress_bar.dart';
import '../widgets/project_actions.dart';
import '../widgets/status_chip.dart';
import 'project_detail_screen.dart';
import 'request_project_dialog.dart';

/// شاشة موحّدة لعرض جميع المشاريع (ضمن النطاق المسموح به للمستخدم) بمعزل
/// عن التنقل عبر الإدارات، مع فلاتر حسب الإدارة والشخص المنفذ.
class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _departmentFilter;
  String? _executorFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// يعرض ما سيتغيّر **قبل** أن يتغيّر: تعديل عشرات المستندات دفعةً واحدة
  /// دون أن يرى مسؤول النظام ماذا سيمسّه ليس قراراً بل مقامرة.
  Future<void> _reconcileStatuses(BuildContext context, AppStore store) async {
    final stale = store.projectsWithStaleStatus;
    final sample = stale.take(5).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مطابقة الحالات المخزّنة'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stale.length} مشروعاً حالته المخزّنة تخالف تاريخ استحقاقه. '
                  'المنصة تعرض الحالة الصحيحة أصلاً؛ هذه المطابقة تكتبها في السجل '
                  'حتى تتفق معها التقارير المُصدَّرة.',
                  style: const TextStyle(fontSize: 13, height: 1.9, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                for (final p in sample)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${p.name}: ${p.status.label} ← ${p.effectiveStatus.label}',
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                  ),
                if (stale.length > sample.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('و${stale.length - sample.length} غيرها…',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('طابِق')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = await store.reconcileProjectStatuses();
    messenger.showSnackBar(SnackBar(content: Text('طوبقت حالة $count مشروعاً.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var projects = store.visibleProjects;

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      projects = projects
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.executorNames.any((e) => e.toLowerCase().contains(q)))
          .toList();
    }
    if (_departmentFilter != null) {
      projects = projects.where((p) => p.departmentId == _departmentFilter).toList();
    }
    if (_executorFilter != null) {
      projects = projects.where((p) => p.executorNames.contains(_executorFilter)).toList();
    }
    projects = projects.toList()..sort((a, b) => a.name.compareTo(b.name));

    final departmentOptions = store.visibleDepartments.where((d) => store.projectsForDepartment(d.id).isNotEmpty).toList();
    final executorOptions = store.visibleProjects.expand((p) => p.executorNames).toSet().toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المشاريع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('كل المشاريع ضمن نطاقك، بمعزل عن التنقل عبر الإدارات', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              // مطابقة الحالات المخزّنة مع تواريخ الاستحقاق.
              //
              // العرض يستعمل الحالة الفعلية دائماً، فالمنصة متسقة بدون هذا
              // الزر. لكن الحقل المخزَّن يخرج مع التقارير المُصدَّرة ويقرؤه
              // أي نظام آخر، فمطابقته تمنع أن يقرأ الخارج حالةً غير التي
              // يراها المستخدم على الشاشة.
              if (store.isAdmin && store.projectsWithStaleStatus.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _reconcileStatuses(context, store),
                  icon: const Icon(Icons.rule_rounded, size: 18),
                  label: Text('مطابقة ${store.projectsWithStaleStatus.length} حالة مخزّنة'),
                ),
                const SizedBox(width: 10),
              ],
              if (store.isAdmin)
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const RequestProjectDialog()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مشروع'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المشروع أو المنفذ',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _departmentFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب الإدارة', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                    ...departmentOptions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _departmentFilter = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _executorFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب المنفذ', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المنفذين')),
                    ...executorOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  ],
                  onChanged: (v) => setState(() => _executorFilter = v),
                ),
              ),
              if (_departmentFilter != null || _executorFilter != null || _query.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _departmentFilter = null;
                    _executorFilter = null;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('مسح الفلاتر'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('${projects.length} مشروع', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // «لا توجد مشاريع مطابقة» جوابٌ خاطئ حين لا يكون للحساب إدارة أصلاً:
          // نطاق المستخدم عندها **فارغ بنيوياً** لا مُصفّى، فيبحث عن عطل ليس
          // موجوداً. ونفرّق كذلك بين نطاق خالٍ وتصفية لم تطابق شيئاً.
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_off_outlined, size: 34, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      store.myDepartmentIds.isEmpty && !store.canViewAllDepartments
                          ? 'لا توجد إدارة مرتبطة بحسابك'
                          : (store.visibleProjects.isEmpty
                              ? 'لا توجد مشاريع في نطاقك بعد'
                              : 'لا توجد مشاريع مطابقة لبحثك'),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    if (store.myDepartmentIds.isEmpty && !store.canViewAllDepartments) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'مشاريعك تُعرض بحسب إدارتك. اطلب من مسؤول النظام ربط حسابك بإدارتك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...projects.map((p) => _ProjectRow(project: p)),
          const SizedBox(height: 28),
          CustomWidgetsSection(
            store: store,
            widgets: store.projectsPageWidgets,
            onSave: store.saveProjectsPageWidgets,
            canManage: store.canManageDashboard,
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(project.departmentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(project.name)),
            body: ProjectDetailScreen(projectId: project.id),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        if (dept != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(dept.icon, size: 12, color: dept.color),
                              const SizedBox(width: 4),
                              Text(dept.name, style: TextStyle(fontSize: 11.5, color: dept.color, fontWeight: FontWeight.w700)),
                            ],
                          )
                        else
                          const Text('بدون إدارة', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  StatusChip(status: project.effectiveStatus),
                  if (store.isAdmin) ...[
                    IconButton(
                      icon: Icon(
                        store.isFocused(project.id) ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 19,
                        color: store.isFocused(project.id) ? AppColors.accent : AppColors.textSecondary,
                      ),
                      tooltip: store.isFocused(project.id) ? 'إزالة من التركيز' : 'وضع تحت التركيز',
                      onPressed: () => store.toggleFocusedProject(project),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                      tooltip: 'حذف المشروع',
                      onPressed: () => confirmDeleteProject(context, project),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (project.executorNames.isNotEmpty)
                    _InfoBit(icon: Icons.badge_outlined, text: 'المنفذ: ${project.executorLabel}'),
                  _InfoBit(icon: Icons.event_outlined, text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  _InfoBit(
                    icon: Icons.schedule_rounded,
                    text: project.delayDays > 0 ? 'متأخر ${project.delayDays} يوم' : 'ضمن الجدول الزمني',
                    color: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoBit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
