// إعداداتُ التقارير الدورية — مدّةُ الجمود.
//
// ــــ ولماذا هنا لا في شاشة إعداداتٍ عامة ــــ
//
// لأن الإعداد يُضبط حيث يُرى أثرُه: من يقرأ «١٢ مشروعاً غير نشط» ويرى أن
// المدّة سبعة أيام هو من يعرف إن كانت سبعةً كثيرةً أو قليلة. وإعدادٌ في
// شاشةٍ بعيدة يُضبط مرّةً ثم يُنسى معياره — فيُقرأ الرقمُ بلا مقياسه.
//
// وهو نمطُ `DailyReportSettingsDialog` نفسه: زرٌّ في ترويسة القسم، لمسؤول
// النظام وحده.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/periodic_report_settings.dart';
import '../theme/app_theme.dart';

class PeriodicReportSettingsDialog extends StatefulWidget {
  const PeriodicReportSettingsDialog({super.key});

  @override
  State<PeriodicReportSettingsDialog> createState() =>
      _PeriodicReportSettingsDialogState();
}

class _PeriodicReportSettingsDialogState
    extends State<PeriodicReportSettingsDialog> {
  late int _days;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = context.read<AppStore>().periodicReportSettings.inactiveAfterDays;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<AppStore>()
          .savePeriodicReportSettings(PeriodicReportSettings(inactiveAfterDays: _days));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // الفشلُ يُقال ولا يُبتلع: نافذةٌ تُغلق بلا حفظٍ تترك المستخدم يظنّ
      // أنه ضبط ما لم يُضبط.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذّر الحفظ: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعدادات التقارير الدورية'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بعد كم يومٍ بلا تحديثٍ يُعدّ المشروع أو العمل «غير نشط»؟',
              style: TextStyle(fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 6),
            const Text(
              'يُغيّر هذا طولَ قائمة «غير النشطة» وحالةَ «يحتاج متابعة» — '
              'ويسري على كل من يفتح التقرير.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 16),
            // الخيارات الثلاثة التي ذكرتَها حاضرةٌ بلمسة، والحقلُ الحرّ لما
            // سواها — فلا يُحبس الإعداد في ثلاثة أرقام.
            Wrap(
              spacing: 8,
              children: [
                for (final d in [3, 7, 14])
                  ChoiceChip(
                    label: Text('$d أيام'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('أو حدّد: ', style: TextStyle(fontSize: 13)),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    key: const ValueKey('inactiveDaysField'),
                    initialValue: '$_days',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, suffixText: 'يوم'),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null && n >= kMinInactiveDays && n <= kMaxInactiveDays) {
                        setState(() => _days = n);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'من $kMinInactiveDays إلى $kMaxInactiveDays',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
