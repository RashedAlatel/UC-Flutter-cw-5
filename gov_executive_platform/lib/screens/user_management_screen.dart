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
                    Text('إدارة حسابات المستخدمين وصلاحياتهم، وإرسال إشعارات عبر البريد وواتساب', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
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

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(u.name.isNotEmpty ? u.name.substring(0, 1) : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      ),
      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text('${u.role.label}${dept != null ? ' · ${dept.name}' : ''} · ${u.email}', style: const TextStyle(fontSize: 11.5)),
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
            icon: const Icon(Icons.mail_outline_rounded, size: 19),
            tooltip: 'إرسال إشعار',
            onPressed: () => showDialog(context: context, builder: (_) => _NotifyDialog(user: u)),
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

class _NotifyDialog extends StatefulWidget {
  final AppUser user;
  const _NotifyDialog({required this.user});

  @override
  State<_NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<_NotifyDialog> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  NotifyChannel _channel = NotifyChannel.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء كتابة نص الرسالة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().sendUserNotification(
          user: widget.user,
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إرسال إشعار إلى ${widget.user.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
  String? _departmentId;
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
    final needsDept = _role == UserRole.departmentManager || _role == UserRole.projectOfficer;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء تعبئة جميع الحقول');
      return;
    }
    if (needsDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
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
          departmentId: needsDept ? _departmentId : null,
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
    final store = context.watch<AppStore>();
    final needsDept = _role == UserRole.departmentManager || _role == UserRole.projectOfficer;

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
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              if (needsDept) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'الإدارة'),
                  items: store.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
              ],
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
