/// **موضعٌ واحد يقرّر لونَ كلِّ حالةٍ في المنصة.**
///
/// ــــ ما كان قبله ــــ
///
/// ثمانيةُ مواضعَ تقرّر ألوانَ الحالات، فيها **ثلاثُ نسخٍ متطابقةٍ حرفاً**
/// من مفتاحِ نمطِ الإعلان (في لافتة الإعلانات، ولافتة التنبيهات، وشاشة
/// المظهر). ولونُ العائق `#E0692B` **حرفاً مكرّراً في عشرة مواضع** بلا اسم.
/// ودرجتا أولويةٍ حرفيّتان كذلك.
///
/// ــــ وعطلٌ كان قائماً ــــ
///
/// حالةُ المهمّة «قيد المراجعة» كانت تُلوَّن بلون **التمييز**، ولونُ
/// التمييز يختاره مسؤولُ النظام من شاشة المظهر. فمن اختار تمييزاً أحمر صارت
/// «قيد المراجعة» **مطابقةً حرفاً** لـ«متعثّرة» — معنيان بلونٍ واحد. وقِيس
/// ذلك قبل الإصلاح.
///
/// ــــ القاعدة ــــ
///
/// **اللونُ لنقل معنى لا للزينة.** ولذلك لا يدخل لونُ الهوية هنا إطلاقاً:
/// الهويةُ ذوقٌ يتبدّل، والمعنى لا يتبدّل.
library;

import 'package:flutter/material.dart';

import 'app_palette.dart';

/// لونُ معنىً بأدواره الخمسة.
///
/// ولا يُكتفى بلونٍ واحد: ما يُملأ به سطحٌ ليس ما يُكتب به نصّ. و[onFill]
/// مختارٌ لكلِّ معنىً على حدة ومقيسٌ تباينُه — فالأصفرُ يحمل نصّاً داكناً،
/// والأحمرُ يحمل أبيض.
@immutable
class StatusTone {
  /// اسمُ المعنى بالعربية — يظهر في رسائل الاختبارات لا في الواجهة.
  final String name;

  /// اللونُ الصريح: شريطٌ، نقطةٌ، ملءُ شارة.
  final Color fill;

  /// نصٌّ يُقرأ فوق [fill].
  final Color onFill;

  /// سطحٌ هادئٌ — خلفيةُ شارةٍ أو صفٍّ مميَّز.
  final Color soft;

  /// حدُّ [soft].
  final Color border;

  /// نصٌّ يُقرأ فوق [soft].
  final Color text;

  const StatusTone({
    required this.name,
    required this.fill,
    required this.onFill,
    required this.soft,
    required this.border,
    required this.text,
  });

  /// يبني نغمةً من درجات لونٍ واحد.
  ///
  /// و[onFill] وسيطٌ صريحٌ لا مشتقّ: اشتقاقُه بالإضاءة يُخطئ عند الأصفر
  /// والبرتقالي — وهما أكثرُ ما يقع فيه هذا الخطأ.
  ///
  /// ومصنعٌ لا مُنشئٌ ثابت: Dart لا تقرأ حقلَ كائنٍ ثابتٍ داخل مُنشئٍ ثابت.
  /// والنغمةُ تبقى غيرَ قابلةٍ للتغيير — وهو المقصود، لا الثباتُ وقتَ الترجمة.
  factory StatusTone.of(Swatch s, {required String name, required Color onFill}) =>
      StatusTone(
        name: name,
        fill: s.s600,
        onFill: onFill,
        soft: s.s50,
        border: s.s100,
        text: s.s800,
      );

  @override
  bool operator ==(Object other) =>
      other is StatusTone && other.fill == fill && other.soft == soft;

  @override
  int get hashCode => Object.hash(fill, soft);
}

/// ألوانُ الحالات — **المصدرُ الوحيد**.
class StatusPalette {
  static const _white = Colors.white;


  /// نجاحٌ وإنجاز.
  static final success =
      StatusTone.of(AppPalette.green, name: 'نجاح', onFill: _white);

  /// تحذيرٌ وما يحتاج انتباهاً — **ونصُّه داكن**: الأبيضُ على الأصفر لا يُقرأ.
  static final warning =
      StatusTone.of(AppPalette.amber, name: 'تحذير', onFill: AppPalette.ink);

  /// خطرٌ وتأخير.
  static final danger =
      StatusTone.of(AppPalette.red, name: 'خطر', onFill: _white);

