import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/late_alert.dart';
import '../models/notify_templates.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/platform_url.dart';
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
                  MetaLine(
                    icon: Icons.person_outline_rounded,
                    text: 'المسؤول: ${work.assigneeName.isEmpty ? 'غير مُسنَد' : work.assigneeName}',
                  ),
                  // ــ الإسناد بالاسم وحده ــ
                  //
                  // «المُسنَد إليّ» تُبنى على حساب المستخدم لا على اسمه
                  // المكتوب. فعملٌ يحمل اسماً بلا حساب يبدو مُسنَداً هنا ولا
                  // يظهر لصاحبه في صفحته أبداً — ولا شيء يقول لماذا. فيُقال.
                  // ــ رُدَّ لعدم الاختصاص ــ
                  //
                  // بلا هذا يجد مدير الإدارة عملاً «غير مُسنَد» ولا يعرف أنه
                  // عُرض على أحدٍ وردَّه — فيُسنده إليه من جديد وتدور الدورة.
                  if (work.closure.isDeclined && work.assigneeUid.isEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رُدَّ لعدم الاختصاص — ${work.closure.declinedByName}'
                            '${work.closure.declinedAt == null ? '' : ' · ${Formatters.shortDate(work.closure.declinedAt!)}'}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(work.closure.declinedReason,
                              style: const TextStyle(fontSize: 12, height: 1.7)),
                          const SizedBox(height: 4),
                          const Text(
                            'وهو الآن بلا مُسنَدٍ إليه — أسنِده لمن يختصّ من «تعديل بيانات العمل».',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (work.assigneeUid.isEmpty && work.assigneeName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'هذا العمل مُسنَد بالاسم لا بحساب على المنصة، فلا يظهر لصاحبه في صفحة '
                        '«المُسنَد إليّ». افتح «تعديل بيانات العمل» واختر المسؤول من قائمة '
                        'الحسابات ليظهر له.',
                        style: TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // ــ «تم الإنجاز» لا «إغلاق» ــ
                      //
                      // اللفظ مقصود: من ينفّذ **يُفيد** بالإتمام ولا يُغلق.
                      // والإغلاق زرٌّ آخر عند طرفٍ آخر.
                      // ــ «جارٍ العمل» ــ
                      //
                      // كان تحريك الحالة يمرّ بنموذج تعديل العمل (وهو لمدير
                      // الإدارة) أو بالتحديث اليومي. فالموظف الذي بدأ فعلاً
                      // لا يملك أن يقول ذلك، ويبقى عملُه «لم تبدأ» في كل
                      // شاشة وفي التقرير اليومي — فيُقرأ إهمالاً وهو يُنجَز.
                      if (store.canStartWork(work))
                        FilledButton.icon(
                          onPressed: () => _start(context, store, work),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('جارٍ العمل'),
                        ),
                      if (store.canClaimWorkCompletion(work) && !work.isAwaitingApproval)
                        FilledButton.icon(
                          onPressed: () => _claim(context, store, work),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: Text(work.closure.requiresApproval ? 'تم الإنجاز' : 'إغلاق العمل'),
                        ),
                      // ــ «لا يخصّني» ــ
                      //
                      // للمُسنَد إليه وحده، ولا يظهر لمن يشرف: مدير الإدارة
                      // يُعيد الإسناد من النموذج، ولا معنى لأن «يعتذر» عن
                      // عملٍ لم يُسنَد إليه.
                      if (store.canDeclineWork(work))
                        OutlinedButton.icon(
                          onPressed: () => _decline(context, store, work),
                          icon: const Icon(Icons.person_off_outlined, size: 18),
                          label: const Text('لا يخصّني (عدم اختصاص)'),
                        ),
                      if (work.isAwaitingApproval && store.canApproveWorkClosure(work)) ...[
                        FilledButton.icon(
                          onPressed: () => _approve(context, store, work),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('اعتماد الإنجاز والإغلاق'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _rework(context, store, work),
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('إعادة للتنفيذ'),
                        ),
                      ],
                      if (canUpdate)
                        OutlinedButton.icon(
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
                  // من أفاد بالإتمام يجب أن يرى أن الكرة صارت في ملعبٍ آخر،
                  // وإلا ظنّ الزرَّ لم يعمل فأعاد الضغط.
                  if (work.isAwaitingApproval && !store.canApproveWorkClosure(work)) ...[
                    const SizedBox(height: 4),
                    Text(
                      'أُفيد بإتمام هذا العمل، ولا يُغلق إلا باعتماد '
                      '${work.closure.approverName.isEmpty ? 'طالبه' : work.closure.approverName}.',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
                    ),
                  ],
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
          _ClosureTimeline(work: work, store: store),
          const SizedBox(height: 22),
          Row(
            children: [
              // `Flexible` لا نصٌّ حرّ: بلا حدٍّ يُرسم العنوان بطوله كاملاً
              // ويطفح الصفُّ يميناً — وقد قِيس ٢٦ بكسل على آيفون SE.
              const Flexible(
                child: Text('سجل التحديثات اليومية',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
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

/// «تم الإنجاز» — إفادةٌ بالإتمام لا إغلاق.
///
/// ــــ الإشعار: فوريٌّ داخل المنصة، وبريدٌ اختياري ــــ
///
/// إشعار المعتمِد داخل المنصة يقع **دائماً وفوراً**: قسم «بانتظار اعتمادك»
/// في صفحته يُبنى من الحالة نفسها بلا وسيط.
///
/// والبريد اختياري لأنه يمرّ ببوابة `notifySend`: كل رسالة تخرج باسم المنصة
/// يعتمدها مسؤول النظام. فإخطارٌ من غير مسؤول النظام يصير **طلباً** ينتظر
/// البتّ، وقد يتراكم في مركز القرارات إن أُرسل مع كل إفادة إتمام. فيُقال ذلك
/// في النافذة ويُترك القرار لمن يضغط — والحالة تتحوّل سواء خرج البريد أو لا.
Future<void> _claim(BuildContext context, AppStore store, WorkItem work) async {
  final gated = work.closure.requiresApproval;
  var alsoEmail = true;

  final approver =
      store.users.where((u) => u.id == work.closure.approverUid).firstOrNull;
  final canEmail = gated && approver != null && approver.email.trim().isNotEmpty;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      return AlertDialog(
        title: Text(gated ? 'الإفادة بإتمام العمل' : 'إغلاق العمل'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gated
                    ? 'تنتقل حالة العمل إلى «بانتظار الاعتماد»، ويظهر لدى '
                        '${work.closure.approverName} في صفحته فوراً. ولا يُغلق إلا باعتماده.'
                    : 'هذا العمل بلا مرحلة اعتماد، فيُغلق الآن مباشرةً.',
                style: const TextStyle(fontSize: 12.5, height: 1.9),
              ),
              if (canEmail) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: alsoEmail,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('إخطاره بالبريد أيضاً',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    store.isAdmin
                        ? 'يُرسَل البريد الآن.'
                        : 'البريد يمرّ باعتماد مسؤول النظام، فقد يصل متأخراً. '
                            'أما الإشعار داخل المنصة فيصل فوراً بلا انتظار.',
                    style: const TextStyle(
                        fontSize: 11, height: 1.6, color: AppColors.textSecondary),
                  ),
                  onChanged: (v) => setLocal(() => alsoEmail = v ?? false),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(gated ? 'تم الإنجاز' : 'إغلاق'),
          ),
        ],
      );
    }),
  );
  if (go != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await store.claimWorkCompletion(work);
    if (canEmail && alsoEmail) {
      final notice = completionClaimNotice(
        itemTitle: work.title,
        claimedByName: store.currentUser?.name ?? '',
        claimedAt: DateTime.now(),
        link: workLink(platformBaseUrl(), work.id),
      );
      // البريد **بعد** تحوّل الحالة ولا يُفشلها: الحوكمة في الحالة لا في
      // الرسالة، وفشلُ الإرسال لا يجوز أن يُبقي العمل معلّقاً في يد المنفّذ.
      await store.sendOrRequestNotification(
        messages: [(user: approver, subject: notice.subject, body: notice.body)],
        channel: NotifyChannel.email,
        requestTitle: 'إخطار اعتماد إنجاز — ${work.title}',
        requestDescription: notice.subject,
        auditAction: 'إخطار اعتماد',
        auditDetails: 'إخطار ${approver.name} باعتماد إنجاز العمل "${work.title}"',
      );
    }
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(gated
          ? 'أُفيد بإتمام العمل. لا يُغلق إلا باعتماد ${work.closure.approverName}.'
          : 'أُغلق العمل.'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('تعذّر التنفيذ: $e')));
  }
}

/// «اعتماد الإنجاز» — هنا وحده يُغلق العمل.
Future<void> _approve(BuildContext context, AppStore store, WorkItem work) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await store.approveWorkClosure(work);
    messenger.showSnackBar(const SnackBar(content: Text('اعتُمد الإنجاز وأُغلق العمل.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('تعذّر الاعتماد: $e')));
  }
}

/// «إعادة للتنفيذ» — بسببٍ مكتوب لا بضغطة صامتة.
Future<void> _rework(BuildContext context, AppStore store, WorkItem work) async {
  final ctrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إعادة العمل للتنفيذ'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ما الذي ينقص؟ يقرؤه المنفّذ، ويبقى في سجل العمل. وردٌّ بلا سبب '
              'يُعيده إلى نقطة البداية بلا أن يعرف المطلوب فيُردّ ثانيةً.',
              style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'سبب الإعادة…'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('إعادة للتنفيذ'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (reason == null) return;
  if (reason.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('سبب الإعادة مطلوب.')));
    return;
  }
  try {
    await store.sendWorkBackForRework(work, reason);
    // ومن أُعيد إليه العمل يُخطَر: الرد بلا إخطار يترك العمل يرجع إلى قائمته
    // بلا أن يعرف أنه رجع، فيقف أياماً بلا حركة.
    final assignee = store.users.where((u) => u.id == work.assigneeUid).firstOrNull;
    if (assignee != null && assignee.email.trim().isNotEmpty) {
      final notice = reworkNotice(
        itemTitle: work.title,
        byName: store.currentUser?.name ?? '',
        reason: reason,
        link: workLink(platformBaseUrl(), work.id),
      );
      await store.sendOrRequestNotification(
        messages: [(user: assignee, subject: notice.subject, body: notice.body)],
        channel: NotifyChannel.email,
        requestTitle: 'إخطار إعادة للتنفيذ — ${work.title}',
        requestDescription: notice.subject,
        auditAction: 'إخطار إعادة للتنفيذ',
        auditDetails: 'إخطار ${assignee.name} بإعادة العمل "${work.title}" للتنفيذ',
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('أُعيد العمل للتنفيذ مع السبب.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('تعذّرت الإعادة: $e')));
  }
}

/// شريط دورة الإغلاق: من أنشأ ← من استلم ← من أفاد بالإتمام ← من اعتمد.
///
/// ــــ لماذا شريطٌ لا سطرٌ في سجل التدقيق؟ ــــ
///
/// لأن سجل التدقيق لمسؤول النظام وحده ويُقرأ بالبحث. ومن يسأل «من قال إن هذا
/// تمّ، ومتى، ومن اعتمده؟» يسأل عن **هذا العمل** وهو ينظر إليه — فالجواب
/// يجب أن يكون في صفحته لا في شاشةٍ أخرى لا يفتحها.
class _ClosureTimeline extends StatelessWidget {
  final WorkItem work;
  final AppStore store;
  const _ClosureTimeline({required this.work, required this.store});

  String _nameOf(String uid, String fallback) {
    if (uid.isEmpty) return fallback;
    return store.users.where((u) => u.id == uid).map((u) => u.name).firstOrNull ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = work.closure;
    final steps = <({IconData icon, String title, String detail, Color color, bool done})>[
      (
        icon: Icons.add_circle_outline_rounded,
        title: 'أنشأ الطلب',
        detail: '${_nameOf(work.createdByUid, 'غير معروف')} · ${Formatters.date(work.createdAt)}',
        color: AppColors.info,
        done: true,
      ),
      (
        icon: Icons.person_outline_rounded,
        title: 'استلمه',
        detail: work.assigneeName.isEmpty ? 'لم يُسنَد بعد' : work.assigneeName,
        color: AppColors.info,
        done: work.assigneeName.isNotEmpty,
      ),
      (
        icon: Icons.done_all_rounded,
        title: 'أفاد بالإتمام',
        detail: c.claimedAt == null
            ? 'لم يُفَد بالإتمام بعد'
            : '${c.claimedByName} · ${Formatters.date(c.claimedAt!)}',
        color: AppColors.warning,
        done: c.claimedAt != null,
      ),
      (
        icon: Icons.verified_rounded,
        title: 'اعتمد الإغلاق',
        detail: c.approvedAt == null
            ? (c.requiresApproval
                ? 'بانتظار ${c.approverName.isEmpty ? 'المعتمِد' : c.approverName}'
                : 'هذا العمل يُغلق مباشرةً بلا اعتماد')
            : '${c.approvedByName} · ${Formatters.date(c.approvedAt!)}',
        color: AppColors.success,
        done: c.approvedAt != null,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('دورة الإغلاق',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            for (final s in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s.icon,
                        size: 18,
                        color: s.done ? s.color : AppColors.textSecondary.withValues(alpha: 0.45)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: s.done
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary)),
                          Text(s.detail,
                              style: const TextStyle(
                                  fontSize: 11.5, height: 1.6, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // الإعادة ليست خطوةً في الدورة بل انحرافٌ عنها — فتُعرض تحتها
            // بعددها وسببها، لا مدسوسةً بينها.
            if (c.reworkCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أُعيد للتنفيذ ${c.reworkCount} مرة',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    if (c.reworkReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'آخر سبب: ${c.reworkReason}'
                          '${c.reworkByName.isEmpty ? '' : ' — ${c.reworkByName}'}',
                          style: const TextStyle(
                              fontSize: 11.5, height: 1.7, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
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

/// «جارٍ العمل» — إعلانُ البدء بضغطة.
Future<void> _start(BuildContext context, AppStore store, WorkItem work) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await store.startWork(work);
    messenger.showSnackBar(const SnackBar(
      content: Text('حُدِّثت الحالة إلى «قيد التنفيذ».'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeWriteFailure(e))));
  }
}

/// «لا يخصّني» — ردُّ المُسنَد إليه البندَ لعدم الاختصاص.
///
/// ــــ ولماذا يُشترط سببٌ مكتوب؟ ــــ
///
/// لأن البند يعود إلى مدير الإدارة **بلا مُسنَدٍ إليه**. فلولا السبب لَوجده
/// «غير مُسنَد» بلا أن يعرف أنه عُرض على أحدٍ وردَّه — فيُسنده إليه من جديد،
/// وتدور الدورة. والسببُ هو ما يكسرها.
Future<void> _decline(BuildContext context, AppStore store, WorkItem work) async {
  final ctrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ردّ العمل لعدم الاختصاص'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ما سيقع يُقال قبل الضغط لا بعده.
            const Text(
              'يُرفع اسمك عن هذا العمل، ويبقى في إدارتك مفتوحاً فيراه مديرها '
              'ويُسنده لمن يختصّ. ولا يُلغى ولا يعود لمن طلبه.',
              style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'لماذا لا يخصّك؟ ومن يخصّه إن كنت تعرف…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('ردّ لعدم الاختصاص'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (reason == null) return;
  if (reason.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('سبب عدم الاختصاص مطلوب.')));
    return;
  }
  try {
    await store.declineWork(work, reason);
    messenger.showSnackBar(const SnackBar(
      content: Text('رُدَّ العمل لعدم الاختصاص، وعاد إلى إدارتك بلا مُسنَدٍ إليه.'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeWriteFailure(e))));
  }
}
