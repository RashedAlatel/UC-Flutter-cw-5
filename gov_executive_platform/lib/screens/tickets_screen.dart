/// طابورُ البلاغات — **شاشةٌ واحدةٌ لطرفين**.
///
/// ــــ ولماذا لا شاشتان ــــ
///
/// المُبلِّغُ يرى بلاغاتِه، والمعالِجُ يرى الطابورَ كلَّه. وهما القائمةُ
/// نفسُها بمرشِّحٍ مختلف، لا شاشتان لكلٍّ جدولُها وبطاقاتُها — فشاشتان
/// تنحرف إحداهما عن أختها في أوّل تعديل، وقد وقع ذلك في هذه المنصّة:
/// صفٌّ ضيّقٌ يعرض `status` وجدولٌ عريضٌ يعرض `effectiveStatus`، فقالت
/// الشاشةُ الواحدةُ شيئين بحسب عرض النافذة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../itsm/sla.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';
import 'ticket_form_dialog.dart';
import 'ticket_detail_screen.dart';

/// مرشِّحاتُ الطابور — **ولا شاشةَ لكلّ واحدٍ منها**.
enum TicketView {
  mine('بلاغاتي'),
  queue('الطابور'),
  assignedToMe('المُسنَدة إليّ'),
  unassigned('بلا مُسنَد'),
  breached('متجاوزةُ المدّة'),
  waiting('بانتظار المستفيد');

  final String label;
  const TicketView(this.label);
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  TicketView _view = TicketView.mine;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final me = store.currentUser?.id ?? '';
    final now = DateTime.now();
    final handler = store.canHandleTickets;

    // ومن لا يعالج لا يُعرض له إلا بابُه: مرشِّحٌ يُظهر ما يردُّه الخادمُ
    // وعدٌ بما لا يُعطى.
    final views = handler
        ? TicketView.values
        : const [TicketView.mine];
    if (!views.contains(_view)) _view = TicketView.mine;

    final all = store.visibleTickets;
    final shown = all.where((t) => switch (_view) {
          TicketView.mine => t.reporterUid == me,
          TicketView.queue => t.status.isActive,
          TicketView.assignedToMe => t.assigneeUid == me && t.status.isActive,
          TicketView.unassigned => !t.isAssigned && t.status.isActive,
          TicketView.breached => t.status.isActive &&
              store.resolveClock(t, now: now).outcome == SlaOutcome.breached,
          TicketView.waiting => t.status == TicketStatus.waitingOnReporter,
        }).toList()
      // والأحدثُ أوّلاً: طابورٌ يُقرأ من أعلاه.
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final active = all.where((t) => t.status.isActive).toList();
    final late = active
        .where((t) => store.resolveClock(t, now: now).outcome == SlaOutcome.breached)
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTicketFormDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('بلاغٌ جديد'),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          const SectionTitle('البلاغات وطلبات الخدمة', icon: Icons.support_agent_rounded),
          SizedBox(height: AppSpace.sm),
          if (handler)
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'في الطابور',
                    value: '${active.length}',
                    icon: Icons.inbox_rounded,
                    tone: StatusPalette.info,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'تجاوزت مدّتها',
                    value: '$late',
                    icon: Icons.report_gmailerrorred_rounded,
                    // والنغمةُ تتبع الرقم: صفرٌ ليس خطراً، وحمرةٌ دائمةٌ
                    // تُهمَل بعد أسبوع فيضيع معها التحذيرُ الحقيقيّ.
                    tone: late > 0 ? StatusPalette.danger : StatusPalette.success,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StatCard(
                    title: 'بلا مُسنَد',
                    value: '${active.where((t) => !t.isAssigned).length}',
                    icon: Icons.person_off_outlined,
                    tone: StatusPalette.warning,
                  ),
                ),
              ],
            ),
          if (handler) SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final v in views)
                ChoiceChip(
                  label: Text(v.label),
                  selected: _view == v,
                  onSelected: (_) => setState(() => _view = v),
                ),
            ],
          ),
          SizedBox(height: AppSpace.md),
          if (shown.isEmpty)
            AppEmptyState(
              title: _view == TicketView.mine ? 'لا بلاغاتِ لك' : 'لا شيءَ في هذا المرشِّح',
              message: _view == TicketView.mine
                  ? 'إن تعطّل شيءٌ أو احتجتَ خدمةً، افتح بلاغاً من الزرّ أسفلَ الشاشة.'
                  : null,
              icon: Icons.inbox_rounded,
            )
          else
            for (final t in shown)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpace.sm),
                child: _TicketRow(ticket: t, now: now),
              ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final Ticket ticket;
  final DateTime now;

  const _TicketRow({required this.ticket, required this.now});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final clock = store.resolveClock(ticket, now: now);
    // و[AppCard] لا تُضغط بنفسها، فيُلبَسها سطحُ ضغطٍ ولا تُنسخ بطاقةٌ
    // خاصّةٌ تُضغط — وحارسُ `shared_widgets` يمنع النسخ لسببه.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket.id)),
        ),
        child: AppCard(
          shrinkToChild: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(ticket.title, style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              StatusPill(label: ticket.kind.label, tone: StatusPalette.neutral, dot: false),
              StatusPill(
                  label: ticket.status.label, tone: StatusPalette.ticketTone(ticket.status.name)),
              StatusPill(
                  label: ticket.priority.label,
                  tone: StatusPalette.priorityTone(ticket.priority.name),
                  dot: false),
              // وساعةُ المدّة لا تُعرض على المحلول: خبرٌ انتهى أمرُه.
              if (ticket.status.isActive)
                StatusPill(
                  label: clock.outcome.label,
                  tone: StatusPalette.slaTone(clock.outcome.name),
                  dot: false,
                ),
            ],
          ),
          SizedBox(height: AppSpace.xs),
          Text(
            ticket.isAssigned ? 'لدى ${ticket.assigneeName}' : 'بلا مُسنَد بعد',
            style: AppText.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
            ],
          ),
        ),
      ),
    );
  }
}