  /// معلومةٌ ونشاط.
  static final info =
      StatusTone.of(AppPalette.blue, name: 'معلومة', onFill: _white);

  /// **عائق** — يوقف العمل، وهو غيرُ الخطر الذي يهدّده.
  static final blocker =
      StatusTone.of(AppPalette.orange, name: 'عائق', onFill: _white);

  /// تصنيفٌ إداريّ لا إنذارَ فيه.
  static final category =
      StatusTone.of(AppPalette.violet, name: 'تصنيف', onFill: _white);

  /// تدريبٌ وما يُصنَّف ولا يُنذر.
  static final learning =
      StatusTone.of(AppPalette.teal, name: 'تدريب', onFill: _white);

  /// غيرُ نشطٍ أو مغلقٍ أو مجهول.
  static final neutral =
      StatusTone.of(AppPalette.slate, name: 'محايد', onFill: _white);

  /// كلُّ النغمات — يمرّ عليها اختبارُ التباين فلا تُضاف نغمةٌ لا تُقرأ.
  static final List<StatusTone> allTones = [
    success, warning, danger, info, blocker, category, learning, neutral,
  ];

  /// نغمةٌ باسمها — **وهو البابُ الوحيد الذي يفتحه مسؤولُ النظام**.
  ///
  /// ــ ولماذا اسمٌ لا لون ــ
  ///
  /// أنواعُ الحالات اليومية قائمةٌ يحرّرها مسؤولُ النظام: يضيف «عملاً عن
  /// بُعد» ويختار له لوناً. ولو خُزّن اللونُ رقماً في المستند لَصار في
  /// المنصّة **موضعٌ ثانٍ يقرّر لونَ معنى**، ولَعجز الحارسُ الرابعَ عشر عن
  /// رؤيته: هو يقرأ الشيفرةَ لا قاعدةَ البيانات.
  ///
  /// فالمخزَّن **اسمُ نغمة**، والنغماتُ الثمانُ هنا كما هي. ومسؤولُ النظام
  /// يختار من بينها ولا يخترع لوناً.
  ///
  /// وما لا يُعرف محايدٌ لا يُخترع له لون — كسائر مفاتيح هذا الملفّ.
  static StatusTone byToneKey(String key) => switch (key) {
        'success' => success,
        'warning' => warning,
        'danger' => danger,
        'info' => info,
        'blocker' => blocker,
        'category' => category,
        'learning' => learning,
        'neutral' => neutral,
        _ => neutral,
      };

  /// أسماءُ النغمات التي يختار منها مسؤولُ النظام، بمسمّياتها العربية.
  ///
  /// ومن هنا تُبنى قائمةُ الاختيار في شاشة الأنواع، فلا تفترق عن [byToneKey]
  /// — قائمتان تُكتبان بأيديهما تفترقان بأوّل إضافة.
  static const Map<String, String> toneChoices = {
    'success': 'أخضر — حضورٌ وإنجاز',
    'info': 'أزرق — معلومةٌ ونشاط',
    'warning': 'أصفر — يحتاج انتباهاً',
    'danger': 'أحمر — خطرٌ وتأخير',
    'blocker': 'برتقالي — يوقف العمل',
    'category': 'بنفسجي — تصنيفٌ إداريّ',
    'learning': 'فيروزي — تدريبٌ وتعلّم',
    'neutral': 'رمادي — غيرُ نشط',
  };

  // ــــــــــــــ حالاتُ المشروع ــــــــــــــ

  /// نغمةُ حالةِ مشروع — والمجهولُ محايدٌ لا يُخترع له لون.
  static StatusTone projectTone(String status) => switch (status) {
        'onTrack' => success,
        'atRisk' => warning,
        'delayed' => danger,
        'completed' => info,
        _ => neutral,
      };

  static Color project(String status) => projectTone(status).fill;

  // ــــــــــــــ حالاتُ المهمّة ــــــــــــــ

  /// نغمةُ حالةِ مهمّة.
  ///
  /// و«قيد المراجعة» **بنفسجيّةٌ لا لونَ هوية**: هي مرحلةٌ تنتظر إنساناً،
  /// لا نجاحاً ولا خطراً. وكانت بلون التمييز، فكان تغييرُ الهوية يخلطها
  /// بالمتعثّرة أو بالمنجزة.
  ///
  /// و«بانتظار الاعتماد» تحذيرٌ لا نجاح: العملُ واقفٌ على مكتبٍ لا يتقدّم،
  /// ولونُ النجاح عليه يجعله يبدو منتهياً وهو ليس كذلك.
  static StatusTone taskTone(String status) => switch (status) {
        'todo' => neutral,
        'inProgress' => info,
        'review' => category,
        'awaitingApproval' => warning,
        'blocked' => danger,
        'done' => success,
        _ => neutral,
      };

