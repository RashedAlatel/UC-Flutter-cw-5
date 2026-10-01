import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/late_alert.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// نافذة مراجعة تنبيه التأخير الجماعي — قبل أن يخرج بريدٌ واحد.
///
/// ــــ لماذا نافذةٌ كاملة لا سؤال «هل أنت متأكد؟» ــــ
///
/// لأن الإجراء الجماعي يختلف عن الفردي في شيءٍ واحد يغيّر كل شيء: **لا
/// يستطيع صاحبه أن يتخيّل نتيجته**. من يضغط «تنبيه ٤٧ مشروعاً» لا يعرف كم
/// شخصاً سيصلهم بريد، ولا مَن هم، ولا أن مشروعاً منها سُلِّم أمس ولم تُحدَّث
/// نسبته بعد. وسؤالُ «هل أنت متأكد؟» لا يضيف معلومةً واحدة إلى ما لا يعرفه.
///
/// فالنافذة تُري ما سيقع: المشاريع بأسمائها وأيام تأخيرها، والمستلمين وعدد
/// مشاريع كلٍّ منهم، **ويُستبعَد أيٌّ منهما بضغطة**. واستبعاد مشروع يعيد
/// حساب المستلمين فوراً — فقد يسقط مستلمٌ لم يكن له غيره.
class LateAlertReviewDialog extends StatefulWidget {
  /// المشاريع المتأخرة التي حدّدها المستخدم.
  final List<Project> projects;

  /// عنوان المنصة كما يراه المتصفح — يُبنى منه الرابط المباشر في البريد.
  final String baseUrl;

  const LateAlertReviewDialog({
    super.key,
    required this.projects,
    required this.baseUrl,
  });

  @override
  State<LateAlertReviewDialog> createState() => _LateAlertReviewDialogState();
}

class _LateAlertReviewDialogState extends State<LateAlertReviewDialog> {
  final Set<String> _droppedProjects = {};
  final Set<String> _droppedUsers = {};
  bool _busy = false;
  String? _error;

  List<Project> get _kept =>
      widget.projects.where((p) => !_droppedProjects.contains(p.id)).toList();

  List<AlertMessage> _messages(AppStore store) => buildLateAlerts(
        lateProjects: _kept,
        users: store.users,
        baseUrl: widget.baseUrl,
        excludedUids: _droppedUsers,
      );

  Future<void> _send(AppStore store, List<AlertMessage> messages) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final projects = _kept;
    // ــ سجل التدقيق: من أرسل، ومتى، ولأي مشاريع، ولأي مستلمين ــ
    //
    // الأسماء تُقتطع عند حدٍّ: سطرٌ فيه سبعة وأربعون اسماً لا يُقرأ في جدول
    // السجل، والعدد الكامل مذكور قبله فلا تضيع الحقيقة.
    String names(Iterable<String> all, int max) {
      final list = all.toList();
      final shown = list.take(max).join('، ');
      final rest = list.length - max;
      return rest > 0 ? '$shown و$rest غيرها' : shown;
    }

