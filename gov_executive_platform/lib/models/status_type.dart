/// نوعُ حالةٍ يوميّة — **قائمةٌ يحرّرها مسؤولُ النظام**.
///
/// ــــ ولماذا تُحرَّر ولا تُكتب في الشيفرة ــــ
///
/// لأنّ الوزارة تُحدث أنواعاً لا نعرفها: «عملٌ عن بُعد»، «انتدابٌ خارجيّ»،
/// «مرافقةُ مريض». ولو كُتبت الثمانيةُ في تعدادٍ لَاحتاج كلُّ نوعٍ جديدٍ
/// إصداراً جديداً من المنصة.
///
/// ــــ واللونُ اسمُ نغمةٍ لا رقم ــــ
///
/// يختار مسؤولُ النظام من ثماني نغماتٍ مسمّاة، ويحوّلها
/// `StatusPalette.byToneKey`. ولو خُزّن اللونُ رقماً لَصار في المنصة موضعٌ
/// ثانٍ يقرّر لونَ معنى — في قاعدة البيانات حيث لا يبلغه الحارس.
library;

import 'safe_read.dart';

class StatusType {
  final String id;
  final String name;

  /// اسمُ النغمة — راجع `StatusPalette.toneChoices`.
  final String toneKey;

  /// أيصلح حالةً تشغل اليومَ كلَّه؟ «حضور» و«إجازة دورية» نعم.
  final bool canBeDay;

  /// أيصلح **خروجاً بوقته** داخل يوم حضور؟ «استئذان» و«مهمّة رسميّة» نعم.
  ///
  /// وهو ما وصفه مسؤولُ النظام: اليومُ حالةٌ واحدة، إلا أن يخرج الموظّف من
  /// الوزارة — فيُضاف خروجٌ بوقته.
  final bool canBeOuting;

  /// أيُحتسب صاحبُه حاضراً في عدّ الملخّص؟
  ///
  /// و«المهمّة الرسميّة» حضورٌ وإن كان خارج المبنى: الموظّف يعمل. أمّا
  /// الإجازةُ فلا. ويبقى القرارُ بيد مسؤول النظام لكلّ نوع، فهو سياسةٌ
  /// إداريّةٌ لا حقيقةٌ تقنيّة.
  final bool countsAsPresent;

  /// أيلزمُه مكان؟ «مهمّة رسميّة» تحتاج أن يُقال أين.
  final bool requiresPlace;

  /// أيلزمُه مرفق؟ «إجازة طبيّة» تحتاج شهادة.
  final bool requiresAttachment;

  final int order;

  /// **ولا حذف**: نوعٌ يُحذف يترك سجلّاتٍ قديمةً بلا اسم. فيُؤرشَف ويبقى
  /// اسمُه يُقرأ في تقارير ما مضى، ولا يُعرض لمن يسجّل اليوم.
  final bool isActive;

  const StatusType({
    required this.id,
    required this.name,
    this.toneKey = 'neutral',
    this.canBeDay = true,
    this.canBeOuting = false,
    this.countsAsPresent = false,
    this.requiresPlace = false,
    this.requiresAttachment = false,
    this.order = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'toneKey': toneKey,
        'canBeDay': canBeDay,
        'canBeOuting': canBeOuting,
        'countsAsPresent': countsAsPresent,
        'requiresPlace': requiresPlace,
        'requiresAttachment': requiresAttachment,
        'order': order,
        'isActive': isActive,
      };

  /// يقرأ بقرّاء `safe_read.dart` الآمنة — فمستندٌ واحدٌ معطوبٌ لا يُفرغ
  /// القائمةَ كلَّها. وهو الدرسُ المكتوب في `parseDocs`.
  static StatusType? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = readText(map['id']);
    final name = readText(map['name']);
    if (id.isEmpty || name.isEmpty) return null;
    return StatusType(
      id: id,
      name: name,
      // ونغمةٌ غائبةٌ محايدةٌ لا مخترَعة — و`byToneKey` تقرّر ذلك، فلا
      // يُكتب القرارُ هنا ثانيةً.
      toneKey: readText(map['toneKey']),
      canBeDay: map['canBeDay'] != false,
      canBeOuting: map['canBeOuting'] == true,
      countsAsPresent: map['countsAsPresent'] == true,
      requiresPlace: map['requiresPlace'] == true,
      requiresAttachment: map['requiresAttachment'] == true,
      order: (readNum(map['order']) ?? 0).toInt(),
      isActive: map['isActive'] != false,
    );
  }

  StatusType copyWith({
    String? name,
    String? toneKey,
    bool? canBeDay,
    bool? canBeOuting,
    bool? countsAsPresent,
    bool? requiresPlace,
    bool? requiresAttachment,
    int? order,
    bool? isActive,
  }) =>
      StatusType(
        id: id,
        name: name ?? this.name,
        toneKey: toneKey ?? this.toneKey,
        canBeDay: canBeDay ?? this.canBeDay,
        canBeOuting: canBeOuting ?? this.canBeOuting,
        countsAsPresent: countsAsPresent ?? this.countsAsPresent,
        requiresPlace: requiresPlace ?? this.requiresPlace,
        requiresAttachment: requiresAttachment ?? this.requiresAttachment,
        order: order ?? this.order,
        isActive: isActive ?? this.isActive,
      );

  /// الأنواعُ الثمانيةُ التي سمّاها مسؤولُ النظام — **بذرةٌ تُحرَّر لا حدٌّ**.
  ///
  /// وتُعرض حين لا يكون المستندُ مكتوباً بعد، فلا تفتح الوزارةُ الشاشةَ على
  /// قائمةٍ خالية.
  static List<StatusType> seed() => const [
        StatusType(
            id: 'present', name: 'حضور', toneKey: 'success',
            countsAsPresent: true, order: 0),
        StatusType(
            id: 'permission', name: 'استئذان', toneKey: 'warning',
            canBeDay: false, canBeOuting: true, order: 1),
        StatusType(
            id: 'mission', name: 'مهمّة رسميّة', toneKey: 'info',
            canBeOuting: true, countsAsPresent: true, requiresPlace: true, order: 2),
        StatusType(
            id: 'sickLeave', name: 'إجازة طبيّة', toneKey: 'danger',
            requiresAttachment: true, order: 3),
        StatusType(
            id: 'annualLeave', name: 'إجازة دوريّة', toneKey: 'category', order: 4),
        StatusType(
            id: 'training', name: 'تدريب', toneKey: 'learning',
            countsAsPresent: true, order: 5),
        StatusType(
            id: 'fieldWork', name: 'عمل خارجيّ', toneKey: 'blocker',
            canBeOuting: true, countsAsPresent: true, requiresPlace: true, order: 6),
        StatusType(id: 'other', name: 'أخرى', toneKey: 'neutral',
            canBeOuting: true, order: 7),
      ];
}
