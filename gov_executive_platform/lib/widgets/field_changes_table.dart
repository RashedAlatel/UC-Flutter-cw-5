import 'package:flutter/material.dart';

import '../models/project_edit.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// عرضُ قيمةِ حقلٍ في جدول الفروق — و«غير مسجّل» تُقال ولا تُترك خانةً فارغة.
///
/// وخانةٌ فارغة في جدول اعتمادٍ تُقرأ عطلاً في العرض لا قيمةً غائبة، فيُظنّ
/// أن الطلب وصل ناقصاً.
///
/// والتواريخُ تُحمَل في الطلب نصّاً زمنياً (ISO) — تُعرض مقروءةً لا خاماً:
/// «٢٠٢٦-٠٢-١٥T٠٠:٠٠:٠٠.٠٠٠» ليس تاريخاً يبتّ فيه أحد.
String showFieldValue(Object? v) {
  if (v == null) return 'غير مسجّل';
  if (v is List) return v.isEmpty ? 'لا شيء' : v.join('، ');
  final text = v.toString().trim();
  if (text.isEmpty) return 'غير مسجّل';
  final parsed = DateTime.tryParse(text);
  if (parsed != null && text.contains('T')) return Formatters.date(parsed);
  return text;
}

/// جدولُ «القيمة الحالية ← الجديدة» — **موضعٌ واحد يقرّر شكلَه**.
///
/// ــــ ولماذا واحدٌ لا اثنان ــــ
///
/// يُعرض مرّتين: لمقدّم الطلب قبل الإرسال، وللمعتمِد قبل البتّ. ولو كُتب
/// مرّتين لَافترقا بأول تعديل، فقرأ الاثنان الطلبَ نفسَه بصيغتين — وأشدُّ ما
/// يفترق فيه: **تمييزُ الحقل الجوهري**. فنسخةٌ تُميّزه ونسخةٌ لا تُميّزه
/// تعني معتمِداً يمرّر قيمةَ عقدٍ ظنّها تصحيحَ وصف.
///
/// وهو كذلك موضعُ الطفرة: تعديلٌ واحد هنا يُسقط اختباراً — بخلاف نصٍّ مكرّر
/// في شاشتين، لا يعضّ فيه تغييرُ إحداهما.
class FieldChangesTable extends StatelessWidget {
  final List<FieldChange> changes;

  /// عنوانٌ فوق الجدول؛ ويُترك فارغاً حين يكون سياقُه قائلاً بنفسه.
  final String? title;

  /// ما يُقال حين لا تغييرَ — يختلف بين «لم تُغيّر بعد» و«طلبٌ بلا تغيير».
  final String emptyText;

  const FieldChangesTable({
    super.key,
    required this.changes,
    this.title,
    this.emptyText = 'لا تغييرات',
  });

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          emptyText,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text('$title (${changes.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
        ],
        for (final c in changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الجوهريُّ يُميَّز — وهو ما طلبتَ إبرازَه للمعتمِد.
                if (c.isSensitive)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 6, top: 2),
                    child: Icon(Icons.priority_high_rounded, size: 14, color: AppColors.warning),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.isSensitive ? AppColors.warning : null,
                          )),
                      const SizedBox(height: 2),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                          text: showFieldValue(c.before),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const TextSpan(text: '  ←  ', style: TextStyle(fontSize: 12)),
                        TextSpan(
                          text: showFieldValue(c.after),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ])),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
