import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/role_permissions.dart';
import '../theme/app_theme.dart';

/// صلاحيات **فردية** لمستخدم بعينه، تعلو على إعدادات دوره.
///
/// شاشة «صلاحيات الأدوار» تمنح الدور كله؛ وهذه تمنح أو تمنع شخصاً واحداً
/// دون المساس بزملائه ولا بتغيير دوره. ولكل صلاحية ثلاث حالات لا اثنتان:
/// **يتبع دوره** (لا استثناء)، أو **ممنوحة**، أو **ممنوعة** — والفرق بين
/// «يتبع دوره وهي مغلقة» و«ممنوعة صراحةً» فرقٌ حقيقي: الأولى تنفتح تلقائياً
/// إن مُنحت للدور لاحقاً، والثانية تبقى مغلقة عليه وحده.
class UserPermissionsDialog extends StatefulWidget {
  final AppUser user;
  const UserPermissionsDialog({super.key, required this.user});

  @override
  State<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

enum _Choice { inherit, granted, denied }

class _UserPermissionsDialogState extends State<UserPermissionsDialog> {
  late final Map<String, bool> _overrides = Map<String, bool>.from(widget.user.permissionOverrides);
  bool _busy = false;
  String? _error;

  _Choice _choiceOf(RolePermission p) {
    final value = _overrides[p.key];
    if (value == null) return _Choice.inherit;
    return value ? _Choice.granted : _Choice.denied;
  }

  void _set(RolePermission p, _Choice choice) {
    setState(() {
      switch (choice) {
        case _Choice.inherit:
          _overrides.remove(p.key);
        case _Choice.granted:
          _overrides[p.key] = true;
        case _Choice.denied:
          _overrides[p.key] = false;
      }
    });
  }

  /// ما يمنحه دور المستخدم لولا الاستثناء — يُعرض بجانب كل صلاحية حتى يعرف
  /// مسؤول النظام ما الذي يغيّره فعلاً بدل أن يمنح ما هو ممنوح.
  bool _roleGrants(AppStore store, RolePermission p) {
    if (widget.user.role == UserRole.systemAdmin) return true;
    if (widget.user.role == UserRole.custom) {
      final matches = store.customRoles.where((r) => r.id == widget.user.customRoleId);
      if (matches.isEmpty) return false;
      final r = matches.first;
      switch (p) {
        case RolePermission.viewAllDepartments:
          return r.viewAllDepartments;
        case RolePermission.manageReports:
          return r.manageReports;
        case RolePermission.manageDashboard:
          return r.manageDashboard;
        case RolePermission.approveGeneralDecisions:
          return r.approveGeneralDecisions;
        case RolePermission.selfAssignProjects:
          return r.selfAssignProjects;
        default:
          return false;
      }
    }
    return store.rolePermissions.has(widget.user.role, p);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().setPermissionOverrides(widget.user.id, _overrides);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final admin = widget.user.role == UserRole.systemAdmin;

    return AlertDialog(
      title: Text('صلاحيات ${widget.user.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                admin
                    ? 'هذا الحساب مسؤول نظام، وصلاحياته كاملة دائماً ولا تُقيَّد من هنا.'
                    : 'استثناءات تخصّ هذا الحساب وحده وتعلو على إعدادات دوره '
                        '(${widget.user.role.label}). «يتبع دوره» تعني بلا استثناء.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
              ),
              const SizedBox(height: 8),
              // القيد الثابت يُذكر هنا أيضاً: هذه الشاشة أقرب مكان يبحث فيه
              // مسؤول النظام عن تفويض الاعتماد، فيجب أن يجد الجواب لا الفراغ.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'تسجيل الأعضاء وإضافة المشاريع وتعديل المواعيد النهائية لا تُفوَّض لأحد، '
                  'وتبقى لمسؤول النظام وحده.',
                  style: TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              if (!admin)
                for (final p in RolePermission.values) ...[
                  const Divider(height: 22),
                  Text(p.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(p.description,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 8),
                  SegmentedButton<_Choice>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(
                        value: _Choice.inherit,
                        label: Text(_roleGrants(store, p) ? 'يتبع دوره (ممنوحة)' : 'يتبع دوره (مغلقة)'),
                      ),
                      const ButtonSegment(value: _Choice.granted, label: Text('ممنوحة')),
                      const ButtonSegment(value: _Choice.denied, label: Text('ممنوعة')),
                    ],
                    selected: {_choiceOf(p)},
                    onSelectionChanged: _busy ? null : (s) => _set(p, s.first),
                  ),
                ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        if (!admin)
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ'),
          ),
      ],
    );
  }
}
