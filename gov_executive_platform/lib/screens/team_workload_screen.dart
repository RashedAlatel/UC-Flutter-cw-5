/// **حملُ الفريق وخطّةُ الأسبوع** — من فوق طاقته، وما وعد به الأسبوعَ القادم.
///
/// ــــ ولماذا الشاشتان واحدة ــــ
///
/// لأنّ السؤالين يُسألان معاً: مديرٌ يضع خطّةَ الأسبوع لا بدّ أن يرى من
/// عليه حملٌ زائدٌ قبل أن يُسند إليه ثلاثَ أولويّاتٍ أخرى. وفصلُهما كان
/// يعني أن يوازن المديرُ بين شاشتين بذاكرته.
///
/// ــــ والحملُ موزونٌ لا معدود ــــ
///
/// راجع `WorkloadEngine`: الأولويّةُ وقربُ الموعد والتأخُّرُ وعددُ المشاريع.
/// فسبعُ مهامّ خفيفةٍ بعيدةِ الموعد أخفُّ من مهمّتين حرجتين متأخّرتين.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/weekly_plan.dart';
import '../reports/workload.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/command_band.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';

StatusTone toneOfBand(LoadBand band) => switch (band) {
      LoadBand.overloaded => StatusPalette.danger,
      LoadBand.high => StatusPalette.warning,
      LoadBand.normal => StatusPalette.success,
      LoadBand.underloaded => StatusPalette.info,
    };

class TeamWorkloadScreen extends StatefulWidget {
  const TeamWorkloadScreen({super.key});

  @override
  State<TeamWorkloadScreen> createState() => _TeamWorkloadScreenState();
}

class _TeamWorkloadScreenState extends State<TeamWorkloadScreen> {
  /// الأسبوعُ المعروض — يبدأ بالأسبوع القادم، فالخطّةُ تُوضع قبل أن يبدأ.
  late DateTime _week = WeeklyPlan.weekStart(DateTime.now().add(const Duration(days: 7)));

