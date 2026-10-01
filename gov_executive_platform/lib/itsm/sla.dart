/// ساعةُ مدّةِ الخدمة (SLA) — **حسابٌ لا حقول**.
///
/// ــــ ولماذا لا يُخزَّن هدفٌ ولا تجاوز ــــ
///
/// كان أقربَ الطرق أن يُكتب `slaResolveBy` و`slaBreached` في المستند عند
/// الفتح. وهو خطأ من وجهين:
///
/// • **المخزَّنُ المشتقُّ يتناقض مع أصله**: تُعدَّل سياسةُ المدد، فتبقى
///   آلافُ البلاغات القديمة على أهدافٍ لم تعد قائمة، ولا أحدَ يعرف أيُّهما
///   الصحيح.
/// • **والمخزَّنُ يُكتب**: حقلٌ اسمُه `slaBreached` يُقلب بكتابةٍ واحدة،
///   فيصير الرقمُ الذي يُقاس به الفريقُ رهنَ من يكتبه.
///
/// فالهدفُ يُحسب من ثلاثةٍ لا يُزوَّر أوّلُها: [Ticket.createdAt] (تفرضه
/// القاعدةُ `request.time`)، والأولويّة، والسياسة. والتجاوزُ نتيجةُ مقارنة،
/// لا علَمٌ مرفوع.
///
/// ــــ و`now` تُمرَّر ولا تُقرأ هنا ــــ
///
/// كلُّ دالّةٍ تأخذ [DateTime] صريحاً. وقد كلّفنا خلافُ ذلك اختباراً في
/// `attention.dart`: طُلب تأخيرُ اثني عشر يوماً فجاء أحدَ عشر، لأنّ دالّةً
/// تحتها قرأت `DateTime.now()` بنفسها. ودالّةٌ تقرأ ساعةَ الجهاز لا تُختبَر.
library;

import '../models/enums.dart';
import '../models/ticket.dart';

/// مدّتان لأولويّةٍ واحدة: مهلةُ أوّلِ ردٍّ، ومهلةُ الحلّ.
class SlaTarget {
  final int respondMinutes;
  final int resolveMinutes;

  const SlaTarget({required this.respondMinutes, required this.resolveMinutes});

  Map<String, dynamic> toMap() =>
      {'respondMinutes': respondMinutes, 'resolveMinutes': resolveMinutes};

  static SlaTarget fromMap(Object? raw, SlaTarget fallback) {
    if (raw is! Map) return fallback;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final respond = _positiveInt(m['respondMinutes']);
    final resolve = _positiveInt(m['resolveMinutes']);
    // ولا يُقبل صفرٌ ولا سالب: مهلةٌ صفرٌ تجعل كلَّ بلاغٍ متجاوزاً لحظةَ
    // فتحه، فيصير الرقمُ بلا معنى ويُهمَل — وهو أسوأ من غيابه.
    return SlaTarget(
      respondMinutes: respond ?? fallback.respondMinutes,
      resolveMinutes: resolve ?? fallback.resolveMinutes,
    );
  }

  static int? _positiveInt(Object? raw) {
    final n = raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null);
    if (n == null) return null;
    final i = n.round();
    return i > 0 ? i : null;
  }
}

/// سياسةُ المدد — مدّتان لكلّ أولويّة، وكسرُ «يوشك».
class SlaPolicy {
  final Map<String, SlaTarget> byPriority;

  /// متى يُقال «يوشك على التجاوز»؟ — حين يبقى من المهلة هذا الكسرُ أو أقلّ.
  ///
  /// وكسرٌ لا دقائقُ ثابتة: بقاءُ ساعةٍ من مهلةِ أربعٍ إنذار، وبقاؤها من
  /// مهلةِ ثلاثةِ أيّامٍ ليس خبراً.
  final double atRiskFraction;

  const SlaPolicy({required this.byPriority, this.atRiskFraction = 0.25});

  /// المبدئيّةُ حين لا يكون في الإعدادات مستند — ولا تُترك المنصّةُ بلا مدد.
  static const SlaPolicy standard = SlaPolicy(byPriority: {
    'critical': SlaTarget(respondMinutes: 15, resolveMinutes: 4 * 60),
    'high': SlaTarget(respondMinutes: 60, resolveMinutes: 8 * 60),
    'medium': SlaTarget(respondMinutes: 4 * 60, resolveMinutes: 24 * 60),
    'low': SlaTarget(respondMinutes: 8 * 60, resolveMinutes: 72 * 60),
  });

  SlaTarget targetFor(PriorityLevel priority) =>
      byPriority[priority.name] ??
      standard.byPriority[priority.name] ??
      const SlaTarget(respondMinutes: 4 * 60, resolveMinutes: 24 * 60);

  Map<String, dynamic> toMap() => {
        'atRiskFraction': atRiskFraction,
        'byPriority': byPriority.map((k, v) => MapEntry(k, v.toMap())),
      };

