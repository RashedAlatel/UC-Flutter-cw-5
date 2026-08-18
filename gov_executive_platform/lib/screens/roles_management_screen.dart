import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../models/custom_role.dart';
import '../theme/app_theme.dart';

/// شاشة إدارة الأدوار المخصصة (مسؤول النظام فقط): إنشاء/تعديل/حذف أدوار
/// بمجموعة صلاحيات يختارها بنفسه، إضافة إلى الأدوار الأساسية الأربعة الثابتة.
/// لا تمنح أي صلاحية مخصصة القدرة على اعتماد بوابات الموافقة الثلاث
/// (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي) — تبقى حصراً لمسؤول النظام.
class RolesManagementScreen extends StatelessWidget {
  const RolesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

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
                    Text('إدارة الأدوار', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text(
                      'أدوار مخصصة إضافية بصلاحيات تختارها بنفسك. بوابات الموافقة الثلاث (تسجيل الأعضاء، المشاريع، المواعيد النهائية) تبقى دائماً حصراً لمسؤول النظام.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _RoleFormDialog()),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة دور'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (store.customRoles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد أدوار مخصصة بعد', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...store.customRoles.map((role) => _RoleCard(role: role)),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final CustomRole role;
  const _RoleCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final perms = <String>[
      if (role.viewAllDepartments) 'عرض كل الإدارات',
      if (role.manageReports) 'توليد وتحرير التقارير',
      if (role.manageDashboard) 'تخصيص لوحة القيادة',
      if (role.approveGeneralDecisions) 'اعتماد القرارات التنفيذية العامة',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.badge_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  perms.isEmpty
                      ? const Text('لا توجد صلاحيات إضافية مفعّلة', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: perms
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                                    child: Text(p, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                  ))
                              .toList(),
                        ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textSecondary),
              onPressed: () => showDialog(context: context, builder: (_) => _RoleFormDialog(existing: role)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
              onPressed: () => _confirmDelete(context, role),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomRole role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدور'),
        content: Text('هل تريد حذف الدور "${role.name}"؟ المستخدمون المعيّنون على هذا الدور سيفقدون صلاحياته الإضافية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<AppStore>().deleteCustomRole(role);
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _RoleFormDialog extends StatefulWidget {
  final CustomRole? existing;
  const _RoleFormDialog({this.existing});

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late bool _viewAllDepartments = widget.existing?.viewAllDepartments ?? false;
  late bool _manageReports = widget.existing?.manageReports ?? false;
  late bool _manageDashboard = widget.existing?.manageDashboard ?? false;
  late bool _approveGeneralDecisions = widget.existing?.approveGeneralDecisions ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم الدور');
      return;
    }
    setState(() => _busy = true);
    await context.read<AppStore>().saveCustomRole(CustomRole(
          id: widget.existing?.id ?? const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          viewAllDepartments: _viewAllDepartments,
          manageReports: _manageReports,
          manageDashboard: _manageDashboard,
          approveGeneralDecisions: _approveGeneralDecisions,
        ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة دور مخصص' : 'تعديل الدور'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الدور')),
              const SizedBox(height: 14),
              const Text('الصلاحيات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('عرض كل الإدارات (مثل المستخدم التنفيذي)', style: TextStyle(fontSize: 12.5)),
                value: _viewAllDepartments,
                onChanged: (v) => setState(() => _viewAllDepartments = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('توليد التقارير وتحرير التعليقات عليها', style: TextStyle(fontSize: 12.5)),
                value: _manageReports,
                onChanged: (v) => setState(() => _manageReports = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('تخصيص ودجات لوحة القيادة', style: TextStyle(fontSize: 12.5)),
                value: _manageDashboard,
                onChanged: (v) => setState(() => _manageDashboard = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('اعتماد/رفض القرارات التنفيذية العامة', style: TextStyle(fontSize: 12.5)),
                subtitle: const Text('لا يشمل تسجيل الأعضاء أو المشاريع أو المواعيد النهائية', style: TextStyle(fontSize: 10.5)),
                value: _approveGeneralDecisions,
                onChanged: (v) => setState(() => _approveGeneralDecisions = v ?? false),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
