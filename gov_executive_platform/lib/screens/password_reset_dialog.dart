import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

/// نافذة «نسيت كلمة المرور؟» — تُفتح من شاشة الدخول بلا تسجيل دخول.
///
/// ــــ قراران فيها، وكلٌّ لسبب ــــ
///
/// ١) **رسالة واحدة للحالتين**: سواءٌ وُجد الحساب أو لم يوجد، يُقال النصّ
///    نفسه. فشاشة الدخول مفتوحة لمن لا حساب له، ولو قالت «هذا البريد غير
///    مسجَّل» لَصارت أداةً يعرف بها أيُّ أحد أيَّ البُرد الوزارية مسجَّلٌ في
///    المنصة. والإخفاء مفروضٌ في `AppStore.sendPasswordReset` لا هنا: لو
///    كان في نصّ الشاشة وحده لَكشفته أوّلُ رسالة خطأ تمرّ من تحته.
///
/// ٢) **الحقل يُملأ مسبقاً** بما كُتب في شاشة الدخول — فلا يكتب المستخدم
///    بريده مرّتين، ولا يُخطئ في الثانية.
class PasswordResetDialog extends StatefulWidget {
  /// ما كُتب في حقل البريد على شاشة الدخول، إن كُتب شيء.
  final String initialEmail;

  const PasswordResetDialog({super.key, this.initialEmail = ''});

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'الرجاء إدخال البريد الإلكتروني');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      // النجاح الظاهري يشمل البريد غير المسجَّل — راجع `sendPasswordReset`.
      _sent = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعادة تعيين كلمة المرور'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sent) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: AppColors.success),
                  const SizedBox(width: AppSpace.sm),
                  const Expanded(
                    child: Text(
                      AppStore.passwordResetNotice,
                      style: TextStyle(height: 1.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              const Text(
                'الرابط في الرسالة صالح لمرّة واحدة ولمدّة محدودة. وبعد ضبط كلمة '
                'المرور الجديدة عُد إلى هذه الصفحة وسجّل الدخول بها.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7),
              ),
            ] else ...[
              const Text(
                'اكتب البريد الإلكتروني المسجَّل باسمك في المنصة، ويصلك عليه '
                'رابطٌ تضبط به كلمة مرور جديدة.',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ],
        ),
      ),
      actions: _sent
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'جارٍ الإرسال…' : 'أرسل الرابط'),
              ),
            ],
    );
  }
}
