/// شارةُ حالةٍ — **لونُها من نغمةِ معناها**.
///
/// ــــ ولماذا `soft` لا شفافيّةٌ محسوبة ــــ
///
/// كانت الشارةُ تُبنى بـ`color.withValues(alpha: 0.12)`: لونُ المعنى مخفَّفٌ
/// على الأبيض. وذلك يُنتج سطحاً مختلفَ التشبّعِ لكلّ معنى — الأحمرُ المخفَّف
/// ورديٌّ فاقع، والأصفرُ المخفَّف يكاد يختفي. فصار السطحُ درجةً **مختارةً**
/// في اللوحة (`s50`) ونصُّه درجةً مختارة (`s800`)، ويُقاس تباينُهما.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/status_palette.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;

  /// نقطةٌ صغيرةٌ قبل النصّ — تُعين من لا يفرّق الألوان.
  final bool dot;

  const StatusPill({super.key, required this.label, required this.tone, this.dot = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.soft,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: AppType.pill.copyWith(color: tone.text)),
        ],
      ),
    );
  }
}

/// معلومةٌ صغيرةٌ بأيقونتها — «١٢ مهمّة» · «تنتهي في ٣ مارس».
///
/// وكانت مكتوبةً **مرّتين متطابقتين حرفاً** في بطاقتين. وفيهما `w600` وهو
/// وزنٌ لا ملفَّ خطٍّ له فيصطنعه المحرّك — فصار `w700` هنا في موضعٍ واحد.
class MetaBit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const MetaBit({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text,
            style: AppType.micro.copyWith(
                fontSize: 11, color: c, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
