import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../models/notify_templates.dart';
import '../widgets/focus_assignment_dialog.dart';
import '../widgets/kpi_card.dart';
import '../widgets/notify_dialog.dart';
import '../widgets/progress_bar.dart';

/// شاشة "الأعمال": بنود العمل التشغيلية المستقلة عن المشاريع.
///
/// تعرض تبويبين: الأعمال الجارية، وسجل الإنجاز (المنجَزة مرتّبة بالأحدث).
class WorksListScreen extends StatefulWidget {
  const WorksListScreen({super.key});

  @override
  State<WorksListScreen> createState() => _WorksListScreenState();
}

class _WorksListScreenState extends State<WorksListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _departmentFilter;
  String? _assigneeFilter;
  TaskStatus? _statusFilter;
  bool _showLog = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.visibleWorks;

    final q = _query.trim().toLowerCase();
    var works = (_showLog ? store.completedWorks : all.where((w) => !w.isDone).toList()).where((w) {
      if (_departmentFilter != null && w.departmentId != _departmentFilter) return false;
      if (_assigneeFilter != null && w.assigneeUid != _assigneeFilter) return false;
      if (_statusFilter != null && w.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return w.title.toLowerCase().contains(q) || w.assigneeName.toLowerCase().contains(q);
    }).toList();

    final overdue = all.where((w) => w.delayDays > 0).length;
    final assigneeOptions = <String, String>{
      for (final w in all) w.assigneeUid: w.assigneeName,
    }..removeWhere((k, v) => k.isEmpty);

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
                    Text('الأعمال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('بنود العمل التشغيلية والإدارية المستقلة عن المشاريع',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              if (store.canManageWorks)
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const WorkFormDialog()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة عمل'),
                ),
            ],
          ),
          const SizedBox(height: 18),

          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 820 ? 4 : (c.maxWidth > 520 ? 2 : 1);
            const spacing = 14.0;
            const itemHeight = 92.0;
            final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: itemWidth / itemHeight,
              children: [
                KpiCard(title: 'إجمالي الأعمال', value: '${all.length}', icon: Icons.checklist_rounded, color: AppColors.primary),
                KpiCard(title: 'قيد التنفيذ', value: '${all.where((w) => !w.isDone).length}', icon: Icons.play_arrow_rounded, color: AppColors.info),
                KpiCard(title: 'منجزة', value: '${all.where((w) => w.isDone).length}', icon: Icons.check_circle_outline_rounded, color: AppColors.success),
                KpiCard(title: 'متأخرة عن موعدها', value: '$overdue', icon: Icons.schedule_rounded, color: AppColors.danger),
              ],
            );
          }),
          const SizedBox(height: 18),

          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('الأعمال الجارية'), icon: Icon(Icons.pending_actions_rounded, size: 16)),
              ButtonSegment(value: true, label: Text('سجل الإنجاز'), icon: Icon(Icons.verified_rounded, size: 16)),
            ],
            selected: {_showLog},
            onSelectionChanged: (s) => setState(() => _showLog = s.first),
          ),
          const SizedBox(height: 16),

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
                    hintText: 'ابحث باسم العمل أو المسؤول',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              if (store.visibleDepartments.length > 1)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _departmentFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الإدارة', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                      ...store.visibleDepartments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                    ],
                    onChanged: (v) => setState(() => _departmentFilter = v),
                  ),
                ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: _assigneeFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المسؤول', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المسؤولين')),
                    ...assigneeOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) => setState(() => _assigneeFilter = v),
                ),
              ),
              if (!_showLog)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<TaskStatus?>(
                    initialValue: _statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الحالة', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                      ...TaskStatus.values
                          .where((s) => s != TaskStatus.done)
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Text('${works.length} عمل', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (works.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  _showLog ? 'لا توجد أعمال منجزة بعد' : 'لا توجد أعمال مطابقة',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...works.map((w) => _WorkRow(work: w)),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  final WorkItem work;
  const _WorkRow({required this.work});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(work.departmentId);
    final canEdit = store.canEditWork(work);
    final delay = work.delayDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? () => showDialog(context: context, builder: (_) => WorkFormDialog(editing: work)) : null,
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
                        Text(work.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(
                          '${dept?.name ?? 'بدون إدارة'} · ${work.assigneeName.isEmpty ? 'غير مُسنَد' : work.assigneeName}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.taskStatusColor(work.status.name).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(work.status.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.taskStatusColor(work.status.name))),
                  ),
                  if (store.canSendNotifications && work.assigneeUid.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.forward_to_inbox_rounded, size: 18, color: AppColors.primary),
                      tooltip: 'مراسلة المسؤول عن العمل',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => NotifyDialog(
                          initialUsers: store.recipientsForWork(work),
                          context: NotifyContext.fromWork(work),
                        ),
                      ),
                    ),
                  if (store.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.push_pin_outlined, size: 18, color: AppColors.textSecondary),
                      tooltip: 'عرض في لوحة قيادة مستخدم',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => FocusAssignmentDialog(workId: work.id, title: work.title),
                      ),
                    ),
                  if (store.isAdmin || store.canDeleteRecords)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      tooltip: 'حذف العمل',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف العمل'),
                            content: Text('سيُحذف "${work.title}" نهائياً.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        final error = await store.deleteWork(work);
                        if (error != null) {
                          messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledProgressBar(value: work.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Bit(icon: Icons.event_outlined, text: 'الموعد: ${Formatters.shortDate(work.dueDate)}'),
                  if (work.completedDate != null)
                    _Bit(
                        icon: Icons.check_circle_outline_rounded,
                        text: 'أُنجز: ${Formatters.shortDate(work.completedDate!)}',
                        color: AppColors.success),
                  if (delay > 0) _Bit(icon: Icons.schedule_rounded, text: 'متأخر $delay يوم', color: AppColors.danger),
                  if (work.isRecurring) const _Bit(icon: Icons.repeat_rounded, text: 'عمل دوري'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Bit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// نموذج إضافة/تعديل عمل. الموظف المُسنَد إليه يعدّل الحالة والتقدّم فقط،
/// بينما من يملك صلاحية "إدارة الأعمال" يعدّل كل الحقول ويعيد الإسناد.
class WorkFormDialog extends StatefulWidget {
  final WorkItem? editing;
  const WorkFormDialog({super.key, this.editing});

  @override
  State<WorkFormDialog> createState() => _WorkFormDialogState();
}

class _WorkFormDialogState extends State<WorkFormDialog> {
  late final _titleCtrl = TextEditingController(text: widget.editing?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.editing?.description ?? '');
  late String _departmentId = widget.editing?.departmentId ?? '';
  late String _assigneeUid = widget.editing?.assigneeUid ?? '';
  late TaskStatus _status = widget.editing?.status ?? TaskStatus.todo;
  late PriorityLevel _priority = widget.editing?.priority ?? PriorityLevel.medium;
  late double _progress = widget.editing?.progressPercent ?? 0;
  late DateTime _dueDate = widget.editing?.dueDate ?? DateTime.now().add(const Duration(days: 7));
  late bool _recurring = widget.editing?.isRecurring ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final store = context.read<AppStore>();
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم العمل');
      return;
    }
    if (_departmentId.isEmpty) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final assignee = store.users.where((u) => u.id == _assigneeUid);
      final assigneeName = assignee.isEmpty ? (widget.editing?.assigneeName ?? '') : assignee.first.name;

      if (widget.editing == null) {
        await store.addWork(WorkItem(
          id: '',
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          departmentId: _departmentId,
          assigneeUid: _assigneeUid,
          assigneeName: assigneeName,
          status: _status,
          priority: _priority,
          progressPercent: _progress,
          dueDate: _dueDate,
          completedDate: _status == TaskStatus.done ? DateTime.now() : null,
          isRecurring: _recurring,
          createdByUid: store.currentUser?.id ?? '',
          createdAt: DateTime.now(),
        ));
      } else {
        await store.updateWork(widget.editing!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          departmentId: _departmentId,
          assigneeUid: _assigneeUid,
          assigneeName: assigneeName,
          status: _status,
          priority: _priority,
          progressPercent: _progress,
          dueDate: _dueDate,
          isRecurring: _recurring,
        ));
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر الحفظ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canManage = store.canManageWorks;
    final departments = store.visibleDepartments;
    // المسؤولون المتاحون للإسناد: حسابات الإدارة المختارة.
    final candidates = store.users
        .where((u) =>
            u.status == UserStatus.approved &&
            (_departmentId.isEmpty || u.departmentId == _departmentId || u.departmentIds.contains(_departmentId)))
        .toList();

    return AlertDialog(
      title: Text(widget.editing == null ? 'إضافة عمل' : 'تعديل العمل'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                enabled: canManage,
                decoration: const InputDecoration(labelText: 'اسم العمل'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                enabled: canManage,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف مختصر (اختياري)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _departmentId.isEmpty ? null : _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الإدارة'),
                items: departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: canManage
                    ? (v) => setState(() {
                          _departmentId = v ?? '';
                          _assigneeUid = '';
                        })
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: candidates.any((u) => u.id == _assigneeUid) ? _assigneeUid : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ'),
                items: candidates.map((u) => DropdownMenuItem<String>(value: u.id, child: Text(_userLabel(u)))).toList(),
                onChanged: canManage ? (v) => setState(() => _assigneeUid = v ?? '') : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: TaskStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PriorityLevel>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الأولوية'),
                      items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                      onChanged: canManage ? (v) => setState(() => _priority = v ?? _priority) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('نسبة الإنجاز: ${_progress.toStringAsFixed(0)}٪',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              Slider(
                value: _progress,
                max: 100,
                divisions: 20,
                label: '${_progress.toStringAsFixed(0)}٪',
                onChanged: (v) => setState(() => _progress = v),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text('الموعد: ${Formatters.shortDate(_dueDate)}', style: const TextStyle(fontSize: 12.5)),
                  ),
                  TextButton.icon(
                    onPressed: canManage
                        ? () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _dueDate = picked);
                          }
                        : null,
                    icon: const Icon(Icons.event_rounded, size: 16),
                    label: const Text('تغيير'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _recurring,
                onChanged: canManage ? (v) => setState(() => _recurring = v) : null,
                title: const Text('عمل دوري متكرر', style: TextStyle(fontSize: 13)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }

  String _userLabel(AppUser u) => '${u.name} — ${u.role.label}';
}
