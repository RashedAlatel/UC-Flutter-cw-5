import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// يوم بلا وقت — مفتاحُ المقارنة في التقويم.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// حال اليوم في التقويم، وبها يُصبغ.
enum CalendarDayState {
  /// فيه تحديث مسجَّل.
  hasUpdate,

  /// مضى ولم يُسجَّل فيه شيء — داخل مدة المشروع.
  missed,

  /// يومٌ عادي ضمن المدة، لم يحن أو لا يُنتظر فيه شيء.
  plain,

  /// خارج المدة المسموح باختيارها (قبل بدء المشروع أو في المستقبل).
  disabled,
}

/// تقويم شهري بسيط لاختيار يوم التحديث.
///
/// ــــ لماذا تقويمٌ لا حقل تاريخ؟ ــــ
///
/// كان التحديث اليومي يُختم بتاريخ **لحظة الحفظ** ولا يُسأل المستخدم. فمن
/// نسي تحديث أمس لا سبيل له إلى تسجيله في موضعه، ومن أراد أن يعرف أي الأيام
/// سجّل فيها كان عليه أن يقرأ سجلاً طويلاً بالتواريخ.
///
/// والتقويم يجيب عن السؤالين معاً بنظرة: **أين أنا؟** و**أين الفجوات؟**
///
/// وبلا حزمة خارجية: `CalendarDatePicker` في Flutter لا يسمح بصبغ يومٍ بعينه،
/// وهو جوهر الفائدة هنا — تمييز اليوم الذي فيه تحديث من اليوم الذي مضى بلا
/// تحديث. فبُني الشهر من `Row`ات، وهو أقل مما تكلّفه حزمةٌ تُضاف للأبد.
class MonthCalendar extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// الأيام التي تحمل تحديثاً (تُقارن باليوم لا بالوقت).
  final Set<DateTime> daysWithUpdates;

  /// أول يوم يمكن اختياره — بدء المشروع عادةً.
  final DateTime firstDay;

  /// آخر يوم يمكن اختياره — اليوم عادةً: لا يُسجَّل تحديثٌ لغدٍ لم يأتِ.
  final DateTime lastDay;

  const MonthCalendar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.daysWithUpdates,
    required this.firstDay,
    required this.lastDay,
  });

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.selected.year, widget.selected.month);
  }

  @override
  void didUpdateWidget(MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اختيارُ يومٍ من شهرٍ آخر (بزرّ «أمس» مثلاً) ينقل العرض إليه، وإلا بقي
    // المستخدم ينظر إلى شهرٍ ليس فيه اختياره.
    if (widget.selected.month != oldWidget.selected.month ||
        widget.selected.year != oldWidget.selected.year) {
      _month = DateTime(widget.selected.year, widget.selected.month);
    }
  }

  CalendarDayState _stateOf(DateTime day) {
    final first = dayOnly(widget.firstDay);
    final last = dayOnly(widget.lastDay);
    if (day.isBefore(first) || day.isAfter(last)) return CalendarDayState.disabled;
    if (widget.daysWithUpdates.contains(day)) return CalendarDayState.hasUpdate;
    // «مضى بلا تحديث» لا يشمل اليوم نفسه: نهاره لم ينتهِ بعد، ووسمُه
    // بالتقصير قبل انتهائه ظلمٌ ظاهر.
    if (day.isBefore(dayOnly(DateTime.now()))) return CalendarDayState.missed;
    return CalendarDayState.plain;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.month == 12 ? _month.year + 1 : _month.year,
            _month.month == 12 ? 1 : _month.month + 1, 0)
        .day;

    // الأسبوع يبدأ بالأحد في الكويت. و`DateTime.weekday` يجعل الاثنين ١
    // والأحد ٧، فتُزاح القيمة لتصير الأحد صفراً.
    final leading = first.weekday % 7;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++) _dayCell(DateTime(_month.year, _month.month, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (var j = i; j < i + 7; j++) Expanded(child: cells[j]),
        ],
      ));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'الشهر السابق',
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Text(
                  '${_monthName(_month.month)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'الشهر التالي',
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          Row(
            children: [
              for (final name in const ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'])
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...rows,
          const SizedBox(height: 8),
          const _Legend(),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day) {
    final state = _stateOf(day);
    final isSelected = dayOnly(widget.selected) == day;
    final isToday = dayOnly(DateTime.now()) == day;

    Color background = Colors.transparent;
    Color foreground = AppColors.textPrimary;
    if (isSelected) {
      background = AppColors.primary;
      foreground = AppColors.onBrand(AppColors.primary);
    } else {
      switch (state) {
        case CalendarDayState.hasUpdate:
          background = AppColors.success.withValues(alpha: 0.16);
        case CalendarDayState.missed:
          background = AppColors.warning.withValues(alpha: 0.14);
        case CalendarDayState.disabled:
          foreground = AppColors.textSecondary.withValues(alpha: 0.4);
        case CalendarDayState.plain:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: state == CalendarDayState.disabled ? null : () => widget.onSelected(day),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected ? Border.all(color: AppColors.accent, width: 1.4) : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int m) => Formatters.monthName(m);
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        _LegendItem(color: AppColors.success.withValues(alpha: 0.16), label: 'فيه تحديث'),
        _LegendItem(color: AppColors.warning.withValues(alpha: 0.14), label: 'مضى بلا تحديث'),
        _LegendItem(color: AppColors.primary, label: 'المختار'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ],
    );
  }
}
