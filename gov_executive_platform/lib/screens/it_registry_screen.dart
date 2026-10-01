/// سجلُّ التقنية: الأنظمةُ والأجهزة · المورّدون · العقود.
///
/// ــــ ولماذا مدخلٌ واحدٌ لا ثلاثة ــــ
///
/// القائمةُ الجانبيّة فيها نحو خمسةٍ وعشرين مدخلاً، وثلاثةٌ جديدةٌ تُثقلها
/// حتّى يصير إيجادُ ما يُبحث عنه أصعبَ من فتحه. والثلاثةُ يقرؤها الشخصُ
/// نفسُه في الجلسة نفسِها — فشرائحُ في شاشةٍ واحدة أقربُ لعمله من ثلاثِ
/// وقفاتٍ في القائمة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/contract.dart';
import '../models/it_asset.dart';
import '../models/vendor.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';

enum RegistrySection {
  assets('الأنظمة والأجهزة'),
  vendors('المورّدون'),
  contracts('العقود');

  final String label;
  const RegistrySection(this.label);
}

class ItRegistryScreen extends StatefulWidget {
  const ItRegistryScreen({super.key});

  @override
  State<ItRegistryScreen> createState() => _ItRegistryScreenState();
}

class _ItRegistryScreenState extends State<ItRegistryScreen> {
  RegistrySection _section = RegistrySection.assets;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, _section, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(switch (_section) {
          RegistrySection.assets => 'أصلٌ جديد',
          RegistrySection.vendors => 'مورّدٌ جديد',
          RegistrySection.contracts => 'عقدٌ جديد',
        }),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpace.md),
        children: [
          const SectionTitle('سجلّ التقنية', icon: Icons.inventory_2_rounded),
          SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in RegistrySection.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _section == s,
                  onSelected: (_) => setState(() => _section = s),
                ),
            ],
          ),
          SizedBox(height: AppSpace.md),
          ...switch (_section) {
            RegistrySection.assets => _assets(store),
            RegistrySection.vendors => _vendors(store),
            RegistrySection.contracts => _contracts(store),
          },
        ],
      ),
    );
  }

  List<Widget> _assets(AppStore store) {
    final items = store.visibleAssets.toList()
      ..sort((a, b) {
        // والمتجاوزُ سعتَه يتصدّر: هو ما يحتاج قراراً.
        if (a.isOverCapacity != b.isOverCapacity) return a.isOverCapacity ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final over = items.where((a) => a.isOverCapacity).length;
    final unmeasured = items.where((a) => a.capacityUsedPercent == null).length;
    return [
      Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          SizedBox(
            width: 220,
            child: StatCard(
              title: 'في السجلّ',
              value: '${items.length}',
              icon: Icons.inventory_2_rounded,
              tone: StatusPalette.info,
            ),
          ),
          SizedBox(
            width: 220,
            child: StatCard(
              title: 'تجاوز سعتَه',
              value: '$over',
              icon: Icons.storage_rounded,
              tone: over > 0 ? StatusPalette.warning : StatusPalette.success,
            ),
          ),
          SizedBox(
            width: 220,
            child: StatCard(
              title: 'سعتُه غيرُ مقيسة',
              // ــ ويُقال العددُ ولا يُخفى ــ
              //
              // أصلٌ لم تُقَس سعتُه لا يُنبَّه عليه، فلولا هذا الرقم لبدا
              // السجلُّ كلُّه سليماً وفيه ما لم يُنظر إليه أصلاً.
              value: '$unmeasured',
              icon: Icons.help_outline_rounded,
              tone: StatusPalette.neutral,
            ),
          ),
        ],
      ),
      SizedBox(height: AppSpace.md),
      if (items.isEmpty)
        const AppEmptyState(
          title: 'السجلُّ فارغ',
          message: 'سجّل الأنظمةَ والخوادمَ والتراخيصَ لتعرف ماذا تملك ومن يملكه.',
          icon: Icons.inventory_2_rounded,
        )
      else
        for (final a in items)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpace.sm),
            child: _Row(
              title: a.name,
              onTap: () => _openEditor(context, RegistrySection.assets, a),
              pills: [
                StatusPill(label: a.kind.label, tone: StatusPalette.neutral, dot: false),
                StatusPill(label: a.status.label, tone: StatusPalette.assetTone(a.status.name)),
                if (a.criticality.isNotEmpty)
                  StatusPill(
                      label: a.criticality, tone: StatusPalette.neutral, dot: false),
                StatusPill(
                  label: a.capacityUsedPercent == null
                      ? 'السعة غيرُ مقيسة'
                      : 'السعة ${a.capacityUsedPercent}%',
                  tone: a.isOverCapacity ? StatusPalette.warning : StatusPalette.neutral,
                  dot: false,
                ),
              ],
              subtitle: [
                if (a.ownerName.isNotEmpty) 'المالك: ${a.ownerName}',
                if (a.vendorName.isNotEmpty) 'المورّد: ${a.vendorName}',
              ].join(' · '),
            ),
          ),
    ];
  }

  List<Widget> _vendors(AppStore store) {
    final items = store.visibleVendors.toList()..sort((a, b) => a.name.compareTo(b.name));
    return [
      if (items.isEmpty)
        const AppEmptyState(
          title: 'لا مورّدين مسجّلين',
          message: 'سجّلهم مرّةً، ثمّ اربط بهم العقودَ والأنظمة.',
          icon: Icons.handshake_outlined,
        )
      else
        for (final v in items)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpace.sm),
            child: _Row(
              title: v.name,
              onTap: () => _openEditor(context, RegistrySection.vendors, v),
              pills: [
                StatusPill(
                  label: v.isActive ? 'نشط' : 'موقوف',
                  tone: v.isActive ? StatusPalette.success : StatusPalette.neutral,
                ),
              ],
              subtitle: [
                if (v.contactName.isNotEmpty) v.contactName,
                if (v.contactPhone.isNotEmpty) v.contactPhone,
                if (v.contactEmail.isNotEmpty) v.contactEmail,
              ].join(' · '),
            ),
          ),
    ];
  }

  List<Widget> _contracts(AppStore store) {
    final items = store.visibleContracts.toList()
      ..sort((a, b) {
        final ae = a.endDate, be = b.endDate;
        if (ae == null && be == null) return a.title.compareTo(b.title);
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });
    final today = DateTime.now();
    return [
      Text(
        'عقدٌ مرتبطٌ بمشروع يُتابَع من صفحة المشروع — ولا يُنبَّه عليه هنا كي لا يُعدّ مرّتين.',
        style: AppText.label,
      ),
      SizedBox(height: AppSpace.sm),
      if (items.isEmpty)
        const AppEmptyState(
          title: 'لا عقودَ مسجّلة',
          message: 'عقودُ الدعم والتراخيص والصيانة — وهي التي لا مشروعَ لها.',
          icon: Icons.description_outlined,
        )
      else
        for (final c in items)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpace.sm),
            child: _Row(
              title: c.title,
              onTap: () => _openEditor(context, RegistrySection.contracts, c),
              pills: [
                StatusPill(label: c.kind.label, tone: StatusPalette.neutral, dot: false),
                if (c.endDate != null)
                  StatusPill(
                    label: _endLabel(c, today),
                    tone: _endTone(c, today),
                    dot: false,
                  ),
                if (c.relatedProjectId.isNotEmpty)
                  StatusPill(label: 'عقدُ مشروع', tone: StatusPalette.info, dot: false),
              ],
              subtitle: [
                if (c.vendorName.isNotEmpty) c.vendorName,
                if (c.value != null) '${c.value} د.ك',
              ].join(' · '),
            ),
          ),
    ];
  }

  static String _endLabel(Contract c, DateTime today) {
    final left = c.endDate!.difference(today).inDays;
    if (left < 0) return 'انتهى منذ ${-left} يوماً';
    return 'ينتهي بعد $left يوماً';
  }

  static StatusTone _endTone(Contract c, DateTime today) {
    final left = c.endDate!.difference(today).inDays;
    if (left < 0) return StatusPalette.danger;
    if (left <= c.renewalNoticeDays) return StatusPalette.warning;
    return StatusPalette.success;
  }
}

