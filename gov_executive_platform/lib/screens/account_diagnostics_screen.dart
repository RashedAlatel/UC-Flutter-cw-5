import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/role_permissions.dart';
import '../theme/app_theme.dart';

/// «تشخيص حسابي» — سجلّ المستخدم مقابل بطاقة دخوله.
///
/// قواعد Firestore كلها تبدأ من `isApproved()`، وهي تقرأ
/// `request.auth.token.approved` — أي بصمة في **بطاقة الدخول**، لا الحقل
/// الموجود في سجل المستخدم. بينما التطبيق يقرّر دخول المستخدم من السجل. فحساب
/// سجلّه يقول «معتمد» وبطاقته لا تحمل البصمة يدخل المنصة ثم يجد كل شيء
/// فارغاً — لا مشاريعه ولا حتى التعميمات العامة — بلا أي رسالة تشرح السبب.
///
/// هذه الشاشة تضع الاثنين جنباً إلى جنب وتُبرز الاختلاف، فيراه المستخدم
/// بنفسه ويصلحه بضغطة، أو يصوّرها ويرسلها. لقطة واحدة بدل جولة أسئلة.
class AccountDiagnosticsScreen extends StatefulWidget {
  const AccountDiagnosticsScreen({super.key});

  @override
  State<AccountDiagnosticsScreen> createState() => _AccountDiagnosticsScreenState();
}

