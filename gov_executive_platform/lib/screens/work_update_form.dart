import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/month_calendar.dart';

/// التحديث اليومي لعملٍ تشغيلي — بالتقويم نفسه الذي للمشروع.
///
/// ــــ لماذا نموذجٌ أبسط من نموذج المشروع؟ ــــ
///
/// نموذج المشروع يحمل المهام المنجزة والمخاطر الجديدة والعوائق والقرارات
/// المطلوبة من القيادة — وهي كيانات **للمشروع** لها صفحاتها وسجلّاتها.
/// والعمل التشغيلي ليس له شيء منها: هو مهمّةٌ واحدة مُسنَدة إلى شخص. فحقولٌ
/// لا يملؤها أحد تُطيل النموذج وتُثقل من يكتب كل يوم — والغرض أن يُكتب
/// التحديث لا أن يُهجَر.
class WorkUpdateForm extends StatefulWidget {
  final WorkItem work;
  const WorkUpdateForm({super.key, required this.work});

  @override
  State<WorkUpdateForm> createState() => _WorkUpdateFormState();
}

class _WorkUpdateFormState extends State<WorkUpdateForm> {
  final _summaryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late double _progress;
  late DateTime _day;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.work.progressPercent;
    _day = dayOnly(DateTime.now());
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _selectDay(DateTime day) {
    final existing = context.read<AppStore>().workUpdatesOnDay(widget.work.id, day);
    setState(() {
      _day = day;
      // يُملأ بآخر ما كُتب في ذلك اليوم ولا يُقفل: المتجر **يُضيف** تحديثاً
      // ولا يستبدله، فالملء يُري ما كُتب بلا ادّعاء تعديلٍ لا يقع — ويُقال
      // ذلك صراحةً في اللافتة.
      final latest = existing.isEmpty ? null : existing.first;
      _summaryCtrl.text = latest?.summary ?? '';
      _notesCtrl.text = latest?.notes ?? '';
      _progress = latest?.progressPercent ?? widget.work.progressPercent;
    });
  }

  Future<void> _submit() async {
    // التحديث يجب أن يقول **شيئاً**: بلا ملخّص ولا ملاحظة ولا تغيّر في
    // النسبة، فهو مستند فارغ يُثقل السجل ويُوهم بمتابعة لم تقع.
    final saysSomething = _summaryCtrl.text.trim().isNotEmpty ||
        _notesCtrl.text.trim().isNotEmpty ||
        _progress != widget.work.progressPercent;
    if (!saysSomething) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التحديث فارغ. اكتب ما أُنجز أو ملاحظة، أو حرّك نسبة الإنجاز.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<AppStore>().addWorkUpdate(
            work: widget.work,
            summary: _summaryCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            progressPercent: _progress,
            forDay: _day,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      // ــ النتيجة الجزئية تُقال ــ
      //
      // التحديث يُكتب أوّلاً وبمفرده، وتحديثُ نسبة العمل قد يُردّ وحده. فلو
      // قيل «تم الحفظ» وسكتنا، لبحث الكاتب عن نسبةٍ حرّكها ولم تتحرّك، وظنّ
      // التحديث نفسه ضائعاً. والنمط من `daily_update_form`.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.notRecorded.isEmpty
            ? 'تم حفظ تحديث العمل'
            : 'حُفظ التحديث، ولم يُسجَّل: ${result.notRecorded.join(' · ')}'),
        backgroundColor: result.notRecorded.isEmpty ? null : AppColors.warning,
        duration: Duration(seconds: result.notRecorded.isEmpty ? 4 : 12),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ التحديث: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dayUpdates = store.workUpdatesOnDay(widget.work.id, _day);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
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
                  const Icon(Icons.edit_note_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تحديث يومي',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(widget.work.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
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
                    Text('يوم التحديث', style: AppText.label),
                    const SizedBox(height: 6),
                    MonthCalendar(
                      selected: _day,
                      onSelected: _selectDay,
                      daysWithUpdates: {
                        for (final u in store.updatesForWork(widget.work.id)) dayOnly(u.date),
                      },
                      // العمل لا يحمل تاريخ بدء، فأول ما يمكن اختياره يوم
                      // إنشائه: تحديثٌ قبل وجوده كذبٌ في السجل.
                      firstDay: widget.work.createdAt,
                      lastDay: DateTime.now(),
                    ),
                    const SizedBox(height: 10),
                    if (dayUpdates.isEmpty)
                      Text(
                        '${Formatters.date(_day)} — لا يوجد تحديث مسجَّل لهذا اليوم.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Formatters.date(_day)} — فيه ${dayUpdates.length} تحديث مسجَّل',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                            for (final u in dayUpdates)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• ${u.authorName}: '
                                  '${u.summary.trim().isEmpty ? 'بلا ملخّص' : u.summary.trim()}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
                                ),
                              ),
                            const SizedBox(height: 6),
                            const Text(
                              'الحقول أدناه مملوءة بآخر تحديث لهذا اليوم. والحفظ يضيف تحديثاً '
                              'جديداً لليوم نفسه ولا يستبدل ما سبق.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('ما أُنجز', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _summaryCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'صف ما أُنجز في هذا العمل…'),
                    ),
                    const SizedBox(height: 16),
                    Text('ملاحظات أو عوائق (اختياري)', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'ما يعوق الإنجاز، أو ما يحتاج قراراً…'),
                    ),
                    const SizedBox(height: 16),
                    Text('نسبة الإنجاز: ${_progress.toStringAsFixed(0)}٪',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Slider(
                      value: _progress,
                      max: 100,
                      divisions: 100,
                      label: '${_progress.toStringAsFixed(0)}٪',
                      onChanged: (v) => setState(() => _progress = v),
                    ),
                    if (_progress >= 100)
                      const Text(
                        'بلوغ المئة يُعلّم العمل منجَزاً.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.success, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ التحديث'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
