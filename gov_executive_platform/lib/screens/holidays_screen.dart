/// العطلُ الرسميّة — **ما لا يُعدّ غياباً على أحد**.
///
/// ــــ ولماذا تُسجَّل ولا تُحسب ــــ
///
/// عطلُ الكويت بعضُها بالتقويم الهجريّ، وبعضُها يُعلَن بمرسومٍ قبل أيام،
/// وبعضُها يُنقل من يومٍ إلى يوم. فلا سبيل إلى حسابها، وكلُّ محاولةٍ لحسابها
/// تُصيب سنةً وتُخطئ أخرى.
///
/// ــــ وأثرُها ــــ
///
/// اليومُ المسجَّلُ عطلةً لا يُعدّ يومَ عمل: لا يُحسب غياباً على أحد، ولا
/// يدخل في مقام «حضر ١٨ من ٢٢». وبلا هذه الشاشة يصير كلُّ عيدٍ **غياباً
/// جماعيّاً** في تقرير الوزارة.
///
/// والجمعةُ والسبتُ خارجَ هذه القائمة: هما عطلةُ الأسبوع، يعرفهما
/// `WorkWeek` بلا تسجيل.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/holiday.dart';
import '../models/work_week.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/command_band.dart';
import '../widgets/status_pill.dart';

class HolidaysScreen extends StatelessWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final holidays = [...store.holidays]..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    final todayKey = WorkWeek.keyOf(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'العطل الرسميّة',
            subtitle: 'أيامٌ لا تُعدّ غياباً على أحد ولا تدخل في مقام الحضور',
            actions: [
              if (store.isAdmin)
                BandButton(
                  label: 'تسجيل عطلة',
                  icon: Icons.event_busy_outlined,
                  filled: true,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const _HolidayDialog(),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // وأسبوعُ العمل يُقال ولا يُفترَض: من يفتح الشاشة يسأل أوّلَ
                // ما يسأل «وأين الجمعة والسبت؟».
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 17, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أسبوعُ العمل من الأحد إلى الخميس. والجمعةُ والسبتُ عطلةٌ '
                          'أسبوعيّةٌ لا تحتاج تسجيلاً — وهذه القائمةُ للعطل الرسميّة وحدها.',
                          style: AppType.micro.copyWith(
                              color: AppColors.textSecondary, height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionTitle('العطل المسجّلة', count: '${holidays.length}'),
                const SizedBox(height: 14),
                if (holidays.isEmpty)
                  const AppEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'لا عطلَ مسجّلة',
                    message: 'سجّل العطلَ الرسميّة حتى لا تُحسب غياباً على الموظّفين.',
                  )
                else
                  ...holidays.map((h) => _HolidayRow(
                        holiday: h,
                        isPast: h.dayKey.compareTo(todayKey) < 0,
                        onRemove: store.isAdmin
                            ? () => _remove(context, store, h)
                            : null,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _remove(BuildContext context, AppStore store, Holiday holiday) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العطلة'),
        // ويُقال أثرُ الحذف لا فعلُه: «هل أنت متأكد؟» لا تقول للمسؤول شيئاً.
        content: Text(
          'سيعود يومُ «${holiday.name}» يومَ عملٍ في الحساب، '
          'فيُعدّ غياباً على من لم يسجّل فيه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await store.saveHolidays(
      store.holidays.where((h) => h.dayKey != holiday.dayKey).toList(),
    );
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}

class _HolidayRow extends StatelessWidget {
  final Holiday holiday;
  final bool isPast;
  final VoidCallback? onRemove;

  const _HolidayRow({required this.holiday, required this.isPast, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final day = holiday.day;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // وما مضى محايدٌ وما هو آتٍ معلومة: اللونُ يقول أيُّهما يعني
          // القارئَ اليوم.
          StatusPill(
            label: day == null ? holiday.dayKey : Formatters.shortDate(day),
            tone: isPast ? StatusPalette.neutral : StatusPalette.info,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(holiday.name, style: AppType.body)),
          if (onRemove != null)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog();

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _name = TextEditingController();
  DateTime _day = WorkWeek.dayOnly(DateTime.now());
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      // ومدىً واسعٌ عمداً: العطلُ تُسجَّل للسنة القادمة سلفاً، وتُستدرَك
      // لسنةٍ مضت حين يُراجَع تقريرُها.
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (picked != null) setState(() => _day = WorkWeek.dayOnly(picked));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'الرجاء كتابة اسم العطلة');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final key = WorkWeek.keyOf(_day);
    // واليومُ الواحدُ عطلةٌ واحدة: تسجيلُه مرّتين يجعل القائمةَ تكذب على
    // قارئها بعددها.
    final items = [
      ...store.holidays.where((h) => h.dayKey != key),
      Holiday(dayKey: key, name: name),
    ];
    final error = await store.saveHolidays(items);
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
    final isWeekend = WorkWeek.isWeekend(_day);
    return AlertDialog(
      title: const Text('تسجيل عطلة رسميّة'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم العطلة',
                hintText: 'عيد الفطر · العيد الوطني',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.event_outlined, size: 17),
              label: Text('اليوم: ${Formatters.shortDate(_day)}'),
            ),
            // ــ ويُقال حين لا أثرَ للتسجيل ــ
            //
            // تسجيلُ الجمعة عطلةً رسميّةً لا يغيّر شيئاً — هي عطلةٌ أصلاً.
            // ومسؤولٌ يسجّلها يظنّ أنّه فعل شيئاً وهو لم يفعل.
            if (isWeekend) ...[
              const SizedBox(height: 10),
              Text(
                'هذا اليومُ عطلةٌ أسبوعيّةٌ أصلاً، فتسجيلُه لا يغيّر شيئاً في الحساب.',
                style: AppType.micro.copyWith(
                    color: StatusPalette.warning.text, height: 1.7),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppType.body.copyWith(color: AppColors.danger)),
            ],
          ],
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
