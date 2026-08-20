import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department_section.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/kpi_card.dart';
import '../widgets/section_picker.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'daily_update_form.dart';
import 'project_detail_screen.dart';
import 'request_project_dialog.dart';

class DepartmentDetailScreen extends StatelessWidget {
  final String departmentId;
  const DepartmentDetailScreen({super.key, required this.departmentId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(departmentId);
    if (dept == null) {
      return const Center(child: Text('الإدارة غير موجودة'));
    }
    final projects = store.projectsForDepartment(departmentId);
    final progress = store.departmentProgress(departmentId);
    final delay = store.departmentAvgDelay(departmentId);
    final risks = store.departmentRiskCount(departmentId);
    final blockers = store.departmentBlockerCount(departmentId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: dept.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(dept.icon, color: dept.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('مسؤول الإدارة: ${dept.headName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              if (store.canRequestNewProject(departmentId))
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => RequestProjectDialog(departmentId: departmentId),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(store.isAdmin ? 'إضافة مشروع' : 'طلب إضافة مشروع'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 520 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.6,
              children: [
                KpiCard(title: 'نسبة الإنجاز', value: Formatters.percent(progress), icon: Icons.trending_up_rounded, color: AppColors.success),
                KpiCard(title: 'متوسط التأخير', value: '${delay.toStringAsFixed(1)} يوم', icon: Icons.schedule_rounded, color: AppColors.warning),
                KpiCard(title: 'مخاطر قائمة', value: '$risks', icon: Icons.warning_amber_rounded, color: AppColors.danger),
                KpiCard(title: 'عوائق نشطة', value: '$blockers', icon: Icons.block_rounded, color: const Color(0xFFE0692B)),
              ],
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('الأقسام والمشاريع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              if (store.canManageSections(departmentId))
                OutlinedButton.icon(
                  onPressed: () => _showSectionNameDialog(
                    context,
                    title: 'إضافة قسم',
                    onSubmit: (name) => store.addSection(departmentId: departmentId, name: name),
                  ),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                  label: const Text('إضافة قسم'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (projects.isEmpty && store.sectionsOf(departmentId).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('لا توجد مشاريع لهذه الإدارة بعد', style: TextStyle(color: AppColors.textSecondary)),
            )
          else ...[
            ...store.sectionsOf(departmentId).map((s) => _SectionBlock(section: s, dept: dept)),
            _LooseProjects(departmentId: departmentId, dept: dept),
          ],
        ],
      ),
    );
  }
}

/// نافذة صغيرة لإدخال اسم قسم (إضافة أو إعادة تسمية).
Future<void> _showSectionNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  required Future<void> Function(String name) onSubmit,
}) async {
  final ctrl = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'اسم القسم'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('حفظ')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  await onSubmit(name);
}

/// قسم واحد في الشجرة: عنوانه وعدّاده وأدوات إدارته، ثم مشاريعه المباشرة،
/// ثم أقسامه الفرعية بإزاحة بصرية تُظهر أنها تحته.
class _SectionBlock extends StatelessWidget {
  final DepartmentSection section;
  final dynamic dept;
  final bool nested;
  const _SectionBlock({required this.section, required this.dept, this.nested = false});

  Future<void> _confirmDelete(BuildContext context, AppStore store) async {
    final direct = store.projectsInSection(section.id, includeDescendants: true).length;
    final children = store.sectionsOf(section.departmentId, parentId: section.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف قسم "${section.name}"'),
        content: Text(
          children == 0 && direct == 0
              ? 'القسم فارغ وسيُحذف نهائياً.'
              : 'سيُحذف القسم فقط. ما بداخله لن يُحذف: '
                  '${direct > 0 ? '$direct مشروعاً' : ''}'
                  '${direct > 0 && children > 0 ? ' و' : ''}'
                  '${children > 0 ? '$children قسماً فرعياً' : ''}'
                  ' سيُنقل إلى المستوى الأعلى.',
          style: const TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف القسم'),
          ),
        ],
      ),
    );
    if (ok == true) await store.deleteSection(section);
  }

  /// نقل القسم بكامل فرعه إلى إدارة أخرى. النافذة تذكر بالضبط ما سينتقل معه
  /// قبل التأكيد، لأن النقل يغيّر من يرى هذه المشاريع ومن يعدّلها.
  Future<void> _confirmMove(BuildContext context, AppStore store) async {
    final targets = store.departments.where((d) => d.id != section.departmentId).toList();
    if (targets.isEmpty) return;
    final projectCount = store.projectsInSection(section.id).length;
    final childCount = store.sectionWithDescendants(section.id).length - 1;
    String? targetId;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('نقل قسم "${section.name}" إلى إدارة أخرى'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سينتقل القسم ومعه $childCount قسماً فرعياً و$projectCount مشروعاً. '
                  'لن يُحذف شيء، لكن من يرى هذه المشاريع ومن يعدّلها سيتغيّر تبعاً للإدارة الجديدة.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: targetId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الإدارة المستقبِلة'),
                  items: targets.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                  onChanged: (v) => setLocal(() => targetId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: targetId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('نقل القسم'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || targetId == null) return;
    final error = await store.moveSectionToDepartment(section, targetId!);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'تم نقل القسم وكل ما تحته'),
      backgroundColor: error == null ? null : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canManage = store.canManageSections(section.departmentId);
    final own = store.projectsInSection(section.id, includeDescendants: false);
    final total = store.projectsInSection(section.id).length;
    final children = store.sectionsOf(section.departmentId, parentId: section.id);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: nested ? 18 : 0, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: nested ? 0.04 : 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(nested ? Icons.subdirectory_arrow_left_rounded : Icons.folder_rounded,
                    size: nested ? 16 : 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(section.name,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: nested ? 13 : 14.5)),
                ),
                Text('$total مشروعاً',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                if (canManage)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    onSelected: (v) {
                      switch (v) {
                        case 'rename':
                          _showSectionNameDialog(context,
                              title: 'إعادة تسمية القسم',
                              initial: section.name,
                              onSubmit: (n) => store.renameSection(section, n));
                        case 'child':
                          _showSectionNameDialog(context,
                              title: 'إضافة قسم فرعي تحت "${section.name}"',
                              onSubmit: (n) => store.addSection(
                                  departmentId: section.departmentId, parentId: section.id, name: n));
                        case 'move':
                          _confirmMove(context, store);
                        case 'delete':
                          _confirmDelete(context, store);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('إعادة التسمية')),
                      if (store.canAddChildSection(section))
                        const PopupMenuItem(value: 'child', child: Text('إضافة قسم فرعي')),
                      // نقل القسم بين الإدارات لمسؤول النظام وحده.
                      if (store.canMoveSectionAcrossDepartments)
                        const PopupMenuItem(value: 'move', child: Text('نقل القسم إلى إدارة أخرى')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('حذف القسم', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
              ],
            ),
          ),
          ...own.map((p) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: _ProjectCard(project: p, dept: dept),
              )),
          ...children.map((c) => _SectionBlock(section: c, dept: dept, nested: true)),
        ],
      ),
    );
  }
}

