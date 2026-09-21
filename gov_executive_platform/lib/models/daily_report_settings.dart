/// إعدادات التقرير التنفيذي اليومي — `settings/dailyReport`.
///
/// يقرؤها الخادم عند التوليد (`functions/src/daily_report_job.ts`)، ويضبطها
/// مسؤول النظام من نافذة الإعدادات في شاشة التقرير.
///
/// وحقولٌ في المستند لا تظهر هنا عمداً — `baseUrl` و`extraRecipientUids`
/// و`excludedUids` — لأنها لا تُضبط من الشاشة. والكتابة تدمج ولا تستبدل
/// (`SetOptions(merge: true)`)، فلا تمحو الشاشةُ ما لا تعرفه.
library;

/// من يصله بريد التقرير.
enum ReportEmailMode {
  /// كل من يُولَّد له تقرير — أي المستوى الإشرافي كله.
  everyone,

  /// مسؤول النظام وحده — للتجربة قبل فتحه للناس.
  meOnly,

  /// أشخاصٌ بأعيانهم يختارهم مسؤول النظام.
  chosen,
}

class DailyReportSettings {
  /// هل يُولَّد التقرير أصلاً؟ إيقافُه يوقف الشاشة والبريد معاً.
  final bool enabled;

  /// هل يخرج بريدٌ؟ إطفاؤه يُبقي التقرير على الشاشة بلا رسائل.
  final bool emailEnabled;

  /// قائمةُ سماحٍ للبريد وحده — فارغةً تعني «الجميع».
  ///
  /// وهي قائمةُ سماحٍ لا استثناء: لحصر البريد بشخصٍ عبر قائمة استثناء يلزم
  /// إدراج كل موظفي الوزارة فيها، وأن يُضاف إليها كلُّ من يُعيَّن لاحقاً —
  /// فينكسر الحصر بصمت كلّما وُظّف أحد.
  final List<String> emailRecipientUids;

  const DailyReportSettings({
    this.enabled = true,
    this.emailEnabled = true,
    this.emailRecipientUids = const [],
  });

  /// الوضع المقروء من القائمة — [myUid] هو مسؤول النظام الحالي.
  ReportEmailMode modeFor(String? myUid) {
    if (emailRecipientUids.isEmpty) return ReportEmailMode.everyone;
    if (emailRecipientUids.length == 1 && emailRecipientUids.first == myUid) {
      return ReportEmailMode.meOnly;
    }
    return ReportEmailMode.chosen;
  }

  DailyReportSettings copyWith({
    bool? enabled,
    bool? emailEnabled,
    List<String>? emailRecipientUids,
  }) =>
      DailyReportSettings(
        enabled: enabled ?? this.enabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        emailRecipientUids: emailRecipientUids ?? this.emailRecipientUids,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'emailEnabled': emailEnabled,
        'emailRecipientUids': emailRecipientUids,
      };

  factory DailyReportSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const DailyReportSettings();
    return DailyReportSettings(
      // المبدئي `true` في الطرفين — يطابق `readSettings` على الخادم
      // (`r.enabled !== false`). ومستندٌ ناقص يعني «يعمل»، لا «متوقّف».
      enabled: m['enabled'] as bool? ?? true,
      emailEnabled: m['emailEnabled'] as bool? ?? true,
      emailRecipientUids:
          List<String>.from(m['emailRecipientUids'] as List? ?? const []),
    );
  }
}
