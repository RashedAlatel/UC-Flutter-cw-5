import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../theme/department_icons.dart';
import '../widgets/focused_project_card.dart';
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

class DepartmentsListScreen extends StatefulWidget {
  const DepartmentsListScreen({super.key});

  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.visibleDepartments;
    // البحث يقارن بعد توحيد الفروقات الإملائية، فيجد "إدارة التشغيل" سواء
    // كُتبت في البحث بهمزة أو بدونها.
    final q = _normalizeArabic(_query);
    final departments = q.isEmpty
        ? all
        : all.where((d) => _normalizeArabic(d.name).contains(q) || _normalizeArabic(d.headName).contains(q)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'الإدارات',
            subtitle: '${all.length} إدارة · مؤشرات أداء مشاريع كل إدارة',
            actions: [
              if (store.canManageUsers)
                BandButton(
                  label: 'إضافة إدارة',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const _AddDepartmentDialog()),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          if (all.length > 6) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الإدارة أو مسؤولها',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
          ],
          // بطاقة الاستيراد تعتمد على الإدارات كلها لا على نتيجة البحث، حتى لا
          // تظهر "لا توجد إدارات بعد" لمجرد أن البحث الحالي بلا نتائج.
          if (store.canManageUsers && all.isEmpty) ...[
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
            _MinistryImportCard(
              title: 'استيراد ملف متابعة المشروعات ٢٠٢٦',
              description:
                  'يستورد ٦ أقسام كإدارات مستقلة برؤسائها (تخطيط المشروعات، النظم الآلية، حفظ الوثائق، صيانة النظم، جودة الإنتاج، ومشاريع خطط واتفاقيات الدولة) '
                  'و١٠٨ مشاريع بوصفها وجهاتها المستفيدة وفرق عملها وملاحظاتها كما وردت في الملف. '
                  'تكرار الاستيراد آمن ولا يُنشئ سجلات مكرّرة. '
                  'الحالة ونسبة الإنجاز مستنتجتان من نص الملف وقد تحتاجان مراجعة يدوية لبعض البنود.',
              onImport: (store) => store.importMinistryProjects2026(),
            ),
            const SizedBox(height: 14),
            _MinistryImportCard(
              title: 'استيراد بيانات وزارة العدل (ملف Excel)',
              description:
                  'يستورد ٤ إدارات (تطوير النظم، التشغيل، الدعم الفني، الإحصاء والبحوث) و٦٥ مشروعاً من ملف Excel، مع تعيين المنفذين لكل مشروع. '
                  'الحالة ونسبة الإنجاز استُنتجتا آلياً من نص الملاحظات الأصلي وقد تحتاجان مراجعة يدوية لبعض المشاريع.',
              onImport: (store) => store.importMinistryData(),
            ),
          ],
          const SizedBox(height: 20),
          if (departments.isEmpty && all.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد إدارات مطابقة للبحث', style: TextStyle(color: AppColors.textSecondary))),
            ),
          // ــ لماذا `Wrap` لا `GridView.count`؟ ــ
          //
          // كان هنا `childAspectRatio: 1.35`، أي أن ارتفاع البطاقة = عرضها
          // ÷ ١٫٣٥. والعرض يتبدّل بعرض الشاشة، فالارتفاع يتبدّل معه **بلا أي
          // علاقة بما في البطاقة**: على المكتب صار الفراغ المفروض ١٣٤ بكسل،
          // وعلى الجوال — حيث عمود واحد بعرض الشاشة كلها — ٥١ بكسل تحت كل
          // بطاقة. وهو الفراغ المشتكى منه.
          //
          // و`Wrap` يعطي كل بطاقة **ارتفاعها هي**: لا فراغ مفروض، ولا خطر
          // انسكاب المحتوى لو طال الاسم سطراً ثالثاً — وهو ما يقع لو ثُبِّت
          // ارتفاعٌ مخمَّن بدل النسبة.
          //
          // وهذا النمط قائم في المنصة لا مخترع هنا: لوح ودجات لوحة القيادة
          // (`_WidgetBoard` في `dashboard_screen.dart`) تركه لهذا السبب نفسه.
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 1150 ? 3 : (constraints.maxWidth > 720 ? 2 : 1);
            const spacing = 16.0;
            final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in <Widget>[
                // المشاريع الموضوعة تحت التركيز تظهر كبطاقات مستقلة بجانب
                // بطاقات الإدارات، لا داخل إدارتها — وهو الغرض من تمييزها.
                ...store.focusedProjects.map((p) => FocusedProjectCard(project: p, compact: true)),
                ...departments.map((dept) {
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
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz_rounded, size: 19),
                                  tooltip: 'إجراءات الإدارة',
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'convert':
                                        _confirmConvert(context, dept);
                                      case 'delete':
                                        _confirmDelete(context, dept);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    // ضمّ إدارة تحت إدارة أخرى كقسم — الهيكل
                                    // الفعلي في الوزارة: الإدارة تضم أقساماً.
                                    if (store.canMoveSectionAcrossDepartments)
                                      const PopupMenuItem(
                                        value: 'convert',
                                        child: Text('تحويل إلى قسم داخل إدارة أخرى'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف الإدارة', style: TextStyle(color: AppColors.danger)),
                                    ),
                                  ],
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
                }),
                ])
                  SizedBox(width: itemWidth, child: card),
              ],
            );
          }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نتيجة نافذة تأكيد حذف الإدارة: إلغاء، أو حذف مع إبقاء المشاريع، أو حذف
