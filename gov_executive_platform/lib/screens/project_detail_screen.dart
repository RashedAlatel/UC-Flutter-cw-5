import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/assignment_policy.dart';
import '../models/closure_trail.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_header_row.dart';
import '../widgets/project_team_card.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/custom_widgets_section.dart';
import '../widgets/day_updates_dialog.dart';
import '../widgets/executors_field.dart';
import '../widgets/progress_bar.dart';
import '../models/notify_templates.dart';
import '../widgets/focus_assignment_dialog.dart';
import '../widgets/notify_dialog.dart';
import '../widgets/project_actions.dart';
import '../models/daily_update.dart';
import '../widgets/month_calendar.dart' show dayOnly;
import '../widgets/updates_calendar.dart';
import '../widgets/section_picker.dart';
import '../widgets/status_chip.dart';
import 'daily_update_form.dart';
import 'request_deadline_change_dialog.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  /// يحوّل سجل التحديثات إلى خلاصة يومٍ لكل يوم — وهو ما يقرؤه التقويم.
  ///
  /// واليوم الذي فيه أكثر من تحديث يُعرض بأحدثها ويُقال كم فيه: التقويم
  /// نظرةٌ لا سجل، والسجل كامل تحته.
  Map<DateTime, DayDigest> _digestsOf(List<DailyUpdate> updates) {
    final byDay = <DateTime, List<DailyUpdate>>{};
    for (final u in updates) {
      byDay.putIfAbsent(dayOnly(u.date), () => []).add(u);
    }
    return {
      for (final entry in byDay.entries)
        entry.key: () {
          final sorted = entry.value..sort((a, b) => b.date.compareTo(a.date));
          final latest = sorted.first;
          // الملخّص أول سطرٍ ممّا كُتب: البطاقة تُقرأ بلمحة، والنصّ الكامل
          // في السجل.
          final firstLine = latest.achievements.trim().split('\n').first.trim();
          return DayDigest(
            day: entry.key,
            summary: firstLine,
            count: sorted.length,
            progress: latest.progressPercent,
            // العائق علامةٌ حمراء: هو ما يحتاج قراراً، ولا يجوز أن يختفي
            // بين سطور السجل.
            hasBlocker: sorted.any((u) => u.blockers.isNotEmpty),
          );
        }(),
    };
  }

  /// يفتح يوماً من التقويم: **ما جرى فيه**، لا نموذجَ إضافةٍ فارغاً.
  ///
  /// وكان الأمر معكوساً: من يملك التحرير — أي مدير المشروع نفسه — يُقذف إلى
  /// النموذج ولا يرى ما كُتب في ذلك اليوم، ومن لا يملكه يرى السرد. فصاحبُ
  /// المشروع وحده هو المحروم من سجلّه. راجع [DayUpdatesDialog].
  void _openDay(BuildContext context, Project project, DateTime day) {
    showDialog(
      context: context,
      builder: (_) => DayUpdatesDialog(project: project, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final project = store.projectById(projectId);
    if (project == null) return const Center(child: Text('المشروع غير موجود'));
    final dept = store.departmentById(project.departmentId);
    final canEdit = store.canEditProject(project);
    final risks = store.risksForProject(projectId).where((r) => r.status == ItemStatus.open).toList();
    final blockers = store.blockersForProject(projectId).where((b) => b.status == ItemStatus.open).toList();
    final updates = store.updatesForProject(projectId);
    final tasks = store.tasksForProject(projectId);
    store.ensureProjectWidgetsSubscribed(projectId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveHeaderRow(
                    title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            // مسار المشروع كاملاً: الإدارة ثم القسم فالقسم
                            // الفرعي إن وُجدا، ليعرف القارئ موقعه في الهيكل
                            // دون العودة لصفحة الإدارة.
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    [dept?.name ?? 'بدون إدارة', store.sectionPathLabel(project.sectionId)]
                                        .where((e) => e.isNotEmpty)
                                        .join(' ← '),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                  ),
                                ),
                                // نقل المشروع بين أقسام إدارته من صفحته نفسها،
                                // لا من صفحة الإدارة وحدها.
                                if (store.canManageSections(project.departmentId))
                                  IconButton(
                                    icon: const Icon(Icons.drive_file_move_outline, size: 17),
                                    tooltip: 'تغيير قسم المشروع',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => showMoveProjectToSectionDialog(context, project),
                                  ),
                              ],
                            ),
                    ],
                    ),
                    actions: [
                      StatusChip(status: project.effectiveStatus),
                      if (store.canSendNotifications)
                        IconButton(
                          icon: Icon(Icons.forward_to_inbox_rounded, size: 20, color: AppColors.primary),
                          tooltip: 'مراسلة فريق المشروع',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => NotifyDialog(
                              initialUsers: store.recipientsForProject(project),
                              context: NotifyContext.fromProject(project),
                            ),
                          ),
                        ),
                      if (store.isAdmin)
                        IconButton(
                          icon: Icon(
                            store.isFocused(project.id) ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 20,
                            color: store.isFocused(project.id) ? AppColors.accent : AppColors.textSecondary,
                          ),
                          tooltip: store.isFocused(project.id) ? 'إزالة من التركيز' : 'وضع تحت التركيز',
                          onPressed: () => store.toggleFocusedProject(project),
                        ),
                      if (store.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.push_pin_outlined, size: 20, color: AppColors.textSecondary),
                          tooltip: 'عرض في لوحة قيادة مستخدم',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => FocusAssignmentDialog(projectId: project.id, title: project.name),
                          ),
                        ),
                      if (store.canSoftDeleteProject(project))
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                          tooltip: 'حذف المشروع',
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final deleted = await confirmDeleteProject(context, project);
                            // بعد الحذف لم يعد لهذه الصفحة مشروع تعرضه، فنعود
                            // للخلف إن كانت مفتوحة فوق صفحة أخرى.
                            if (deleted && navigator.canPop()) navigator.pop();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(project.description, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.6)),
                  const SizedBox(height: 16),
                  LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز الكلية', height: 10),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 22,
                    runSpacing: 10,
                    children: [
                      _MetaBit(icon: Icons.flag_outlined, label: 'الأولوية', child: PriorityChip(priority: project.priority)),
                      _MetaBit(
                        icon: Icons.badge_outlined,
                        label: 'المنفذون',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              project.executorNames.isEmpty ? 'بدون تعيين' : project.executorLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            if (canEdit) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => _EditExecutorsDialog(project: project),
                                ),
                                child: Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // العدد لا الاسم المفرد: للمشروع أكثر من مدير الآن،
                      // والتعديل صار من بطاقة «فريق المشروع» أدناه.
                      _MetaBit(
                        icon: Icons.manage_accounts_outlined,
                        label: project.managerUids.length > 1 ? 'مديرو المشروع' : 'مدير المشروع',
                        value: project.managerUids.isEmpty
                            ? 'لم يُعيَّن بعد'
                            : project.managerUids.length == 1
                                ? _managerName(store, project.managerUids.first)
                                : '${_managerName(store, project.managerUids.first)} و${project.managerUids.length - 1} غيره',
                      ),
                      _MetaBit(icon: Icons.event_outlined, label: 'تاريخ البدء', value: Formatters.shortDate(project.startDate)),
                      _MetaBit(
                        icon: Icons.event_available_outlined,
                        label: 'تاريخ الاستحقاق',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.shortDate(project.dueDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            if (canEdit) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => RequestDeadlineChangeDialog(project: project),
                                ),
                                child: Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _MetaBit(
                        icon: Icons.schedule_rounded,
                        label: 'التأخير عن الخطة',
                        value: project.delayDays > 0 ? '${project.delayDays} يوم' : 'لا يوجد',
                        valueColor: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ],
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => DailyUpdateForm(project: project)),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('إضافة تحديث يومي'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ProjectTeamCard(project: project),
          const SizedBox(height: 16),
          _ProjectPipelineCard(project: project, tasks: tasks),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final statusChart = _ChartCard(
              title: 'توزيع حالة المهام',
              height: 240,
              child: StatusDonutChart(
                data: {for (final s in _kanbanColumns) s.label: tasks.where((t) => t.status == s).length},
                colors: {for (final s in _kanbanColumns) s.label: AppColors.taskStatusColor(s.name)},
              ),
            );
            final overdueTable = _OverdueTasksCard(tasks: tasks);
            final workloadChart = _WorkloadCard(tasks: tasks);
            final upcomingTable = _UpcomingDeadlinesCard(tasks: tasks);
            if (!wide) {
              return Column(children: [
                statusChart,
                const SizedBox(height: 16),
                overdueTable,
                const SizedBox(height: 16),
                workloadChart,
                const SizedBox(height: 16),
                upcomingTable,
              ]);
            }
            return Column(children: [
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: statusChart),
                  const SizedBox(width: 16),
                  Expanded(child: overdueTable),
                ]),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: workloadChart),
                  const SizedBox(width: 16),
                  Expanded(child: upcomingTable),
                ]),
              ),
            ]);
          }),
          if (risks.isNotEmpty || blockers.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              final riskCard = _IssuesCard(
                title: 'المخاطر القائمة',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
                items: risks.map((r) => r.description).toList(),
              );
              final blockerCard = _IssuesCard(
                title: 'العوائق النشطة',
                icon: Icons.block_rounded,
                color: const Color(0xFFE0692B),
                items: blockers.map((b) => b.description).toList(),
              );
              if (!wide) {
                return Column(children: [riskCard, const SizedBox(height: 12), blockerCard]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: riskCard),
                  const SizedBox(width: 12),
                  Expanded(child: blockerCard),
                ],
              );
            }),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('لوحة المهام', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: () => _showAddTaskDialog(context, projectId, project.departmentId, project.startDate, project.dueDate),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مهمة'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _KanbanBoard(projectId: projectId, canEdit: canEdit),
          const SizedBox(height: 24),
          const Text('التحديثات اليومية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'خطٌّ زمني للمشروع: أين وقع العمل، وأين الفجوات، وأين العوائق.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.7),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: UpdatesCalendar(
                firstDay: project.startDate,
                lastDay: DateTime.now(),
                digests: _digestsOf(updates),
                onOpenDay: (day) => _openDay(context, project, day),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // السجل النصّي يبقى تحت التقويم مطويّاً: هو الأثر الكامل، ويُقرأ
          // حين يُراد قراءته — لا أن يُزاحم النظرة الأولى.
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('السجل الكامل (${updates.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            children: [
          if (updates.isEmpty)
            // ــ الفراغ يُفسَّر ولا يُترك غامضاً ــ
            //
            // «لا توجد تحديثات» كانت تُعرض سواءٌ لم يُكتب شيء، أو كُتب ولم
            // يصل، أو رُدّت القراءة. راجع `whyNoUpdates`.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                store.whyNoUpdates(project) ?? 'لا توجد تحديثات بعد',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.7),
              ),
            )
          else
            ...updates.map((u) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(u.authorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                            Text(Formatters.timeAgo(u.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(u.achievements, style: const TextStyle(fontSize: 13, height: 1.5)),
                        if (u.blockers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _UpdateLines(label: 'عوائق', lines: u.blockers, color: const Color(0xFFE0692B)),
                        ],
                        if (u.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _UpdateLines(label: 'ملاحظات', lines: [u.notes], color: AppColors.info),
                        ],
                        if (u.attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final a in u.attachments) AttachmentChip(attachment: a),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text('نسبة التقدم عند التحديث: ${Formatters.percent(u.progressPercent)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )),
            ],
          ),
          const SizedBox(height: 28),
          CustomWidgetsSection(
            store: store,
            widgets: store.projectWidgetsFor(projectId),
            onSave: (widgets) => store.saveProjectWidgets(projectId, widgets),
            canManage: store.canManageDashboard,
            scopeProjectId: projectId,
            title: 'ودجات مخصصة لهذا المشروع',
          ),
        ],
      ),
    );
  }

  String _managerName(AppStore store, String? managerUid) {
    if (managerUid == null || managerUid.isEmpty) return 'لم يُعيَّن بعد';
    final match = store.users.where((u) => u.id == managerUid);
    if (match.isNotEmpty) return match.first.name;
    if (store.currentUser?.id == managerUid) return store.currentUser!.name;
    return 'مُعيَّن';
  }

  void _showAddTaskDialog(
    BuildContext context,
    String projectId,
    String departmentId,
    DateTime projectStartDate,
    DateTime projectDueDate,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AddTaskDialog(
        projectId: projectId,
        departmentId: departmentId,
        projectStartDate: projectStartDate,
        projectDueDate: projectDueDate,
      ),
    );
  }
}

