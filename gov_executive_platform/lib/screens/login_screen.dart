import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _obscure = true;

  static const _demoAccounts = [
    ('admin', 'admin123', 'مسؤول نظام'),
    ('exec', 'exec123', 'مستخدم تنفيذي'),
    ('mgr.it', 'mgr123', 'مدير إدارة تقنية المعلومات'),
    ('officer.it', 'off123', 'ضابط مشروع'),
  ];

  void _submit() {
    final store = context.read<AppStore>();
    final ok = store.login(_usernameCtrl.text, _passwordCtrl.text);
    setState(() {
      _error = ok ? null : 'اسم المستخدم أو كلمة المرور غير صحيحة';
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 640;
                final form = _buildForm();
                final brand = _buildBrandPanel();
                if (!wide) {
                  return Column(mainAxisSize: MainAxisSize.min, children: [brand, form]);
                }
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: brand),
                      Expanded(flex: 6, child: form),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.account_balance_rounded, color: Colors.white, size: 44),
          SizedBox(height: 18),
          Text(
            'المنصة التنفيذية الحكومية',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.4),
          ),
          SizedBox(height: 10),
          Text(
            'إدارة ومتابعة الخطة الاستراتيجية ومشاريع الوزارة على مستوى القيادة التنفيذية، بمؤشرات فورية وقرارات أسرع.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('الرجاء إدخال بيانات الدخول الخاصة بك', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submit,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('دخول', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 22),
          const Text('حسابات تجريبية للدخول السريع:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _demoAccounts.map((a) {
              return ActionChip(
                label: Text(a.$3, style: const TextStyle(fontSize: 11.5)),
                backgroundColor: AppColors.background,
                onPressed: () {
                  _usernameCtrl.text = a.$1;
                  _passwordCtrl.text = a.$2;
                  _submit();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
