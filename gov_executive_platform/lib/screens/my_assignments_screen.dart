import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../utils/formatters.dart';
import '../widgets/meta_row.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'project_detail_screen.dart';
import 'work_detail_screen.dart';

/// «المُسنَد إليّ»: مشاريع المستخدم وأعماله في مكان واحد.
///
/// وهي حاجة لا ترفٌ: بقية الشاشات مبنية على **الإدارة** — مشاريع إدارتي،
/// أعمال إدارتي. فمن أُسنِد إليه مشروع أو عمل في إدارة أخرى كان عليه أن
/// يبحث عنه بين ما ليس له، أو لا يجده أصلاً. وهذه الشاشة مبنية على
/// **العضوية** لا الإدارة، فتجمع ما يخصّه أينما كان.
class MyAssignmentsScreen extends StatelessWidget {
  const MyAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final projects = store.myProjects;
    final works = store.myWorks;
    final openWorks = works.where((w) => !w.isDone).length;
    final awaiting = store.worksAwaitingMyApproval;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommandBand(
            title: 'المُسنَد إليّ',
            subtitle: 'كل مشروع أنت مديره أو منفّذه، وكل عمل مُسنَد إليك — ولو كان خارج إدارتك.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // ــــ إشعار الاعتماد: فوريٌّ وفي طريقه ــــ
          //
          // «يظهر إشعار لمدير المشروع بأن الإدارة أفادت بإتمام المطلوب» —
          // وأصدقُ موضعٍ له صفحةُ ما هو عليه، لا لافتةٌ تُغلق ولا بريدٌ ينتظر
          // اعتماداً. ويتصدّر القسمين لأنه **الشيء الوحيد هنا الذي يقف على
          // المستخدم نفسه**: بقيةُ الصفحة عملٌ عليه أن ينفّذه، وهذا قرارٌ
          // ينتظره غيره منه.
          if (awaiting.isNotEmpty) ...[
            _SectionTitle('بانتظار اعتمادك', count: awaiting.length),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.40)),
              ),
              child: const Text(
                'أفادت الإدارات المنفّذة بإتمام هذه الأعمال. ولا تُغلق إلا بعد '
                'مراجعتك — افتح العمل ثم «اعتماد الإنجاز» أو «إعادة للتنفيذ».',
                style: TextStyle(fontSize: 12, height: 1.8, fontWeight: FontWeight.w700),
              ),
            ),
            ...awaiting.map((w) => _WorkTile(work: w)),
            const SizedBox(height: 26),
          ],
          _SectionTitle('مشاريعي', count: projects.length),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            const _Empty(
              icon: Icons.folder_off_outlined,
              title: 'لم تُسنَد إليك مشاريع بعد',
              hint: 'حين يضيفك مدير الإدارة إلى مشروع — أو تسجّل نفسك على أحدها من صفحة المشاريع — يظهر هنا.',
            )
          else
            ...projects.map((p) => _ProjectTile(project: p)),
          const SizedBox(height: 26),
          _SectionTitle('أعمالي', count: works.length, openCount: openWorks),
          const SizedBox(height: 10),
          if (works.isEmpty)
            const _Empty(
              icon: Icons.checklist_rtl_rounded,
              title: 'لم يُسنَد إليك عمل بعد',
              hint: 'الأعمال التشغيلية يُسنِدها مدير الإدارة، وتظهر هنا فور إسنادها إليك.',
            )
          else
            ...works.map((w) => _WorkTile(work: w)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final int count;
  final int? openCount;

  const _SectionTitle(this.text, {required this.count, this.openCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Text(
          openCount != null && openCount! > 0 ? '($count — $openCount قيد العمل)' : '($count)',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _Empty({required this.icon, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final uid = store.currentUser?.id;
    final dept = store.departmentById(project.departmentId);
    // الدور في هذا المشروع بعينه: قد يكون مديراً هنا ومنفّذاً هناك.
    final role = project.isManager(uid) ? 'مدير المشروع' : 'منفّذ';
    // إدارة المشروع تُذكر حين تخالف إدارة المستخدم — وهي الحالة التي بُنيت
    // هذه الشاشة لأجلها، فلا يُترك الفرق بلا بيان.
    final outside = dept != null && !store.myDepartmentIds.contains(project.departmentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                    child: Text(project.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: project.effectiveStatus),
                ],
              ),
              const SizedBox(height: 10),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              MetaRow(
                runSpacing: 6,
                children: [
                  MetaChip(icon: Icons.person_pin_circle_outlined, text: 'دورك: $role'),
                  MetaChip(
                      icon: Icons.event_outlined,
                      text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  MetaChip(
                    icon: Icons.schedule_rounded,
                    text: project.delayDays > 0 ? 'متأخر ${project.delayDays} يوم' : 'ضمن الجدول الزمني',
                    color: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                  ),
                ],
              ),
              if (outside) ...[
                const SizedBox(height: 8),
                MetaLine(icon: Icons.account_balance_outlined, text: 'إدارة المشروع: ${dept.name}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  final WorkItem work;
  const _WorkTile({required this.work});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(work.departmentId);
    final outside = dept != null && !store.myDepartmentIds.contains(work.departmentId);
    final delay = work.delayDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // العمل يُدخَل كما يُدخل المشروع: كانت البطاقة بلا `onTap` إطلاقاً،
      // فمن أُسنِد إليه عمل لا يجد موضعاً يقرأ فيه سجلّه ولا يكتب فيه تحديثه.
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openWorkDetail(context, work),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(work.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        decoration: work.isDone ? TextDecoration.lineThrough : null,
                        color: work.isDone ? AppColors.textSecondary : AppColors.textPrimary,
                      )),
                ),
                const SizedBox(width: 8),
                PriorityChip(priority: work.priority),
              ],
            ),
            if (work.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(work.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.6)),
            ],
            const SizedBox(height: 10),
            LabeledProgressBar(value: work.progressPercent, label: 'نسبة الإنجاز'),
            const SizedBox(height: 10),
            MetaRow(
              runSpacing: 6,
              children: [
                MetaChip(icon: Icons.event_outlined, text: 'الموعد: ${Formatters.shortDate(work.dueDate)}'),
                if (work.isDone)
                  const MetaChip(
                      icon: Icons.check_circle_outline_rounded, text: 'منجَز', color: AppColors.success)
                else if (delay > 0)
                  MetaChip(icon: Icons.schedule_rounded, text: 'متأخر $delay يوم', color: AppColors.danger),
                if (work.isRecurring) const MetaChip(icon: Icons.repeat_rounded, text: 'عمل دوري'),
              ],
            ),
            if (outside) ...[
              const SizedBox(height: 8),
              MetaLine(icon: Icons.account_balance_outlined, text: 'إدارة العمل: ${dept.name}'),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