class _MetaBit extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? child;
  const _MetaBit({required this.icon, required this.label, this.value, this.valueColor, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        child ?? Text(value ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

/// تعيين/تغيير "مدير المشروع" (مسؤول النظام فقط) من قائمة الحسابات الحقيقية
/// بدور "مدير مشروع" — الحساب المُختار هو الوحيد الذي سيرى هذا المشروع.
/// تعديل قائمة الأشخاص المنفذين للمشروع (يمكن أن يكون أكثر من شخص).
class _EditExecutorsDialog extends StatefulWidget {
  final Project project;
  const _EditExecutorsDialog({required this.project});

  @override
  State<_EditExecutorsDialog> createState() => _EditExecutorsDialogState();
}

class _EditExecutorsDialogState extends State<_EditExecutorsDialog> {
  late List<String> _names = List.of(widget.project.executorNames);
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    await context.read<AppStore>().updateProjectExecutors(widget.project, _names);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل المنفذين'),
      content: SizedBox(
        width: 380,
        child: ExecutorsField(
          initial: _names,
          departmentId: widget.project.departmentId,
          onChanged: (v) => _names = v,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

/// شريط مراحل المشروع (بحسب حالات المهام) + مربع الموعد النهائي المتبقي،
/// بنفس تقسيمات التصميم المرجعي المعتمد للوحة قيادة المشروع.
class _ProjectPipelineCard extends StatelessWidget {
  final Project project;
  final List<ProjectTask> tasks;
  const _ProjectPipelineCard({required this.project, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final due = DateTime(project.dueDate.year, project.dueDate.month, project.dueDate.day);
    final now = DateTime(today.year, today.month, today.day);
    final remaining = due.difference(now).inDays;
    final overdue = remaining < 0 && project.effectiveStatus != ProjectStatus.completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          final stagesRow = Row(
            children: _kanbanColumns
                .map((s) => Expanded(child: _StageBit(status: s, count: tasks.where((t) => t.status == s).length)))
                .toList(),
          );
          final dateBox = _DueDateBox(dueDate: project.dueDate, remaining: remaining, overdue: overdue);
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [stagesRow, const SizedBox(height: 16), dateBox]);
          }
          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: stagesRow),
              const SizedBox(width: 18),
              SizedBox(width: 190, child: dateBox),
            ]),
          );
        }),
      ),
    );
  }
}

