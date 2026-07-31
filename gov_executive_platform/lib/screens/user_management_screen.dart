import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
                    Text('إدارة حسابات المستخدمين وصلاحياتهم على المنصة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _UserFormDialog()),
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('إضافة مستخدم'),
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
              itemBuilder: (context, i) {
                final u = users[i];
                final dept = u.departmentId != null ? store.departmentById(u.departmentId!) : null;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(u.name.substring(0, 1), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('${u.role.label}${dept != null ? ' · ${dept.name}' : ''} · ${u.username}', style: const TextStyle(fontSize: 11.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (u.active ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(u.active ? 'مفعّل' : 'موقوف',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: u.active ? AppColors.success : AppColors.textSecondary)),
                      ),
                      IconButton(
                        icon: Icon(u.active ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 19),
                        tooltip: u.active ? 'إيقاف الحساب' : 'تفعيل الحساب',
                        onPressed: () => context.read<AppStore>().toggleUserActive(u),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.projectOfficer;
  String? _departmentId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final needsDept = _role == UserRole.departmentManager || _role == UserRole.projectOfficer;

    return AlertDialog(
      title: const Text('إضافة مستخدم جديد'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 12),
              TextField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
              const SizedBox(height: 12),
              TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور')),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) return;
            if (needsDept && _departmentId == null) return;
            context.read<AppStore>().addUser(AppUser(
                  id: const Uuid().v4(),
                  name: _nameCtrl.text.trim(),
                  username: _usernameCtrl.text.trim(),
                  password: _passwordCtrl.text.trim(),
                  role: _role,
                  departmentId: needsDept ? _departmentId : null,
                ));
            Navigator.pop(context);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
