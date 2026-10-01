/// «لا بيانات» — **بصيغةٍ واحدةٍ في المنصة كلِّها**.
///
/// ــــ ما كان ــــ
///
/// ثلاثُ شاشاتٍ تقول الشيءَ نفسَه بثلاثة أشكال: واحدةٌ بإطارٍ وأيقونةٍ
/// وعنوانٍ ووصف، وأخرى سطرٌ في حشوةٍ رأسيّةٍ ٢٤، وثالثةٌ نصٌّ في حشوة ٢٨.
/// ورابعةٌ في لوحة القيادة باسمٍ آخر. ولا شيءَ من ذلك قرارٌ — كلُّ كاتبٍ
/// كتب ما حضره.
///
/// ــــ ولماذا وصفٌ لا عنوانٌ وحده ــــ
///
/// «لا توجد بيانات» لا تقول للقارئ شيئاً: أهي فارغةٌ لأنّه لا يملك رؤيتها،
/// أم لأنّ مرشِّحاً ضيّقاً، أم لأنّ العملَ لم يبدأ؟ فيُفتح [message] ليُقال
/// السبب. وهو الدرسُ نفسُه المكتوب في لافتة تعذُّر القراءة.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  /// سطرٌ يقول ما ينقص — «لا مشاريع في نطاقك».
  final String title;

  /// وسببُه أو ما يُفعل — يُترك فارغاً حين يكفي العنوان.
  final String? message;

  final IconData icon;

  /// هل يُرسم الإطارُ والسطحُ الهادئ؟ يُطفأ داخل بطاقةٍ لها إطارُها.
  final bool framed;

  /// زرٌّ يخرج من الفراغ — «أضف أوّلَ ودجة».
  ///
  /// وليس زينةً: لوحةٌ فارغةٌ بلا زرٍّ تترك المستخدمَ يعرف أنّها فارغةٌ ولا
  /// يعرف كيف يملؤها. فحيث كان للفراغ مخرجٌ يُعرض.
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.framed = true,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 30, color: AppColors.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(height: 1.7, color: AppColors.textSecondary)),
        ],
        if (action != null) ...[
          const SizedBox(height: 14),
          action!,
        ],
      ],
    );

    if (!framed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        child: Center(child: body),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: body,
    );
  }
}
