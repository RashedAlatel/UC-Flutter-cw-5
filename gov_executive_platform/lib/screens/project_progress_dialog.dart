// تصحيحُ نسبة إنجاز مشروعٍ اكتمل.
//
// ــــ الحاجةُ التي أوجدتها ــــ
//
// طريقُ النسبة في المنصة هو التحديثُ اليومي، وهو الصواب ما دام المشروع
// جارياً: من رفع النسبة قال معها ماذا أنجز. أمّا من أدخل ١٠٠٪ سهواً فقد
// اكتمل مشروعُه، ولا تحديثَ يومياً يُنتظر منه — فبقي الرقمُ الخاطئ بلا
// سبيلٍ إلى تصحيحه.
//
// ــــ وتقول ما ستفعله قبل أن تفعله ــــ
//
// النزولُ عن ١٠٠٪ **يُخرج المشروعَ من المكتملة**، فيعود إلى قوائم المتابعة
// وإلى تنبيهات التأخير. وذلك أثرٌ يتجاوز الرقمَ نفسَه، فيُقال قبل الضغط.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_progress.dart';
import '../theme/app_theme.dart';

/// يفتح نافذة تصحيح النسبة. يُعيد `true` إن وقع التصحيح.
Future<bool> showProjectProgressDialog(BuildContext context, Project project) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => ProjectProgressDialog(project: project),
  );
  return done ?? false;
}

class ProjectProgressDialog extends StatefulWidget {
  final Project project;
  const ProjectProgressDialog({super.key, required this.project});

  @override
  State<ProjectProgressDialog> createState() => _ProjectProgressDialogState();
}

class _ProjectProgressDialogState extends State<ProjectProgressDialog> {
  late double _progress = widget.project.progressPercent;
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().setProjectProgress(
          widget.project,
          _progress,
          reason: _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // الحالةُ التي سيصير إليها تُحسب بالقاعدة نفسِها التي تكتبها — لا
    // بتخمينٍ في الشاشة يفترق عنها بأول تعديل.
    final next = statusForProgress(
      progress: _progress,
      current: widget.project.status,
      delayDays: widget.project.delayDays,
      hasNewRisk: false,
    );
    final leavesCompleted = next != ProjectStatus.completed;

    return AlertDialog(
      title: const Text('تصحيح نسبة الإنجاز'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المشروع: ${widget.project.name}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'النسبة المسجّلة الآن: ${widget.project.progressPercent.toStringAsFixed(0)}٪',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text('النسبة الجديدة: ${_progress.toStringAsFixed(0)}٪',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Slider(
                value: _progress,
                max: 100,
                divisions: 100,
                label: '${_progress.toStringAsFixed(0)}٪',
                onChanged: _busy ? null : (v) => setState(() => _progress = v),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _reasonCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب التصحيح (اختياري)',
                  helperText: 'يُحفظ في سجل التدقيق',
                ),
              ),
              const SizedBox(height: 14),
              // ــ الأثرُ يُقال قبل الضغط لا بعده ــ
              //
              // خروجُ المشروع من المكتملة يُعيده إلى قوائم المتابعة وإلى
              // تنبيهات التأخير. وذلك أوسعُ من تغيير رقم.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: (leavesCompleted ? AppColors.warning : AppColors.info)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (leavesCompleted ? AppColors.warning : AppColors.info)
                          .withValues(alpha: 0.3)),
                ),
                child: Text(
                  leavesCompleted
                      ? 'بحفظ هذه النسبة يخرج المشروع من المشاريع المكتملة، '
                          'وتصير حالته «${next.label}» بحسب موعده — فيعود إلى '
                          'قوائم المتابعة وتنبيهات التأخير.'
                      : 'المشروع يبقى مكتملاً بهذه النسبة.',
                  style: const TextStyle(fontSize: 11.5, height: 1.8),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          // بلا تغييرٍ لا معنى للحفظ.
          onPressed: (_busy || _progress == widget.project.progressPercent) ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