class _AccountDiagnosticsScreenState extends State<AccountDiagnosticsScreen> {
  Map<String, dynamic>? _claims;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final store = context.read<AppStore>();
    try {
      final claims = await store.currentTokenClaims(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await store.syncMyClaims();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load(forceRefresh: true);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'تمت مزامنة صلاحيات حسابك. حدِّث الصفحة إن لم تظهر بياناتك.'),
      duration: const Duration(seconds: 8),
    ));
  }

  String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is List) return v.isEmpty ? '(فارغة)' : v.join('، ');
    if (v is Map) return v.isEmpty ? '(فارغة)' : v.entries.map((e) => '${e.key}=${e.value}').join('، ');
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final claims = _claims ?? const {};

    final rows = <_DiagRow>[
      _DiagRow('الدور', user?.role.name, claims['role']),
      _DiagRow('الاعتماد', user?.status.name == 'approved', claims['approved'] == true),
      _DiagRow('الإدارة (مفرد)', user?.departmentId, claims['departmentId']),
      _DiagRow('الإدارات (قائمة)', user?.departmentIds ?? const [],
          (claims['departmentIds'] as List?)?.map((e) => e.toString()).toList() ?? const []),
    ];

    final mismatched = rows.where((r) => !r.matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تشخيص حسابي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    _Note(
                      color: AppColors.danger,
                      icon: Icons.error_outline_rounded,
                      title: 'تعذّرت قراءة بطاقة الدخول',
                      body: _error!,
                    )
                  else if (mismatched.isEmpty)
                    const _Note(
                      color: AppColors.success,
                      icon: Icons.verified_rounded,
                      title: 'سجلّك وبطاقة دخولك متطابقان',
                      body: 'إن كانت بياناتك لا تظهر رغم ذلك، فالسبب ليس في صلاحيات الحساب — '
                          'راجع لافتة الخطأ أعلى المنصة، فهي تسمّي البيانات التي رُفضت قراءتها.',
                    )
                  else
                    _Note(
                      color: AppColors.danger,
                      icon: Icons.report_problem_rounded,
                      title: 'بطاقة دخولك لا تطابق سجلّك',
                      body: 'قواعد الحماية على الخادم تحتكم إلى بطاقة الدخول لا إلى السجل، '
                          'ولهذا لا تظهر لك بياناتك. اضغط «مزامنة صلاحيات حسابي» أدناه — '
                          'المزامنة تنسخ ما سجّله مسؤول النظام لك ولا تمنحك شيئاً إضافياً.',
                    ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(flex: 4, child: Text('البند', style: _head)),
                              const Expanded(flex: 4, child: Text('في سجلّك', style: _head)),
                              const Expanded(flex: 4, child: Text('في بطاقة دخولك', style: _head)),
                              const SizedBox(width: 26),
                            ],
                          ),
                          const Divider(height: 18),
                          for (final r in rows) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: Text(r.label, style: const TextStyle(fontSize: 13))),
                                  Expanded(flex: 4, child: Text(_fmt(r.inDoc), style: _value)),
                                  Expanded(flex: 4, child: Text(_fmt(r.inToken), style: _value)),
                                  SizedBox(
                                    width: 26,
                                    child: Icon(
                                      r.matches ? Icons.check_rounded : Icons.close_rounded,
                                      size: 18,
                                      color: r.matches ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (r != rows.last) const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _syncing ? null : _sync,
                        icon: _syncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('مزامنة صلاحيات حسابي'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : () => _load(forceRefresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة الفحص'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _report(store, claims)));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('نُسخت التفاصيل — أرسلها لمسؤول النظام.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('نسخ التفاصيل'),
                      ),
                    ],
                  ),
                  // الصلاحيات: ما تقوله إعدادات دورك مقابل ما تحمله بطاقتك.
                  // غياب هذا القسم هو ما جعل «منحتُ الصلاحية ولا تعمل» سؤالاً
                  // بلا جواب — والقواعد تحتكم إلى البطاقة لا إلى الإعدادات.
                  if (!store.isAdmin) ...[
                    const SizedBox(height: 24),
                    const Text('الصلاحيات',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Expanded(flex: 7, child: Text('الصلاحية', style: _head)),
                                Expanded(flex: 3, child: Text('في إعدادات دورك', style: _head)),
                                Expanded(flex: 3, child: Text('في بطاقتك', style: _head)),
                              ],
                            ),
                            const Divider(height: 18),
                            for (final p in RolePermission.values)
                              _permRow(
                                p,
                                store.hasPermission(p),
                                store.tokenPermissionKeys(claims).contains(p.key),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (store.hasDataErrors) ...[
                    const SizedBox(height: 24),
                    const Text('بيانات رُفضت قراءتها',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in store.dataErrors.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: SelectableText('${e.key}: ${e.value}',
                                    style: const TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textSecondary)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _permRow(RolePermission p, bool inSettings, bool inToken) {
    final agree = inSettings == inToken;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: Text(p.label, style: const TextStyle(fontSize: 12.5))),
          Expanded(flex: 3, child: Text(inSettings ? 'ممنوحة' : '—', style: _value)),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(inToken ? 'موجودة' : '—', style: _value),
                const SizedBox(width: 6),
                if (!agree)
                  const Icon(Icons.priority_high_rounded, size: 15, color: AppColors.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _report(AppStore store, Map<String, dynamic> claims) {
    final u = store.currentUser;
    return [
      'الحساب: ${u?.email ?? '—'}',
      'السجل: role=${u?.role.name} status=${u?.status.name} dept=${u?.departmentId} depts=${u?.departmentIds}',
      'البطاقة: role=${claims['role']} approved=${claims['approved']} '
          'dept=${claims['departmentId']} depts=${claims['departmentIds']} perms=${claims['perms']}',
      if (store.hasDataErrors) 'رُفضت: ${store.dataErrors.entries.map((e) => '${e.key} → ${e.value}').join(' | ')}',
    ].join('\n');
  }
}

const _head = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary);
const _value = TextStyle(fontSize: 12.5);

class _DiagRow {
  final String label;
  final Object? inDoc;
  final Object? inToken;
  const _DiagRow(this.label, this.inDoc, this.inToken);

  bool get matches {
    final a = inDoc, b = inToken;
    if (a is List && b is List) {
      return a.length == b.length && a.map((e) => e.toString()).toSet().containsAll(b.map((e) => e.toString()));
    }
    // السجل قد يحمل قيمة فارغة والبطاقة null — وهما متساويان عملياً.
    final an = (a == null || a == '') ? null : a;
    final bn = (b == null || b == '') ? null : b;
    return an == bn;
  }
}

class _Note extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  const _Note({required this.color, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
