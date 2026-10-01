/// أنواعُ الحالات اليومية — **قائمةٌ يحرّرها مسؤولُ النظام**.
///
/// ــــ ولماذا تُحرَّر ولا تُكتب في الشيفرة ــــ
///
/// لأنّ الوزارة تُحدث أنواعاً لا نعرفها: «عملٌ عن بُعد»، «انتدابٌ خارجيّ»،
/// «مرافقةُ مريض». ولو كُتبت الثمانيةُ في تعدادٍ لَاحتاج كلُّ نوعٍ جديدٍ
/// إصداراً جديداً من المنصة وانتظارَ من يبنيه.
///
/// ــــ وما يُضبط لكلّ نوع ــــ
///
/// ليس اسماً ولوناً فحسب: **أين يصلح** (يوماً كاملاً أم خروجاً بوقته)،
/// و**أيُحتسب حضوراً** في العدّ، و**أيلزمُه مكانٌ أو مرفق**. وهذه سياساتٌ
/// إداريّةٌ لا حقائقُ تقنيّة — فتبقى بيد من يقرّرها.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/status_type.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/command_band.dart';
import '../widgets/status_pill.dart';

class StatusTypesScreen extends StatelessWidget {
  const StatusTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final types = [...store.statusTypes]..sort((a, b) => a.order.compareTo(b.order));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'أنواع الحالات اليومية',
            subtitle: 'ما يختار منه الموظّف حين يسجّل حالتَه — وأثرُ كلِّ نوعٍ في العدّ',
            actions: [
              if (store.isAdmin)
                BandButton(
                  label: 'إضافة نوع',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => _edit(context, store, null),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('الأنواع المتاحة'),
                const SizedBox(height: 14),
                if (types.isEmpty)
                  const AppEmptyState(
                    icon: Icons.category_outlined,
                    title: 'لا أنواعَ مسجّلة',
                    message: 'أضف نوعاً ليظهر للموظّفين حين يسجّلون حالاتهم.',
                  )
                else
                  ...types.map((t) => _TypeRow(
                        type: t,
                        onEdit: store.isAdmin ? () => _edit(context, store, t) : null,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _edit(BuildContext context, AppStore store, StatusType? existing) =>
      showDialog(context: context, builder: (_) => _TypeDialog(existing: existing));
}

/// صفُّ نوعٍ واحد — اسمُه بنغمته، ثمّ ما يقوله عنه النظامُ في سطر.
class _TypeRow extends StatelessWidget {
  final StatusType type;
  final VoidCallback? onEdit;

  const _TypeRow({required this.type, this.onEdit});

  @override
  Widget build(BuildContext context) {
    // وما يُقال عن النوع **جملاً لا رموزاً**: «يُحتسب حضوراً» أوضحُ من
    // علامةِ صحٍّ في عمودٍ عنوانُه «حضور».
    final facts = <String>[
      if (type.canBeDay) 'يشغل اليومَ كلَّه',
      if (type.canBeOuting) 'يصلح خروجاً بوقته',
      if (type.countsAsPresent) 'يُحتسب حضوراً',
      if (type.requiresPlace) 'يلزمه مكان',
      if (type.requiresAttachment) 'يلزمه مرفق',
    ];

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StatusPill(label: type.name, tone: StatusPalette.byToneKey(type.toneKey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              facts.isEmpty ? 'لا يصلح حالةً ولا خروجاً — لن يظهر للموظّف' : facts.join(' · '),
              style: AppType.micro.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!type.isActive) ...[
            const SizedBox(width: 8),
            StatusPill(label: 'مؤرشَف', tone: StatusPalette.neutral, dot: false),
          ],
          if (onEdit != null)
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

class _TypeDialog extends StatefulWidget {
  final StatusType? existing;
  const _TypeDialog({this.existing});

  @override
  State<_TypeDialog> createState() => _TypeDialogState();
}

class _TypeDialogState extends State<_TypeDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _tone = widget.existing?.toneKey ?? 'neutral';
  late bool _canBeDay = widget.existing?.canBeDay ?? true;
  late bool _canBeOuting = widget.existing?.canBeOuting ?? false;
  late bool _countsAsPresent = widget.existing?.countsAsPresent ?? false;
  late bool _requiresPlace = widget.existing?.requiresPlace ?? false;
  late bool _requiresAttachment = widget.existing?.requiresAttachment ?? false;
  late bool _isActive = widget.existing?.isActive ?? true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'الرجاء كتابة اسم النوع');
      return;
    }
    // ــ ونوعٌ لا يصلح يوماً ولا خروجاً لا يُحفظ ــ
    //
    // لأنّه لن يظهر للموظّف في أيّ موضع، فيبقى في القائمة يوهم مسؤولَ
    // النظام أنّه أتاح شيئاً. وهذا هو «خطّافٌ بُني ولم يُوصَل» بعينه.
    if (!_canBeDay && !_canBeOuting) {
      setState(() => _error = 'اختر أين يصلح هذا النوع: حالةً لليوم، أو خروجاً بوقته، أو كليهما');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final items = [...store.statusTypes];
    final existing = widget.existing;
    final built = StatusType(
      // والمعرّفُ يبقى كما هو للقائم، ويُشتقّ من الوقت للجديد: معرّفٌ من
      // الاسم كان يتبدّل بتصحيح حرفٍ فيه، فتصير سجلّاتُ الشهر الماضي
      // منسوبةً إلى نوعٍ لا وجود له.
      id: existing?.id ?? 'st${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      toneKey: _tone,
      canBeDay: _canBeDay,
      canBeOuting: _canBeOuting,
      countsAsPresent: _countsAsPresent,
      requiresPlace: _requiresPlace,
      requiresAttachment: _requiresAttachment,
      order: existing?.order ?? items.length,
      isActive: _isActive,
    );
    final index = items.indexWhere((t) => t.id == built.id);
    if (index >= 0) {
      items[index] = built;
    } else {
      items.add(built);
    }

    final error = await store.saveStatusTypes(items);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'نوع حالة جديد' : 'تعديل النوع'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم النوع', isDense: true),
              ),
              const SizedBox(height: 14),
              // ــ واللونُ اسمُ نغمةٍ لا لوحةُ ألوان ــ
              //
              // فلو اختار مسؤولُ النظام لوناً حرّاً لَصار في المنصة موضعٌ
              // ثانٍ يقرّر لونَ معنى — في قاعدة البيانات حيث لا يبلغه حارسُ
              // لون المعنى. والنغماتُ الثمانُ هي التي تحمل معانيَ المنصة.
              DropdownButtonFormField<String>(
                initialValue: StatusPalette.toneChoices.containsKey(_tone) ? _tone : 'neutral',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'اللون ومعناه', isDense: true),
                items: [
                  for (final e in StatusPalette.toneChoices.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _tone = v ?? _tone),
              ),
              const SizedBox(height: 10),
              _Check('يشغل اليومَ كلَّه', _canBeDay, (v) => setState(() => _canBeDay = v),
                  'كـ«حضور» و«إجازة دوريّة»'),
              _Check('يصلح خروجاً بوقته', _canBeOuting, (v) => setState(() => _canBeOuting = v),
                  'كـ«استئذان» و«مهمّة رسميّة» — يُسجَّل بوقت من وإلى على يوم حضور'),
              _Check('يُحتسب حضوراً', _countsAsPresent, (v) => setState(() => _countsAsPresent = v),
                  'يظهر صاحبُه في عدّ الحاضرين ولو كان خارج المبنى'),
              _Check('يلزمه مكان', _requiresPlace, (v) => setState(() => _requiresPlace = v),
                  'يُسأل الموظّف أين — كـ«وزارة المالية»'),
              _Check('يلزمه مرفق', _requiresAttachment,
                  (v) => setState(() => _requiresAttachment = v), 'كشهادة الإجازة الطبيّة'),
              const Divider(height: 24),
              _Check('متاح للتسجيل', _isActive, (v) => setState(() => _isActive = v),
                  'المؤرشَف يبقى يُقرأ في تقارير ما مضى ولا يُعرض لمن يسجّل اليوم'),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppType.body.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'يُحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}

/// خيارٌ بسببه — **ولا خيارَ بلا سبب**.
///
/// «يُحتسب حضوراً» وحدَها لا تقول لمسؤول النظام ماذا تفعل. والسطرُ تحتها
/// هو الفرقُ بين إعدادٍ يُضبط بعلمٍ وإعدادٍ يُضبط بالتخمين.
class _Check extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String hint;

  const _Check(this.label, this.value, this.onChanged, this.hint);

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(label, style: AppType.body),
        subtitle: Text(hint, style: AppType.micro.copyWith(color: AppColors.textSecondary)),
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      );
}
