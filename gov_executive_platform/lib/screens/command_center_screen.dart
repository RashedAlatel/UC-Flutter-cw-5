/// **مركزُ قيادة القطاع** — الإدارةُ بالاستثناء.
///
/// ــــ ما لا تعرضه ــــ
///
/// لا تعرض كلَّ شيء. هذه ليست لوحةَ القيادة العامّة — تلك تعرض المؤشّراتِ
/// والرسومَ لمن يريد الصورةَ كاملة. وهذه تجيب عن سؤالٍ واحد: **ما الذي
/// يحتاج قراري الآن؟**
///
/// ولذلك لا رسمَ بيانيّاً فيها ولا نسبةَ إنجازٍ عامّة: رقمٌ لا يليه فعلٌ
/// لا مكانَ له هنا. وكلُّ بطاقةٍ تُضغط فتُعطي الأسماء.
///
/// ــــ ومن أين تقرأ ــــ
///
/// من `AttentionEngine` و`WorkloadEngine` — **والمحرّكان هما اللذان يقرأ
/// منهما التقريرُ التنفيذيُّ كذلك**. فلا تقول اللوحةُ «ثلاثةُ مشاريعَ
/// متأخرة» ويقول تقريرُ الصباح «أربعة».
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/sector.dart';
import '../reports/attention.dart';
import '../widgets/kpi_card.dart';
import '../reports/workload.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/brand.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/command_band.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  /// بابُ الاهتمام المختار — أو `null` لكلِّها.
  AttentionKind? _kind;

  /// القطاعُ المختار — أو `null` لكلِّ ما يراه.
  String? _sectorId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    final sectors = store.visibleSectors;
    final scopedDepts = _sectorId == null
        ? null
        : store.departmentsOfSector(_sectorId!).map((d) => d.id).toSet();

    var items = store.attentionItems();
    if (scopedDepts != null) {
      items = items
          .where((i) => i.departmentId.isEmpty || scopedDepts.contains(i.departmentId))
          .toList();
    }
    final counts = AttentionEngine.countByKind(items);
    final shown = _kind == null ? items : items.where((i) => i.kind == _kind).toList();

    var loads = store.teamWorkload();
    if (scopedDepts != null) {
      loads = loads.where((l) => scopedDepts.contains(l.departmentId)).toList();
    }
    final bands = WorkloadEngine.countByBand(loads);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            eyebrow: '${Brand.state} — ${Brand.ministry}',
            title: 'مركز قيادة القطاع',
            subtitle: 'ما يحتاج قرارك الآن — لا كلُّ ما في المنصة',
            metrics: [
              // ــ ثلاثةُ أرقامٍ لا عشرة ــ
              //
              // شريطٌ بعشرة مؤشّراتٍ يُقرأ زينةً. وهذه الثلاثةُ تجيب عن
              // السؤال الذي تُفتح الصفحةُ لأجله.
              KpiMetric(
                title: 'يحتاج تدخّلاً الآن',
                value: '${items.where((i) => i.severity == AttentionSeverity.critical).length}',
                color: StatusPalette.danger.fill,
                emphasize: items.any((i) => i.severity == AttentionSeverity.critical),
              ),
              KpiMetric(
                title: 'يحتاج متابعة',
                value: '${items.where((i) => i.severity == AttentionSeverity.needsAttention).length}',
                color: StatusPalette.warning.fill,
                emphasize: items.any((i) => i.severity == AttentionSeverity.needsAttention),
              ),
              KpiMetric(
                title: 'موظّفون فوق طاقتهم',
                value: '${bands[LoadBand.overloaded] ?? 0}',
                color: StatusPalette.blocker.fill,
                emphasize: (bands[LoadBand.overloaded] ?? 0) > 0,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sectors.length > 1) ...[
                  _SectorBar(
                    sectors: sectors,
                    selected: _sectorId,
                    onChanged: (id) => setState(() => _sectorId = id),
                  ),
                  const SizedBox(height: 20),
                ],
                const SectionTitle('ما يحتاج اهتماماً', icon: Icons.priority_high_rounded),
                const SizedBox(height: 14),
                if (counts.isEmpty)
                  const AppEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'لا شيءَ يحتاج تدخّلاً',
                    message: 'كلُّ ما في نطاقك يسير في موعده، ولا قرارَ معلَّق.',
                  )
                else ...[
                  _KindGrid(
                    counts: counts,
                    selected: _kind,
                    onSelect: (k) => setState(() => _kind = _kind == k ? null : k),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    title: _kind == null ? 'كلُّ البنود' : _kind!.label,
                    subtitle: 'الأشدُّ أوّلاً — واضغط بطاقةً أعلاه لتصفية الباب',
                    shrinkToChild: true,
                    child: Column(
                      children: [
                        for (final item in shown.take(_maxRows)) _AttentionRow(item: item),
                        if (shown.length > _maxRows)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'يُعرض $_maxRows من ${shown.length} — '
                                'صفِّ بالأبواب أعلاه لترى الباقي.',
                                style: AppType.micro.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const SectionTitle('حملُ الفريق', icon: Icons.groups_2_rounded),
                const SizedBox(height: 14),
                if (loads.isEmpty)
                  const AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'لا موظّفين في نطاقك',
                    message: 'يظهر هنا حملُ من تديرهم، موزوناً بالأولويّة والمواعيد.',
                  )
                else
                  _LoadSummary(bands: bands, loads: loads),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// أكثرُ ما يُعرض من بنودٍ في القائمة — والباقي بالتصفية.
  ///
  /// وسقفٌ لأنّ الصفحةَ تُقرأ في دقيقة: قائمةٌ بمئتي بندٍ ليست إدارةً
  /// بالاستثناء، هي قائمةٌ أخرى.
  static const int _maxRows = 12;
}

/// شريطُ اختيار القطاع — ولا يظهر إلا لمن يرى أكثرَ من واحد.
class _SectorBar extends StatelessWidget {
  final List<Sector> sectors;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _SectorBar({required this.sectors, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('كل القطاعات'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final s in sectors)
            ChoiceChip(
              label: Text(s.name),
              selected: selected == s.id,
              onSelected: (_) => onChanged(s.id),
            ),
        ],
      );
}

/// شبكةُ الأبواب — كلُّ بابٍ بعدده، ويُضغط فيُصفّي.
class _KindGrid extends StatelessWidget {
  final Map<AttentionKind, int> counts;
  final AttentionKind? selected;
  final ValueChanged<AttentionKind> onSelect;

  const _KindGrid({required this.counts, required this.selected, required this.onSelect});

  /// نغمةُ البابِ — **من `StatusPalette` لا من لونٍ يُكتب هنا**.
  static StatusTone _tone(AttentionKind kind) => switch (kind) {
        AttentionKind.projectOverdue => StatusPalette.danger,
        AttentionKind.taskOverdue => StatusPalette.danger,
        AttentionKind.workOverdue => StatusPalette.danger,
        AttentionKind.decisionPending => StatusPalette.blocker,
        AttentionKind.contractExpiring => StatusPalette.blocker,
        AttentionKind.projectStale => StatusPalette.warning,
        AttentionKind.projectNoNextAction => StatusPalette.warning,
        AttentionKind.awaitingApproval => StatusPalette.warning,
      };

  static IconData _icon(AttentionKind kind) => switch (kind) {
        AttentionKind.projectOverdue => Icons.running_with_errors_rounded,
        AttentionKind.projectStale => Icons.update_disabled_rounded,
        AttentionKind.projectNoNextAction => Icons.help_outline_rounded,
        AttentionKind.taskOverdue => Icons.schedule_rounded,
        AttentionKind.workOverdue => Icons.schedule_rounded,
        AttentionKind.decisionPending => Icons.gavel_rounded,
        AttentionKind.contractExpiring => Icons.description_outlined,
        AttentionKind.awaitingApproval => Icons.how_to_reg_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 520 ? 2 : 1);
      const spacing = 14.0;
      final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: itemWidth / StatCard.tileHeight,
        children: [
          for (final e in entries)
            StatCard(
              title: e.key.label,
              value: '${e.value}',
              icon: _icon(e.key),
              tone: _tone(e.key),
              // ــ ويُملأ السطحُ للمختار وللحرِج وحدَهما ــ
              //
              // القاعدةُ المكتوبة في `StatCard`: يُملأ للخطر والعائق برقمٍ
              // غيرِ صفر. ويُضاف هنا المختارُ ليُرى أيُّ بابٍ يُصفّى.
              emphasize: selected == e.key ||
                  (_tone(e.key) == StatusPalette.danger && e.value > 0),
              onTap: () => onSelect(e.key),
            ),
        ],
      );
    });
  }
}

