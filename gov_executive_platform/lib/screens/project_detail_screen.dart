import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/project.dart';
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
                      if (project.executorName.isNotEmpty)
                        _MetaBit(icon: Icons.badge_outlined, label: 'الشخص المنفذ', value: project.executorName),
                      _MetaBit(
                        icon: Icons.manage_accounts_outlined,
                        label: 'مدير المشروع',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _managerName(store, project.managerUid),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            if (store.isAdmin) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => _AssignManagerDialog(project: project),
                                ),
                                child: Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ],
                        ),
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
class _AssignManagerDialog extends StatefulWidget {
  final Project project;
  const _AssignManagerDialog({required this.project});

  @override
  State<_AssignManagerDialog> createState() => _AssignManagerDialogState();
}

class _AssignManagerDialogState extends State<_AssignManagerDialog> {
  String? _managerUid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _managerUid = widget.project.managerUid;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await context.read<AppStore>().setProjectManager(widget.project, _managerUid);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final officers = store.users.where((u) => u.role == UserRole.projectOfficer).toList();
    return AlertDialog(
      title: const Text('تعيين مدير المشروع'),
      content: SizedBox(
        width: 380,
        child: DropdownButtonFormField<String?>(
          initialValue: _managerUid,
          decoration: const InputDecoration(labelText: 'مدير المشروع'),
          items: [
            const DropdownMenuItem(value: null, child: Text('بدون تعيين')),
            ...officers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
          ],
          onChanged: (v) => setState(() => _managerUid = v),
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
            TextField(controller: _assigneeCtrl, decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ')),
            const SizedBox(height: 12),
            DropdownButtonFormField<PriorityLevel>(
              initialValue: _priority,
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
            context.read<AppStore>().addTask(ProjectTask(
                  id: '${widget.projectId}_t${DateTime.now().microsecondsSinceEpoch}',
                  projectId: widget.projectId,
                  departmentId: widget.departmentId,
                  title: _titleCtrl.text.trim(),
                  assigneeName: _assigneeCtrl.text.trim(),
                  status: TaskStatus.todo,
                  progressPercent: 0,
                  lastUpdated: DateTime.now(),
                  dueDate: _dueDate,
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
