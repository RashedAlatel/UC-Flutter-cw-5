import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/daily_report_settings.dart';
import '../theme/app_theme.dart';

/// إعدادات التقرير التنفيذي اليومي — لمسؤول النظام.
///
/// ــــ لماذا هنا لا في «إعدادات المظهر»؟ ــــ
///
/// لأن هذه هي الشاشة التي يكون فيها مسؤول النظام حين يفكّر في التقرير أصلاً.
/// وإعدادٌ يُبحث عنه في شاشةٍ أخرى إعدادٌ لا يُضبط.
///
/// وكانت هذه الإعدادات مبنيّةً في الخادم بلا شاشة إطلاقاً — تُقرأ من
/// `settings/dailyReport` ولا سبيل لضبطها إلا بتحرير قاعدة البيانات يدوياً.
/// وهي فجوة: ميزةٌ لا واجهة لها ميزةٌ لا وجود لها عملياً.
class DailyReportSettingsDialog extends StatefulWidget {
  const DailyReportSettingsDialog({super.key});

  @override
  State<DailyReportSettingsDialog> createState() => _DailyReportSettingsDialogState();
}

class _DailyReportSettingsDialogState extends State<DailyReportSettingsDialog> {
  DailyReportSettings? _settings;
  ReportEmailMode _mode = ReportEmailMode.everyone;
  Set<String> _chosen = {};
  String? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<AppStore>().loadDailyReportSettings();
      if (!mounted) return;
      final myUid = context.read<AppStore>().currentUser?.id;
      setState(() {
        _settings = s;
        _mode = s.modeFor(myUid);
        _chosen = s.emailRecipientUids.toSet();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  /// القائمة التي ستُكتب فعلاً — مشتقّةٌ من الوضع المختار.
  ///
  /// و«الجميع» قائمةٌ **فارغة** لا قائمةٌ بكل الأسماء: لو كُتبت بالأسماء
  /// لَتجمّدت عند لحظة الحفظ، فلا يصل البريد من يُعيَّن غداً — وهو حصرٌ
  /// لم يقصده أحد.
  List<String> _uidsFor(String? myUid) => switch (_mode) {
        ReportEmailMode.everyone => const [],
        ReportEmailMode.meOnly => myUid == null ? const [] : [myUid],
        ReportEmailMode.chosen => _chosen.toList(),
      };

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final uids = _uidsFor(store.currentUser?.id);
    if (_mode == ReportEmailMode.chosen && uids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر مستلماً واحداً على الأقل، أو اختر «كل من له مدخل التقرير».'),
      ));
      return;
    }
    setState(() => _saving = true);
    final error = await store.saveDailyReportSettings(
      _settings!.copyWith(emailRecipientUids: uids),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (_mode) {
        ReportEmailMode.everyone => 'يصل بريد التقرير كل من له مدخل «التقرير اليومي».',
        ReportEmailMode.meOnly => 'حُصر بريد التقرير بك وحدك.',
        ReportEmailMode.chosen => 'حُصر بريد التقرير بـ${uids.length} مستلماً.',
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = _settings;

    return AlertDialog(
      title: const Text('إعدادات التقرير التنفيذي اليومي'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: _loadError != null
              ? _Note(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                  text: 'تعذّرت قراءة الإعدادات:\n$_loadError',
                )
              : s == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: s.enabled,
                          onChanged: (v) =>
                              setState(() => _settings = s.copyWith(enabled: v)),
                          title: const Text('توليد التقرير الساعة السابعة صباحاً'),
                          subtitle: const Text(
                            'إيقافه يوقف الشاشة والبريد معاً.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: s.emailEnabled,
                          onChanged: s.enabled
                              ? (v) => setState(
                                  () => _settings = s.copyWith(emailEnabled: v))
                              : null,
                          title: const Text('إرسال التقرير بالبريد'),
                          subtitle: const Text(
                            'إطفاؤه يُبقي التقرير على الشاشة بلا رسائل.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const Divider(height: 24),
                        const Text('من يصله البريد؟',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpace.xs),
                        // الجملة التي تمنع انتظار رسالةٍ لن تأتي.
                        const _Note(
                          icon: Icons.info_outline_rounded,
                          color: AppColors.info,
                          text: 'لا يصل البريد إلا من يُولَّد له تقرير — أي المستوى '
                              'الإشرافي: مسؤول النظام، والمسؤول التنفيذي، ومدير '
                              'الإدارة، ومن يقود مشروعاً فعلاً.',
                        ),
                        const SizedBox(height: AppSpace.sm),
                        for (final entry in const [
                          (ReportEmailMode.everyone, 'كل من له مدخل التقرير',
                              'السلوك المبدئي.'),
                          (ReportEmailMode.meOnly, 'أنا وحدي',
                              'لتجربة التقرير قبل فتحه للناس.'),
                          (ReportEmailMode.chosen, 'أشخاص محدَّدون',
                              'اختر الأسماء من القائمة أدناه.'),
                        ])
                          // `ListTile` بأيقونة اختيار لا `RadioListTile`:
                          // الأخيرة صار `groupValue`/`onChanged` فيها
                          // مهجورَين، وبديلُهما `RadioGroup` يلفّ الأبناء —
                          // وهو أثقل من أن يُلفّ به صفٌّ واحد داخل عمود.
                          _ModeTile(
                            selected: _mode == entry.$1,
                            enabled: s.enabled && s.emailEnabled,
                            title: entry.$2,
                            subtitle: entry.$3,
                            onTap: () => setState(() => _mode = entry.$1),
                          ),
                        if (_mode == ReportEmailMode.chosen) ...[
                          const SizedBox(height: AppSpace.xs),
                          _RecipientPicker(
                            // كل المعتمَدين، ولا يُصفَّون إلى «المستوى
                            // الإشرافي» هنا: تلك قاعدةٌ يحسبها الخادم
                            // (`scopesFor`)، وإعادةُ حسابها في العميل تعني
                            // نسختين تفترقان. والملاحظة أعلاه تقول لمن
                            // يختار إن كان اختياره سيصله بريدٌ أم لا.
                            users: store.users
                                .where((u) => u.status == UserStatus.approved)
                                .toList(),
                            chosen: _chosen,
                            onToggle: (uid) => setState(() {
                              _chosen.contains(uid)
                                  ? _chosen.remove(uid)
                                  : _chosen.add(uid);
                            }),
                          ),
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
          onPressed: (s == null || _saving) ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}

/// صفُّ اختيارٍ واحد — مظهر زرّ الاختيار بلا واجهته المهجورة.
class _ModeTile extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textSecondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? color : AppColors.textSecondary,
        size: 20,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
    );
  }
}

class _RecipientPicker extends StatelessWidget {
  final List<AppUser> users;
  final Set<String> chosen;
  final void Function(String uid) onToggle;

  const _RecipientPicker({
    required this.users,
    required this.chosen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: users.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpace.md),
              child: Text('لا يوجد مستخدمون معتمَدون.'),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final u in users)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: chosen.contains(u.id),
                    onChanged: (_) => onToggle(u.id),
                    title: Text(u.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${u.role.label} · ${u.email}',
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Note({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.7))),
        ],
      ),
    );
  }
}
