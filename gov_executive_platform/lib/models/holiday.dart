/// عطلةٌ رسميّةٌ يسجّلها مسؤولُ النظام.
///
/// ــــ ولماذا تُسجَّل ولا تُحسب ــــ
///
/// عطلُ الكويت الرسميّة بعضُها بالتقويم الهجريّ وبعضُها تُعلَن بمرسوم قبل
/// أيام، وبعضُها يُنقل من يومٍ إلى يوم. فلا سبيل إلى حسابها، وكلُّ محاولةٍ
/// لحسابها تُخطئ سنةً وتصيب أخرى.
///
/// وأثرُها الوحيد أنّ اليومَ لا يُعدّ يومَ عمل: فلا يُحسب غياباً على أحد،
/// ولا يدخل في مقام «حضر ١٨ من ٢٢».
library;

import 'safe_read.dart';
import 'work_week.dart';

class Holiday {
  /// مفتاحُ اليوم `yyyy-mm-dd`.
  final String dayKey;
  final String name;

  const Holiday({required this.dayKey, required this.name});

  DateTime? get day => DateTime.tryParse(dayKey);

  Map<String, dynamic> toMap() => {'dayKey': dayKey, 'name': name};

  static Holiday? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    // ويُقبل الختمُ والنصُّ معاً: مستنداتٌ كُتبت بيدٍ قد تحمل ختماً، وقارئٌ
    // يفترض صيغةً واحدة هو بعينه ما أسقط مشاريع الوزارة يوماً كاملاً.
    final key = readText(map['dayKey']);
    final resolved = key.isNotEmpty
        ? key
        : (readDate(map['day']) == null ? '' : WorkWeek.keyOf(readDate(map['day'])!));
    if (resolved.isEmpty) return null;
    final name = readText(map['name']);
    return Holiday(dayKey: resolved, name: name.isEmpty ? 'عطلة رسميّة' : name);
  }
}
