import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/assignment_policy.dart';
import '../models/closure_trail.dart';
import '../models/enums.dart';
import '../models/work_sort.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../widgets/meta_row.dart';
import '../utils/formatters.dart';
import '../models/notify_templates.dart';
import '../widgets/focus_assignment_dialog.dart';
import '../widgets/kpi_card.dart';
import '../widgets/notify_dialog.dart';
import '../widgets/progress_bar.dart';
import 'work_detail_screen.dart';

/// شاشة "الأعمال": بنود العمل التشغيلية المستقلة عن المشاريع.
///
/// تعرض تبويبين: الأعمال الجارية، وسجل الإنجاز (المنجَزة مرتّبة بالأحدث).
/// وصف الإسناد كما يُقرأ — ومعه تحذيرٌ إن كان بالاسم وحده.
///
/// ــــ لماذا التفريق؟ ــــ
///
/// «المُسنَد إليّ» تُبنى على **حساب** المستخدم (`assigneeUid`) لا على اسمه
/// المكتوب. فعملٌ يحمل اسماً بلا حساب يبدو مُسنَداً في قائمة الأعمال، ولا
/// يظهر لصاحبه في صفحته أبداً — ولا شيء في الشاشة يقول لماذا.
///
/// ويقع هذا في حالين حقيقيّين: عملٌ أُنشئ قبل أن يكون للشخص حساب، أو طلبٌ
/// اعتُمد بلا اختيار مسؤول من القائمة (الخادم يكتب `assigneeUid: null`).
String assigneeLabel(WorkItem work) {
  if (work.assigneeName.isEmpty) return 'غير مُسنَد';
  if (work.assigneeUid.isEmpty) return '${work.assigneeName} (بالاسم فقط)';
  return work.assigneeName;
}

class WorksListScreen extends StatefulWidget {
  const WorksListScreen({super.key});

  @override
  State<WorksListScreen> createState() => _WorksListScreenState();
}

/// قيمةُ خيار «غير مُسنَد» في مرشِّح المسؤول.
///
/// ولا تكون السلسلة الفارغة: `null` تعني «كل المسؤولين»، و`''` قد تُقرأ
/// خطأً مساويةً لـ`assigneeUid` الفارغ في مقارنةٍ لاحقة — فيلتبس المرشِّح
/// بالمرشَّح. وهذه قيمةٌ لا تصلح معرّفاً لأحد.
const String _unassignedFilter = '__unassigned__';

