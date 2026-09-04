// نقلُ المشروع من إدارة إلى أخرى.
//
// ــــ ولماذا نافذةٌ تقول ما ستفعل قبل أن تفعله ــــ
//
// النقلُ يُخرج المشروع **وتوابعَه كاملةً** من نطاق إدارةٍ ويُدخلها أخرى:
// مديرُ الإدارة القديمة يفقد رؤيتَه، ومديرُ الجديدة يكسبها. وهو أوسعُ أثراً
// من تغيير المدير، ويقع بضغطةٍ واحدة — فيُقال أثرُه قبلها لا بعدها.
//
// ــــ ومسارانِ لا مسار ــــ
//
// مسؤولُ النظام ينقل مباشرةً (لا يرفع طلباً إلى نفسه)، وغيرُه يرفع طلباً
// يبتّ فيه مسؤولُ النظام وحده. والزرُّ يقول أيَّهما يفعل — فلا يَعِد بنقلٍ
// لا يقع.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// يفتح نافذة نقل المشروع. يُعيد `true` إن وقع النقل أو رُفع الطلب.
Future<bool> showTransferProjectDialog(BuildContext context, Project project) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => ProjectTransferDialog(project: project),
  );
  return done ?? false;
}

class ProjectTransferDialog extends StatefulWidget {
  final Project project;
  const ProjectTransferDialog({super.key, required this.project});

  @override
  State<ProjectTransferDialog> createState() => _ProjectTransferDialogState();
}

class _ProjectTransferDialogState extends State<ProjectTransferDialog> {
  String? _departmentId;
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target = _departmentId;
    if (target == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final error = store.isAdmin
        ? await store.transferProjectDepartment(
            project: widget.project,
            newDepartmentId: target,
            reason: _reasonCtrl.text.trim(),
          )
        : await store.submitDepartmentTransferRequest(
            project: widget.project,
            newDepartmentId: target,
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
    final store = context.watch<AppStore>();
    final current = store.departmentById(widget.project.departmentId);
    // وإدارتُه الحالية لا تُعرض خياراً: نقلُ الشيء إلى موضعه ليس نقلاً.
    final targets = store.departments
        .where((d) => d.id != widget.project.departmentId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final pending = store.pendingTransferFor(widget.project);

    return AlertDialog(
      title: Text(store.isAdmin ? 'نقل المشروع إلى إدارة أخرى' : 'طلب نقل المشروع'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending != null) ...[
                _Note(
                  color: AppColors.info,
                  icon: Icons.hourglass_top_rounded,
                  text: 'على هذا المشروع طلبُ نقلٍ معلّق قدّمه '
                      '${pending.requestedByName} — بانتظار مسؤول النظام.',
                ),
                const SizedBox(height: 12),
              ],
              Text('الإدارة الحالية: ${current?.name ?? widget.project.departmentId}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الإدارة المستقبِلة'),
                items: targets
                    .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                    .toList(),
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'سبب النقل (اختياري)',
                  helperText: 'يُعرض للمعتمِد ويُحفظ في السجل',
                ),
              ),
              const SizedBox(height: 16),
              // ــ ما سيقع، بالحرف ــ
              //
              // ثلاثةُ أشياء يخشاها من ينقل: أن يضيع شيء، وألّا تنتقل
              // الصلاحيات، وألّا يُعرف من نقل. فتُنفى الثلاثة صراحةً.
              _Note(
                color: AppColors.warning,
                icon: Icons.info_outline_rounded,
                text: 'ينتقل مع المشروع كلُّ ما فيه: مهامُّه وتحديثاته اليومية '
                    'ومخاطره وعوائقه ومرفقاته — لا يُحذف منها شيء ولا يُنشأ. '
                    'ويكسب مديرُ الإدارة المستقبِلة رؤيتَها وإدارتَها، ويفقدها '
                    'مديرُ الإدارة الحالية. ويُفرَّغ القسمُ داخل الإدارة لأن '
                    'قسمها القديم ليس من الإدارة الجديدة. ويُسجَّل تاريخ النقل '
                    'ومن نفّذه في سجل التدقيق.',
              ),
              if (!store.isAdmin) ...[
                const SizedBox(height: 10),
                _Note(
                  color: AppColors.info,
                  icon: Icons.verified_user_outlined,
                  text: 'ولا يقع النقل بإرسالك: يبتّ فيه مسؤول النظام، '
                      'وحتى يعتمده تبقى البيانات كما هي.',
                ),
              ],
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
          // بلا إدارةٍ مختارة لا معنى للزرّ.
          onPressed: (_busy || _departmentId == null) ? null : _submit,
          child: Text(
            _busy
                ? (store.isAdmin ? 'جارٍ النقل…' : 'جارٍ الإرسال…')
                : (store.isAdmin ? 'نقل المشروع' : 'إرسال للاعتماد'),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Note({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11.5, height: 1.8)),
          ),
        ],
      ),
    );
  }
}