/// صفُّ بندٍ يحتاج اهتماماً — اسمُه، وسببُه بعدده، وشدّتُه.
class _AttentionRow extends StatelessWidget {
  final AttentionItem item;
  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = item.departmentId.isEmpty ? null : store.departmentById(item.departmentId);
    final tone = item.severity == AttentionSeverity.critical
        ? StatusPalette.danger
        : StatusPalette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(label: item.severity.label, tone: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    // والسببُ بعدده لا بوصفه: «متأخّر» لا تقول لمديرٍ
                    // يوازن بين عشرة بنودٍ أيَّها يبدأ به.
                    MetaBit(icon: Icons.info_outline_rounded, text: item.reason, color: tone.text),
                    if (dept != null)
                      MetaBit(icon: dept.icon, text: dept.name),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// خلاصةُ الحمل — أربعةُ أعدادٍ ثمّ أثقلُ خمسة.
class _LoadSummary extends StatelessWidget {
  final Map<LoadBand, int> bands;
  final List<Workload> loads;

  const _LoadSummary({required this.bands, required this.loads});

  static StatusTone _tone(LoadBand band) => switch (band) {
        LoadBand.overloaded => StatusPalette.danger,
        LoadBand.high => StatusPalette.warning,
        LoadBand.normal => StatusPalette.success,
        LoadBand.underloaded => StatusPalette.info,
      };

  @override
  Widget build(BuildContext context) {
    final idle = loads.where((l) => l.isIdle).length;
    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 520 ? 2 : 1);
          const spacing = 14.0;
          final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: itemWidth / StatCard.tileHeight,
            children: [
              for (final band in LoadBand.values)
                StatCard(
                  title: band.label,
                  value: '${bands[band] ?? 0}',
                  icon: Icons.person_outline_rounded,
                  tone: _tone(band),
                  emphasize: band == LoadBand.overloaded && (bands[band] ?? 0) > 0,
                  // و«لا عملَ عليه» يُقال تحت «الحمل الخفيف»: هما حالان،
                  // والأولى تحتاج قراراً لا تخفيفاً.
                  subtitle: band == LoadBand.underloaded && idle > 0
                      ? 'منهم $idle بلا عملٍ جارٍ'
                      : null,
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
        AppCard(
          title: 'أثقلُ الفريق حملاً',
          shrinkToChild: true,
          child: Column(
            children: [
              for (final l in loads.take(5))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      StatusPill(label: l.band.label, tone: _tone(l.band)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.name, style: AppType.body)),
                      Wrap(
                        spacing: 10,
                        children: [
                          MetaBit(icon: Icons.folder_copy_rounded, text: '${l.activeProjects} مشروع'),
                          MetaBit(
                              icon: Icons.checklist_rounded,
                              text: '${l.activeTasks + l.activeWorks} بند'),
                          if (l.overdueItems > 0)
                            MetaBit(
                              icon: Icons.schedule_rounded,
                              text: '${l.overdueItems} متأخّر',
                              color: StatusPalette.danger.text,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
