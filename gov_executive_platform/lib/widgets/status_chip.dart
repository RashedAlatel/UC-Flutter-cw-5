/// شارتا الحالة والأولوية — **وقد صارتا لباساً على [StatusPill]**.
///
/// ــــ ما كان ــــ
///
/// كانت كلٌّ منهما تبني سطحَها بـ`color.withValues(alpha: 0.12)`: لونُ
/// المعنى مخفَّفاً على الأبيض. وذلك يُنتج سطحاً مختلفَ التشبّع لكلّ معنى —
/// الأحمرُ المخفَّف ورديٌّ فاقع، والأصفرُ المخفَّف يكاد يختفي — ونصّاً
/// بلونِ المعنى الصريح فوقه، **بتباينٍ لم يُقَس قطّ**.
///
/// ــــ ولماذا لم تُحذفا ــــ
///
/// تُقرآن في خمسَ عشرةَ شاشة، وتعرفان النماذج (`ProjectStatus` و
/// `PriorityLevel`) بينما [StatusPill] لا تعرف إلا النغمةَ والنصّ. فبقيتا
/// جسراً يترجم الحالةَ إلى نغمةٍ ونصّ — وتبدّل مظهرُ خمسَ عشرةَ شاشةً
/// بتبديل هذا الملفّ وحده.
library;

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/status_palette.dart';
import 'status_pill.dart';

class StatusChip extends StatelessWidget {
  final ProjectStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => StatusPill(
        label: status.label,
        tone: StatusPalette.projectTone(status.name),
      );
}

/// شارةُ الأولوية — **بلا نقطة**.
///
/// فهي تقع إلى جانب شارة الحالة في صفٍّ واحد في أكثر المواضع، ونقطتان
/// متجاورتان تُقرآن زينةً لا معنى.
class PriorityChip extends StatelessWidget {
  final PriorityLevel priority;
  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) => StatusPill(
        label: priority.label,
        tone: StatusPalette.priorityTone(priority.name),
        dot: false,
      );
}
