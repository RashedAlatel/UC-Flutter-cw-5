// إعادةُ جدولة مهمة — بموعدٍ جديدٍ وسببٍ مكتوب.
//
// ــــ ولماذا السببُ مطلوب ــــ
//
// موعدٌ يتحرّك بلا سببٍ ليس إعادةَ جدولة بل محواً للخطة: يقرأ المديرُ بعد
// شهرين مهمةً موعدُها غيرُ ما أُقرّ ولا يجد ما يفسّره. والسببُ يُختم في
// سجل التدقيق مع «قبل ← بعد».
//
// ــــ والحدُّ يُقال قبل الضغط ــــ
//
// «لا يتجاوز موعدَ المشروع» — يُعرض الحدُّ بتاريخه، ويُمنع الحفظُ قبله لا
// بعده. والقاعدةُ في `taskDueDateRejection` تقرؤها هذه النافذة ويقرؤها
// المتجر وتردّ بها قاعدةُ الخادم — موضعٌ واحد لا ثلاثة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/task_reschedule.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// يفتح نافذة إعادة الجدولة. يُعيد `true` إن وقعت.
Future<bool> showTaskRescheduleDialog(
  BuildContext context,
  ProjectTask task,
  Project project,
) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => TaskRescheduleDialog(task: task, project: project),
  );
  return done ?? false;
}

class TaskRescheduleDialog extends StatefulWidget {
  final ProjectTask task;
  final Project project;
  const TaskRescheduleDialog({super.key, required this.task, required this.project});

  @override
  State<TaskRescheduleDialog> createState() => _TaskRescheduleDialogState();
}

class _TaskRescheduleDialogState extends State<TaskRescheduleDialog> {
  late DateTime _due = widget.task.dueDate;
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due.isAfter(widget.project.dueDate) ? widget.project.dueDate : _due,
      firstDate: DateTime(2020),
      // ــ والحدُّ في المُنتقي نفسِه ــ
      //
      // فلا يختار المستخدمُ يوماً ثم يُقال له إنه ممنوع. والقاعدةُ تبقى
      // مفحوصةً بعده: المُنتقي ترتيبٌ، والفحصُ حكم.
      lastDate: widget.project.dueDate,
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().rescheduleTask(
          widget.task,
          _due,
          reason: _reasonCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final rejection =
        taskDueDateRejection(newDue: _due, projectDue: widget.project.dueDate);
    final unchanged = _due.year == widget.task.dueDate.year &&
        _due.month == widget.task.dueDate.month &&
        _due.day == widget.task.dueDate.day;

    return AlertDialog(
      title: const Text('إعادة جدولة المهمة'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.task.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                'الموعد الحالي: ${Formatters.date(widget.task.dueDate)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.event_rounded, size: 17),
                label: Text('الموعد الجديد: ${Formatters.date(_due)}'),
              ),
              const SizedBox(height: 6),
              // ــ الحدُّ يُقال دائماً، لا عند تجاوزه وحده ــ
              //
              // فيعرف من يجدول أين ينتهي مداه قبل أن يحاول.
              Text(
                'ولا يتجاوز موعد المشروع: ${Formatters.date(widget.project.dueDate)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reasonCtrl,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'سبب إعادة الجدولة',
                  helperText: 'يُحفظ في سجل التدقيق مع الموعدين',
                ),
              ),
              if (rejection != null) ...[
                const SizedBox(height: 12),
                Text(rejection,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12, height: 1.6)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          // بلا موعدٍ جديدٍ ولا سببٍ لا معنى للحفظ. والسببُ **مطلوب**:
          // موعدٌ يتحرّك بلا تفسيرٍ يُقرأ بعد شهرين خطأً في البيانات.
          onPressed: (_busy || unchanged || rejection != null ||
                  _reasonCtrl.text.trim().isEmpty)
              ? null
              : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