  static SlaPolicy fromMap(Object? raw) {
    if (raw is! Map) return standard;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final rawByPriority = m['byPriority'];
    final out = <String, SlaTarget>{};
    for (final p in PriorityLevel.values) {
      final fallback = standard.byPriority[p.name]!;
      final entry = rawByPriority is Map ? rawByPriority[p.name] : null;
      out[p.name] = SlaTarget.fromMap(entry, fallback);
    }
    final f = m['atRiskFraction'];
    final fraction = f is num ? f.toDouble() : standard.atRiskFraction;
    return SlaPolicy(
      byPriority: out,
      // وخارجُ المدى يُردّ إلى المبدئيّ: كسرٌ فوق الواحد يجعل كلَّ بلاغٍ
      // «يوشك» لحظةَ فتحه، وسالبٌ يُلغي التحذير كلَّه بصمت.
      atRiskFraction: fraction > 0 && fraction < 1 ? fraction : standard.atRiskFraction,
    );
  }
}

/// نتيجةُ ساعةٍ واحدة.
enum SlaOutcome {
  /// وقع الحدثُ داخل المهلة — خبرٌ انتهى.
  met('ضمن المدّة'),

  /// وقع بعدها — خبرٌ انتهى أيضاً، ولا يُصلحه شيء.
  missed('تجاوز المدّة'),

  /// لم يقع بعد، وفي الوقت متّسع.
  onTrack('ضمن المدّة'),

  /// لم يقع، وبقي من المهلة أقلُّ من كسر «يوشك».
  atRisk('يوشك على التجاوز'),

  /// لم يقع، وانقضت المهلة.
  breached('متجاوزٌ للمدّة');

  final String label;
  const SlaOutcome(this.label);

  bool get isLate => this == missed || this == breached;
}

/// ساعةٌ واحدةٌ محسوبة.
class SlaClock {
  final DateTime dueAt;

  /// ما بقي من المهلة — **وسالبٌ يعني ما مضى بعدها**.
  final Duration remaining;

  final SlaOutcome outcome;

  const SlaClock({required this.dueAt, required this.remaining, required this.outcome});
}

/// يحسب الساعتين لبلاغٍ واحد.
class SlaEngine {
  /// ــ ساعةُ أوّلِ ردّ ــ
  ///
  /// ولا تتوقّف: المستفيدُ لم يُسأل بعد، فلا شيءَ يُنتظَر منه.
  static SlaClock respond(Ticket t, SlaPolicy policy, DateTime now) {
    final window = Duration(minutes: policy.targetFor(t.priority).respondMinutes);
    return _clock(
      dueAt: t.createdAt.add(window),
      window: window,
      stamp: t.firstResponseAt,
      now: now,
      atRiskFraction: policy.atRiskFraction,
    );
  }

  /// ــ ساعةُ الحلّ، **وتتوقّف حين يكون الدورُ على المستفيد** ــ
  ///
  /// فنّيٌّ سأل المستفيدَ سؤالاً فلم يُجَب ثلاثةَ أيّام ليس متجاوزاً للمدّة،
  /// ورقمٌ يقول إنّه متجاوزٌ يتّهمه بما لم يفعل. ومقياسٌ يُتّهم به البريءُ
  /// يُهمَل بعد أسبوع.
  ///
  /// فالموعدُ يُزاح بقدر ما انتظر، ومدّةُ الانتظار [Ticket.waitingMs] فعلٌ
  /// مسجَّلٌ كنظائره (`firstResponseAt`)، لا هدفٌ ولا علَمُ تجاوز.
  static SlaClock resolve(Ticket t, SlaPolicy policy, DateTime now) {
    final window = Duration(minutes: policy.targetFor(t.priority).resolveMinutes);
    // والمرجعُ وقتُ الحلّ إن حُلّ، وإلا فالآن: انتظارٌ وقع **بعد** الحلّ
    // لا يُزيح موعداً انقضى أمرُه.
    final reference = t.resolvedAt ?? now;
    final waited = t.waitingUpTo(reference);
    return _clock(
      dueAt: t.createdAt.add(window).add(waited),
      window: window,
      stamp: t.resolvedAt,
      now: now,
      atRiskFraction: policy.atRiskFraction,
    );
  }

  static SlaClock _clock({
    required DateTime dueAt,
    required Duration window,
    required DateTime? stamp,
    required DateTime now,
    required double atRiskFraction,
  }) {
    if (stamp != null) {
      return SlaClock(
        dueAt: dueAt,
        remaining: dueAt.difference(stamp),
        // و`isAfter` لا `!isBefore`: الوقوعُ في اللحظة الأخيرة بالضبط
        // وقوعٌ داخل المهلة — والحدُّ لمن بلغه لا عليه.
        outcome: stamp.isAfter(dueAt) ? SlaOutcome.missed : SlaOutcome.met,
      );
    }
    final remaining = dueAt.difference(now);
    final risk = Duration(microseconds: (window.inMicroseconds * atRiskFraction).round());
    final SlaOutcome outcome;
    if (!remaining.isNegative && remaining.inMicroseconds > 0) {
      outcome = remaining <= risk ? SlaOutcome.atRisk : SlaOutcome.onTrack;
    } else {
      outcome = SlaOutcome.breached;
    }
    return SlaClock(dueAt: dueAt, remaining: remaining, outcome: outcome);
  }
}
