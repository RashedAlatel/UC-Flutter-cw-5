/// **تقويمُ القطاع الموحَّد** — كلُّ ما له موعدٌ في مكانٍ واحد.
///
/// ــــ ما يعرضه ــــ
///
/// مواعيدَ المشاريع بدايةً واستحقاقاً، ونهاياتِ العقود، واستحقاقاتِ
/// الفواتير، والخطواتِ التالية، ومواعيدَ المهامّ والأعمال، والعطلَ الرسميّة.
///
/// ــــ وكلُّه مُشتقٌّ لا مخزَّن ــــ
///
/// لا مجموعةَ أحداثٍ في قاعدة البيانات. راجع `CalendarBuilder`: نسخةٌ
/// ثانيةٌ من هذه التواريخ كانت ستنحرف عن أصلها بأوّل تأجيلِ موعد، فيبقى
/// الحدثُ على تاريخه القديم ولا شيء يقول لماذا.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/calendar_event.dart';
import '../models/work_week.dart';
import '../reports/attention.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/command_band.dart';
import '../widgets/status_pill.dart';

/// نغمةُ بابِ الحدث — **من `StatusPalette` لا لونٌ يُكتب هنا**.
StatusTone toneOfEvent(EventKind kind) => switch (kind) {
      EventKind.projectDue => StatusPalette.info,
      EventKind.projectStart => StatusPalette.success,
      EventKind.contractEnd => StatusPalette.blocker,
      EventKind.invoiceDue => StatusPalette.blocker,
      EventKind.taskDue => StatusPalette.warning,
      EventKind.workDue => StatusPalette.warning,
      EventKind.nextAction => StatusPalette.category,
      EventKind.holiday => StatusPalette.neutral,
    };

class MasterCalendarScreen extends StatefulWidget {
  const MasterCalendarScreen({super.key});

  @override
  State<MasterCalendarScreen> createState() => _MasterCalendarScreenState();
}

class _MasterCalendarScreenState extends State<MasterCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  EventKind? _kind;
  String? _departmentId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    var events = CalendarBuilder.build(
      projects: store.visibleProjects,
      tasks: store.tasks,
      works: store.visibleWorks,
      holidayNames: {for (final h in store.holidays) h.dayKey: h.name},
    );
    if (_kind != null) events = events.where((e) => e.kind == _kind).toList();
    if (_departmentId != null) {
      // والعطلُ تبقى مع كلّ إدارة: هي للوزارة كلِّها لا لإدارةٍ بعينها.
      events = events
          .where((e) => e.departmentId == _departmentId || e.kind == EventKind.holiday)
          .toList();
    }

    final byDay = CalendarBuilder.byDay(events);
    final selected = _selectedDay;
    final dayEvents = selected == null ? const <CalendarEvent>[] : CalendarBuilder.onDay(events, selected);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'تقويم القطاع',
            subtitle: 'كلُّ ما له موعد — مشاريع وعقود وفواتير ومهامّ',
            actions: [
              BandButton(
                label: 'الشهر السابق',
                icon: Icons.chevron_right_rounded,
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                  _selectedDay = null;
                }),
              ),
              BandButton(
                label: 'اليوم',
                icon: Icons.today_rounded,
                onPressed: () => setState(() {
                  final now = DateTime.now();
                  _month = DateTime(now.year, now.month);
                  _selectedDay = WorkWeek.dayOnly(now);
                }),
              ),
              BandButton(
                label: 'الشهر التالي',
                icon: Icons.chevron_left_rounded,
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                  _selectedDay = null;
                }),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Filters(
                  kind: _kind,
                  departmentId: _departmentId,
                  departments: store.visibleDepartments,
                  onKind: (k) => setState(() => _kind = k),
                  onDepartment: (d) => setState(() => _departmentId = d),
                ),
                const SizedBox(height: 20),
                AppCard(
                  title: '${Formatters.monthName(_month.month)} ${_month.year}',
                  subtitle: '${events.length} حدثاً في النطاق المعروض',
                  shrinkToChild: true,
                  child: _MonthGrid(
                    month: _month,
                    byDay: byDay,
                    holidayKeys: store.holidayKeys,
                    selected: _selectedDay,
                    onSelect: (d) => setState(() => _selectedDay = d),
                  ),
                ),
                const SizedBox(height: 20),
                if (selected != null) ...[
                  SectionTitle(
                    Formatters.shortDate(selected),
                    icon: Icons.event_rounded,
                    count: '${dayEvents.length}',
                  ),
                  const SizedBox(height: 14),
                  if (dayEvents.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'لا حدثَ في هذا اليوم',
                      message: 'اختر يوماً آخرَ من التقويم أعلاه.',
                      framed: false,
                    )
                  else
                    AppCard(
                      shrinkToChild: true,
                      child: Column(
                        children: [for (final e in dayEvents) _EventRow(event: e)],
                      ),
                    ),
                ] else
                  const AppEmptyState(
                    icon: Icons.touch_app_outlined,
                    title: 'اختر يوماً لعرض أحداثه',
                    message: 'المربّعاتُ الملوّنة فيها أحداث، والرمادية عطلة.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final EventKind? kind;
  final String? departmentId;
  final List<dynamic> departments;
  final ValueChanged<EventKind?> onKind;
  final ValueChanged<String?> onDepartment;

  const _Filters({
    required this.kind,
    required this.departmentId,
    required this.departments,
    required this.onKind,
    required this.onDepartment,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<EventKind?>(
              initialValue: kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع الحدث', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                for (final k in EventKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: onKind,
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String?>(
              initialValue: departmentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الإدارة', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                for (final d in departments)
                  DropdownMenuItem(value: d.id as String, child: Text(d.name as String)),
              ],
              onChanged: onDepartment,
            ),
          ),
        ],
      );
}

