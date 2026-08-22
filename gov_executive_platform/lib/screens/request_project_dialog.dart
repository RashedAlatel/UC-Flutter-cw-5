import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/executors_field.dart';
import '../widgets/section_picker.dart';

/// نموذج إضافة مشروع: لمسؤول النظام يُنشئ المشروع مباشرة (موافقته الذاتية
/// كافية)، ولأي دور آخر يُرسل "طلب إضافة مشروع" ينتظر اعتماد مسؤول النظام
/// من مركز القرارات التنفيذية. إن لم تُحدَّد [departmentId] (الاستدعاء من
/// شاشة "المشاريع" الموحّدة بدل شاشة إدارة بعينها) يظهر حقل اختيار إدارة
/// اختياري يشمل خيار "بدون إدارة" — لا يتوفر هذا المسار إلا لمسؤول النظام.
class RequestProjectDialog extends StatefulWidget {
  final String? departmentId;
  const RequestProjectDialog({super.key, this.departmentId});

  @override
  State<RequestProjectDialog> createState() => _RequestProjectDialogState();
}

class _RequestProjectDialogState extends State<RequestProjectDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<String> _executorNames = [];
  PriorityLevel _priority = PriorityLevel.medium;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 60));
  final Set<String> _managerUids = {};
  final Set<String> _executorUids = {};
  late String? _selectedDepartmentId = widget.departmentId;
  String? _sectionId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء تعبئة اسم المشروع ووصفه');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final departmentId = _selectedDepartmentId ?? '';
    // المعيار هو النطاق لا الدور: مسؤول النظام يُنشئ في أي إدارة، وصاحب
    // منحة «إنشاء المشاريع» يُنشئ داخل نطاقه، ومن سواهما يقدّم طلباً.
    final direct = store.canCreateIn(departmentId);
    if (direct) {
      await store.createProjectDirect(
        departmentId: departmentId,
        sectionId: _sectionId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
        executorNames: _executorNames,
        managerUids: _managerUids.toList(),
        executorUids: _executorUids.toList(),
      );
    } else {
      await store.submitProjectRequest(
        departmentId: departmentId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
        executorNames: _executorNames,
        managerUids: _managerUids.toList(),
        executorUids: _executorUids.toList(),
        sectionId: _sectionId,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(direct
            ? 'تمت إضافة المشروع بنجاح'
            : 'تم إرسال طلب إضافة المشروع للاعتماد'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final departmentId = _selectedDepartmentId;
    final isAdmin = store.canCreateIn(departmentId);
    // ــــ من يُسنَد إلى المشروع ــــ
    //
    // كانت القائمة `users.where(role == projectOfficer)` — فالموظف صاحب
    // صلاحية الإنشاء **لا يجد اسمه فيها** ولو أراد تسجيل نفسه، وهو ما
    // اشتُكي منه. المعيار الآن الانتماء للإدارة لا الدور.
    final candidates = store.users
        .where((u) =>
            u.status == UserStatus.approved &&
            (departmentId == null ||
                departmentId.isEmpty ||
                u.departmentId == departmentId ||
                u.departmentIds.contains(departmentId)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final me = store.currentUser;
    return AlertDialog(
      title: Text(isAdmin ? 'إضافة مشروع جديد' : 'طلب إضافة مشروع جديد'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المشروع')),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف المشروع')),
              const SizedBox(height: 12),
              ExecutorsField(initial: _executorNames, onChanged: (v) => _executorNames = v),
              const SizedBox(height: 12),
              if (widget.departmentId == null) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedDepartmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الإدارة (اختياري)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون إدارة')),
                    ...store.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedDepartmentId = v),
                ),
                const SizedBox(height: 12),
              ],
              // القسم داخل الإدارة — لا يظهر إلا للإدارات التي أنشأت أقساماً،
              // فلا يُزحم النموذج على من لا يستخدمها.
              if (departmentId != null && departmentId.isNotEmpty) ...[
                SectionPicker(
                  departmentId: departmentId,
                  initialSectionId: _sectionId,
                  onChanged: (v) => _sectionId = v,
                ),
                if (store.sectionsOf(departmentId).isNotEmpty) const SizedBox(height: 12),
              ],
              // ــــ العضوية: تُختار هنا وتُكتب مع المشروع ــــ
              //
              // وتظهر لمن يُنشئ ولمن يطلب معاً: الطلب يحمل العضوية في حمولته،
              // فيخرج المشروع المُعتمَد وعليه أعضاؤه ويظهر لهم في «المُسنَد
              // إليّ» فوراً. وكان يخرج بلا عضو واحد فلا يجده أحد.
              if (me != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      final mine = _managerUids.contains(me.id) && _executorUids.contains(me.id);
                      if (mine) {
                        _managerUids.remove(me.id);
                        _executorUids.remove(me.id);
                      } else {
                        _managerUids.add(me.id);
                        _executorUids.add(me.id);
                      }
                    }),
                    icon: Icon(
                      _managerUids.contains(me.id) && _executorUids.contains(me.id)
                          ? Icons.person_remove_outlined
                          : Icons.person_add_alt_1_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _managerUids.contains(me.id) && _executorUids.contains(me.id)
                          ? 'أزلني من المشروع'
                          : 'أضفني مديراً ومنفّذاً',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (candidates.isNotEmpty) ...[
                _MemberPicker(
                  label: 'مديرو المشروع',
                  hint: 'من يقود المشروع ويكتب تحديثاته اليومية',
                  candidates: candidates,
                  selected: _managerUids,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _MemberPicker(
                  label: 'المنفّذون (حسابات)',
                  hint: 'أعضاء المنصة المسجَّلون على المشروع — غير الأسماء المكتوبة أعلاه',
                  candidates: candidates,
                  selected: _executorUids,
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: PriorityLevel.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text('البدء: ${_startDate.year}/${_startDate.month}/${_startDate.day}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_available_outlined, size: 16),
                      label: Text('الاستحقاق: ${_dueDate.year}/${_dueDate.month}/${_dueDate.day}'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isAdmin ? 'إضافة المشروع' : 'إرسال الطلب'),
        ),
      ],
    );
  }
}

/// اختيار أعضاء من حسابات الإدارة.
///
/// قائمة مربّعات لا قائمة منسدلة: العضوية متعددة، والمنسدلة تعطي واحداً.
/// وهي محدودة الارتفاع وتُمرَّر داخلها — إدارة فيها ثلاثون موظفاً تجعل
/// الحوار أطول من الشاشة وتُخفي زرّ الحفظ.
class _MemberPicker extends StatelessWidget {
  final String label;
  final String hint;
  final List<AppUser> candidates;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MemberPicker({
    required this.label,
    required this.hint,
    required this.candidates,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final u in candidates)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    value: selected.contains(u.id),
                    title: Text(u.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onChanged: (v) {
                      if (v == true) {
                        selected.add(u.id);
                      } else {
                        selected.remove(u.id);
                      }
                      onChanged(selected);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