  static Color task(String status) => taskTone(status).fill;

  // ــــــــــــــ الأولويات ــــــــــــــ

  /// نغمةُ أولوية — أربعُ درجاتٍ متمايزة.
  ///
  /// و«منخفضة» محايدةٌ لا خضراء: الخضرةُ نجاحٌ، وأولويةٌ منخفضةٌ ليست
  /// إنجازاً. وكانت `#5C9E68` حرفاً بلا اسم.
  static StatusTone priorityTone(String priority) => switch (priority) {
        'low' => neutral,
        'medium' => warning,
        'high' => blocker,
        'critical' => danger,
        _ => neutral,
      };

  static Color priority(String priority) => priorityTone(priority).fill;

  // ــــــــــــــ البلاغاتُ ومدَدُها ــــــــــــــ

  /// نغمةُ حالةِ بلاغ.
  ///
  /// و«بانتظار المستفيد» بلونٍ مميَّزٍ لا بالمحايد: هي الحالةُ التي **توقف
  /// ساعةَ الحلّ**، ومن يقرأ الطابورَ يحتاج أن يميّزها بنظرةٍ ليعرف أين
  /// يقف العملُ ولماذا.
  static StatusTone ticketTone(String status) => switch (status) {
        'open' => warning,
        'inProgress' => info,
        'waitingOnReporter' => category,
        'resolved' => success,
        'closed' => neutral,
        _ => neutral,
      };

  /// نغمةُ حالةِ مشكلة.
  ///
  /// و«حلٌّ مؤقّت» بلونٍ مميَّزٍ لا بلون النجاح: المستفيدُ يعمل والسببُ
  /// باقٍ، فهو دَينٌ لا إنجاز. ولونُ النجاح عليه يجعله يبدو منتهياً.
  static StatusTone problemTone(String status) => switch (status) {
        'investigating' => warning,
        'workaroundFound' => category,
        'rootCauseFound' => info,
        'resolved' => success,
        'closed' => neutral,
        _ => neutral,
      };

  /// نغمةُ حالةِ تغيير.
  ///
  /// و«نُفِّذ» ليست نجاحاً بذاتها: قد يكون طارئاً لم يُراجَع بعد. والنجاحُ
  /// للمعتمَد وحدَه — ووسمُ المراجعة يُعرض إلى جانبها لا مكانَها.
  static StatusTone changeTone(String status) => switch (status) {
        'draft' => neutral,
        'awaitingApproval' => warning,
        'approved' => success,
        'rejected' => danger,
        'implemented' => info,
        'rolledBack' => blocker,
        'closed' => neutral,
        _ => neutral,
      };

  /// نغمةُ ساعةِ المدّة — **والمعنى واحدٌ أينما وقع**.
  ///
  /// «تجاوز» خطرٌ كالمشروع المتأخّر، و«يوشك» تحذيرٌ كالعقد الذي يقارب
  /// انتهاءه. ولو أُعطيت ألواناً خاصّةً بها لَقُرئ اللونُ تصنيفاً للنوع لا
  /// للخطورة — وهو ما يُفقد اللونَ معناه في المنصّة كلّها.
  static StatusTone slaTone(String outcome) => switch (outcome) {
        'breached' => danger,
        'missed' => danger,
        'atRisk' => warning,
        'onTrack' => success,
        'met' => success,
        _ => neutral,
      };

  // ــــــــــــــ حالاتُ القرار ــــــــــــــ

  static StatusTone decisionTone(String status) => switch (status) {
        'pending' => warning,
        'approved' => success,
        'rejected' => danger,
        'returnedForRevision' => info,
        _ => neutral,
      };

  // ــــــــــــــ الشكاوى والاقتراحات ــــــــــــــ

  static StatusTone feedbackTone(String status) => switch (status) {
        'submitted' => info,
        'inReview' => warning,
        'resolved' => success,
        'dismissed' => neutral,
        _ => neutral,
      };

