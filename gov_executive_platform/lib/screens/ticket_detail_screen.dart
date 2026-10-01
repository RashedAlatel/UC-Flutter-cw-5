/// تفصيلُ بلاغٍ — **وما يُعرض فيه يتبع من يقرأ**.
///
/// المعالِجُ يرى أزرارَ الإسناد والنقل والإغلاق. والمُبلِّغُ يرى بلاغَه
/// وساعتَه، ولا يرى إلا باباً واحداً: جوابَه حين يُسأل.
///
/// ولا يُعرض له زرٌّ يردُّه الخادم: **الشاشةُ لا تَعِدُ بما ترفضه القاعدة**
/// — وهو العطلُ الذي تكرّر في هذه المنصّة مرّتين، وكلَّف جولةَ تشخيصٍ في
/// كلّ مرّة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/status_pill.dart';

class TicketDetailScreen extends StatelessWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final matches = store.visibleTickets.where((t) => t.id == ticketId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('بلاغ')),
        body: const AppEmptyState(
          title: 'لم يعد هذا البلاغُ معروضاً',
          message: 'قد يكون حُذف، أو لم تعد تملك قراءته.',
          icon: Icons.inbox_rounded,
        ),
      );
    }
    final t = matches.first;
    final now = DateTime.now();
    final respond = store.respondClock(t, now: now);
    final resolve = store.resolveClock(t, now: now);
    final handler = store.canHandleTickets;
    final isReporter = t.reporterUid == (store.currentUser?.id ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(t.kind.label)),
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          AppCard(
            shrinkToChild: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: AppText.pageTitle),
                SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    StatusPill(
                        label: t.status.label, tone: StatusPalette.ticketTone(t.status.name)),
                    StatusPill(
                        label: t.priority.label,
                        tone: StatusPalette.priorityTone(t.priority.name),
                        dot: false),
                    if (t.category.isNotEmpty)
                      StatusPill(label: t.category, tone: StatusPalette.neutral, dot: false),
                  ],
                ),
                if (t.description.isNotEmpty) ...[
                  SizedBox(height: AppSpace.sm),
                  Text(t.description, style: AppText.body),
                ],
                SizedBox(height: AppSpace.sm),
                Text('فتحه ${t.reporterName}', style: AppText.label),
                Text(t.isAssigned ? 'لدى ${t.assigneeName}' : 'بلا مُسنَد بعد',
                    style: AppText.label),
              ],
            ),
          ),
          SizedBox(height: AppSpace.md),
          const SectionTitle('مدّةُ الخدمة', icon: Icons.timer_outlined),
          SizedBox(height: AppSpace.sm),
          _ClockRow(label: 'أوّلُ ردّ', outcome: respond.outcome.label, name: respond.outcome.name),
          SizedBox(height: AppSpace.xs),
          _ClockRow(label: 'الحلّ', outcome: resolve.outcome.label, name: resolve.outcome.name),
          // ــ ومدّةُ الانتظار تُقال صراحةً ــ
          //
          // وإلا بدا الموعدُ المُزاحُ خطأً في الحساب: قارئٌ يرى مهلةَ ثماني
          // ساعاتٍ ويرى البلاغَ «ضمن المدّة» بعد يومين يظنّ الرقمَ معطوباً.
          if (t.waitingUpTo(now) > Duration.zero) ...[
            SizedBox(height: AppSpace.xs),
            Text(
              'أُزيح الموعدُ ${t.waitingUpTo(now).inHours} ساعةً — مدّةَ انتظارِ جوابِ المستفيد',
              style: AppText.label,
            ),
          ],
          if (t.resolutionNote.isNotEmpty) ...[
            SizedBox(height: AppSpace.md),
            const SectionTitle('ما جرى', icon: Icons.check_circle_outline),
            SizedBox(height: AppSpace.sm),
            Text(t.resolutionNote, style: AppText.body),
          ],
          if (t.reporterReply.isNotEmpty) ...[
            SizedBox(height: AppSpace.md),
            const SectionTitle('جوابُ المستفيد', icon: Icons.reply_rounded),
            SizedBox(height: AppSpace.sm),
            Text(t.reporterReply, style: AppText.body),
          ],
          SizedBox(height: AppSpace.md),
          if (handler) _HandlerActions(ticket: t),
          if (!handler && isReporter && t.status == TicketStatus.waitingOnReporter)
            _ReporterReply(ticket: t),
        ],
      ),
    );
  }
}

class _ClockRow extends StatelessWidget {
  final String label;
  final String outcome;
  final String name;

  const _ClockRow({required this.label, required this.outcome, required this.name});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: AppText.label)),
          StatusPill(label: outcome, tone: StatusPalette.slaTone(name), dot: false),
        ],
      );
}

class _HandlerActions extends StatelessWidget {
  final Ticket ticket;
  const _HandlerActions({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return AppCard(
      shrinkToChild: true,
      title: 'إجراءاتُ مكتب الخدمة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in TicketStatus.values)
                if (s != ticket.status)
                  OutlinedButton(
                    onPressed: () async {
                      final err = await store.setTicketStatus(ticket, s);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                    child: Text(s.label),
                  ),
            ],
          ),
          SizedBox(height: AppSpace.sm),
          _AssignButton(ticket: ticket),
        ],
      ),
    );
  }
}

class _AssignButton extends StatelessWidget {
  final Ticket ticket;
  const _AssignButton({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: Text(ticket.isAssigned ? 'تغييرُ المُسنَد إليه' : 'إسنادٌ إلى فنّيّ'),
      onPressed: () async {
        final picked = await showDialog<AppUser>(
          context: context,
          builder: (_) => const _PickTechDialog(),
        );
        if (picked == null) return;
        final err = await store.assignTicket(ticket, picked);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      },
    );
  }
}

class _PickTechDialog extends StatelessWidget {
  const _PickTechDialog();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // ــ ولا يُعرض إلا من يستطيع أن يعالج ــ
    //
    // فإسنادُ بلاغٍ إلى من لا يقرؤه يُخفيه عنه ويُخرجه من الطابور معاً.
    final techs = store.users
        .where((u) => u.status == UserStatus.approved)
        .where((u) => u.permissionOverrides['htk'] == true || u.role == UserRole.systemAdmin)
        .toList();
    return AlertDialog(
      title: const Text('إسنادٌ إلى فنّيّ'),
      content: SizedBox(
        width: 380,
        child: techs.isEmpty
            ? const AppEmptyState(
                title: 'لا أحدَ يحمل معالجةَ البلاغات بعد',
                message: 'يمنحها مسؤولُ النظام من شاشة المستخدمين.',
                icon: Icons.person_off_outlined,
                framed: false,
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final u in techs)
                    ListTile(
                      title: Text(u.name),
                      onTap: () => Navigator.of(context).pop(u),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ReporterReply extends StatefulWidget {
  final Ticket ticket;
  const _ReporterReply({required this.ticket});

  @override
  State<_ReporterReply> createState() => _ReporterReplyState();
}

class _ReporterReplyState extends State<_ReporterReply> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppCard(
        shrinkToChild: true,
        title: 'مكتبُ الخدمة ينتظر جوابَك',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'اكتب جوابَك هنا'),
            ),
            SizedBox(height: AppSpace.sm),
            FilledButton(
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      final err = await context
                          .read<AppStore>()
                          .replyToTicket(widget.ticket, _controller.text);
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(this.context);
                      setState(() => _sending = false);
                      if (err != null) {
                        messenger.showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
              child: Text(_sending ? 'يُرسَل…' : 'أرسِل الجواب'),
            ),
          ],
        ),
      );
}