class _Row extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> pills;
  final VoidCallback onTap;

  const _Row({
    required this.title,
    required this.subtitle,
    required this.pills,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: AppCard(
            shrinkToChild: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: AppSpace.xs),
                Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: pills),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: AppSpace.xs),
                  Text(subtitle,
                      style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      );
}

Future<void> _openEditor(BuildContext context, RegistrySection section, Object? existing) =>
    showDialog(
      context: context,
      builder: (_) => _RegistryEditor(section: section, existing: existing),
    );

class _RegistryEditor extends StatefulWidget {
  final RegistrySection section;
  final Object? existing;
  const _RegistryEditor({required this.section, this.existing});

  @override
  State<_RegistryEditor> createState() => _RegistryEditorState();
}

class _RegistryEditorState extends State<_RegistryEditor> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();
  AssetKind _assetKind = AssetKind.system;
  AssetStatus _assetStatus = AssetStatus.live;
  ContractKind _contractKind = ContractKind.support;
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e is ITAsset) {
      _a.text = e.name;
      _b.text = e.technology;
      _c.text = e.ownerName;
      _d.text = e.capacityUsedPercent?.toString() ?? '';
      _assetKind = e.kind;
      _assetStatus = e.status;
    } else if (e is Vendor) {
      _a.text = e.name;
      _b.text = e.contactName;
      _c.text = e.contactPhone;
      _d.text = e.contactEmail;
      _isActive = e.isActive;
    } else if (e is Contract) {
      _a.text = e.title;
      _b.text = e.vendorName;
      _c.text = e.value?.toString() ?? '';
      _d.text = '${e.renewalNoticeDays}';
      _contractKind = e.kind;
      _endDate = e.endDate;
    }
  }

  @override
  void dispose() {
    for (final c in [_a, _b, _c, _d]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.existing == null ? "إضافة" : "تعديل"} — ${widget.section.label}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...switch (widget.section) {
                RegistrySection.assets => _assetFields(),
                RegistrySection.vendors => _vendorFields(),
                RegistrySection.contracts => _contractFields(),
              },
              if (_error != null) ...[
                SizedBox(height: AppSpace.sm),
                Text(_error!, style: AppText.label.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'يُحفَظ…' : 'احفظ'),
        ),
      ],
    );
  }

  List<Widget> _assetFields() => [
        TextField(controller: _a, decoration: const InputDecoration(labelText: 'الاسم')),
        SizedBox(height: AppSpace.sm),
        DropdownButtonFormField<AssetKind>(
          initialValue: _assetKind,
          decoration: const InputDecoration(labelText: 'الصنف'),
          items: [
            for (final k in AssetKind.values) DropdownMenuItem(value: k, child: Text(k.label)),
          ],
          onChanged: (v) => setState(() => _assetKind = v ?? _assetKind),
        ),
        SizedBox(height: AppSpace.sm),
        DropdownButtonFormField<AssetStatus>(
          initialValue: _assetStatus,
          decoration: const InputDecoration(labelText: 'الحالة'),
          items: [
            for (final s in AssetStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) => setState(() => _assetStatus = v ?? _assetStatus),
        ),
        SizedBox(height: AppSpace.sm),
        TextField(
            controller: _b,
            decoration: const InputDecoration(
                labelText: 'التقنية', hintText: 'Oracle 19c · Windows Server 2022')),
        SizedBox(height: AppSpace.sm),
        TextField(
            controller: _c,
            decoration: const InputDecoration(
                labelText: 'مالكُ العمل', hintText: 'من يقرّر مصيرَ النظام لا من يشغّله')),
        SizedBox(height: AppSpace.sm),
        TextField(
          controller: _d,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'السعةُ المستهلَكة %',
            hintText: 'يُترك فارغاً إن لم تُقَس — ولا يُكتب صفراً',
          ),
        ),
      ];

  List<Widget> _vendorFields() => [
        TextField(controller: _a, decoration: const InputDecoration(labelText: 'اسم المورّد')),
        SizedBox(height: AppSpace.sm),
        TextField(controller: _b, decoration: const InputDecoration(labelText: 'جهةُ الاتصال')),
        SizedBox(height: AppSpace.sm),
        TextField(controller: _c, decoration: const InputDecoration(labelText: 'الهاتف')),
        SizedBox(height: AppSpace.sm),
        TextField(controller: _d, decoration: const InputDecoration(labelText: 'البريد')),
        SizedBox(height: AppSpace.sm),
        SwitchListTile(
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          title: const Text('نشط'),
          subtitle: const Text('والموقوفُ يبقى في السجلّ: عقودٌ قديمةٌ تحمل اسمَه'),
          contentPadding: EdgeInsets.zero,
        ),
      ];

  List<Widget> _contractFields() => [
        TextField(controller: _a, decoration: const InputDecoration(labelText: 'عنوانُ العقد')),
        SizedBox(height: AppSpace.sm),
        DropdownButtonFormField<ContractKind>(
          initialValue: _contractKind,
          decoration: const InputDecoration(labelText: 'الصنف'),
          items: [
            for (final k in ContractKind.values) DropdownMenuItem(value: k, child: Text(k.label)),
          ],
          onChanged: (v) => setState(() => _contractKind = v ?? _contractKind),
        ),
        SizedBox(height: AppSpace.sm),
        TextField(controller: _b, decoration: const InputDecoration(labelText: 'المورّد')),
        SizedBox(height: AppSpace.sm),
        TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'القيمة (د.ك)')),
        SizedBox(height: AppSpace.sm),
        TextField(
            controller: _d,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'مهلةُ التنبيه قبل الانتهاء (يوماً)', hintText: '٦٠')),
        SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _endDate == null
                    ? 'تاريخُ الانتهاء: غير محدَّد'
                    : 'ينتهي: ${_endDate!.year}/${_endDate!.month}/${_endDate!.day}',
                style: AppText.label,
              ),
            ),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? now,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 15),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
              child: const Text('اختر'),
            ),
          ],
        ),
      ];

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final me = store.currentUser;
    final e = widget.existing;
    final String? err;
    switch (widget.section) {
      case RegistrySection.assets:
        final base = e is ITAsset
            ? e
            : ITAsset(
                id: '',
                kind: _assetKind,
                name: '',
                status: _assetStatus,
                createdByUid: me?.id ?? '',
                createdAt: DateTime.now(),
              );
        err = await store.saveAsset(base.copyWith(
          name: _a.text.trim(),
          kind: _assetKind,
          status: _assetStatus,
          technology: _b.text.trim(),
          ownerName: _c.text.trim(),
          // وفارغٌ يُكتب `null` لا صفراً: «لم تُقَس» غيرُ «صفر».
          capacityUsedPercent: num.tryParse(_d.text.trim()),
        ));
      case RegistrySection.vendors:
        final base = e is Vendor
            ? e
            : Vendor(id: '', name: '', createdByUid: me?.id ?? '', createdAt: DateTime.now());
        err = await store.saveVendor(base.copyWith(
          name: _a.text.trim(),
          contactName: _b.text.trim(),
          contactPhone: _c.text.trim(),
          contactEmail: _d.text.trim(),
          isActive: _isActive,
        ));
      case RegistrySection.contracts:
        final base = e is Contract
            ? e
            : Contract(
                id: '',
                title: '',
                kind: _contractKind,
                createdByUid: me?.id ?? '',
                createdAt: DateTime.now(),
              );
        err = await store.saveContract(base.copyWith(
          title: _a.text.trim(),
          kind: _contractKind,
          vendorName: _b.text.trim(),
          value: double.tryParse(_c.text.trim()),
          renewalNoticeDays: int.tryParse(_d.text.trim()) ?? base.renewalNoticeDays,
          endDate: _endDate,
        ));
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    nav.pop();
  }
}
