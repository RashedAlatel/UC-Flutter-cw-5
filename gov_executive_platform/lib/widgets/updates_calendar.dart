import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'month_calendar.dart' show dayOnly;

/// خلاصة يومٍ واحد كما تُعرض في مربّعه.
class DayDigest {
  final DateTime day;

  /// ملخّص قصير جداً — أول سطرٍ ممّا كُتب.
  final String summary;
  final double? progress;
  final bool hasBlocker;
  final int count;

  const DayDigest({
    required this.day,
    required this.summary,
    required this.count,
    this.progress,
    this.hasBlocker = false,
  });
}

/// مدى العرض: شهر أو أسبوع.
enum CalendarSpan {
  month('شهري'),
  week('أسبوعي');

  final String label;
  const CalendarSpan(this.label);
}

/// تقويم التحديثات اليومية — **خطٌّ زمني مرئي للمشروع لا قائمة نصوص**.
///
/// ــــ لماذا تقويمٌ لا سجلّ؟ ــــ
///
/// السجل النصّي يجيب عن «ماذا كُتب»، ولا يجيب عن السؤالين اللذين تُفتح
/// الصفحة لأجلهما: **أين الفجوات؟** و**كيف سار الإنجاز؟** فمن يريد أن يعرف
/// أن الأسبوع الماضي مضى بلا تحديث واحد كان عليه أن يقرأ التواريخ سطراً
/// سطراً ويطرحها بنفسه.
///
/// وفي التقويم يُقرأ ذلك بنظرة: الأخضر يومٌ فيه تحديث، والبرتقالي يومٌ مضى
/// بلا تحديث، والحافّة الحمراء يومٌ فيه عائق.
///
/// ــــ ولماذا مدَيان؟ ــــ
///
/// لأن مربّع الشهر على شاشة هاتف عرضه نحو خمسين بكسلاً — لا يتّسع لملخّص
/// نصّي مهما قصُر. فالشهر يعرض **الحال** (لون، ونسبة، وعلامة عائق)،
/// والأسبوع يعرض **المضمون** لأن كل يوم يأخذ سطراً كاملاً. ووعدُ ملخّصٍ
/// نصّي في مربّع خمسين بكسلاً وعدٌ لا يقع.
class UpdatesCalendar extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;

  /// اليوم ← خلاصته. المفاتيح بلا وقت (`dayOnly`).
  final Map<DateTime, DayDigest> digests;

  final void Function(DateTime day) onOpenDay;

  const UpdatesCalendar({
    super.key,
    required this.firstDay,
    required this.lastDay,
    required this.digests,
    required this.onOpenDay,
  });

  @override
  State<UpdatesCalendar> createState() => _UpdatesCalendarState();
}

