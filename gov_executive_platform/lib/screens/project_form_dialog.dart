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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
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
