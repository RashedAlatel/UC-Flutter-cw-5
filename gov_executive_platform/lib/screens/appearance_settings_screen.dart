import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

/// شاشة إعدادات المظهر (مسؤول النظام فقط): تخصيص لوني الهوية (الأساسي
/// والتمييز) عبر لوحة ألوان مقترحة أو إدخال يدوي حر (Hex)، مع معاينة فورية
/// قبل الحفظ. القيم تُطبَّق على المنصة بالكامل فور الحفظ عبر AppColors.applyBrand.
class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  static const List<Color> _primaryPresets = [
    Color(0xFF0A3358), // الافتراضي: أزرق حكومي عميق
    Color(0xFF163A2E), // أخضر غابي داكن
    Color(0xFF5A1F1F), // عنّابي
    Color(0xFF2B2E3A), // كحلي رمادي (سليت)
    Color(0xFF0E3B3B), // أخضر مسي داكن
    Color(0xFF2C2560), // نيلي
    Color(0xFF3A1F4D), // بنفسجي داكن
    Color(0xFF4A2A16), // بنّي بندقي
    Color(0xFF123448), // أزرق بترولي
    Color(0xFF1F2937), // رمادي فحمي
  ];

  static const List<Color> _accentPresets = [
    Color(0xFFCB9B3C), // الافتراضي: ذهبي دافئ
    Color(0xFFB5732E), // نحاسي
    Color(0xFF3E7CB1), // أزرق سماوي
    Color(0xFF3F8F5F), // زمردي
    Color(0xFFAE4C4C), // وردي غامق
    Color(0xFFC97A2B), // كهرماني
    Color(0xFF2E8E8A), // تركواز
    Color(0xFF8C93A6), // فضي فولاذي
    Color(0xFFB94A34), // مرجاني
    Color(0xFF8965B3), // ليلكي
  ];

  late Color _primary = AppColors.primary;
  late Color _accent = AppColors.accent;
  late final _primaryHexCtrl = TextEditingController(text: _hex(_primary));
  late final _accentHexCtrl = TextEditingController(text: _hex(_accent));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _primaryHexCtrl.dispose();
    _accentHexCtrl.dispose();
    super.dispose();
  }

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  Color? _parseHex(String input) {
    var s = input.trim().replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }

  bool get _hasChanges => _primary.toARGB32() != AppColors.primary.toARGB32() || _accent.toARGB32() != AppColors.accent.toARGB32();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppStore>().saveBrandColors(primary: _primary, accent: _accent);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ ألوان الهوية وتطبيقها على المنصة')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر حفظ الألوان، حاول مرة أخرى.';
      });
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    await context.read<AppStore>().resetBrandColors();
    if (!mounted) return;
    setState(() {
      _primary = AppColors.defaultPrimary;
      _accent = AppColors.defaultAccent;
      _primaryHexCtrl.text = _hex(_primary);
      _accentHexCtrl.text = _hex(_accent);
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات المظهر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'اختر لوني الهوية (الأساسي والتمييز) اللذين يُطبَّقان على كل شاشات المنصة فور الحفظ.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 22),
          _LivePreview(primary: _primary, accent: _accent),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ColorPickerCard(
                  title: 'اللون الأساسي',
                  subtitle: 'الشريط الجانبي، الأزرار، العناوين الرئيسية',
                  presets: _primaryPresets,
                  value: _primary,
                  hexController: _primaryHexCtrl,
                  onSelectPreset: (c) => setState(() {
                    _primary = c;
                    _primaryHexCtrl.text = _hex(c);
                  }),
                  onHexSubmitted: (v) {
                    final c = _parseHex(v);
                    if (c != null) setState(() => _primary = c);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ColorPickerCard(
                  title: 'لون التمييز',
                  subtitle: 'الشارات، المؤشرات، عناصر التنبيه اللطيفة',
                  presets: _accentPresets,
                  value: _accent,
                  hexController: _accentHexCtrl,
                  onSelectPreset: (c) => setState(() {
                    _accent = c;
                    _accentHexCtrl.text = _hex(c);
                  }),
                  onHexSubmitted: (v) {
                    final c = _parseHex(v);
                    if (c != null) setState(() => _accent = c);
                  },
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _busy || !_hasChanges ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('حفظ وتطبيق الألوان'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('استعادة الألوان الافتراضية'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  final Color primary;
  final Color accent;
  const _LivePreview({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: primary,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('معاينة حية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('نسبة الإنجاز العام', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('٦٠٪', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text('٣ طلبات بانتظار القيادة', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: primary,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: const Text('زر أساسي'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent, width: 1.4),
                        disabledForegroundColor: accent,
                      ),
                      child: const Text('زر ثانوي'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> presets;
  final Color value;
  final TextEditingController hexController;
  final ValueChanged<Color> onSelectPreset;
  final ValueChanged<String> onHexSubmitted;

  const _ColorPickerCard({
    required this.title,
    required this.subtitle,
    required this.presets,
    required this.value,
    required this.hexController,
    required this.onSelectPreset,
    required this.onHexSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.map((c) {
                final selected = c.toARGB32() == value.toARGB32();
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelectPreset(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? AppColors.textPrimary : Colors.transparent, width: 2.4),
                      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 17) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: value, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: hexController,
                    decoration: const InputDecoration(labelText: 'كود اللون (Hex)', hintText: '#0A3358', isDense: true),
                    onSubmitted: onHexSubmitted,
                    onChanged: onHexSubmitted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
