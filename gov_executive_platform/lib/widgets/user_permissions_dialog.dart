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
                  'تسجيل الأعضاء وتعديل المواعيد النهائية لا تُفوَّض لأحد وتبقى لمسؤول '
                  'النظام وحده. أما إضافة المشاريع فتُفوَّض من القسم أدناه بنطاق محدَّد، '
                  'ويمكن سحبها متى شئت.',
                  style: TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              if (!admin) ...[
                const Divider(height: 26),
                const Text('صلاحيات بنطاق إدارات',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 2),
                const Text(
                  'لا يرثها دور ولا تُضبط من «صلاحيات الأدوار» — تُمنح لهذا الحساب وحده، '
                  'وتسري في الإدارات التي تختارها فقط.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6),
                ),
                for (final p in RolePermission.scoped)
                  _ScopedGrantEditor(
                    permission: p,
                    user: widget.user,
                    enabled: !_busy,
                  ),
              ],
              if (!admin)
                for (final p in RolePermission.roleAssignable) ...[
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

/// محرّر منحة صلاحية بنطاق إدارات.
///
/// النطاق ليس تفصيلاً تجميلياً: مفتاحٌ بلا نطاق لا يسري على شيء، ومنحةٌ
/// بنطاق «كل الإدارات» تفتح المنصة كلها. فيُعرض الاختيار صريحاً بثلاث
/// حالات لا يخفى فرقها.
class _ScopedGrantEditor extends StatefulWidget {
  final RolePermission permission;
  final AppUser user;
  final bool enabled;

  const _ScopedGrantEditor({required this.permission, required this.user, required this.enabled});

  @override
  State<_ScopedGrantEditor> createState() => _ScopedGrantEditorState();
}

/// وضع محرِّر النطاق — **صريح لا مشتقّ من القيمة**.
///
/// وهذا هو أصل العطل: «إدارات محدَّدة ولم تُختر إدارة بعد» و«مغلقة» لهما
/// **القيمة نفسها** (`GrantScope.isEmpty`)، ومعنيان مختلفان تماماً. وكان
/// الوضع يُشتقّ من القيمة، فما إن يُختار «إدارات محدَّدة» حتى يعود الزرّ إلى
/// «مغلقة» ولا تظهر مربعات الإدارات — أي أن الخيار لا يعمل إطلاقاً.
enum _ScopeMode { closed, specific, all }

class _ScopedGrantEditorState extends State<_ScopedGrantEditor> {
  late GrantScope _scope = widget.user.scopeOf(widget.permission);
  late _ScopeMode _mode = _scope.allDepartments
      ? _ScopeMode.all
      : (_scope.departmentIds.isEmpty ? _ScopeMode.closed : _ScopeMode.specific);
  bool _busy = false;
  String? _error;

  Future<void> _save(GrantScope next) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().setScopedGrant(widget.user.id, widget.permission, next);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _scope = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final departments = store.departments;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.permission.label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text(widget.permission.description,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 0, label: Text('مغلقة')),
              ButtonSegment(value: 1, label: Text('إدارات محدَّدة')),
              ButtonSegment(value: 2, label: Text('كل الإدارات')),
            ],
            selected: {_mode.index},
            onSelectionChanged: !widget.enabled || _busy
                ? null
                : (s) {
                    final choice = _ScopeMode.values[s.first];
                    setState(() => _mode = choice);
                    if (choice == _ScopeMode.closed) {
                      _save(GrantScope.none);
                      return;
                    }
                    if (choice == _ScopeMode.all) {
                      _save(GrantScope.all);
                      return;
                    }
                    // «إدارات محدَّدة» بلا اختيار بعدُ: تُعرض المربعات ولا
                    // يُحفظ شيء حتى تُختار إدارة — فلا تُكتب منحة لا تسري.
                    setState(() => _scope = const GrantScope(departmentIds: []));
                  },
          ),
          if (_mode == _ScopeMode.specific) ...[
            const SizedBox(height: 6),
            if (_scope.departmentIds.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'اختر إدارة واحدة على الأقل — المنحة لا تسري قبل ذلك.',
                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w700),
                ),
              ),
            ...departments.map((d) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  value: _scope.departmentIds.contains(d.id),
                  title: Text(d.name, style: const TextStyle(fontSize: 12.5)),
                  onChanged: !widget.enabled || _busy
                      ? null
                      : (v) {
                          final next = List<String>.from(_scope.departmentIds);
                          if (v == true) {
                            next.add(d.id);
                          } else {
                            next.remove(d.id);
                          }
                          _save(GrantScope(departmentIds: next));
                        },
                )),
          ],
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 11.5)),
        ],
      ),
    );
  }
}
