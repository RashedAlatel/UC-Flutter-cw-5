import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/role_permissions.dart';
import '../theme/app_theme.dart';

/// شاشة ضبط صلاحيات الأدوار الأساسية (مسؤول النظام فقط).
///
/// بعد الحفظ تُعاد كتابة بصمات الصلاحيات على كل حسابات الدور عبر Cloud
/// Function، وإلا بقي التعديل في الواجهة فقط دون أثر على الخادم.
class RolePermissionsScreen extends StatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  State<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  RolePermissionsConfig? _draft;
  bool _busy = false;
  String? _status;

  RolePermissionsConfig _current(AppStore store) => _draft ?? store.rolePermissions;

  bool get _dirty => _draft != null;

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await store.saveRolePermissions(draft);
      // تطبيق فوري على كل مستخدمي الأدوار الأربعة.
      var total = 0;
      final failures = <String>[];
      for (final role in UserRole.configurable) {
        final res = await store.applyRolePermissions(role);
        total += res.updated;
        if (res.error != null) failures.add('${role.label}: ${res.error}');
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _draft = null;
        _status = failures.isEmpty
            ? 'تم الحفظ وتحديث $total حساباً — يسري على كل مستخدم عند إعادة دخوله.'
            : 'تم الحفظ، لكن تعذر تحديث بعض الحسابات:\n${failures.join('\n')}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'تعذر الحفظ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final config = _current(store);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('صلاحيات الأدوار',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('حدّد ما يستطيع كل دور فعله في المنصة. مسؤول النظام يملك كل الصلاحيات دائماً.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 16),

          // قيد ثابت يجب أن يبقى ظاهراً للمسؤول حتى لا يبحث عنه بين المفاتيح.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'اعتماد تسجيل الأعضاء، وإضافة المشاريع، وتعديل المواعيد النهائية — ثلاث صلاحيات '
                      'محصورة بمسؤول النظام ولا يمكن منحها لأي دور آخر، حمايةً لبوابات الاعتماد.',
                      style: TextStyle(fontSize: 12, height: 1.7, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          ...UserRole.configurable.map((role) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_roleIcon(role), size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(role.label,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                            const Spacer(),
                            Text('${store.users.where((u) => u.role == role).length} حساب',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ],
                        ),
                        const Divider(height: 22),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${RolePermission.baseline.map((p) => '«${p.label}»').join(' و')} '
                            'حقٌّ لكل حساب معتمد لا يحتاج منحاً. ولسحبه من موظف بعينه '
                            'افتح «المستخدمون» ← صلاحيات المستخدم.',
                            style: const TextStyle(fontSize: 11, height: 1.7, color: AppColors.textSecondary),
                          ),
                        ),
                        // الحقوق الأساسية خارج الشبكة: مفتاحٌ لا أثر له يخدع
                        // أكثر مما يفيد — يظنّه مسؤول النظام هو ما يمنع
                        // الميزة، فيقلّبه بلا نتيجة.
                        ...RolePermission.roleAssignable.map((p) => SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: config.has(role, p),
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() => _draft = config.toggled(role, p, v)),
                              title: Text(p.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              subtitle: Text(p.description,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
                            )),
                      ],
                    ),
                  ),
                ),
              )),

          if (_status != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_status!, style: const TextStyle(fontSize: 12, height: 1.7, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: (!_dirty || _busy) ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_busy ? 'جارٍ التطبيق على الحسابات...' : 'حفظ وتطبيق على المستخدمين'),
              ),
              if (_dirty && !_busy) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _draft = null),
                  child: const Text('تراجع عن التغييرات'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.executiveViewer:
        return Icons.visibility_outlined;
      case UserRole.departmentManager:
        return Icons.account_balance_rounded;
      case UserRole.projectOfficer:
        return Icons.folder_copy_rounded;
      case UserRole.employee:
        return Icons.badge_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }
}