/// مشاريع الإدارة غير المُسنَدة لأي قسم. لا يظهر العنوان إلا حين توجد أقسام
/// فعلاً — على الإدارات التي لا تستخدم الأقسام تبقى الشاشة كما كانت.
class _LooseProjects extends StatelessWidget {
  final String departmentId;
  final dynamic dept;
  const _LooseProjects({required this.departmentId, required this.dept});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final loose = store.projectsWithoutSection(departmentId);
    if (loose.isEmpty) return const SizedBox.shrink();
    final hasSections = store.sectionsOf(departmentId).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSections)
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 10),
            child: Text('مشاريع بلا قسم',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textSecondary)),
          ),
        ...loose.map((p) => _ProjectCard(project: p, dept: dept)),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final dynamic dept;
  const _ProjectCard({required this.project, required this.dept});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canEdit = store.canEditProject(project);
    final taskCount = store.tasksForProject(project.id).length;
    final doneCount = store.tasksForProject(project.id).where((t) => t.status.name == 'done').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(project.name)),
            body: ProjectDetailScreen(projectId: project.id),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(project.description,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(status: project.effectiveStatus),
                  if (store.canManageSections(project.departmentId))
                    IconButton(
                      tooltip: 'نقل المشروع إلى قسم',
                      icon: const Icon(Icons.drive_file_move_outline, size: 18),
                      onPressed: () => showMoveProjectToSectionDialog(context, project),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InfoBit(icon: Icons.flag_outlined, text: project.priority.label),
                  if (project.executorNames.isNotEmpty)
                    _InfoBit(icon: Icons.badge_outlined, text: 'المنفذ: ${project.executorLabel}'),
                  _InfoBit(icon: Icons.event_outlined, text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  _InfoBit(
                    icon: Icons.schedule_rounded,
                    text: project.delayDays > 0 ? 'متأخر ${project.delayDays} يوم' : 'ضمن الجدول الزمني',
                    color: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                  ),
                  _InfoBit(icon: Icons.checklist_rounded, text: 'المهام: $doneCount / $taskCount'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(project.name)),
                        body: ProjectDetailScreen(projectId: project.id),
                      ),
                    )),
                    icon: const Icon(Icons.view_kanban_outlined, size: 18),
                    label: const Text('لوحة المهام'),
                  ),
                  const SizedBox(width: 10),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => DailyUpdateForm(project: project),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('تحديث يومي'),
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
