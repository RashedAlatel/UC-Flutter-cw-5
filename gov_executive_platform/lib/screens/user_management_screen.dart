import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final users = store.users;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة المستخدمين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('إدارة حسابات المستخدمين وأدوارهم، وإرسال إشعارات عبر البريد وواتساب', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _NotifyDialog(initialUsers: [])),
                icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                label: const Text('إشعار جماعي'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _UserFormDialog()),
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('إضافة مستخدم مباشرة'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _UserRow(user: users[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  final AppUser user;
  const _UserRow({required this.user});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _busy = false;

  Future<void> _toggleStatus() async {
    setState(() => _busy = true);
    final target = widget.user.status == UserStatus.approved ? UserStatus.suspended : UserStatus.approved;
    final error = await context.read<AppStore>().setUserStatus(widget.user, target);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final store = context.watch<AppStore>();
    final dept = u.departmentId != null ? store.departmentById(u.departmentId!) : null;
    final active = u.status == UserStatus.approved;
    final roleLabel = u.role == UserRole.custom
        ? (store.customRoles.where((r) => r.id == u.customRoleId).isEmpty
            ? 'دور مخصص'
            : store.customRoles.firstWhere((r) => r.id == u.customRoleId).name)
        : u.role.label;
    final deptLabel = u.role == UserRole.departmentManager
        ? u.departmentIds.map((id) => store.departmentById(id)?.name).whereType<String>().join('، ')
        : dept?.name;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(u.name.isNotEmpty ? u.name.substring(0, 1) : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      ),
      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text(
        '$roleLabel${(deptLabel != null && deptLabel.isNotEmpty) ? ' · $deptLabel' : ''} · ${u.email}',
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (active ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(u.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? AppColors.success : AppColors.textSecondary)),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 19),
            tooltip: 'تعديل الدور',
            onPressed: () => showDialog(context: context, builder: (_) => _EditRoleDialog(user: u)),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded, size: 19),
            tooltip: 'إرسال إشعار',
            onPressed: () => showDialog(context: context, builder: (_) => _NotifyDialog(initialUsers: [u])),
          ),
          if (u.status == UserStatus.approved || u.status == UserStatus.suspended)
            IconButton(
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(active ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 19),
              tooltip: active ? 'إيقاف الحساب' : 'إعادة التفعيل',
              onPressed: _busy ? null : _toggleStatus,
            ),
        ],
      ),
    );
  }
}

/// إرسال إشعار (بريد و/أو واتساب) لمستخدم واحد (عبر زر الصف) أو لعدة
/// مستخدمين دفعة واحدة (عبر زر "إشعار جماعي" أعلى الشاشة).
class _NotifyDialog extends StatefulWidget {
  final List<AppUser> initialUsers;
  const _NotifyDialog({required this.initialUsers});

