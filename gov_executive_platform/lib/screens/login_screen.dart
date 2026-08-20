import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../build_stamp.dart';
import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/ministry_logo.dart';
import '../widgets/ornament_border.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'الرجاء إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 48, offset: const Offset(0, 18))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 640;
                    final form = _buildForm();
                    final brand = _buildBrandPanel(compact: !wide);
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
                const SizedBox(height: 18),
                Text(
                  'جميع الحقوق محفوظة © ${DateTime.now().year} — ${Brand.ministry}، ${Brand.state}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// اللوحة التعريفية الرسمية: شعار الوزارة، اسم الدولة والجهة، ثم اسم
  /// المنصة ووصفها — بترتيب هرمي رسمي يقرأ من الأعلى للأسفل.
  Widget _buildBrandPanel({required bool compact}) {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.sidebarGradient),
      // IntrinsicHeight ضروري لا تجميلي، وغيابه هو ما منع فتح المنصة على
      // الجوال شهراً كاملاً:
      //
      // `CrossAxisAlignment.stretch` في صفٍّ يفرض على أبنائه ارتفاع الصف
      // نفسه. وفي مسار الشاشة الضيّقة توضع هذه اللوحة داخل عمود داخل
      // SingleChildScrollView، أي في سياق **ارتفاعه غير محدود** — فيصير
      // المطلوب من الشريط الزخرفي ارتفاعاً لا نهائياً، فينهار التخطيط:
      //   BoxConstraints forces an infinite height (h=Infinity)
      // وفي بناء الإصدار لا تظهر رسالة الانهيار بل يُرسم فراغ، فيرى
      // المستخدم صفحة خضراء صمّاء ولا يعرف أحد لماذا.
      //
      // ولم يظهر العطل على الكمبيوتر لأن المسار العريض يلفّ الصف بـ
      // IntrinsicHeight أصلاً فيحدّ ارتفاعه. فاللفّ هنا يجعل اللوحة
      // مكتفيةً بذاتها في المسارين، ولا تعتمد على من يستدعيها.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الإطار الزخرفي الرسمي على الحافة الخارجية للوحة، بالذهبي المخفّف
            // ليقرأ كزخرفة رصينة فوق الأخضر الداكن لا كشريط صاخب.
            OrnamentBorder(width: 30, color: AppColors.accent.withValues(alpha: 0.55)),
            Expanded(child: _buildBrandContent(compact: compact)),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandContent({required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 32 : 44),
      child: Column(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const MinistryLogo(size: 86, onDark: true),
          const SizedBox(height: 20),
          Text(
            Brand.state,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 2),
          Text(
            Brand.ministry,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(height: 2, width: 52, color: AppColors.accent),
          const SizedBox(height: 14),
          Text(
            Brand.platform,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            Brand.tagline,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5, height: 1.9),
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
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline_rounded)),
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
            onPressed: _busy ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('دخول', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
              child: const Text('ليس لديك حساب؟ إنشاء حساب جديد'),
            ),
          ),
          // بصمة البناء على شاشة الدخول أيضاً: يراها المستخدم قبل الدخول، فيمكنه
          // إخبار مسؤول النظام أي نسخة تعمل على جهازه عند الإبلاغ عن أي عطل.
          const SizedBox(height: 6),
          Center(
            child: Text(
              'إصدار $buildLabel',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}