/// متسلسل يشمل المشاريع.
enum _DeleteChoice { keepProjects, cascade }

Future<void> _confirmDelete(BuildContext context, Department dept) async {
  final store = context.read<AppStore>();
  final count = store.projectsForDepartment(dept.id).length;

  // بلا مشاريع: تأكيد بسيط. مع مشاريع: يختار المستخدم مصيرها صراحةً.
  final choice = await showDialog<_DeleteChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف الإدارة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'هل أنت متأكد من حذف "${dept.name}"؟ لا توجد مشاريع مرتبطة بها.'
                : 'بداخل "${dept.name}" $count مشروعاً. اختر ما يحدث لها:',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          if (count > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'الحذف النهائي يشمل مهام المشاريع ومخاطرها وعوائقها وتحديثاتها اليومية، ولا يمكن التراجع عنه.',
                style: TextStyle(fontSize: 11.5, color: AppColors.danger, height: 1.6),
              ),
            ),
          ],
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        if (count > 0)
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _DeleteChoice.keepProjects),
            child: const Text('حذف الإدارة وإبقاء المشاريع'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, _DeleteChoice.cascade),
          child: Text(count == 0 ? 'حذف' : 'حذف الإدارة ومشاريعها'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  final error = await store.deleteDepartment(dept, cascade: choice == _DeleteChoice.cascade);
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.danger));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(choice == _DeleteChoice.cascade
          ? 'تم حذف "${dept.name}" ومشاريعها'
          : count == 0
              ? 'تم حذف "${dept.name}"'
              : 'تم حذف "${dept.name}" ونُقل $count مشروعاً إلى "بدون إدارة"'),
    ));
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
/// بطاقة استيراد دفعة بيانات جاهزة. تُستخدم لأكثر من ملف مصدر (Excel متابعة
/// الأعمال، وملف مراقبة تنفيذ المشروعات ٢٠٢٦)، لذا يُمرَّر لها العنوان والشرح
/// ودالة الاستيراد بدل تكرار البطاقة نفسها لكل ملف.
class _MinistryImportCard extends StatefulWidget {
  final String title;
  final String description;
  final Future<void> Function(AppStore store) onImport;

  const _MinistryImportCard({
    required this.title,
    required this.description,
    required this.onImport,
  });

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
      await widget.onImport(context.read<AppStore>());
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
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
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

/// تحويل إدارة إلى قسم داخل إدارة أخرى.
///
/// الأقسام المستوردة من ملفات المتابعة تأتي كإدارات مستقلة، بينما هي في الواقع
/// أقسام تحت إدارتها الأم. هذه النافذة تضمّها لمكانها الصحيح: تنتقل مشاريعها
/// وأقسامها معها، ثم تُحذف الإدارة الفارغة — بلا فقد أي سجل.
Future<void> _confirmConvert(BuildContext context, Department dept) async {
  final store = context.read<AppStore>();
  final targets = store.departments.where((d) => d.id != dept.id).toList();
  final messenger = ScaffoldMessenger.of(context);

  if (targets.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('لا توجد إدارة أخرى لضمّ هذه الإدارة إليها')));
    return;
  }

  final projectCount = store.projectsForDepartment(dept.id).length;
  final sectionCount = store.sections.where((s) => s.departmentId == dept.id).length;
  String? targetId;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('تحويل "${dept.name}" إلى قسم'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ستصبح هذه الإدارة قسماً داخل الإدارة التي تختارها، وينتقل معها '
                '$projectCount مشروعاً'
                '${sectionCount > 0 ? ' و$sectionCount قسماً' : ''}. '
                'لا يُحذف أي مشروع، ويبقى اسم المسؤول "${dept.headName}" مسجّلاً على القسم.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.8),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: targetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الإدارة الأم'),
                items: targets.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (v) => setLocal(() => targetId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: targetId == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('تحويل'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || targetId == null) return;

  final error = await store.convertDepartmentToSection(dept, targetId!);
  messenger.showSnackBar(SnackBar(
    content: Text(error ?? 'تم تحويل "${dept.name}" إلى قسم'),
    backgroundColor: error == null ? null : AppColors.danger,
  ));
}