  // ــــــــــــــ أنماطُ الإعلانات والتنبيهات ــــــــــــــ
  //
  // وكان هذا المفتاحُ **مكتوباً ثلاثَ مرّاتٍ متطابقة** في ثلاثة ملفّات.

  static StatusTone announcementTone(String style) => switch (style) {
        'info' => info,
        'success' => success,
        'warning' => warning,
        'danger' => danger,
        _ => info,
      };

  /// وأيقونةُ النمط كذلك — **وكانت مكرّرةً هي الأخرى**.
  ///
  /// فاللونُ والأيقونةُ قرارٌ واحد: «هذا تحذير» يُقال بالاثنين معاً. ولو
  /// افترقا لَظهر يوماً إعلانٌ بلونِ خطرٍ وأيقونةِ معلومة.
  static IconData announcementIcon(String style) => switch (style) {
        'info' => Icons.info_outline_rounded,
        'success' => Icons.check_circle_outline_rounded,
        'warning' => Icons.warning_amber_rounded,
        'danger' => Icons.error_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  // ــــــــــــــ بنودُ التقرير الدوري ــــــــــــــ

  static StatusTone reportItemTone(String status) => switch (status) {
        'needsIntervention' => danger,
        'late_' => blocker,
        'needsFollowUp' => warning,
        'normal' => success,
        _ => neutral,
      };

  // ــــــــــــــ شدّةُ بند التقرير اليومي ــــــــــــــ

  static StatusTone severityTone(String severity) => switch (severity) {
        'critical' => danger,
        'needsAttention' => warning,
        'normal' => success,
        _ => neutral,
      };

  // ــــــــــــــ مستوى النشاط في التقرير الدوري ــــــــــــــ

  /// و«متوسّط» **معلومةٌ زرقاء لا لونَ هوية**.
  ///
  /// كان `AppColors.primary` — وهو ثاني تسرُّبٍ للهوية إلى المعنى بعد «قيد
  /// المراجعة»: من غيّر لونَ منصّته غيّر معه معنى «نشاطٍ متوسّط». والنشاطُ
  /// خبرٌ يُقال لا حكمٌ يُصدَر، فالأزرقُ بابُه.
  static StatusTone activityTone(String level) => switch (level) {
        'high' => success,
        'medium' => info,
        'low' => warning,
        'none' => neutral,
        _ => neutral,
      };

  // ــــــــــــــ خلايا التقويم ــــــــــــــ

  static StatusTone calendarDayTone(String state) => switch (state) {
        'hasUpdate' => success,
        'missed' => warning,
        'disabled' => neutral,
        _ => neutral,
      };

  // ــــــــــــــ قربُ الاستحقاق ــــــــــــــ

  /// نغمةُ موعدِ استحقاق — «متأخر» و«متبقّي ثلاثة أيام» و«مكتمل».
  ///
  /// وكانت مكتوبةً في `projects_list_screen.dart` باسم `_dueColor`: دالّةٌ
  /// تقرّر أخضرَ وأحمرَ وأصفرَ في شاشة. ومرّت على الحارس **صامتة** لأنّها
  /// صيغةُ `if`/`return` لا ذراعَ مفتاح — والقرارُ واحدٌ وإن اختلفت الصيغة.
  ///
  /// و**أسبوعٌ أو أقلّ تحذيرٌ لا اطمئنان**: هو آخرُ ما يمكن التصرّفُ فيه.
  /// والحدُّ هنا لا في شاشة، فلا تفترق شاشتان في معنى «يوشك».
  ///
  /// وبأعدادٍ لا بمشروع: `StatusPalette` لا تعرف النماذج ولا تستوردها —
  /// ولو عرفتها لصار موضعُ قرارِ اللون تابعاً لشكل البيانات.
  static const int dueSoonDays = 7;

  static StatusTone dueTone({
    required bool completed,
    required int delayDays,
    required int remainingDays,
  }) {
    if (completed) return success;
    if (delayDays > 0) return danger;
    return remainingDays <= dueSoonDays ? warning : success;
  }

  // ــــــــــــــ نسبةُ الإنجاز ــــــــــــــ

  /// نغمةُ شريطِ إنجازٍ بنسبته.
  ///
  /// والحدّان ٧٥ و٤٠ كما كانا في `LabeledProgressBar` — نُقلا إلى هنا فلا
  /// يبقى قرارُ لونٍ في ودجة.
  static StatusTone progressTone(double percent) {
    if (percent >= 75) return success;
    if (percent >= 40) return warning;
    return danger;
  }
}