class _UpdatesCalendarState extends State<UpdatesCalendar> {
  CalendarSpan _span = CalendarSpan.month;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    // يبدأ من اليوم لا من بدء المشروع: ما يعني القارئ هو الآن.
    _anchor = dayOnly(DateTime.now());
  }

  bool _isPast(DateTime day) => day.isBefore(dayOnly(DateTime.now()));

  bool _inRange(DateTime day) =>
      !day.isBefore(dayOnly(widget.firstDay)) && !day.isAfter(dayOnly(widget.lastDay));

  void _shift(int steps) {
    setState(() {
      _anchor = _span == CalendarSpan.month
          ? DateTime(_anchor.year, _anchor.month + steps, 1)
          : _anchor.add(Duration(days: 7 * steps));
    });
  }

  String get _title {
    if (_span == CalendarSpan.month) {
      return '${Formatters.monthName(_anchor.month)} ${_anchor.year}';
    }
    final start = _weekStart(_anchor);
    final end = start.add(const Duration(days: 6));
    return '${Formatters.shortDate(start)} — ${Formatters.shortDate(end)}';
  }

  /// الأسبوع يبدأ بالأحد في الكويت، و`weekday` يجعل الأحد ٧.
  DateTime _weekStart(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday % 7));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: _span == CalendarSpan.month ? 'الشهر السابق' : 'الأسبوع السابق',
              onPressed: () => _shift(-1),
            ),
            Expanded(
              child: Text(_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: _span == CalendarSpan.month ? 'الشهر التالي' : 'الأسبوع التالي',
              onPressed: () => _shift(1),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<CalendarSpan>(
            segments: [
              for (final s in CalendarSpan.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {_span},
            onSelectionChanged: (s) => setState(() => _span = s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
        const SizedBox(height: 12),
        if (_span == CalendarSpan.month) _monthGrid() else _weekList(),
        const SizedBox(height: 10),
        const _Legend(),
      ],
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_anchor.year, _anchor.month);
    final days = DateTime(
      _anchor.month == 12 ? _anchor.year + 1 : _anchor.year,
      _anchor.month == 12 ? 1 : _anchor.month + 1,
      0,
    ).day;
    final leading = first.weekday % 7;

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _monthCell(DateTime(_anchor.year, _anchor.month, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      children: [
        Row(
          children: [
            for (final name in const ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'])
              Expanded(
                child: Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < cells.length; i += 7)
          // بلا `CrossAxisAlignment.stretch`: الصفّ داخل عمودٍ في منطقة
          // تمرير، فارتفاعه غير محدود — و`stretch` يمدّ الأبناء إلى ما لا
          // نهاية فيصير ارتفاع الصفّ `Infinity`. وهو العطل نفسه الذي جعل
          // بطاقة «أحدث التحديثات» تبتلع لوحة القيادة. والمربّعات لها
          // ارتفاعها بنفسها (٥٢)، فلا حاجة إليه أصلاً.
          Row(
            children: [
              for (var j = i; j < i + 7; j++) Expanded(child: cells[j]),
            ],
          ),
      ],
    );
  }

  ({Color background, Color? border}) _colorsFor(DateTime day, DayDigest? digest) {
    if (!_inRange(day)) return (background: Colors.transparent, border: null);
    if (digest != null) {
      return (
        background: AppColors.success.withValues(alpha: 0.16),
        border: digest.hasBlocker ? AppColors.danger : null,
      );
    }
    // اليوم نفسه ليس «فائتاً»: نهاره لم ينتهِ بعد.
    if (_isPast(day)) return (background: AppColors.warning.withValues(alpha: 0.16), border: null);
    return (background: Colors.transparent, border: null);
  }

  Widget _monthCell(DateTime day) {
    final digest = widget.digests[day];
    final colors = _colorsFor(day, digest);
    final enabled = _inRange(day);
    final isToday = dayOnly(DateTime.now()) == day;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => widget.onOpenDay(day) : null,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: colors.border != null
                  ? Border.all(color: colors.border!, width: 1.4)
                  : (isToday ? Border.all(color: AppColors.accent, width: 1.4) : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.4),
                    )),
                if (digest?.progress != null)
                  Text(Formatters.percent(digest!.progress!),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                if (digest?.hasBlocker ?? false)
                  const Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekList() {
    final start = _weekStart(_anchor);
    return Column(
      children: [
        for (var i = 0; i < 7; i++) _weekRow(start.add(Duration(days: i))),
      ],
    );
  }

  Widget _weekRow(DateTime day) {
    final digest = widget.digests[day];
    final colors = _colorsFor(day, digest);
    final enabled = _inRange(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.background == Colors.transparent ? AppColors.background : colors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => widget.onOpenDay(day) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: colors.border != null ? Border.all(color: colors.border!, width: 1.4) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    '${day.day} ${Formatters.monthName(day.month)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        digest == null
                            ? (enabled
                                ? (_isPast(day) ? 'لا يوجد تحديث لهذا اليوم' : 'لم يحن بعد')
                                : 'خارج مدة المشروع')
                            : (digest.summary.trim().isEmpty ? 'تحديث بلا ملخّص' : digest.summary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: digest == null ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                      ),
                      if (digest != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (digest.progress != null)
                              _Tag(
                                icon: Icons.trending_up_rounded,
                                text: 'إنجاز ${Formatters.percent(digest.progress!)}',
                              ),
                            if (digest.hasBlocker)
                              const _Tag(
                                icon: Icons.warning_amber_rounded,
                                text: 'يوجد عائق',
                                color: AppColors.danger,
                              ),
                            if (digest.count > 1)
                              _Tag(icon: Icons.layers_rounded, text: '${digest.count} تحديثات'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Tag({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _LegendItem(color: AppColors.success.withValues(alpha: 0.16), label: 'فيه تحديث'),
        _LegendItem(color: AppColors.warning.withValues(alpha: 0.16), label: 'مضى بلا تحديث'),
        _LegendItem(color: Colors.transparent, border: AppColors.danger, label: 'فيه عائق'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;
  const _LegendItem({required this.color, required this.label, this.border});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border != null ? Border.all(color: border!, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ],
    );
  }
}
