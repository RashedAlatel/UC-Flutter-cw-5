import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _requestedRole = UserRole.projectOfficer;
  String? _departmentId;
  String? _error;
  bool _busy = false;

  static const _selectableRoles = [UserRole.executiveViewer, UserRole.departmentManager, UserRole.projectOfficer];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final needsDept = _requestedRole != UserRole.executiveViewer;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'الرجاء تعبئة جميع الحقول المطلوبة');
      return;
    }
    if (needsDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().signUp(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          requestedRole: _requestedRole,
          requestedDepartmentId: needsDept ? _departmentId : null,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    // عند النجاح، سيلتقط AppStore حالة تسجيل الدخول تلقائياً وينتقل الجذر لشاشة "بانتظار الموافقة".
  }

  @override
  Widget build(BuildContext context) {
    final needsDept = _requestedRole != UserRole.executiveViewer;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'سيتم إرسال طلب حسابك إلى مسؤول النظام للمراجعة، ولن تتمكن من الدخول إلا بعد الموافقة.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم الجوال (لواتساب)', hintText: '+9715xxxxxxxx'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                    const SizedBox(height: 12),
                    TextField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      initialValue: _requestedRole,
                      decoration: const InputDecoration(labelText: 'الدور المطلوب'),
                      items: _selectableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                      onChanged: (v) => setState(() {
                        _requestedRole = v ?? _requestedRole;
                        _departmentId = null;
                      }),
                    ),
                    if (needsDept) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<List<Department>>(
                        future: _loadDepartments(),
                        builder: (context, snapshot) {
                          final depts = snapshot.data ?? const [];
                          return DropdownButtonFormField<String>(
                            initialValue: _departmentId,
                            decoration: const InputDecoration(labelText: 'الإدارة'),
                            items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                            onChanged: (v) => setState(() => _departmentId = v),
                          );
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('إرسال طلب التسجيل', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Department>> _loadDepartments() async {
    final snap = await FirebaseFirestore.instance.collection('departments').orderBy('name').get();
    return snap.docs.map(Department.fromDoc).toList();
  }
}
