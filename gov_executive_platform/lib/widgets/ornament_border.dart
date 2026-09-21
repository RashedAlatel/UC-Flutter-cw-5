import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شريط الزخرفة الهندسية الرسمي المعتمد في وثائق الوزارة، يُكرَّر رأسياً.
///
/// ملف الزخرفة مرسوم بلون واحد مع شفافية، لذا يمكن صبغه بأي لون عبر
/// [color] — أخضر على الخلفيات الفاتحة، وذهبي على الخلفيات الداكنة.
class OrnamentBorder extends StatelessWidget {
  /// عرض الشريط. ارتفاع البلاطة يتبعه تلقائياً بنفس نسبة الصورة الأصلية
  /// (٥٣×١٩٤ بكسل) حتى لا تتشوّه الزخرفة.
  final double width;

  /// لون الزخرفة. الافتراضي هو الذهبي الرسمي.
  final Color? color;

  const OrnamentBorder({super.key, this.width = 26, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/frame_border.png'),
            repeat: ImageRepeat.repeatY,
            // العرض ثابت والتكرار رأسي فقط، فتبقى الزخرفة بنسبتها الصحيحة.
            scale: 53 / width,
            alignment: Alignment.topCenter,
            colorFilter: ColorFilter.mode(color ?? AppColors.accent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