  LoadBand? _band;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final weekKey = WeeklyPlan.weekKeyOf(_week);
    var loads = store.teamWorkload();
    final bands = WorkloadEngine.countByBand(loads);
    if (_band != null) loads = loads.where((l) => l.band == _band).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'حمل الفريق وخطّة الأسبوع',
            subtitle: 'من فوق طاقته، ومن بلا عمل، وما وعدوا به',
            actions: [
              BandButton(
                label: 'الأسبوع السابق',
                icon: Icons.chevron_right_rounded,
                onPressed: () => setState(
                    () => _week = _week.subtract(const Duration(days: 7))),
              ),
              BandButton(
                label: 'الأسبوع التالي',
                icon: Icons.chevron_left_rounded,
                onPressed: () =>
                    setState(() => _week = _week.add(const Duration(days: 7))),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('توزيعُ الحمل', icon: Icons.balance_rounded),
                const SizedBox(height: 14),
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
                          tone: toneOfBand(band),
                          emphasize: _band == band ||
                              (band == LoadBand.overloaded && (bands[band] ?? 0) > 0),
                          onTap: () => setState(() => _band = _band == band ? null : band),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 26),
                SectionTitle(
                  'أسبوع ${Formatters.shortDate(_week)}',
                  icon: Icons.event_note_rounded,
                  count: '${loads.length} موظّفاً',
                ),
                const SizedBox(height: 14),
                if (loads.isEmpty)
                  AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: _band == null ? 'لا موظّفين في نطاقك' : 'لا أحدَ في هذا التصنيف',
                    message: _band == null
                        ? 'يظهر هنا من تديرهم، بحملهم وخططهم.'
                        : 'اضغط البطاقةَ مرّةً أخرى لعرض الجميع.',
                  )
                else
                  ...loads.map((l) => _PersonRow(
                        load: l,
                        weekKey: weekKey,
                        plan: store.planFor(l.uid, weekKey),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صفُّ موظّفٍ: حملُه، ثمّ أولويّاتُه الثلاث.
class _PersonRow extends StatelessWidget {
  final Workload load;
  final String weekKey;
  final WeeklyPlan? plan;

  const _PersonRow({required this.load, required this.weekKey, this.plan});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = plan?.items ?? const [];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(label: load.band.label, tone: toneOfBand(load.band)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(load.name,
                    style: AppType.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (store.canWriteWeeklyPlans)
                TextButton.icon(
                  onPressed: () => _edit(context, store),
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: Text(items.isEmpty ? 'ضع الخطّة' : 'عدّل'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              MetaBit(icon: Icons.folder_copy_rounded, text: '${load.activeProjects} مشروع'),
              MetaBit(
                  icon: Icons.checklist_rounded,
                  text: '${load.activeTasks + load.activeWorks} بند جارٍ'),
              if (load.criticalItems > 0)
                MetaBit(
                  icon: Icons.priority_high_rounded,
                  text: '${load.criticalItems} حرِج',
                  color: StatusPalette.danger.text,
                ),
              if (load.overdueItems > 0)
                MetaBit(
                  icon: Icons.schedule_rounded,
                  text: '${load.overdueItems} متأخّر',
                  color: StatusPalette.danger.text,
                ),
              if (load.dueSoonItems > 0)
                MetaBit(
                  icon: Icons.hourglass_bottom_rounded,
                  text: '${load.dueSoonItems} يستحقّ قريباً',
                  color: StatusPalette.warning.text,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            // ــ وخطّةٌ لم تُوضع تُقال، ولا تُترك فراغاً ــ
            //
            // فراغٌ تحت الاسم يُقرأ «لا شيءَ هذا الأسبوع»، وهو غيرُ «لم
            // يقرّر مديرُه بعد».
            Text(
              store.canWriteWeeklyPlans
                  ? 'لم تُوضع له خطّةُ هذا الأسبوع بعد.'
                  : 'لا خطّةَ معلَنةً لهذا الأسبوع.',
              style: AppType.micro.copyWith(color: AppColors.textSecondary),
            )
          else
            ...items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        i.isDone
                            ? Icons.check_circle_rounded
                            : (i.isCarriedOver
                                ? Icons.redo_rounded
                                : Icons.radio_button_unchecked_rounded),
                        size: 15,
                        color: i.isDone
                            ? StatusPalette.success.fill
                            : (i.isCarriedOver
                                ? StatusPalette.warning.fill
                                : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.title, style: AppType.body),
                            if (i.expectedOutcome.isNotEmpty)
                              Text('المتوقَّع: ${i.expectedOutcome}',
                                  style: AppType.micro
                                      .copyWith(color: AppColors.textSecondary, height: 1.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppStore store) async {
    final person = store.users.where((u) => u.id == load.uid).firstOrNull;
    if (person == null) return;
    await showDialog(
      context: context,
      builder: (_) => _PlanDialog(person: person, weekKey: weekKey, existing: plan),
    );
  }
}

class _PlanDialog extends StatefulWidget {
  final AppUser person;
  final String weekKey;
  final WeeklyPlan? existing;

  const _PlanDialog({required this.person, required this.weekKey, this.existing});

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final List<TextEditingController> _titles;
  late final List<TextEditingController> _outcomes;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final items = widget.existing?.items ?? const [];
    _titles = [
      for (var i = 0; i < WeeklyPlan.maxItems; i++)
        TextEditingController(text: i < items.length ? items[i].title : ''),
    ];
    _outcomes = [
      for (var i = 0; i < WeeklyPlan.maxItems; i++)
        TextEditingController(text: i < items.length ? items[i].expectedOutcome : ''),
    ];
  }

  @override
  void dispose() {
    for (final c in [..._titles, ..._outcomes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final items = <PlanItem>[];
    for (var i = 0; i < WeeklyPlan.maxItems; i++) {
      final title = _titles[i].text.trim();
      if (title.isEmpty) continue;
      final previous = (widget.existing?.items.length ?? 0) > i
          ? widget.existing!.items[i]
          : null;
      items.add(PlanItem(
        title: title,
        expectedOutcome: _outcomes[i].text.trim(),
        // وحالةُ البند تبقى كما كانت: تعديلُ نصٍّ ليس إعادةَ فتحِ بندٍ
        // أُنجز.
        status: previous?.status ?? 'planned',
        projectId: previous?.projectId ?? '',
        projectName: previous?.projectName ?? '',
      ));
    }
    if (items.isEmpty) {
      setState(() => _error = 'اكتب أولويّةً واحدةً على الأقلّ');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AppStore>().saveWeeklyPlan(
          person: widget.person,
          weekKey: widget.weekKey,
          items: items,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('خطّةُ ${widget.person.name}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ــ والحدُّ ثلاثةٌ يُقال سببُه ــ
              //
              // حدٌّ بلا سببٍ يُقرأ نقصاً في المنصة.
              Text(
                'ثلاثُ أولويّاتٍ للأسبوع. والحدُّ هو الأداة: خطّةٌ بعشرة بنودٍ '
                'ليست خطّة، بل قائمةُ أعمالٍ أخرى.',
                style: AppType.micro.copyWith(color: AppColors.textSecondary, height: 1.7),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < WeeklyPlan.maxItems; i++) ...[
                TextField(
                  controller: _titles[i],
                  decoration: InputDecoration(
                    labelText: 'الأولويّة ${i + 1}',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _outcomes[i],
                  decoration: const InputDecoration(
                    labelText: 'النتيجة المتوقَّعة',
                    hintText: 'ما الذي يكون قد تمّ في آخر الأسبوع؟',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null)
                Text(_error!, style: AppType.body.copyWith(color: AppColors.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'يُحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
