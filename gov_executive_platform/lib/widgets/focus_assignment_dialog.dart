import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

/// نموذج تثبيت عنصر (مشروع أو عمل) في لوحات قيادة مستخدمين بعينهم.
///
/// يُفتح من صفحة المشروع أو العمل: تُعرض قائمة المستخدمين بمربعات اختيار
/// مؤشَّرة مسبقاً بمن هو مثبَّت لديه العنصر أصلاً.
class FocusAssignmentDialog extends StatefulWidget {
  /// أحدهما فقط يُمرَّر.
  final String? projectId;
  final String? workId;

  /// اسم العنصر لعرضه في العنوان.
  final String title;

  const FocusAssignmentDialog({super.key, this.projectId, this.workId, required this.title})
      : assert(projectId != null || workId != null, 'مرّر معرّف مشروع أو عمل');

  @override
  State<FocusAssignmentDialog> createState() => _FocusAssignmentDialogState();
}

class _FocusAssignmentDialogState extends State<FocusAssignmentDialog> {
  /// المستخدمون المثبَّت لديهم العنصر حالياً.
  Set<String>? _assigned;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = context.read<AppStore>();
    // نقرأ مستند التثبيت لكل مستخدم مرة واحدة عند الفتح، بدل الاشتراك الدائم
    // بكل المستندات.
    final assigned = <String>{};
    for (final u in store.users.where((u) => u.status == UserStatus.approved)) {
      final f = await store.focusFor(u.id);
      final has = widget.projectId != null
          ? f.projectIds.contains(widget.projectId)
          : f.workIds.contains(widget.workId);
      if (has) assigned.add(u.id);
    }
    if (!mounted) return;
    setState(() => _assigned = assigned);
  }

  Future<void> _toggle(String uid, bool value) async {
    final store = context.read<AppStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.toggleFocusForUser(uid, projectId: widget.projectId, workId: widget.workId);
      if (!mounted) return;
      setState(() {
        if (value) {
          _assigned!.add(uid);
        } else {
          _assigned!.remove(uid);
        }
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر الحفظ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final candidates = store.users.where((u) => u.status == UserStatus.approved).toList();
    final assigned = _assigned;

    return AlertDialog(
      title: const Text('عرض في لوحة قيادة'),
      content: SizedBox(
        width: 420,
        child: assigned == null
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${widget.title}"',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('اختر من تريد أن يظهر له هذا العنصر أعلى لوحة قيادته.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: candidates
                            .map((u) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  value: assigned.contains(u.id),
                                  title: Text(u.name,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  subtitle: Text(u.role.label, style: const TextStyle(fontSize: 10.5)),
                                  onChanged: _busy ? null : (v) => _toggle(u.id, v ?? false),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      ],
    );
  }
}
