import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ministry_logo.dart';

/// شاشة تأكيد البريد الوزاري — تسبق عرض الطلب على مسؤول النظام.
///
/// التأكيد **خطوة إضافية لا بديل** عن اعتماد مسؤول النظام: الموظف يُثبت أنه
/// يملك البريد الوزاري، ثم يبقى طلبه معلّقاً حتى تعتمده أنت. والحراسة الفعلية
/// على الخادم — دالة الاعتماد ترفض اعتماد حساب غير مؤكَّد وغير مستثنى — لأن
/// أي حراسة في المتصفح يمكن تجاوزها.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    final error = await context.read<AppStore>().sendEmailVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _messageIsError = error != null;
      _message = error ?? 'أُرسلت رسالة التأكيد. تفقّد بريدك — وراجع مجلد «غير المرغوب» إن لم تجدها.';
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    final verified = await context.read<AppStore>().refreshEmailVerified();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _messageIsError = !verified;
      _message = verified
          ? 'تم تأكيد بريدك. طلبك الآن بانتظار اعتماد مسؤول النظام.'
          : 'لم يُؤكَّد البريد بعد. افتح الرسالة واضغط رابط التأكيد ثم أعد المحاولة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final email = store.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MinistryLogo(size: 72, onDark: true),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 44, color: AppColors.primary),
                        const SizedBox(height: 18),
                        const Text('أكّد بريدك الوزاري',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        const Text(
                          'أرسلنا رسالة تأكيد إلى:',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.8),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'افتح الرسالة واضغط رابط التأكيد، ثم عُد إلى هنا واضغط «تحققتُ من بريدي». '
                          'بعدها يصل طلبك إلى مسؤول النظام للاعتماد.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.9),
                          textAlign: TextAlign.center,
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_messageIsError ? AppColors.danger : AppColors.success).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.8,
                                color: _messageIsError ? AppColors.danger : AppColors.success,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _checking ? null : _check,
                            icon: _checking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.verified_outlined, size: 18),
                            label: const Text('تحققتُ من بريدي'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _sending ? null : _resend,
                            icon: _sending
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('إعادة إرسال الرسالة'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () => store.logout(),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'إن لم تصلك الرسالة ولا تملك بريداً وزارياً عاملاً، راجع مسؤول النظام — '
                  'فله استثناؤك من هذا الشرط.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5, height: 1.8),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