class _StageBit extends StatelessWidget {
  final TaskStatus status;
  final int count;
  const _StageBit({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.taskStatusColor(status.name);
    final icon = switch (status) {
      TaskStatus.done => Icons.check_circle_rounded,
      TaskStatus.blocked => Icons.block_rounded,
      TaskStatus.inProgress => Icons.autorenew_rounded,
      TaskStatus.review => Icons.rate_review_outlined,
      TaskStatus.awaitingApproval => Icons.how_to_reg_outlined,
      TaskStatus.todo => Icons.schedule_rounded,
    };
    return Column(
      children: [
        CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 8),
        Text('$count', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(status.label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }
}

class _DueDateBox extends StatelessWidget {
  final DateTime dueDate;
  final int remaining;
  final bool overdue;
  const _DueDateBox({required this.dueDate, required this.remaining, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final color = overdue ? AppColors.danger : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الموعد النهائي المتوقع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(overdue ? Icons.error_outline_rounded : Icons.flag_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              overdue ? 'متأخر ${remaining.abs()} يوم' : '$remaining يوم متبقي',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
            ),
          ]),
          const SizedBox(height: 4),
          Text(Formatters.shortDate(dueDate), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;
  const _ChartCard({required this.title, required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            SizedBox(height: height - 50, child: child),
          ],
        ),
      ),
    );
  }
}

/// جدول المهام المتأخرة عن موعدها النهائي ولم تُنجز بعد.
class _OverdueTasksCard extends StatelessWidget {
  final List<ProjectTask> tasks;
  const _OverdueTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final overdue = tasks.where((t) => t.status != TaskStatus.done && t.dueDate.isBefore(today)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return _ChartCard(
      title: 'المهام المتأخرة',
      height: 240,
      child: overdue.isEmpty
          ? const Center(child: Text('لا توجد مهام متأخرة', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: overdue.length,
              separatorBuilder: (context, i) => const Divider(height: 14),
              itemBuilder: (context, i) {
                final t = overdue[i];
                final days = today.difference(t.dueDate).inDays;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${t.assigneeName} · ${Formatters.shortDate(t.dueDate)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('$days يوم', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.danger)),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// توزيع الأعباء بين المسؤولين عن التنفيذ (متوسط نسبة إنجاز مهام كل شخص).
class _WorkloadCard extends StatelessWidget {
  final List<ProjectTask> tasks;
  const _WorkloadCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final byAssignee = <String, List<ProjectTask>>{};
    for (final t in tasks) {
      if (t.assigneeName.isEmpty) continue;
      byAssignee.putIfAbsent(t.assigneeName, () => []).add(t);
    }
    final entries = byAssignee.entries.map((e) {
      final avg = e.value.map((t) => t.progressPercent).reduce((a, b) => a + b) / e.value.length;
      return MapEntry(e.key, avg);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: 'الأعباء حسب المسؤول عن التنفيذ',
      height: 240,
      child: entries.isEmpty
          ? const Center(child: Text('لا توجد مهام مُسنَدة بعد', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (context, i) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final e = entries[i];
                final value = e.value.clamp(0, 100);
                return Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(e.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          Container(height: 16, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                          FractionallySizedBox(
                            widthFactor: value / 100,
                            child: Container(height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 34, child: Text('${value.toStringAsFixed(0)}٪', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                  ],
                );
              },
            ),
    );
  }
}

/// أقرب المهام غير المنجزة استحقاقاً، للمتابعة العاجلة.
class _UpcomingDeadlinesCard extends StatelessWidget {
  final List<ProjectTask> tasks;
  const _UpcomingDeadlinesCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final upcoming = tasks.where((t) => t.status != TaskStatus.done).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final items = upcoming.take(5).toList();
    return _ChartCard(
      title: 'أقرب المواعيد النهائية',
      height: 240,
      child: items.isEmpty
          ? const Center(child: Text('لا توجد مهام قادمة', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, i) => const Divider(height: 14),
              itemBuilder: (context, i) {
                final t = items[i];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(t.assigneeName, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(Formatters.shortDate(t.dueDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ],
                );
              },
            ),
    );
  }
}

class _IssuesCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _IssuesCard({required this.title, required this.icon, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
            ]),
            const SizedBox(height: 10),
            ...items.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 5), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

const _kanbanColumns = [
  TaskStatus.todo,
  TaskStatus.inProgress,
  TaskStatus.review,
  TaskStatus.blocked,
  // عمودٌ قائم بذاته قبل «منجزة»: المهمة التي أُفيد بإتمامها لم تُغلق بعد،
  // ووضعُها في «منجزة» يجعل اللوحة تكذب على من ينظر إليها.
  TaskStatus.awaitingApproval,
  TaskStatus.done,
];

class _KanbanBoard extends StatelessWidget {
  final String projectId;
  final bool canEdit;
  const _KanbanBoard({required this.projectId, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tasks = store.tasksForProject(projectId);

    return SizedBox(
      height: 480,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _kanbanColumns.map((status) {
            final columnTasks = tasks.where((t) => t.status == status).toList();
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _KanbanColumn(status: status, tasks: columnTasks, canEdit: canEdit),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final TaskStatus status;
  final List<ProjectTask> tasks;
  final bool canEdit;
  const _KanbanColumn({required this.status, required this.tasks, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final color = _columnColor(status);
    return SizedBox(
      width: 270,
      child: DragTarget<ProjectTask>(
        onWillAcceptWithDetails: (details) => canEdit && details.data.status != status,
        onAcceptWithDetails: (details) {
          context.read<AppStore>().updateTaskStatus(details.data, status);
        },
        builder: (context, candidate, rejected) {
          final highlighted = candidate.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: highlighted ? color.withValues(alpha: 0.08) : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: highlighted ? color : AppColors.border),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
                    Text('${tasks.length}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.only(top: 30), child: Text('لا توجد مهام', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5))))
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, i) => _TaskCard(task: tasks[i], canEdit: canEdit),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _columnColor(TaskStatus s) => AppColors.taskStatusColor(s.name);
}

class _TaskCard extends StatelessWidget {
  final ProjectTask task;
  final bool canEdit;
  const _TaskCard({required this.task, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                PriorityChip(priority: task.priority),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    task.assigneeName.isNotEmpty ? task.assigneeName.substring(0, 1) : '?',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(task.assigneeName, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            LabeledProgressBar(value: task.progressPercent, height: 5),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.update_rounded, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(Formatters.timeAgo(task.lastUpdated), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
                if (canEdit)
                  InkWell(
                    onTap: () => _showTaskMenu(context),
                    child: const Icon(Icons.more_horiz_rounded, size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!canEdit) return card;

    return LongPressDraggable<ProjectTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 250, child: Opacity(opacity: 0.9, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  void _showTaskMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.percent_rounded),
                title: const Text('تحديث نسبة الإنجاز'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProgressDialog(context);
                },
              ),
              // «إعادة للتنفيذ» تسبق قائمة الحالات: هي القرار المضادّ
              // للاعتماد، وتركُها بين خيارات النقل يجعلها تبدو نقلاً عادياً
              // بلا سبب — والسبب هو كل قيمتها.
              if (task.isAwaitingApproval && context.read<AppStore>().canApproveTaskClosure(task))
                ListTile(
                  leading: const Icon(Icons.undo_rounded),
                  title: const Text('إعادة للتنفيذ (بسبب)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReworkDialog(context);
                  },
                ),
              // ــ «لا يخصّني» للمُسنَد إليه وحده ــ
              //
              // نظيرُ ما في صفحة العمل، والمعنى واحد بقرار صريح: الموظف لا
              // يفرّق بين «عمل» و«مهمة مشروع»، وزرٌّ يظهر في شاشة ويغيب في
              // أختها يُقرأ عطلاً لا تصميماً.
              //
              // وتُعرض **قبل** قائمة الحالات: هي قرارٌ يخرج المهمة من يده،
              // لا نقلاً بين حالاتها.
              if (context.read<AppStore>().canDeclineTask(task))
                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('لا تخصّني (عدم اختصاص)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeclineDialog(context);
                  },
                ),
              ...TaskStatus.values.map((s) => ListTile(
                    leading: Icon(s == task.status ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    title: Text('نقل إلى: ${s.label}'),
                    onTap: () {
                      context.read<AppStore>().updateTaskStatus(task, s);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  /// ردُّ المهمة لعدم الاختصاص — يرفع المُسنَد إليه اسمه عنها بسببٍ مكتوب.
  ///
  /// والسببُ مشروط لا مستحبّ: المهمة تعود إلى المشروع **بلا مُسنَدٍ إليه**،
  /// فلولاه لَوجدها مدير المشروع «غير مُسنَدة» بلا أن يعرف أنها عُرضت على
  /// أحدٍ وردَّها — فيُسندها إليه من جديد، وتدور الدورة.
  void _showDeclineDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final store = context.read<AppStore>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ردّ المهمة لعدم الاختصاص'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يُرفع اسمك عن هذه المهمة وتبقى في المشروع مفتوحة، فيراها مدير '
                'المشروع ويُسندها لمن يختصّ.',
                style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'لماذا لا تخصّك؟ ومن يخصّها إن كنت تعرف…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final reason = ctrl.text.trim();
              final messenger = ScaffoldMessenger.of(ctx);
              if (reason.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('سبب عدم الاختصاص مطلوب.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await store.declineTask(task, reason);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(describeWriteFailure(e))));
              }
            },
            child: const Text('ردّ لعدم الاختصاص'),
          ),
        ],
      ),
    );
  }

  /// إعادة المهمة للتنفيذ — بسببٍ مكتوب يقرؤه المنفّذ ويبقى في سجلّها.
  void _showReworkDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final store = context.read<AppStore>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة المهمة للتنفيذ'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'ما الذي ينقص؟'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;
              store.sendTaskBackForRework(task, reason);
              Navigator.pop(ctx);
            },
            child: const Text('إعادة للتنفيذ'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context) {
    double value = task.progressPercent;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('تحديث نسبة الإنجاز'),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${value.toStringAsFixed(0)}٪', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Slider(value: value, min: 0, max: 100, divisions: 100, onChanged: (v) => setState(() => value = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                context.read<AppStore>().updateTaskProgress(task, value);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      }),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  final String projectId;
  final String departmentId;
  final DateTime projectStartDate;
  final DateTime projectDueDate;
  const _AddTaskDialog({
    required this.projectId,
    required this.departmentId,
    required this.projectStartDate,
    required this.projectDueDate,
  });

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  PriorityLevel _priority = PriorityLevel.medium;
  late DateTime _dueDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final suggested = DateTime.now().add(const Duration(days: 7));
    _dueDate = suggested.isAfter(widget.projectDueDate) ? widget.projectDueDate : suggested;
  }

  String _assigneeUid = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _assigneeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    // لا يمكن أن يسبق تاريخ استحقاق المهمة اليوم، ولا يتجاوز الموعد النهائي للمشروع.
    final firstDate = now.isAfter(widget.projectDueDate) ? widget.projectDueDate : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: firstDate,
      lastDate: widget.projectDueDate,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مهمة جديدة'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'عنوان المهمة')),
            const SizedBox(height: 12),
            // ــ المسؤول بحسابه لا باسمه المكتوب ــ
            //
            // كان حقلاً نصياً حرّاً. وذلك يكفي للعرض ولا يكفي للحوكمة: دورة
            // إغلاقٍ من مرحلتين تحتاج أن تعرف **من** أعلن الإتمام بهويةٍ لا
            // بحروفٍ قد تتشابه. والقائمة تُصفّى بقاعدة الإسناد الموحّدة نفسها.
            Builder(builder: (context) {
              final store = context.watch<AppStore>();
              final candidates = eligibleAssignees(
                allUsers: store.users,
                actor: store.currentUser,
                departmentId: widget.departmentId,
              );
              if (candidates.isEmpty) {
                return Text(
                  emptyAssigneeReason(
                    allUsers: store.users,
                    actor: store.currentUser,
                    departmentId: widget.departmentId,
                  ),
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.7, color: AppColors.textSecondary),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: candidates.any((u) => u.id == _assigneeUid) ? _assigneeUid : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ'),
                items: candidates
                    .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _assigneeUid = v ?? '';
                  _assigneeCtrl.text =
                      candidates.where((u) => u.id == v).map((u) => u.name).firstOrNull ?? '';
                }),
              );
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<PriorityLevel>(
              initialValue: _priority,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الأولوية'),
              items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text('تاريخ الاستحقاق: ${_dueDate.year}/${_dueDate.month}/${_dueDate.day}'),
            ),
            const SizedBox(height: 4),
            Text(
              'لا يمكن أن يتجاوز الموعد النهائي للمشروع (${widget.projectDueDate.year}/${widget.projectDueDate.month}/${widget.projectDueDate.day})',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty || _assigneeCtrl.text.trim().isEmpty) {
              setState(() => _error = 'الرجاء تعبئة عنوان المهمة والمسؤول عن التنفيذ');
              return;
            }
            if (_dueDate.isAfter(widget.projectDueDate)) {
              setState(() => _error = 'لا يمكن أن يتجاوز تاريخ استحقاق المهمة الموعد النهائي للمشروع');
              return;
            }
            final store = context.read<AppStore>();
            final me = store.currentUser;
            // المعتمِد هو المُنشئ حين يكون من خارج الإدارة المنفّذة — القاعدة
            // نفسها التي على الأعمال، من الدالّة نفسها.
            final approver = defaultApproverUid(
              creator: me,
              executingDepartmentId: widget.departmentId,
            );
            store.addTask(ProjectTask(
                  id: '${widget.projectId}_t${DateTime.now().microsecondsSinceEpoch}',
                  projectId: widget.projectId,
                  departmentId: widget.departmentId,
                  title: _titleCtrl.text.trim(),
                  assigneeUid: _assigneeUid,
                  assigneeName: _assigneeCtrl.text.trim(),
                  status: TaskStatus.todo,
                  progressPercent: 0,
                  lastUpdated: DateTime.now(),
                  dueDate: _dueDate,
                  priority: _priority,
                  createdByUid: me?.id ?? '',
                  closure: approver == null || me == null
                      ? ClosureTrail.none
                      : ClosureTrail(approverUid: approver, approverName: me.name),
                ));
            Navigator.pop(context);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

/// سطور مُعنونة داخل بطاقة التحديث اليومي (العوائق، الملاحظات).
class _UpdateLines extends StatelessWidget {
  final String label;
  final List<String> lines;
  final Color color;

  const _UpdateLines({required this.label, required this.lines, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $l', style: const TextStyle(fontSize: 12.5, height: 1.6)),
            )),
      ],
    );
  }
}

/// مرفق على تحديث يومي: يُفتح في تبويب جديد.
///
/// الفتح داخل لمسة المستخدم مباشرة بلا أي انتظار — سفاري على الآيفون يمنع
/// صامتاً كل فتح يقع بعد عملية غير متزامنة، وهو الدرس نفسه الذي كلّفنا
/// جولةً في تنزيل التقارير.

/// يفتح صفحة المشروع بترويسة تحمل اسمه — نظير [openWorkDetail].
///
/// وُضِعت لأن ثلاثة مواضع صارت تفتح صفحة المشروع بالطريقة نفسها: الرابط
/// الوارد من البريد، وسطر التقرير اليومي، وقائمة المشاريع. ونسخُ الدفع
/// الثلاث مرات يعني أن يفترق ما تحمله الترويسة أو ما يُدفع تحتها.
void openProjectDetail(BuildContext context, Project project) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: ProjectDetailScreen(projectId: project.id),
    ),
  ));
}