class _WorksListScreenState extends State<WorksListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _departmentFilter;
  String? _assigneeFilter;
  TaskStatus? _statusFilter;
  WorkSort _sort = WorkSort.newest;
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
      if (_assigneeFilter == _unassignedFilter) {
        if (w.assigneeUid.isNotEmpty) return false;
      } else if (_assigneeFilter != null && w.assigneeUid != _assigneeFilter) {
        return false;
      }
      if (_statusFilter != null && w.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return w.title.toLowerCase().contains(q) || w.assigneeName.toLowerCase().contains(q);
    }).toList();
    works = sortWorks(works, _sort);

    final overdue = all.where((w) => w.delayDays > 0).length;
    final canAssign = store.isAdmin || store.canManageWorks;
    final awaitingAssignment =
        all.where((w) => !w.isDone && w.assigneeUid.isEmpty).length;
    final assigneeOptions = <String, String>{
      for (final w in all) w.assigneeUid: w.assigneeName,
    }..removeWhere((k, v) => k.isEmpty);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'الأعمال',
            subtitle: 'بنود العمل التشغيلية والإدارية المستقلة عن المشاريع',
            actions: [
              // الزر لكل من ينتمي لإدارة: من يملك الإنشاء المباشر يُنشئ،
              // ومن سواه يقدّم طلباً يعتمده مدير إدارته.
              if (store.canManageWorks || store.canRequestNewWork(store.currentUser?.departmentId))
                BandButton(
                  label: store.canManageWorks || store.canCreateIn(store.currentUser?.departmentId)
                      ? 'إضافة عمل'
                      : 'طلب إضافة عمل',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const WorkFormDialog()),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 820 ? 4 : (c.maxWidth > 520 ? 2 : 1);
            const spacing = 14.0;
            const itemHeight = KpiCard.tileHeight;
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
                // «قيد التنفيذ» لم تعد تعني «كل ما ليس منجَزاً»: ما أُعلن
                // إتمامه ينتظر مكتباً لا تنفيذاً، وعدُّه مع الجاري يُخفي
                // بالضبط ما طُلب إظهاره.
                KpiCard(title: 'قيد التنفيذ', value: '${all.where((w) => !w.isDone && !w.isAwaitingApproval).length}', icon: Icons.play_arrow_rounded, color: AppColors.info),
                KpiCard(title: 'بانتظار الاعتماد', value: '${all.where((w) => w.isAwaitingApproval).length}', icon: Icons.how_to_reg_outlined, color: AppColors.warning),
                KpiCard(title: 'منجزة ومغلقة', value: '${all.where((w) => w.isDone).length}', icon: Icons.check_circle_outline_rounded, color: AppColors.success),
                KpiCard(title: 'متأخرة عن موعدها', value: '$overdue', icon: Icons.schedule_rounded, color: AppColors.danger),
                // ــــ ما ينتظر تكليفاً ــــ
                //
                // الطلب الوارد من إدارة أخرى يصل بلا منفّذ، ومن يُردّ لعدم
                // الاختصاص يعود بلا منفّذ. وكلاهما **مرئيّ** لمدير الإدارة
                // في القائمة، **غيرُ قابلٍ للعثور**: لا مرشِّح يجمعه ولا عدّ
                // يذكره. فيبقى ينتظر بلا أن يعلم أحد أنه ينتظر.
                //
                // ولمن يملك التكليف وحده: عدٌّ لا يملك قارئه فعلَه إزعاجٌ.
                if (canAssign)
                  KpiCard(
                    title: 'ينتظر التكليف',
                    value: '$awaitingAssignment',
                    icon: Icons.person_search_rounded,
                    color: AppColors.warning,
                  ),
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
                    // «غير مُسنَد» أوّلَ الخيارات لا آخرها: هو ما يحتاج
                    // فعلاً — والأسماء تُقرأ بحثاً، وهذا يُقرأ عملاً.
                    if (awaitingAssignment > 0)
                      DropdownMenuItem(
                        value: _unassignedFilter,
                        child: Text('غير مُسنَد ($awaitingAssignment)'),
                      ),
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
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<WorkSort>(
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الترتيب', isDense: true),
                  items: WorkSort.values
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _sort = v ?? _sort),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('${works.length} عمل', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // «لا توجد أعمال مطابقة» جوابٌ خاطئ حين لا يكون في نطاق المستخدم عمل
          // أصلاً: فيظن أن عطلاً أصابه بينما لم يُسنَد إليه شيء بعد. نفرّق
          // بين الفراغ والتصفية، ونقول للموظف من يُسنِد إليه العمل.
          if (works.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.checklist_rtl_rounded, size: 34, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      all.isEmpty
                          ? 'لا توجد أعمال مُسنَدة إليك بعد'
                          : (_showLog ? 'لا توجد أعمال منجزة بعد' : 'لا توجد أعمال مطابقة لبحثك'),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    if (all.isEmpty && !store.canManageWorks) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'الأعمال التشغيلية يُسنِدها إليك مدير إدارتك، وتظهر هنا فور إسنادها.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...works.map((w) => _WorkRow(work: w)),
              ],
            ),
          ),
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
    final delay = work.delayDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // النقر يفتح **صفحة العمل** لا نافذة التحرير:
        //
        // كان يفتح التحرير لمن يملكه، ولا يفعل شيئاً لغيره — فمن يقرأ عملاً
        // في إدارته لا يجد سبيلاً إلى تفاصيله ولا إلى سجلّه. والصفحة تحمل
        // زرّ التحرير لمن يملكه، فلم يضع شيء.
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(work.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(
                          '${dept?.name ?? 'بدون إدارة'} · ${assigneeLabel(work)}',
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
                  if (store.canSoftDeleteWork(work))
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      tooltip: 'حذف العمل',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final reasonCtrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف العمل'),
                            content: SizedBox(
                              width: 420,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'سيختفي "${work.title}" من كل القوائم. ولا يُمحى شيء: '
                                    'يستعيده مسؤول النظام متى شاء.',
                                    style: const TextStyle(fontSize: 13, height: 1.7),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: reasonCtrl,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'سبب الحذف (مطلوب)',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('سبب الحذف مطلوب — يُقرأ في سجل التدقيق بعد شهور.'),
                            backgroundColor: AppColors.warning,
                          ));
                          return;
                        }
                        final error = await store.softDeleteWork(work, reason: reason);
                        messenger.showSnackBar(SnackBar(
                          content: Text(error ?? 'حُذف "${work.title}" — يمكن استعادته من «المحذوفات».'),
                          backgroundColor: error == null ? AppColors.success : AppColors.danger,
                        ));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledProgressBar(value: work.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              MetaRow(
                runSpacing: 6,
                children: [
                  MetaChip(icon: Icons.event_outlined, text: 'الموعد: ${Formatters.shortDate(work.dueDate)}'),
                  if (work.completedDate != null)
                    MetaChip(
                        icon: Icons.check_circle_outline_rounded,
                        text: 'أُنجز: ${Formatters.shortDate(work.completedDate!)}',
                        color: AppColors.success),
                  if (delay > 0)
                    MetaChip(icon: Icons.schedule_rounded, text: 'متأخر $delay يوم', color: AppColors.danger),
                  if (work.isRecurring) const MetaChip(icon: Icons.repeat_rounded, text: 'عمل دوري'),
                ],
              ),
            ],
          ),
        ),
      ),
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

  /// هل يمرّ هذا العمل بمرحلة اعتماد قبل إغلاقه؟
  ///
  /// يُملأ مبدئياً من `defaultApproverUid`: نعم حين يكون المُنشئ من خارج
  /// الإدارة المنفّذة. ويبقى **ظاهراً وقابلاً للتعديل** — قاعدةٌ صامتة تُقرَّر
  /// عن المستخدم بلا أن يراها تُفاجئه أول مرة يُغلق فيها عملاً فلا يُغلق.
  bool? _requireApprovalOverride;

  bool _requiresApproval(AppStore store) {
    if (widget.editing != null) return widget.editing!.closure.requiresApproval;
    return _requireApprovalOverride ??
        defaultApproverUid(
              creator: store.currentUser,
              executingDepartmentId: _departmentId,
            ) !=
            null;
  }

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
    // ولا يُلزَم الطالب بتسمية منفّذ — ولو كانت الإدارة غير إدارته.
    //
    // كان يُلزَم، وعلّة الإلزام أن العمل بلا مُسنَدٍ إليه لا يظهر في «المُسنَد
    // إليّ» لأحد فيقع في فراغ. والعلّة صحيحة والعلاج كان خطأً: من يطلب من
    // إدارةٍ أخرى **لا يعرف** توزيع الاختصاصات فيها، فإلزامه تخمينٌ باسم.
    //
    // فالترتيب أن الطلب يُعرض على مدير الإدارة، وهو من يكلّف. وسدُّ الفراغ
    // في مكانه لا هنا: زرّ «اعتمد وكلّف» عند الاعتماد، ومرشِّح «غير مُسنَد»
    // وبطاقة «ينتظر التكليف» في هذه الشاشة.
    setState(() {
      _busy = true;
      _error = null;
    });
    var requested = false;
    try {
      final assignee = store.users.where((u) => u.id == _assigneeUid);
      final assigneeName = assignee.isEmpty ? (widget.editing?.assigneeName ?? '') : assignee.first.name;

      // من لا يملك الإنشاء المباشر في هذه الإدارة يقدّم **طلباً** يعتمده
      // مدير الإدارة — نفس النموذج، ومخرجٌ مختلف.
      // `canCreateWorkIn` لا `canCreateIn && !canManageWorks`: الأولى تقرأ
      // نطاق **المشاريع**، والثانية تسأل «هل أملك إدارة الأعمال أصلاً؟» بلا
      // نظرٍ إلى الإدارة المختارة. فمديرُ إدارةٍ يوجّه عملاً لإدارةٍ أخرى كان
      // يسلك مسار الكتابة المباشرة فيردّه الخادم.
      if (widget.editing == null && !store.canCreateWorkIn(_departmentId)) {
        requested = true;
        await store.submitWorkRequest(
          departmentId: _departmentId,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          assigneeUid: _assigneeUid.isEmpty ? null : _assigneeUid,
          assigneeName: assigneeName,
        );
      } else if (widget.editing == null) {
        final me = store.currentUser;
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
          createdByUid: me?.id ?? '',
          createdAt: DateTime.now(),
          // المعتمِد هو **الطالب نفسه**: من طلب العمل هو من يراجع إتمامه.
          closure: _requiresApproval(store) && me != null
              ? ClosureTrail(approverUid: me.id, approverName: me.name)
              : ClosureTrail.none,
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
      if (requested) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب إضافة العمل لمدير الإدارة للاعتماد')),
        );
      }
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

    // ــــ من يفتح النموذج يملؤه ــــ
    //
    // كانت كل الحقول مشروطة بـ`canManageWorks`، بينما الزرّ يظهر لصاحب
    // `canRequestNewWork` أيضاً وفي `_submit` مسارٌ كامل لطلب الاعتماد.
    // فالطالب يفتح النموذج ولا يستطيع كتابة حرف، ومسار الطلب كلّه شيفرة
    // ميتة لا تُبلَغ أبداً — وهو ما اشتُكي منه: «لا يمكن إدخال بيانات».
    //
    // فالتحرير الآن لمن يُنشئ **أو** يطلب. ويبقى مقفلاً على الطالب ما لا
    // يملك تقريره: الحالة ونسبة الإنجاز — يبدأ العمل من «قيد الانتظار» و٠٪،
    // ومن يعتمده هو من يحرّكهما.
    final canManage = store.canManageWorks;
    final isRequest = widget.editing == null &&
        !store.canCreateWorkIn(
            _departmentId.isEmpty ? store.currentUser?.departmentId : _departmentId);
    // ــ ومن يعدّل سجلاً قائماً يُسأل عن السجل نفسه ــ
    //
    // كان الشرط `canManage` وحدها، وهي صلاحية «إدارة الأعمال» تُطفأ من شاشة
    // صلاحيات الأدوار. فمديرُ الإدارة يفتح نموذج عملٍ في إدارته فيجد كل
    // حقوله مقفلة — وهو يملك حذفَه.
    final canEdit = widget.editing == null || store.canEditWorkDetails(widget.editing!);
    final canSetProgress = canManage || !isRequest;
    // ــــ كل الإدارات، لا التي «أراها» ــــ
    //
    // كانت `store.visibleDepartments`، وهي تُرجع إدارة الموظف وحدها. فكان
    // **طلبُ عملٍ من إدارة أخرى مستحيلاً** — وهي حاجةٌ أساسية في وزارة،
    // ومبنيٌّ لها في المنصة دورةُ إغلاقٍ من مرحلتين لا تُبلَغ أصلاً.
    //
    // والخلط كان بين سؤالين: «أيّ إدارةٍ أقرأ بياناتها؟» — وذلك مقيَّد بحق،
    // و«أيّ إدارةٍ أوجّه إليها طلباً؟» — وذلك لا يُقيَّد: أسماء الإدارات
    // تُقرأ علناً حتى قبل تسجيل الدخول (تُعرض في شاشة التسجيل).
    final departments = store.departments;
    // المسؤولون المتاحون للإسناد — بالقاعدة الموحّدة لا بشرطٍ محلي.
    //
    // كان الشرط «معتمَد + في الإدارة» وحده، فكان الموظف يفتح النموذج فيجد
    // **المسؤول التنفيذي** ومدير الإدارة في قائمة من يُسنِد إليهم عملاً.
    final candidates = eligibleAssignees(
      allUsers: store.users,
      actor: store.currentUser,
      departmentId: _departmentId,
    );

    return AlertDialog(
      title: Text(widget.editing == null ? 'إضافة عمل' : 'تعديل العمل'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRequest) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gavel_rounded, size: 16, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذا طلب إضافة عمل يعتمده مدير الإدارة. الحالة ونسبة الإنجاز يحدّدهما عند الاعتماد.',
                          style: TextStyle(fontSize: 12, height: 1.6, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleCtrl,
                enabled: canEdit,
                decoration: const InputDecoration(labelText: 'اسم العمل'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                enabled: canEdit,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف مختصر (اختياري)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _departmentId.isEmpty ? null : _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الإدارة'),
                items: departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: canEdit
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
                decoration: const InputDecoration(
                  labelText: 'المسؤول عن التنفيذ (اختياري)',
                  // الحقلُ الفارغ يُقرأ نسياناً ما لم يُقَل أنه مسارٌ مقصود.
                  // فمن لا يعرف اختصاصات الإدارة يتركه واثقاً لا متردّداً.
                  helperText: 'اتركه إن لم تعرف من يختصّ — يكلّف مديرُ الإدارة '
                      'من يُنفّذ عند اعتماد الطلب.',
                  helperMaxLines: 2,
                ),
                items: candidates.map((u) => DropdownMenuItem<String>(value: u.id, child: Text(_userLabel(u)))).toList(),
                onChanged: canEdit ? (v) => setState(() => _assigneeUid = v ?? '') : null,
              ),
              // قائمةٌ خالية تبدو عطلاً. والسبب يُقال صراحةً.
              if (candidates.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  emptyAssigneeReason(
                    allUsers: store.users,
                    actor: store.currentUser,
                    departmentId: _departmentId,
                  ),
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.7, color: AppColors.textSecondary),
                ),
              ],
              // ــ مرحلة الاعتماد: تُقال ولا تُفترض ــ
              //
              // قاعدةٌ صامتة تقرّر عن المستخدم تُفاجئه أول مرة يضغط فيها «تم
              // الإنجاز» فلا يُغلق العمل ولا يعرف لماذا. فيراها هنا مملوءةً
              // مسبقاً، ويملك تعديلها.
              if (widget.editing == null) ...[
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _requiresApproval(store),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('يُغلق باعتمادي أنا',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                    'الإدارة المنفّذة تُفيد بالإتمام، ولا يُغلق العمل إلا بعد مراجعتك. '
                    'مفعّلٌ تلقائياً حين يكون العمل في إدارة غير إدارتك.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: AppColors.textSecondary),
                  ),
                  onChanged: canEdit
                      ? (v) => setState(() => _requireApprovalOverride = v ?? false)
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      // «منجزة» تُحجب عمّن لا يملك الاعتماد: إغلاقُ العمل
                      // قرارُ طالبه، وتركُها في القائمة يَعِد بما ترفضه قاعدة
                      // الخادم — فيظنّ المستخدم عطلاً وهو حارس.
                      items: TaskStatus.values
                          .where((s) =>
                              s != TaskStatus.done ||
                              widget.editing == null ||
                              !widget.editing!.closure.requiresApproval ||
                              store.canApproveWorkClosure(widget.editing!))
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: canSetProgress ? (v) => setState(() => _status = v ?? _status) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PriorityLevel>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الأولوية'),
                      items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                      onChanged: canEdit ? (v) => setState(() => _priority = v ?? _priority) : null,
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
                onChanged: canSetProgress ? (v) => setState(() => _progress = v) : null,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text('الموعد: ${Formatters.shortDate(_dueDate)}', style: const TextStyle(fontSize: 12.5)),
                  ),
                  TextButton.icon(
                    onPressed: canEdit
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
                onChanged: canEdit ? (v) => setState(() => _recurring = v) : null,
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