  @override
  State<_NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<_NotifyDialog> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  NotifyChannel _channel = NotifyChannel.email;
  late final Set<String> _selectedUids = widget.initialUsers.map((u) => u.id).toSet();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedUids.isEmpty) {
      setState(() => _error = 'الرجاء اختيار مستلم واحد على الأقل');
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء كتابة نص الرسالة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final recipients = store.users.where((u) => _selectedUids.contains(u.id)).toList();
    final error = await store.sendUserNotification(
          users: recipients,
          channel: _channel,
          subject: _subjectCtrl.text.trim().isEmpty ? 'إشعار من المنصة التنفيذية' : _subjectCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال الإشعار إلى ${recipients.length} مستخدم(ين) بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final single = widget.initialUsers.length == 1;
    return AlertDialog(
      title: Text(single ? 'إرسال إشعار إلى ${widget.initialUsers.first.name}' : 'إرسال إشعار جماعي'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!single) ...[
                const Text('المستلمون', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                  child: SingleChildScrollView(
                    child: Column(
                      children: store.users
                          .map((u) => CheckboxListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                value: _selectedUids.contains(u.id),
                                title: Text(u.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                subtitle: Text(u.email, style: const TextStyle(fontSize: 10.5)),
                                onChanged: (v) => setState(() {
                                  if (v ?? false) {
                                    _selectedUids.add(u.id);
                                  } else {
                                    _selectedUids.remove(u.id);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<NotifyChannel>(
                initialValue: _channel,
                decoration: const InputDecoration(labelText: 'قناة الإرسال'),
                items: NotifyChannel.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (v) => setState(() => _channel = v ?? _channel),
              ),
              const SizedBox(height: 12),
              if (_channel != NotifyChannel.whatsapp)
                TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'عنوان البريد (اختياري)')),
              const SizedBox(height: 12),
              TextField(controller: _messageCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'نص الرسالة')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إرسال'),
        ),
      ],
    );
  }
}

/// عناصر نموذج الدور المشتركة بين "إضافة مستخدم" و"تعديل الدور": يعرض
/// الأدوار الأساسية الأربعة + الأدوار المخصصة المُعرَّفة من مسؤول النظام.
class _RoleFields extends StatelessWidget {
  final UserRole role;
  final String? customRoleId;
  final String? departmentId;
  final List<String> departmentIds;
  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<String?> onCustomRoleChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<List<String>> onDepartmentIdsChanged;

  const _RoleFields({
    required this.role,
    required this.customRoleId,
    required this.departmentId,
    required this.departmentIds,
    required this.onRoleChanged,
    required this.onCustomRoleChanged,
    required this.onDepartmentChanged,
    required this.onDepartmentIdsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isManagerRole = role == UserRole.departmentManager;
    final needsSingleDept = role == UserRole.projectOfficer;
    final isCustom = role == UserRole.custom;
    final selectableRoles = UserRole.values.where((r) => r != UserRole.custom || store.customRoles.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<UserRole>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'الدور'),
          items: selectableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
          onChanged: (v) => onRoleChanged(v ?? role),
        ),
        if (isCustom) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: customRoleId,
            decoration: const InputDecoration(labelText: 'الدور المخصص'),
            items: store.customRoles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
            onChanged: onCustomRoleChanged,
          ),
        ],
        if (needsSingleDept || isCustom) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: departmentId,
            decoration: InputDecoration(labelText: isCustom ? 'الإدارة (اختياري)' : 'الإدارة'),
            items: store.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
            onChanged: onDepartmentChanged,
          ),
        ],
        // مدير الإدارة قد يدير أكثر من إدارة واحدة، لذا يُختار له بمربعات
        // اختيار متعددة بدل قائمة منسدلة بخيار واحد.
        if (isManagerRole) ...[
          const SizedBox(height: 12),
          const Text('الإدارات (يمكن اختيار أكثر من إدارة)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(
              child: Column(
                children: store.departments
                    .map((d) => CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          value: departmentIds.contains(d.id),
                          title: Text(d.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          onChanged: (v) {
                            final next = List<String>.from(departmentIds);
                            if (v ?? false) {
                              next.add(d.id);
                            } else {
                              next.remove(d.id);
                            }
                            onDepartmentIdsChanged(next);
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EditRoleDialog extends StatefulWidget {
  final AppUser user;
  const _EditRoleDialog({required this.user});

  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  late UserRole _role = widget.user.role;
  late String? _customRoleId = widget.user.customRoleId;
  late String? _departmentId = widget.user.departmentId;
  late List<String> _departmentIds = List<String>.from(widget.user.departmentIds);
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final isManagerRole = _role == UserRole.departmentManager;
    final needsSingleDept = _role == UserRole.projectOfficer;
    if (needsSingleDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    if (isManagerRole && _departmentIds.isEmpty) {
      setState(() => _error = 'الرجاء اختيار إدارة واحدة على الأقل');
      return;
    }
    if (_role == UserRole.custom && _customRoleId == null) {
      setState(() => _error = 'الرجاء اختيار الدور المخصص');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().setUserRole(
          widget.user,
          role: _role,
          customRoleId: _role == UserRole.custom ? _customRoleId : null,
          departmentId: (needsSingleDept || _role == UserRole.custom) ? _departmentId : null,
          departmentIds: isManagerRole ? _departmentIds : null,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث دور المستخدم')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل دور ${widget.user.name}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoleFields(
                role: _role,
                customRoleId: _customRoleId,
                departmentId: _departmentId,
                departmentIds: _departmentIds,
                onRoleChanged: (v) => setState(() => _role = v),
                onCustomRoleChanged: (v) => setState(() => _customRoleId = v),
                onDepartmentChanged: (v) => setState(() => _departmentId = v),
                onDepartmentIdsChanged: (v) => setState(() => _departmentIds = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog();

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.projectOfficer;
  String? _customRoleId;
  String? _departmentId;
  List<String> _departmentIds = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isManagerRole = _role == UserRole.departmentManager;
    final needsSingleDept = _role == UserRole.projectOfficer;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء تعبئة جميع الحقول');
      return;
    }
    if (needsSingleDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    if (isManagerRole && _departmentIds.isEmpty) {
      setState(() => _error = 'الرجاء اختيار إدارة واحدة على الأقل');
      return;
    }
    if (_role == UserRole.custom && _customRoleId == null) {
      setState(() => _error = 'الرجاء اختيار الدور المخصص');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().adminCreateUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          role: _role,
          customRoleId: _role == UserRole.custom ? _customRoleId : null,
          departmentId: (needsSingleDept || _role == UserRole.custom) ? _departmentId : null,
          departmentIds: isManagerRole ? _departmentIds : null,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مستخدم مباشرة (بدون طلب تسجيل)'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 12),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال (لواتساب)', hintText: '+9715xxxxxxxx')),
              const SizedBox(height: 12),
              TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور المبدئية')),
              const SizedBox(height: 12),
              _RoleFields(
                role: _role,
                customRoleId: _customRoleId,
                departmentId: _departmentId,
                departmentIds: _departmentIds,
                onRoleChanged: (v) => setState(() => _role = v),
                onCustomRoleChanged: (v) => setState(() => _customRoleId = v),
                onDepartmentChanged: (v) => setState(() => _departmentId = v),
                onDepartmentIdsChanged: (v) => setState(() => _departmentIds = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إضافة'),
        ),
      ],
    );
  }
}
