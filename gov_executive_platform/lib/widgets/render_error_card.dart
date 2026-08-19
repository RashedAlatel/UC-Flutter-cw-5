import 'package:flutter/material.dart';

import '../build_stamp.dart';
import '../theme/app_theme.dart';

/// ما يُعرض بدل أي شاشة فشل بناؤها.
///
/// حين يُرمى استثناء أثناء بناء ودجة يستبدلها Flutter بـ`ErrorWidget`. وهذه
/// في **بناء الإصدار** ترسم مستطيلاً صامتاً بلا نصّ — النصّ لا يظهر إلا في
/// بناء التطوير. فيرى المستخدم سطحاً ملوّناً فارغاً ويظن أن المنصة لا تفتح،
/// ولا يصل إلينا من العطل حرف واحد. هذه البطاقة تقول ما جرى بالعربية وتحمل
/// نصّ الاستثناء وبصمة البناء، فتكفي لقطةٌ واحدة لتشخيصه.
///
/// تُبنى **مكتفيةً بذاتها**: لا `Scaffold` ولا `Theme` ولا `Directionality`
/// موروثة، لأن الاستثناء قد يقع فوق شجرة `MaterialApp` نفسها فلا يكون شيء من
/// ذلك متاحاً — واستخدام موروث غائب هنا يعني خطأً ثانياً يخفي الأول.
///
/// ولهذا يُسمّى الخط صراحةً في كل نصّ. بلا `Theme` يقع النص على الخط
/// الافتراضي (Roboto)، ومحرك Flutter على الويب **يجلبه من fonts.gstatic.com
/// عبر الشبكة**. فإن كانت الشبكة هي سبب العطل أصلاً لم يصل الخط، ورسم المحرك
/// الأيقونة والإطار **بلا حرف واحد** — قِيس ذلك فعلاً: بطاقة كاملة بلا نص.
/// فتصير شاشة العطل نفسها صمّاء في اللحظة التي يُحتاج فيها كلامها. أما
/// Tajawal فمحزوم مع المنصة ولا يحتاج شبكة.
class RenderErrorCard extends StatelessWidget {
  final String message;

  /// ما يُنفَّذ عند «إعادة المحاولة» — يُترك فارغاً في الاختبارات.
  final VoidCallback? onRetry;

  const RenderErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFF072E24),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.report_problem_rounded, color: Color(0xFFC9A227), size: 40),
              const SizedBox(height: 16),
              const Text(
                'تعذّر عرض هذه الشاشة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'وقع خطأ أثناء بناء الواجهة. صوّر هذه الشاشة وأرسلها لمسؤول '
                'النظام — النص أدناه يحدّد السبب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Color(0xB3FFFFFF),
                  fontSize: 12.5,
                  height: 1.9,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Color(0x99FFFFFF),
                    fontSize: 11.5,
                    height: 1.7,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (onRetry != null)
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A227),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Color(0xFF072E24),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'إصدار $kBuildStamp',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Color(0x73FFFFFF),
                  fontSize: 10.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