/// شبكةُ الشهر — **مبنيّةٌ بالصفوف لا بحزمةٍ خارجية**.
///
/// وهو النمطُ القائم في `MonthCalendar`: `CalendarDatePicker` لا يسمح بصبغ
/// يومٍ بعينه، وهو جوهرُ الفائدة هنا.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<CalendarEvent>> byDay;
  final Set<String> holidayKeys;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.holidayKeys,
    required this.selected,
    required this.onSelect,
  });

  static const _weekdays = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // الأسبوعُ يبدأ الأحد — أسبوعُ العمل في الوزارة لا تقويمُ الغرب.
    final leading = first.weekday % 7;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      cells.add(_DayCell(
        day: day,
        events: byDay[day] ?? const [],
        isHoliday: !WorkWeek.isWorkingDay(day, holidayKeys),
        isSelected: selected == day,
        onTap: () => onSelect(day),
      ));
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(label,
                      style: AppType.micro.copyWith(color: AppColors.textSecondary)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isHoliday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isHoliday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ــ ولونُ المربّع يقول أشدَّ ما فيه ــ
    //
    // مربّعٌ فيه خمسةُ أحداثٍ أحدُها متأخّرٌ يجب أن يُقرأ متأخّراً بنظرة.
    final overdue = events.any((e) => e.isOverdue);
    final tone = events.isEmpty
        ? null
        : (overdue ? StatusPalette.danger : toneOfEvent(events.first.kind));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        decoration: BoxDecoration(
          color: tone?.soft ?? (isHoliday ? AppColors.background : null),
          border: Border.all(
            color: isSelected ? AppColors.primary : (tone?.border ?? AppColors.border),
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.all(4),
        // ــ والسطران يُقصَّان ولا يُخرجان الخليّة ــ
        //
        // ــــ العطل ــــ
        //
        // الخليّةُ مربَّعةٌ (`childAspectRatio: 1`) وسبعٌ في الصفّ. فعلى
        // هاتفٍ عرضُه ٣٩٠ تصير نحوَ ٤٨ بكسلاً، ويبقى للمحتوى ٤٠ بعد الحشوة.
        // وسطرا نصٍّ بارتفاع السطر المبدئيّ يبلغان ٤٠٫٧ — فتخرج الخليّةُ
        // **بسبعِ أعشار البكسل**، ولا يقع ذلك إلا في يومٍ فيه أحداث.
        //
        // فارتفاعُ السطر يُنصّ عليه، والسطرُ يُلفّ في `Flexible` فينكمش
        // بدل أن يفيض — وهو اصطلاحُ `MetaBit` نفسُه بعد عطلٍ مثلِه.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('${day.day}',
                  maxLines: 1,
                  style: AppType.label.copyWith(
                    height: 1.1,
                    color:
                        tone?.text ?? (isHoliday ? AppColors.textSecondary : AppColors.textPrimary),
                  )),
            ),
            if (events.isNotEmpty)
              Flexible(
                child: Text('${events.length}',
                    maxLines: 1,
                    style: AppType.micro
                        .copyWith(height: 1.1, color: tone?.text ?? AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = event.departmentId.isEmpty ? null : store.departmentById(event.departmentId);
    final tone = event.isOverdue ? StatusPalette.danger : toneOfEvent(event.kind);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          StatusPill(label: event.kind.label, tone: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Text(event.title,
                style: AppType.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (dept != null) ...[
            const SizedBox(width: 8),
            MetaBit(icon: dept.icon, text: dept.name),
          ],
        ],
      ),
    );
  }
}
