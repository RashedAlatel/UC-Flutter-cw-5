import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class LabeledProgressBar extends StatelessWidget {
  final double value; // 0-100
  final String? label;
  final Color? color;
  final double height;

  const LabeledProgressBar({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ??
        (value >= 75
            ? AppColors.success
            : value >= 40
                ? AppColors.warning
                : AppColors.danger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              Text(Formatters.percent(value),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: barColor)),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: (value.clamp(0, 100)) / 100,
            minHeight: height,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }
}
