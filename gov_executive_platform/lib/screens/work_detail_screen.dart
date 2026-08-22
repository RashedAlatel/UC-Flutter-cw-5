import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/meta_row.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'work_update_form.dart';
import 'works_list_screen.dart' show WorkFormDialog;

/// صفحة العمل التشغيلي: تفاصيله، وسجلّ تحديثاته اليومية.
///
/// ــــ لماذا صفحة، والعمل «مهمّة واحدة»؟ ــــ
///
/// لأن العمل كان يُرى ولا يُدخَل: بطاقةٌ في قائمة، وزرُّ تحريرٍ لمن يملك
/// التحرير — ولا شيء لمن أُسنِد إليه. فمن عليه العمل لا يجد موضعاً يكتب فيه
/// ما أنجزه، ولا يقرأ فيه ما كتبه أمس. والمشروع له كل ذلك.
class WorkDetailScreen extends StatelessWidget {
  final String workId;
  const WorkDetailScreen({super.key, required this.workId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final work = store.works.where((w) => w.id == workId).firstOrNull;

    // العمل قد يُحذف والصفحة مفتوحة — يُقال ذلك بدل شاشة فارغة.
    if (work == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'هذا العمل لم يعد موجوداً — قد يكون حُذف.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final dept = store.departmentById(work.departmentId);
    final updates = store.updatesForWork(work.id);
    final canUpdate = store.canEditWork(work);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          work.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            decoration: work.isDone ? TextDecoration.lineThrough : null,
                            color: work.isDone ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PriorityChip(priority: work.priority),
                    ],
                  ),
                  if (work.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(work.description,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.8)),
                  ],
                  const SizedBox(height: 14),
                  LabeledProgressBar(value: work.progressPercent, label: 'نسبة الإنجاز'),
                  const SizedBox(height: 12),
                  MetaRow(
                    runSpacing: 6,
                    children: [
                      MetaChip(
                        icon: Icons.event_outlined,
                        text: 'الاستحقاق: ${Formatters.shortDate(work.dueDate)}',
                      ),
                      MetaChip(
                        icon: Icons.schedule_rounded,
                        text: work.isDone
                            ? 'منجَز'
                            : (work.delayDays > 0 ? 'متأخر ${work.delayDays} يوم' : 'ضمن الجدول الزمني'),
                        color: work.isDone
                            ? AppColors.success
                            : (work.delayDays > 0 ? AppColors.danger : AppColors.success),
                      ),
                      if (dept != null) MetaChip(icon: dept.icon, text: dept.name, color: dept.color),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MetaLine(icon: Icons.person_outline_rounded, text: 'المسؤول: ${work.assigneeName}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canUpdate)
                        FilledButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => WorkUpdateForm(work: work),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('تحديث يومي'),
                        ),
                      if (store.canManageWorks || store.isAdmin)
                        OutlinedButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => WorkFormDialog(editing: work),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('تعديل بيانات العمل'),
                        ),
                    ],
                  ),
                  // من لا يملك التحديث يجب أن يعرف لماذا، لا أن يرى صفحةً
                  // بلا أزرار فيظنّها معطّلة.
                  if (!canUpdate) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'التحديث اليومي يكتبه المسؤول عن العمل أو من يملك إدارة الأعمال في إدارته.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text('سجل التحديثات اليومية',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 8),
              Text('(${updates.length})',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 10),
          if (updates.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'لا توجد تحديثات بعد. أول تحديث يُكتب من زرّ «تحديث يومي» أعلاه، '
                'ويُسجَّل تحت اليوم الذي تختاره من التقويم.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
              ),
            )
          else
            ...updates.map((u) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(u.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: AppColors.primary)),
                            ),
                            Text(Formatters.date(u.date),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          u.summary.trim().isEmpty ? 'بلا ملخّص إنجاز' : u.summary,
                          style: const TextStyle(fontSize: 12.5, height: 1.7),
                        ),
                        if (u.notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('ملاحظات: ${u.notes}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textSecondary, height: 1.7)),
                        ],
                        const SizedBox(height: 8),
                        MetaChip(
                          icon: Icons.trending_up_rounded,
                          text: 'الإنجاز يومها: ${Formatters.percent(u.progressPercent)}',
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

/// يفتح صفحة العمل بترويسة تحمل اسمه — من أي قائمة كان.
void openWorkDetail(BuildContext context, WorkItem work) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: WorkDetailScreen(workId: work.id),
    ),
  ));
}
