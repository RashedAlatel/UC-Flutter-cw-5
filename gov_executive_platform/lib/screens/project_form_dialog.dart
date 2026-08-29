// تعديل بيانات المشروع.
//
// ــــ لم يكن للمشروع نموذجُ تعديلٍ إطلاقاً ــــ
//
// ولا لمسؤول النظام. الموجود كان تعديلَ أسماء المنفّذين وحدها. فخطأٌ مطبعي
// في اسم مشروعٍ يبقى سنةً، وتصنيفٌ وُضع خطأً لا يُرفع، ووصفٌ كُتب على عجل
// لا يُحرَّر — إلا بحذف المشروع وإعادة إنشائه بتاريخٍ جديد وتوابعَ ضائعة.
//
// ــــ وما ليس فيه، وسببُه ــــ
//
// * **الموعد النهائي** — يمرّ بطلبٍ يعتمده مسؤول النظام، وقاعدةُ Firestore
//   تردّه هنا على أي حال. فلا يُعرض حقلٌ يَعِد بما سيُردّ عند الحفظ.
// * **الإدارة** — نقلُ مشروعٍ بين الإدارات يُخرجه من نطاق من ينقله، وله
//   مسارُه القائم (نقل الأقسام).
// * **العضوية** — تمرّ بدالّة `setProjectTeam` على الخادم، لأن القواعد لا
//   تفحص **رتبة** من في القائمتين: لا حلقات في لغتها.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/section_picker.dart';

/// يفتح نموذج تعديل بيانات المشروع. يُعيد true إن حُفظ تعديلٌ فعلاً.
Future<bool> showProjectFormDialog(BuildContext context, Project project) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ProjectFormDialog(project: project),
  );
  return result == true;
}

class ProjectFormDialog extends StatefulWidget {
  final Project project;
  const ProjectFormDialog({super.key, required this.project});

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.project.name);
  late final _descCtrl = TextEditingController(text: widget.project.description);
  late PriorityLevel _priority = widget.project.priority;
  late String? _sectionId = widget.project.sectionId;
  late final List<String> _categoryIds = List<String>.from(widget.project.categoryIds);

  // ــ بيانات العقد ــ
  //
  // و`null` تبقى `null`: حقلٌ لم يُملأ يبقى «غير مسجّل»، ولا يُحفظ صفراً
  // ولا تاريخَ اليوم لمجرّد أن النموذج فُتح وأُغلق.
  late DateTime? _contractDate = widget.project.contractDate;
  late DateTime? _contractStart = widget.project.contractStartDate;
  late DateTime? _contractEnd = widget.project.contractEndDate;
  late DateTime? _invoiceDue = widget.project.invoiceDueDate;
  late final _durationCtrl = TextEditingController(
      text: widget.project.durationDays?.toString() ?? '');
  late final _valueCtrl = TextEditingController(
      text: widget.project.contractValue?.toString() ?? '');
  late final _contractorCtrl =
      TextEditingController(text: widget.project.contractorName);

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _valueCtrl.dispose();
    _contractorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await store.updateProjectDetails(
      widget.project,
      name: _nameCtrl.text,
      description: _descCtrl.text,
      priority: _priority,
      sectionId: _sectionId,
      categoryIds: _categoryIds,
      contractDate: _contractDate,
      contractStartDate: _contractStart,
      contractEndDate: _contractEnd,
      invoiceDueDate: _invoiceDue,
      // حقلٌ فارغ أو نصٌّ لا يُقرأ رقماً يبقى «غير مسجّل» — ولا يُقلب صفراً.
      durationDays: int.tryParse(_durationCtrl.text.trim()),
      contractValue: double.tryParse(_valueCtrl.text.trim()),
      contractorName: _contractorCtrl.text,
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
    final store = context.watch<AppStore>();
    final dept = store.departmentById(widget.project.departmentId);

    return AlertDialog(
      title: const Text('تعديل بيانات المشروع'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم المشروع'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: [
                  for (final p in PriorityLevel.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 12),
              SectionPicker(
                departmentId: widget.project.departmentId,
                initialSectionId: _sectionId,
                onChanged: (v) => _sectionId = v,
              ),
              if (store.categories.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('التصنيفات',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in store.categories)
                      FilterChip(
                        label: Text(c.name, style: const TextStyle(fontSize: 12)),
                        selected: _categoryIds.contains(c.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _categoryIds.add(c.id);
                          } else {
                            _categoryIds.remove(c.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text('بيانات العقد',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              // الفارغُ يبقى فارغاً: من لا عقد له لا يُملأ له تاريخُ اليوم.
              const Text(
                'ما لا يُملأ يبقى «غير مسجّل» — ولا يُحفظ صفراً ولا تاريخاً.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              _DateField(
                label: 'تاريخ العقد',
                value: _contractDate,
                onChanged: (d) => setState(() => _contractDate = d),
              ),
              _DateField(
                label: 'تاريخ بداية العقد',
                value: _contractStart,
                onChanged: (d) => setState(() => _contractStart = d),
              ),
              _DateField(
                label: 'تاريخ انتهاء العقد',
                value: _contractEnd,
                onChanged: (d) => setState(() => _contractEnd = d),
              ),
              _DateField(
                label: 'تاريخ استحقاق الفاتورة',
                value: _invoiceDue,
                onChanged: (d) => setState(() => _invoiceDue = d),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مدة المشروع',
                        suffixText: 'يوم',
                        // المدّةُ منصوصةٌ في العقد لا مشتقّةٌ من التاريخين —
                        // راجع `Project.durationDays`.
                        helperText: 'كما في العقد',
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'قيمة العقد',
                        suffixText: 'د.ك',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contractorCtrl,
                decoration: const InputDecoration(
                  labelText: 'الجهة أو الشركة المنفّذة',
                ),
              ),
              const SizedBox(height: 16),
              // ــ يُقال صراحةً ما لا يُعدَّل من هنا وأين يُعدَّل ــ
              //
              // نموذجٌ ينقصه حقلٌ بلا تفسير يُقرأ نقصاً في المنصة، فيُبحث عنه
              // في كل شاشة. وذكرُ الطريق أقصرُ من البحث.
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'الموعد النهائي يُعدَّل بطلبٍ يعتمده مسؤول النظام، '
                  'وفريق المشروع من بطاقة الفريق في صفحته، '
                  'والإدارة${dept == null ? '' : ' (${dept.name})'} لا تُنقل من هنا.',
                  style: const TextStyle(fontSize: 11.5, height: 1.7),
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
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}

/// حقلُ تاريخٍ **يقبل الفراغ** — ومسحُه فعلٌ صريح لا نسيان.
///
/// و`showDatePicker` وحده لا يكفي: لا سبيل فيه إلى قول «لا تاريخ». فيُوضع
/// إلى جانبه زرُّ مسحٍ يظهر حين يكون هناك ما يُمسح — وبه يعود الحقل «غير
/// مسجّل» بعد أن مُلئ خطأً.
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2040),
                  helpText: label,
                );
                if (picked != null) onChanged(picked);
              },
              icon: const Icon(Icons.event_rounded, size: 17),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value == null ? '$label — غير مسجّل' : '$label: ${Formatters.date(value!)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: value == null ? AppColors.textSecondary : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'مسح $label',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
