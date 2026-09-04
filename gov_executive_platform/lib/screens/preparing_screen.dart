import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../build_stamp.dart';
import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ministry_logo.dart';

/// شاشة الانتظار بين إقلاع التطبيق ووصول أول بيانات من الخادم.
///
/// كانت دوّاراً أبيض على خلفية خضراء **بلا أي نص ولا مهلة ولا زر**. وحين
/// تتعذّر خدمات Google على شبكة الجوال لا يُحسم لا مستمع تسجيل الدخول ولا أول
/// لقطة من مستند المستخدم، فيبقى الدوّار يدور إلى الأبد ويرى المستخدم "شاشة
/// خضراء فارغة" فيظن أن المنصة لا تعمل. الشاشة الآن تتكلّم: تقول ما يجري،
/// وتعرض بصمة البناء (فيعرف مسؤول النظام أي نسخة منشورة فعلاً)، وبعد مهلة
/// تعرض سبباً محتملاً ومخرجاً.
class PreparingScreen extends StatefulWidget {
  /// ما يُنفَّذ عند «إعادة المحاولة». يُمرَّر من `main.dart` ليعيد تشغيل
  /// الإقلاع كاملاً؛ ويبقى اختيارياً حتى تُختبر الشاشة وحدها.
  final VoidCallback? onRetry;

  const PreparingScreen({super.key, this.onRetry});

  @override
  State<PreparingScreen> createState() => _PreparingScreenState();
}

class _PreparingScreenState extends State<PreparingScreen> {
  static const Duration _patience = Duration(seconds: 15);

  Timer? _timer;
  bool _tooLong = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_patience, () {
      if (mounted) setState(() => _tooLong = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MinistryLogo(size: 72, onDark: true),
                const SizedBox(height: 24),
                if (!_tooLong) ...[
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'جارٍ تحضير بياناتك…',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 38),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذّر إكمال الاتصال بخدمات المنصة',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'المنصة تعمل، لكن تحميل بياناتك لم يكتمل. تأكد من اتصال الشبكة، '
                    'وإن كنت داخل شبكة الوزارة فقد يكون الوصول إلى نطاقات Google '
                    '(www.gstatic.com و firestore.googleapis.com) محجوباً — يلزم السماح بها.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12.5, height: 1.9),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                      ),
                      // مخرج لمن علِق بحساب لا تصل بياناته: يعيده لشاشة الدخول
                      // بدل حبسه خلف هذه الشاشة.
                      OutlinedButton.icon(
                        onPressed: () => context.read<AppStore>().logout(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                // بصمة البناء تظهر دائماً: هي ما يحسم أي نسخة منشورة فعلاً حين
                // يتعذّر على المستخدم الوصول إلى الشريط الجانبي.
                Text(
                  'إصدار $buildLabel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
