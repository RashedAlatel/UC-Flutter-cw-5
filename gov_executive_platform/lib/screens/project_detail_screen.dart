import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/project_task.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'daily_update_form.dart';
import 'request_deadline_change_dialog.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
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
                            Text(project.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(dept?.name ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      StatusChip(status: project.status),
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
                                child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
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
                  onPressed: () => _showAddTaskDialog(context, projectId, project.departmentId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مهمة'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _KanbanBoard(projectId: projectId, canEdit: canEdit),
          const SizedBox(height: 24),
          const Text('سجل التحديثات اليومية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (updates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('لا توجد تحديثات بعد', style: TextStyle(color: AppColors.textSecondary)),
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
                        const SizedBox(height: 8),
                        Text('نسبة التقدم عند التحديث: ${Formatters.percent(u.progressPercent)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, String projectId, String departmentId) {
    showDialog(context: context, builder: (_) => _AddTaskDialog(projectId: projectId, departmentId: departmentId));
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

  Color _columnColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return AppColors.textSecondary;
      case TaskStatus.inProgress:
        return AppColors.info;
      case TaskStatus.review:
        return AppColors.accent;
      case TaskStatus.blocked:
        return AppColors.danger;
      case TaskStatus.done:
        return AppColors.success;
    }
  }
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
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary),
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
  const _AddTaskDialog({required this.projectId, required this.departmentId});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  PriorityLevel _priority = PriorityLevel.medium;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _assigneeCtrl.dispose();
    super.dispose();
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
            TextField(controller: _assigneeCtrl, decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ')),
            const SizedBox(height: 12),
            DropdownButtonFormField<PriorityLevel>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'الأولوية'),
              items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty || _assigneeCtrl.text.trim().isEmpty) return;
            context.read<AppStore>().addTask(ProjectTask(
                  id: '${widget.projectId}_t${DateTime.now().microsecondsSinceEpoch}',
                  projectId: widget.projectId,
                  departmentId: widget.departmentId,
                  title: _titleCtrl.text.trim(),
                  assigneeName: _assigneeCtrl.text.trim(),
                  status: TaskStatus.todo,
                  progressPercent: 0,
                  lastUpdated: DateTime.now(),
                  dueDate: DateTime.now().add(const Duration(days: 14)),
                  priority: _priority,
                ));
            Navigator.pop(context);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
