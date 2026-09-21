import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../screens/change_manager_dialog.dart';
import '../theme/app_theme.dart';

/// بطاقة «فريق المشروع» — مديروه ومنفّذوه، وانضمام الموظف بنفسه.
///
/// للمشروع أكثر من مدير بقرار من مسؤول النظام، فحوار «تعيين مدير المشروع»
/// المفرد لم يعد يكفي. وما يظهر هنا من أزرار ينبع من صلاحية فعلية:
/// «الانضمام لمشاريع الإدارة» قابلة للسحب من شاشة صلاحيات الأدوار، وقاعدة
/// الأمان على الخادم تفرض أن يعدّل الموظف **معرّفه هو فقط** — فإخفاء الزر
/// راحة للمستخدم لا حماية، والحماية في مكانها.
class ProjectTeamCard extends StatefulWidget {
  final Project project;
  const ProjectTeamCard({super.key, required this.project});

  @override
  State<ProjectTeamCard> createState() => _ProjectTeamCardState();
}

class _ProjectTeamCardState extends State<ProjectTeamCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      // النصّ يأتي مترجَماً من `describeWriteFailure`، ولا يُلفّ بعبارةٍ
      // ثانية: «تعذّر تنفيذ العملية: رفض الخادم هذا الإجراء…» حشوٌ يُبعد
      // العلاج عن أول سطرٍ يقرؤه المستخدم.
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        duration: const Duration(seconds: 12),
      ));
    }
  }

  String _nameOf(AppStore store, String uid) {
    final match = store.users.where((u) => u.id == uid);
    if (match.isNotEmpty) return match.first.name;
    if (store.currentUser?.id == uid) return store.currentUser!.name;
    return 'حساب غير معروف';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // المشروع يُقرأ من المتجر لا من الودجة: بعد الانضمام تصل لقطة جديدة من
    // الخادم، ولو عرضنا النسخة المُمرَّرة لبقيت البطاقة تُظهر الحالة القديمة.
    final project = store.projectById(widget.project.id) ?? widget.project;
    final me = store.currentUser?.id;
    final canJoin = store.canSelfAssign(project);
    final canManageTeam = store.canManageProjectTeam(project);
    final iAmManager = project.isManager(me);
    final iAmExecutor = project.isExecutor(me);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('فريق المشروع',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_busy)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 14),
            // ــ تغيير المدير من حيث يُرى ــ
            //
            // كان تعديل مدير المشروع متعذّراً على مسؤول النظام نفسه: لا زرّ
            // في المنصة يفعله. فصار هنا، بجوار اسم المدير — لا في شاشة
            // إعدادات بعيدة.
            if (store.canRequestManagerChange(project))
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ChangeManagerDialog(project: project),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                  label: Text(store.isAdmin ? 'تغيير مدير المشروع' : 'طلب تغيير مدير المشروع'),
                ),
              ),
            if (store.canRequestManagerChange(project)) const SizedBox(height: 12),
            _group(
              store,
              project,
              title: 'مديرو المشروع',
              uids: project.managerUids,
              emptyText: 'لم يُعيَّن مدير بعد',
              canManageTeam: canManageTeam,
              isManagerGroup: true,
            ),
            const SizedBox(height: 14),
            _group(
              store,
              project,
              title: 'المنفّذون المسجَّلون',
              uids: project.executorUids,
              emptyText: 'لا منفّذين مسجَّلين بحساباتهم',
              canManageTeam: canManageTeam,
              isManagerGroup: false,
            ),
            if (project.executorNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              // أسماء وردت في ملفات الوزارة ولا تقابلها حسابات في المنصة —
              // تُعرض كما هي ولا تُدمج مع الحسابات حتى لا يختلط المرجعان.
              Text('منفّذون بالاسم من ملفات المتابعة: ${project.executorLabel}',
                  style: const TextStyle(fontSize: 12, height: 1.7, color: AppColors.textSecondary)),
            ],
            if (canJoin) ...[
              const Divider(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // ــ «اطلب» لا «سجّلني» ــ
                  //
                  // اللفظ يتبع ما يقع: قيادةُ المشروع صارت تُطلب ويعتمدها
                  // مدير إدارة المشروع، فزرٌّ يقول «سجّلني مديراً» يَعِد
                  // بما لا يقع. ومن يملك تعديل الفريق (مدير الإدارة ومسؤول
                  // النظام) يسجّل نفسه مباشرةً كما كان — لا معنى لأن يطلب
                  // من نفسه.
                  if (!iAmManager)
                    OutlinedButton.icon(
                      onPressed: _busy || store.hasPendingManagerAppointment(project)
                          ? null
                          : () => _run(() => store.joinProject(project, asManager: true)),
                      icon: const Icon(Icons.manage_accounts_outlined, size: 17),
                      label: Text(store.hasPendingManagerAppointment(project)
                          ? 'طلب التعيين قيد الاعتماد'
                          : (canManageTeam
                              ? 'سجّلني مديراً للمشروع'
                              : 'اطلب تعييني مديراً للمشروع')),
                    ),
                  if (!iAmExecutor)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(() => store.joinProject(project, asManager: false)),
                      icon: const Icon(Icons.engineering_outlined, size: 17),
                      label: const Text('سجّلني منفّذاً'),
                    ),
                  if (iAmManager || iAmExecutor)
                    TextButton.icon(
                      onPressed: _busy ? null : () => _run(() => store.leaveProject(project)),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('انسحب من المشروع'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _group(
    AppStore store,
    Project project, {
    required String title,
    required List<String> uids,
    required String emptyText,
    required bool canManageTeam,
    required bool isManagerGroup,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (uids.isEmpty)
          Text(emptyText, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final uid in uids)
                Chip(
                  avatar: Icon(
                    isManagerGroup ? Icons.manage_accounts_outlined : Icons.engineering_outlined,
                    size: 16,
                  ),
                  label: Text(_nameOf(store, uid), style: const TextStyle(fontSize: 12.5)),
                  // مسؤول النظام ومدير الإدارة يحوّلان الصفة أو يزيلان العضو؛
                  // وهذا ما طلبه مسؤول النظام: تحويل مدير المشروع إلى منفّذ.
                  // وإزالةُ **مدير** تمرّ بـ`revokeProjectManager` لا
                  // بـ`setProjectMemberRole` مباشرةً: تلك تكتب سطراً عاماً
                  // «عُدِّل الفريق»، وهذه تكتب «ألغى فلانٌ تعيين فلان مديراً
                  // لمشروع كذا» — وهو ما يُسأل عنه في المراجعة.
                  onDeleted: canManageTeam && !_busy
                      ? () => _run(() => isManagerGroup
                          ? store.revokeProjectManager(project, uid)
                          : store.setProjectMemberRole(project, uid, null))
                      : null,
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteButtonTooltipMessage: 'إزالة من الفريق',
                ),
              if (canManageTeam)
                for (final uid in uids)
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => store.setProjectMemberRole(
                              project, uid, isManagerGroup ? 'executor' : 'manager')),
                    icon: Icon(isManagerGroup ? Icons.south_rounded : Icons.north_rounded, size: 15),
                    label: Text(
                      isManagerGroup
                          ? 'حوّل ${_nameOf(store, uid)} إلى منفّذ'
                          : 'حوّل ${_nameOf(store, uid)} إلى مدير',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}
