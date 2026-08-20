import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/registration_policy.dart';
import '../theme/app_theme.dart';

/// إعدادات التسجيل الذاتي — نطاقات البريد الوزاري المقبولة.
///
/// النطاقات تُضبط هنا لا في الشيفرة: الوزارة قد تضيف نطاقاً أو تغيّره، وربط
/// ذلك ببناء جديد ونشر يعني تعطيل التسجيل حتى يفرغ المطوّر — وهو ما لا يصح
/// في منصة تشغيلية.
class RegistrationSettingsScreen extends StatefulWidget {
  const RegistrationSettingsScreen({super.key});

  @override
  State<RegistrationSettingsScreen> createState() => _RegistrationSettingsScreenState();
}

class _RegistrationSettingsScreenState extends State<RegistrationSettingsScreen> {
  final _domainCtrl = TextEditingController();
  List<String>? _domains;
  bool? _requireVerification;
  bool _saving = false;

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  List<String> _current(AppStore store) =>
      _domains ?? List<String>.from(store.registrationPolicy.allowedEmailDomains);

  bool _requireCurrent(AppStore store) =>
      _requireVerification ?? store.registrationPolicy.requireEmailVerification;

  void _add(AppStore store) {
    final domain = RegistrationPolicy.normalizeDomain(_domainCtrl.text);
    if (domain.isEmpty) return;
    final next = _current(store);
    if (next.contains(domain)) {
      _domainCtrl.clear();
      return;
    }
    setState(() {
      _domains = [...next, domain];
      _domainCtrl.clear();
    });
  }

  Future<void> _save(AppStore store) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    await store.saveRegistrationPolicy(RegistrationPolicy(
      allowedEmailDomains: _current(store),
      requireEmailVerification: _requireCurrent(store),
    ));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _domains = null;
      _requireVerification = null;
    });
    messenger.showSnackBar(const SnackBar(content: Text('حُفظت سياسة التسجيل.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final domains = _current(store);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سياسة التسجيل الذاتي',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('من يُسمح له بطلب حساب، وبأي بريد — ويبقى اعتماد كل طلب بيدك على أي حال.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نطاقات البريد المقبولة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    domains.isEmpty
                        ? 'لا نطاق محدَّد حالياً — أي بريد يُقبل في نموذج التسجيل. أضف نطاقاً لتقييد ذلك.'
                        : 'لن يُقبل في التسجيل إلا بريد ينتهي بأحد هذه النطاقات.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.8),
                  ),
                  const SizedBox(height: 14),
                  if (domains.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in domains)
                          Chip(
                            label: Text('@$d', style: const TextStyle(fontSize: 12.5)),
                            onDeleted: () => setState(() => _domains = domains.where((x) => x != d).toList()),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _domainCtrl,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'أضف نطاقاً',
                            hintText: 'moj.gov.kw',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _add(store),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _add(store),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('إضافة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: _requireCurrent(store),
              onChanged: (v) => setState(() => _requireVerification = v),
              title: const Text('اشتراط تأكيد البريد قبل عرض الطلب للاعتماد',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'يفتح الموظف رسالة تصله على بريده ويضغط رابط التأكيد. ويبقى لك استثناء أي حساب '
                'على حدة من شاشة إدارة المستخدمين.',
                style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _saving ? null : () => _save(store),
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('حفظ السياسة'),
          ),
        ],
      ),
    );
  }
}