    final result = await store.sendOrRequestNotification(
      messages: [
        for (final m in messages) (user: m.user, subject: m.subject, body: m.body),
      ],
      channel: NotifyChannel.email,
      requestTitle: 'تنبيه تأخير — ${projects.length} مشروعاً',
      requestDescription: 'تنبيه مسؤولي المشاريع المتأخرة (${messages.length} مستلماً)',
      auditAction: 'تنبيه تأخير جماعي',
      auditDetails: '${store.isAdmin ? 'أرسل' : 'طلب'} ${store.currentUser?.name ?? ''} '
          'تنبيه تأخير لـ${projects.length} مشروعاً '
          '(${names(projects.map((p) => p.name), 10)}) '
          'إلى ${messages.length} مستلماً (${names(messages.map((m) => m.user.name), 10)})',
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(result.queued
          ? 'أُرسل الطلب إلى مسؤول النظام. لن يصل البريد قبل اعتماده.'
          : 'أُرسل تنبيه التأخير إلى ${messages.length} مستلماً.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final kept = _kept;
    final messages = _messages(store);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('مراجعة تنبيه التأخير',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Count(label: 'مشروعاً محدَّداً', value: kept.length),
                        const SizedBox(width: 10),
                        _Count(label: 'مستلماً', value: messages.length),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'يصل كل شخص بريدٌ واحد يسرد مشاريعه المتأخرة كلها — لا بريدٌ لكل مشروع. '
                      'ويحمل كل مشروع تاريخ استحقاقه وأيام تأخيره ونسبة إنجازه ورابطاً مباشراً إليه.',
                      style: TextStyle(
                          fontSize: 12, height: 1.8, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('المشاريع (${kept.length})'),
                    const SizedBox(height: 6),
                    for (final p in widget.projects)
                      _RowTile(
                        dropped: _droppedProjects.contains(p.id),
                        title: p.name,
                        subtitle: 'متأخر ${p.delayDays} يوماً · '
                            'الاستحقاق ${Formatters.date(p.dueDate)} · '
                            'الإنجاز ${Formatters.percent(p.progressPercent)}',
                        onToggle: () => setState(() {
                          if (!_droppedProjects.remove(p.id)) _droppedProjects.add(p.id);
                        }),
                      ),
                    const SizedBox(height: 16),
                    _SectionLabel('المستلمون (${messages.length})'),
                    const SizedBox(height: 6),
                    if (messages.isEmpty && _droppedUsers.isEmpty)
                      const Text(
                        'لا يوجد مستلمون: المشاريع المحدَّدة ليس عليها أعضاء بحسابات وبريد '
                        'مسجَّل. والأسماء النصية المستوردة من ملفات الوزارة لا تُراسَل.',
                        style: TextStyle(
                            fontSize: 12, height: 1.8, color: AppColors.textSecondary),
                      ),
                    for (final m in messages)
                      _RowTile(
                        dropped: false,
                        title: m.user.name,
                        subtitle: '${m.user.email} · ${m.projects.length} مشروعاً متأخراً',
                        onToggle: () => setState(() => _droppedUsers.add(m.user.id)),
                      ),
                    // المستبعَدون يبقون مرئيين ليُعادوا: استبعادٌ لا رجعة فيه
                    // إلا بإغلاق النافذة وإعادة التحديد ليس مراجعةً.
                    for (final uid in _droppedUsers)
                      Builder(builder: (_) {
                        final u = store.users.where((x) => x.id == uid).firstOrNull;
                        return _RowTile(
                          dropped: true,
                          title: u?.name ?? uid,
                          subtitle: 'مستبعَد من هذا التنبيه',
                          onToggle: () => setState(() => _droppedUsers.remove(uid)),
                        );
                      }),
                    if (!store.isAdmin) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                        ),
                        child: const Text(
                          'لن يخرج بريدٌ الآن: يُرفع طلبٌ إلى مسؤول النظام يعرض عليه النصّ '
                          'والمستلمين، ولا يُرسَل شيء قبل اعتماده.',
                          style: TextStyle(
                              fontSize: 12, height: 1.8, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.danger, height: 1.7)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _busy || messages.isEmpty ? null : () => _send(store, messages),
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_busy
                      ? 'جارٍ التنفيذ…'
                      : (store.isAdmin
                          ? 'إرسال تنبيه التأخير (${messages.length})'
                          : 'رفع تنبيه التأخير للاعتماد (${messages.length})')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  const _Count({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13));
}

class _RowTile extends StatelessWidget {
  final bool dropped;
  final String title;
  final String subtitle;
  final VoidCallback onToggle;

  const _RowTile({
    required this.dropped,
    required this.title,
    required this.subtitle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dropped ? AppColors.background : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: dropped ? TextDecoration.lineThrough : null,
                    color: dropped ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: dropped ? 'إعادته إلى التنبيه' : 'استبعاده من هذا التنبيه',
            icon: Icon(dropped ? Icons.undo_rounded : Icons.close_rounded, size: 17),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
