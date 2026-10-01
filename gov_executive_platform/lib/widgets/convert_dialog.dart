// التحويل بين مشروعٍ وعمل.
//
// ــــ ما يقع فعلاً، ويُقال قبل الضغط ــــ
//
// لا يُنقل السجل. يُنشأ **نظيرُه** بالبيانات المشتركة، ويُؤرشَف الأصل
// مرتبطاً به في الاتجاهين. فالمهام والتحديثات اليومية والمرفقات والمخاطر
// والعوائق تبقى كلُّها على الأصل المؤرشف بلا أن تُمسّ، ويُقرأ تاريخه منه.
//
// وهذا **ليس** ما يتوقعه من يقرأ كلمة «تحويل» وحدها. فيُقال في النافذة
// صراحةً، بعدد ما سيبقى على الأصل — لا بعبارةٍ عامة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/assignment_policy.dart';
import '../models/project.dart';
import '../models/work_item.dart';
import '../theme/app_theme.dart';
import 'person_picker.dart';

/// يحوّل مشروعاً إلى عمل. يُعيد معرّف العمل الجديد عند النجاح.
Future<String?> showConvertProjectDialog(BuildContext context, Project project) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ConvertDialog(
        kind: 'project',
        id: project.id,
        name: project.name,
        departmentId: project.departmentId,
        suggestedOwnerUid: project.managerUids.isEmpty ? null : project.managerUids.first,
      ),
    );

/// ويحوّل عملاً إلى مشروع. يُعيد معرّف المشروع الجديد عند النجاح.
Future<String?> showConvertWorkDialog(BuildContext context, WorkItem work) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ConvertDialog(
        kind: 'work',
        id: work.id,
        name: work.title,
        departmentId: work.departmentId,
        suggestedOwnerUid: work.assigneeUid.isEmpty ? null : work.assigneeUid,
      ),
    );

class _ConvertDialog extends StatefulWidget {
  final String kind;
  final String id;
  final String name;
  final String departmentId;

  /// المُسنَد إليه الحالي أو أول قادة المشروع — يُقترح ويمكن تغييره.
  final String? suggestedOwnerUid;

  const _ConvertDialog({
    required this.kind,
    required this.id,
    required this.name,
    required this.departmentId,
    required this.suggestedOwnerUid,
  });

  @override
  State<_ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends State<_ConvertDialog> {
  late final Set<String> _picked = {
    if (widget.suggestedOwnerUid != null && widget.suggestedOwnerUid!.isNotEmpty)
      widget.suggestedOwnerUid!,
  };
  bool _busy = false;
  String? _error;

  bool get _toWork => widget.kind == 'project';

  Future<void> _convert() async {
    final store = context.read<AppStore>();
    if (_picked.isEmpty) {
      setState(() => _error = _toWork
          ? 'اختر المسؤول عن العمل بعد التحويل.'
          : 'اختر قائد المشروع بعد التحويل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await store.convertRecord(
      kind: widget.kind,
      id: widget.id,
      ownerUid: _picked.first,
    );
    if (!mounted) return;
    if (res.error != null) {
      setState(() {
        _busy = false;
        _error = res.error;
      });
      return;
    }
    Navigator.pop(context, res.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // ما سيبقى على الأصل — بعدده لا بعبارةٍ عامة. و«لا شيء» يُقال كذلك:
    // نافذةٌ تُحذّر من فقد تاريخٍ لا وجود له تُخيف بلا سبب.
    final d = _toWork ? store.projectDependents(widget.id) : null;
    final staying = d == null ? 0 : d.tasks + d.risks + d.blockers;

    // ولا تُصفّى القائمة بالمُسنَد إليه الحالي: من يقود المشروع اليوم هو
    // أولى من يتولّى العمل غداً، واستبعادُه يجعل الاقتراح غير قابل للاختيار.
    final candidates = eligibleAssignees(
      allUsers: store.users,
      actor: store.currentUser,
      departmentId: widget.departmentId,
    );

    return AlertDialog(
      title: Text(_toWork ? 'تحويل المشروع إلى عمل' : 'تحويل العمل إلى مشروع'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'سيُنشأ ${_toWork ? 'عملٌ' : 'مشروعٌ'} جديد باسم "${widget.name}" '
                  'يحمل الوصف والإدارة والموعد والأولوية ونسبة الإنجاز، '
                  'ويُؤرشَف ${_toWork ? 'المشروع' : 'العمل'} الأصلي مرتبطاً به.\n'
                  '${staying > 0 ? 'ويبقى على الأصل $staying من مهامّه ومخاطره وعوائقه، ومعها تحديثاته اليومية ومرفقاتها — لا تُمحى ولا تُنقل، وتُقرأ من شاشة «المحذوفات».' : 'ولا تُمحى تحديثاته اليومية ولا مرفقاته: تبقى على الأصل وتُقرأ من شاشة «المحذوفات».'}',
                  style: const TextStyle(fontSize: 11.5, height: 1.75),
                ),
              ),
              const SizedBox(height: 14),
              if (candidates.isEmpty)
                Text(
                  emptyAssigneeReason(
                    allUsers: store.users,
                    actor: store.currentUser,
                    departmentId: widget.departmentId,
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                )
              else
                PersonPicker(
                  label: _toWork ? 'المسؤول عن العمل' : 'قائد المشروع',
                  hint: 'اكتب جزءاً من الاسم',
                  candidates: candidates,
                  departmentNameOf: (u) => store.departmentById(u.departmentId ?? '')?.name ?? '',
                  selected: _picked,
                  onChanged: () {
                    // اختيارٌ واحد: آخرُ ما اختير هو المقصود.
                    if (_picked.length > 1) {
                      final last = _picked.last;
                      _picked
                        ..clear()
                        ..add(last);
                    }
                    setState(() => _error = null);
                  },
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
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy || candidates.isEmpty ? null : _convert,
          child: Text(_busy ? 'جارٍ التحويل…' : 'تحويل'),
        ),
      ],
    );
  }
}
