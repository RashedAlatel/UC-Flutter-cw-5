import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/person_picker.dart';

/// نقل قيادة مشروع من مديرٍ إلى آخر.
///
/// ــــ لماذا طلبُ اعتماد لا تعديلٌ مباشر؟ ــــ
///
/// لأن مدير المشروع ليس حقلاً كبقية الحقول: هو من يكتب التحديثات اليومية،
/// ومن تُنسب إليه المتابعة، ومن يُسأل عن التأخير. ونقلُه بقرار طرفٍ واحد
/// يبدّل مسؤولية شخصٍ بلا علمه ولا أثر.
///
/// فمدير الإدارة والمستخدم التنفيذي **يطلبان**، ومسؤول النظام يبتّ. أما هو
/// فيغيّر مباشرةً — فلسفة المنصة تعتبره أعلى صلاحية، ولا يُطلب منه أن يرفع
/// طلباً إلى نفسه. **والأثر يُكتب في سجل التدقيق في الحالين**: الحوكمة في
/// الأثر لا في عدد الخطوات.
class ChangeManagerDialog extends StatefulWidget {
  final Project project;
  const ChangeManagerDialog({super.key, required this.project});

  @override
  State<ChangeManagerDialog> createState() => _ChangeManagerDialogState();
}

class _ChangeManagerDialogState extends State<ChangeManagerDialog> {
  final Set<String> _picked = {};
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppStore store, AppUser newManager) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (store.isAdmin) {
        await store.changeProjectManagerDirectly(
          project: widget.project,
          newManagerUid: newManager.id,
          newManagerName: newManager.name,
          reason: _reasonCtrl.text,
        );
      } else {
        await store.submitManagerChangeRequest(
          project: widget.project,
          newManagerUid: newManager.id,
          newManagerName: newManager.name,
          reason: _reasonCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(store.isAdmin
            ? 'تم تغيير مدير المشروع وتسجيل ذلك في سجل التدقيق'
            : 'أُرسل الطلب إلى مسؤول النظام للاعتماد'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر إتمام العملية: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final project = widget.project;
    final direct = store.isAdmin;

    final currentNames = project.managerUids
        .map((uid) => store.users.where((u) => u.id == uid).firstOrNull?.name ?? uid)
        .toList();

    // المرشَّحون: المعتمَدون في إدارة المشروع. ومن هو مديرٌ الآن مستبعَد —
    // «تغييرٌ» إلى من يقود أصلاً ليس تغييراً.
    final candidates = store.users
        .where((u) =>
            u.status == UserStatus.approved &&
            !project.managerUids.contains(u.id) &&
            (u.departmentId == project.departmentId ||
                u.departmentIds.contains(project.departmentId)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final chosen = candidates.where((u) => _picked.contains(u.id)).firstOrNull;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
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
                  const Icon(Icons.manage_accounts_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(direct ? 'تغيير مدير المشروع' : 'طلب تغيير مدير المشروع',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(project.name,
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'المدير الحالي: ${currentNames.isEmpty ? 'بلا مدير' : currentNames.join('، ')}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (candidates.isEmpty)
                      const Text(
                        'لا يوجد مستخدم معتمَد آخر في إدارة هذا المشروع ليُسنَد إليه.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
                      )
                    else
                      PersonPicker(
                        label: 'المدير الجديد',
                        hint: 'واحدٌ لا أكثر — تغيير المدير نقلُ قيادة لا إضافة عضو',
                        candidates: candidates,
                        departmentNameOf: (u) =>
                            store.departmentById(u.departmentId ?? '')?.name ?? 'بلا إدارة',
                        selected: _picked,
                        onChanged: () => setState(() {
                          // اختيارٌ واحد: آخر ما اختير يُبقى وما قبله يُسقط.
                          if (_picked.length > 1) {
                            final last = _picked.last;
                            _picked
                              ..clear()
                              ..add(last);
                          }
                        }),
                      ),
                    const SizedBox(height: 14),
                    Text(direct ? 'سبب التغيير (اختياري)' : 'سبب التغيير', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: direct
                            ? 'يُكتب في سجل التدقيق مع اسم من غيّر ومتى.'
                            : 'يقرؤه مسؤول النظام قبل الاعتماد.',
                        hintStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (!direct) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'لن يُنفَّذ التغيير الآن: يُرفع طلباً إلى مسؤول النظام، ولا ينتقل '
                        'المشروع إلا باعتماده.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.7),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.6)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || chosen == null || (!direct && _reasonCtrl.text.trim().isEmpty)
                      ? null
                      : () => _submit(store, chosen),
                  icon: _busy
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(direct ? Icons.check_rounded : Icons.send_rounded, size: 18),
                  label: Text(_busy
                      ? 'جارٍ التنفيذ…'
                      : (direct ? 'تغيير المدير الآن' : 'رفع الطلب للاعتماد')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
