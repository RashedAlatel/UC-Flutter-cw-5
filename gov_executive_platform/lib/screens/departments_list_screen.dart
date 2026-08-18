import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../theme/app_theme.dart';
import '../theme/department_icons.dart';
import '../widgets/progress_bar.dart';
import 'department_detail_screen.dart';

/// يوحّد الفروقات الشكلية الشائعة في الكتابة العربية (الهمزة على الألف
/// وحذفها، ألف مقصورة/ياء، تاء مربوطة/هاء، والمسافات الزائدة) قبل مقارنة
/// أسماء الإدارات — لمنع إنشاء إدارة مكررة بالخطأ بسبب فرق إملائي بسيط
/// مثل "إدارة X" مقابل "ادارة X".
String _normalizeArabic(String s) => s
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp('[إأآا]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه');

class DepartmentsListScreen extends StatelessWidget {
  const DepartmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final departments = store.visibleDepartments;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإدارات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('عرض جميع الإدارات ومؤشرات أداء مشاريعها', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              if (store.canManageUsers)
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const _AddDepartmentDialog()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة إدارة'),
                ),
            ],
          ),
          if (store.canManageUsers && departments.isEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('لا توجد إدارات بعد. يمكنك استيراد قائمة إدارات مقترحة كنقطة بداية سريعة.', style: TextStyle(fontSize: 12.5)),
                    ),
                    OutlinedButton(
                      onPressed: () => context.read<AppStore>().seedDefaultDepartments(),
                      child: const Text('استيراد الإدارات الافتراضية'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (store.canManageUsers) ...[
            const SizedBox(height: 14),
            const _MinistryImportCard(),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 1150 ? 3 : (constraints.maxWidth > 720 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.35,
              children: departments.map((dept) {
                final progress = store.departmentProgress(dept.id);
                final delay = store.departmentAvgDelay(dept.id);
                final projectCount = store.projectsForDepartment(dept.id).length;
                final risks = store.departmentRiskCount(dept.id);
                final blockers = store.departmentBlockerCount(dept.id);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(dept.name)),
                        body: DepartmentDetailScreen(departmentId: dept.id),
                      ),
                    )),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: dept.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(dept.icon, color: dept.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), maxLines: 2),
                                    Text('مسؤول الإدارة: ${dept.headName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              if (store.canManageUsers)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                                  tooltip: 'حذف الإدارة',
                                  onPressed: () => _confirmDelete(context, dept),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LabeledProgressBar(value: progress, label: 'نسبة الإنجاز', color: dept.color),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MiniStat(icon: Icons.folder_copy_outlined, label: 'مشاريع', value: '$projectCount'),
                              _MiniStat(icon: Icons.schedule_rounded, label: 'تأخير', value: '${delay.toStringAsFixed(0)} يوم'),
                              _MiniStat(icon: Icons.warning_amber_rounded, label: 'مخاطر', value: '$risks'),
                              _MiniStat(icon: Icons.block_rounded, label: 'عوائق', value: '$blockers'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, Department dept) async {
  final store = context.read<AppStore>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف الإدارة'),
      content: Text('هل أنت متأكد من حذف "${dept.name}"؟ لا يمكن التراجع عن هذا الإجراء.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final error = await store.deleteDepartment(dept);
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف "${dept.name}"')));
  }
}

class _AddDepartmentDialog extends StatefulWidget {
  const _AddDepartmentDialog();

  @override
  State<_AddDepartmentDialog> createState() => _AddDepartmentDialogState();
}

class _AddDepartmentDialogState extends State<_AddDepartmentDialog> {
  final _nameCtrl = TextEditingController();
  final _headCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _headCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final store = context.read<AppStore>();
    final normalized = _normalizeArabic(name);
    final duplicate = store.departments.any((d) => _normalizeArabic(d.name) == normalized);
    if (duplicate) {
      setState(() => _error = 'توجد إدارة بنفس الاسم تقريباً بالفعل. تأكد من عدم التكرار قبل الإضافة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = 'dept_${DateTime.now().microsecondsSinceEpoch}';
    await store.addDepartment(Department(
          id: id,
          name: name,
          headName: _headCtrl.text.trim(),
          colorValue: 0xFF0B3D66,
          iconKey: DepartmentIcons.defaultKey,
        ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة إدارة جديدة'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الإدارة')),
            const SizedBox(height: 12),
            TextField(controller: _headCtrl, decoration: const InputDecoration(labelText: 'اسم مسؤول الإدارة')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إضافة'),
        ),
      ],
    );
  }
}

/// استيراد بيانات وزارة العدل الحقيقية (٤ إدارات + ٦٥ مشروعاً بمنفذيها) من
/// ملف Excel الذي زوّده مسؤول النظام. آمن التكرار (معرّفات ثابتة).
class _MinistryImportCard extends StatefulWidget {
  const _MinistryImportCard();

  @override
  State<_MinistryImportCard> createState() => _MinistryImportCardState();
}

class _MinistryImportCardState extends State<_MinistryImportCard> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppStore>().importMinistryData();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر الاستيراد، حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.file_upload_outlined, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('استيراد بيانات وزارة العدل', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'يستورد ٤ إدارات (تطوير النظم، التشغيل، الدعم الفني، الإحصاء والبحوث) و٦٥ مشروعاً من ملف Excel، مع تعيين المنفذين لكل مشروع. '
                    'الحالة ونسبة الإنجاز استُنتجتا آلياً من نص الملاحظات الأصلي وقد تحتاجان مراجعة يدوية لبعض المشاريع.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  _done
                      ? const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            SizedBox(width: 6),
                            Text('تم الاستيراد بنجاح', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: _busy
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('استيراد الآن'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
