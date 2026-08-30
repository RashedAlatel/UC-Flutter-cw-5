import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'enums.dart';

class Project {
  final String id;
  final String departmentId;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime dueDate;
  final ProjectStatus status;
  final PriorityLevel priority;
  final double progressPercent; // 0-100
  final List<String> executorNames; // الأشخاص المنفذون/المسؤولون عن المشروع (يمكن أن يكون أكثر من شخص)
  final String createdByUid;

  /// حسابات مديري المشروع.
  ///
  /// كان مديراً واحداً في حقل `managerUid`، وصار قائمةً بقرار من مسؤول
  /// النظام: مشروع واحد قد يقوده أكثر من موظف. والحقل المفرد يبقى مكتوباً في
  /// المستند (أول عنصر) ليفهمه أي قارئ قديم، ويبقى مقروءاً كخاصية مشتقّة
  /// أدناه فلا تحتاج عشرات مواضع الاستدعاء القائمة أي تعديل.
  final List<String> managerUids;

  /// حسابات المنفّذين المسجَّلين على المشروع.
  ///
  /// غير [executorNames]: تلك أسماء نصية وردت في ملفات الوزارة ولا تقابلها
  /// حسابات في المنصة، وهذه حسابات فعلية تنضمّ بنفسها أو يُسندها مسؤول
  /// النظام. ولا تُدمجان: دمجهما يُفقد التمييز بين اسم مكتوب وحساب مسؤول.
  final List<String> executorUids;

  /// القسم (أو القسم الفرعي) داخل الإدارة — راجع [DepartmentSection].
  /// null يعني مشروعاً تحت الإدارة مباشرةً بلا قسم.
  final String? sectionId;

  /// الإدارةُ التي كان فيها قبل آخر نقل — و`null` لمشروعٍ لم يُنقل قطّ.
  ///
  /// ولا يُقرأ منها تاريخٌ كامل: هي **آخرُ** نقلة لا كلُّ النقلات. وسجلُّ
  /// النقلات كاملاً في سجل التدقيق، وهو موضعُه: لا يُعدَّل ولا يُحذف.
  final String? previousDepartmentId;

  /// متى نُقل المشروع آخرَ مرّة — «تاريخ النقل» الذي طُلب تسجيلُه.
  ///
  /// ويُكتب من **الخادم** وحده مع النقل نفسه، فلا يُدّعى نقلٌ لم يقع.
  final DateTime? departmentTransferredAt;

  /// هل نُقل هذا المشروع بين الإدارات؟ وبها يُعرض سطرُ النقل في صفحته.
  bool get wasTransferred =>
      departmentTransferredAt != null && (previousDepartmentId ?? '').isNotEmpty;

  /// تاريخ **إضافة** المشروع إلى المنصة — لا تاريخ بدئه.
  ///
  /// والفرق جوهري لترتيب «الأحدث»: مشروعٌ خُطّط بدؤه العام الماضي وأُضيف
  /// اليوم هو الأحدث إضافةً وأقدمها بدءاً.
  ///
  /// null لمشاريع الوزارة المستوردة وكل ما كُتب قبل هذا الحقل. ولا يُختلق لها
  /// تاريخ: `DateTime.now()` عند القراءة يجعل كل مشروع قديم «مُضافاً الآن»
  /// ويتصدّر الترتيب كذباً. تُرتَّب بتاريخ بدئها ويُقال ذلك في الشاشة.
  final DateTime? createdAt;

  /// تصنيفات عرضية يسِم بها مسؤول النظام المشروع — راجع [ProjectCategory].
  ///
  /// قائمة لا حقلاً مفرداً: التصنيف يقطع الهيكل التنظيمي، فمشروع واحد قد
  /// يكون «رقمنة» و«أولوية وزارية» معاً. وهذا يجعل «الترتيب حسب التصنيف»
  /// **تجميعاً** لا فرزاً — فالمشروع يظهر تحت كل تصنيف يحمله.
  final List<String> categoryIds;

  /// ــــ بيانات العقد ــــ
  ///
  /// **و`null` تعني «غير مسجّل» لا صفراً ولا تاريخاً.** وهذا هو الفرق كلُّه:
  /// مشاريع الوزارة المائةُ والثمانية المستوردة لا تحمل عقوداً في المنصة،
  /// فلو قُرئ غيابُها صفراً لَظهرت «قيمة العقد: ٠ د.ك» على مشروعٍ قيمتُه
  /// مئات الألوف — وهو **ادّعاءُ رقمٍ** لا نقصُ بيان.
  ///
  /// وهي القاعدة نفسُها التي حكمت `completedAt` على المهام: غيابُ الحقل
  /// يُقال صراحةً ولا يُملأ بقيمةٍ مختلقة.
  final DateTime? contractDate;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final DateTime? invoiceDueDate;

  /// مدّةُ المشروع بالأيام — **منصوصةٌ لا مشتقّة**.
  ///
  /// ولا تُحسب من [startDate] و[dueDate] بقصد: ذلك فرقٌ تقويمي، وهذه مدّةٌ
  /// مكتوبةٌ في عقدٍ قد تخالفه — تُعلَّق الأعمال، وتُمدَّد المدّة بملحقٍ بلا
  /// تغيير تاريخ الاستحقاق. واشتقاقُها يجعل المدير يقرأ رقماً لم يوقّع عليه
  /// أحد ولا يجده في العقد الذي بين يديه.
  final int? durationDays;

  /// قيمةُ العقد بالدينار الكويتي.
  final double? contractValue;

  /// الجهةُ أو الشركة المنفّذة — نصٌّ حرّ، وفارغُه «غير مسجّل».
  final String contractorName;

  /// هل سُجّل شيءٌ من بيانات العقد أصلاً؟ تُعرض به بطاقةُ العقد أو تُخفى،
  /// فلا تظهر على كل مشروعٍ بطاقةٌ كلُّها «غير مسجّل».
  bool get hasContractData =>
      contractDate != null ||
      contractStartDate != null ||
      contractEndDate != null ||
      invoiceDueDate != null ||
      durationDays != null ||
      contractValue != null ||
      contractorName.trim().isNotEmpty;

  const Project({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.dueDate,
    required this.status,
    required this.priority,
    required this.progressPercent,
    this.executorNames = const [],
    this.createdByUid = '',
    this.managerUids = const [],
    this.executorUids = const [],
    this.sectionId,
    this.previousDepartmentId,
    this.departmentTransferredAt,
    this.categoryIds = const [],
    this.createdAt,
    this.contractDate,
    this.contractStartDate,
    this.contractEndDate,
    this.invoiceDueDate,
    this.durationDays,
    this.contractValue,
    this.contractorName = '',
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
    this.convertedFromType,
    this.convertedFromId,
    this.convertedToType,
    this.convertedToId,
  });

  /// ــ الحذف المنطقي ــ
  ///
  /// المشروع لا يُمحى من قاعدة البيانات، بل يُعلَّم محذوفاً فيختفي من كل
  /// قائمة ويبقى قابلاً للاستعادة. وحذفُه قبل ذلك كان **نهائياً متسلسلاً**
  /// يمحو مهامّه وتحديثاته ومخاطره وعوائقه معه بلا رجعة.
  ///
  /// والحقول ثلاثةٌ لأن «متى» وحدها لا تكفي في سجلٍّ حكومي: من قرّر، ولماذا.
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  /// ــ التحويل بين مشروعٍ وعمل ــ
  ///
  /// التحويل لا يَنقُل السجل بل **يُنشئ نظيره ويؤرشف الأصل**: المهام
  /// والتحديثات والمرفقات والمخاطر والعوائق كلُّها معلّقة بمعرّف الأصل، ونقلُها
  /// إلى معرّفٍ جديد يعني إعادة كتابة كل واحدٍ منها — وأيُّ سطرٍ يسقط في
  /// المنتصف يترك تاريخاً مبتوراً لا يُعرف أين ذهب.
  ///
  /// فيبقى التاريخ كلُّه على الأصل المؤرشف، ويُوصَل الاثنان بحقلين في
  /// الاتجاهين: من الجديد إلى ما جاء منه، ومن الأصل إلى ما صار إليه. ومن
  /// دون الاتجاه الثاني لا تعرف شاشةُ المحذوفات أن هذا الأصل **حُوّل** لا
  /// حُذف، فتعرض له زرَّ استعادةٍ يُحيي نسخةً ثانية من الشيء نفسه.
  final String? convertedFromType;
  final String? convertedFromId;
  final String? convertedToType;
  final String? convertedToId;

  /// هل أُرشِف هذا السجل لأنه **حُوّل** لا لأنه حُذف؟
  bool get wasConverted => convertedToId != null && convertedToId!.isNotEmpty;

  /// أول مديري المشروع — للتوافق مع المواضع التي تتعامل مع مدير واحد.
  String? get managerUid => managerUids.isEmpty ? null : managerUids.first;

  /// هل هذا الحساب عضو في المشروع بأي صفة؟
  bool hasMember(String? uid) =>
      uid != null && (managerUids.contains(uid) || executorUids.contains(uid));

  bool isManager(String? uid) => uid != null && managerUids.contains(uid);
  bool isExecutor(String? uid) => uid != null && executorUids.contains(uid);

  /// نص واحد يجمع كل أسماء المنفذين مفصولة بفاصلة، للاستخدام في الأماكن
  /// التي تعرض نصاً واحداً بدل قائمة (جداول، تصدير التقارير...).
  String get executorLabel => executorNames.join('، ');

  /// أسماء المنفّذين مختصرةً للعرض في بطاقة ضيّقة.
  ///
  /// القائمة الكاملة تبقى في صفحة المشروع؛ أما البطاقة فتُقرأ بلمحة، وسردُ
  /// كل الأسماء بأدوارها فيها يصنع جداراً من نصّ لا يُقرأ — وهو ما كان
  /// يخرج من إطار البطاقة على الجوال.
  String get executorSummary {
    if (executorNames.length <= 2) return executorLabel;
    final rest = executorNames.length - 2;
    return '${executorNames.take(2).join('، ')} و$rest ${rest == 1 ? 'آخر' : 'آخرين'}';
  }

  /// أيام التأخير عن الخطة، محسوبة ديناميكياً في كل مرة (الفرق بين اليوم
  /// الحالي وتاريخ الاستحقاق) بدل قيمة ثابتة تُخزَّن وتتجمّد عند الإدخال —
  /// 0 لأي مشروع مكتمل أو لم يتجاوز موعده النهائي بعد.
  int get delayDays {
    if (status == ProjectStatus.completed) return 0;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    return now.isAfter(due) ? now.difference(due).inDays : 0;
  }

  /// الأيام المتبقية حتى الاستحقاق — سالبةٌ لمن تجاوز موعده.
  ///
  /// يُعرض بجانب كل مشروع بدل تاريخ الاستحقاق وحده: «متبقي ٣ أيام» يُقرأ
  /// بلمحة، أما «٢٠٢٦/٠٩/٠١» فيُحوجُ القارئ إلى حساب المدة بنفسه في كل مرة.
  int get remainingDays {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    return due.difference(now).inDays;
  }

  /// الحالة التي تُعرض للمستخدم — **مصدر الحقيقة الوحيد**.
  ///
  /// كانت البطاقة الواحدة تعرض مصدرين متناقضين: شارة الحالة من الحقل
  /// المخزَّن، وسطر «متأخر N يوم» محسوباً من تاريخ الاستحقاق. فرأى مسؤول
  /// النظام مشاريع متأخرة مكتوباً عليها «على المسار» وعكسها.
  ///
  /// والحقل المخزَّن استُنتج عند الاستيراد من نصوص ملفات الوزارة («جاري
  /// العمل» ← على المسار، «لم يبدأ» ← مهدد بالخطر)، فهو تقدير بشري جامد لا
  /// يعرف مرور الزمن. أما تاريخ الاستحقاق فموضوعي — ولذلك هو الفيصل:
  ///
  /// * المكتمل يبقى مكتملاً مهما مضى من وقت.
  /// * من تجاوز موعده ولم يكتمل فهو **متأخر**، مهما قال الحقل المخزَّن.
  /// * ومن لم يتجاوز موعده فليس متأخراً — ويبقى «مهدد بالخطر» تقديراً بشرياً
  ///   محترماً، لأنه إنذار مبكر لا ادّعاء تأخّر.
  ///
  /// الحقل المخزَّن يبقى في المستند بوصفه ما أُدخل، ولا يُعرض وحده أبداً.
  ProjectStatus get effectiveStatus {
    if (status == ProjectStatus.completed) return ProjectStatus.completed;
    if (delayDays > 0) return ProjectStatus.delayed;
    if (status == ProjectStatus.atRisk) return ProjectStatus.atRisk;
    // مخزَّن «متأخر» وموعده لم يحن: التاريخ يقول إنه ليس متأخراً.
    if (status == ProjectStatus.delayed) return ProjectStatus.onTrack;
    return status;
  }

  /// هل يخالف الحقل المخزَّن ما يقوله التاريخ؟ يستعمله مسؤول النظام في
  /// «مطابقة الحالات المخزّنة».
  bool get statusOutOfSync => status != effectiveStatus;

  Project copyWith({
    String? departmentId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    ProjectStatus? status,
    PriorityLevel? priority,
    double? progressPercent,
    List<String>? executorNames,
    List<String>? managerUids,
    List<String>? executorUids,
    String? sectionId,
    List<String>? categoryIds,
    DateTime? contractDate,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    DateTime? invoiceDueDate,
    int? durationDays,
    double? contractValue,
    String? contractorName,
    bool clearSection = false,
    /// مسحُ بيانات العقد — و`null` وحدها لا تكفي، فهي تعني «لا تغيّر».
    /// ومن أراد أن يقول «لا عقد» يقولها صراحةً.
    bool clearContract = false,
  }) {
    return Project(
      id: id,
      departmentId: departmentId ?? this.departmentId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progressPercent: progressPercent ?? this.progressPercent,
      executorNames: executorNames ?? this.executorNames,
      createdByUid: createdByUid,
      managerUids: managerUids ?? this.managerUids,
      executorUids: executorUids ?? this.executorUids,
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      // ــ أثرُ النقل يُنقَل مع النسخة، كعلامات الحذف تماماً ــ
      //
      // `toMap` تكتب المستند كاملاً، ونسخةٌ بلا هذين الحقلين تمحو من
      // مشروعٍ منقولٍ أنه نُقل — بلا أن يقصد ذلك أحد. وهما يُكتبان من
      // الخادم وحده، فلا سبيل إلى إعادتهما من هنا لو مُحيا.
      previousDepartmentId: previousDepartmentId,
      departmentTransferredAt: departmentTransferredAt,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt,
      contractDate: clearContract ? null : (contractDate ?? this.contractDate),
      contractStartDate:
          clearContract ? null : (contractStartDate ?? this.contractStartDate),
      contractEndDate: clearContract ? null : (contractEndDate ?? this.contractEndDate),
      invoiceDueDate: clearContract ? null : (invoiceDueDate ?? this.invoiceDueDate),
      durationDays: clearContract ? null : (durationDays ?? this.durationDays),
      contractValue: clearContract ? null : (contractValue ?? this.contractValue),
      contractorName: clearContract ? '' : (contractorName ?? this.contractorName),
      // ــ علامات الحذف والتحويل تُنقَل، ولا تُترك للنسيان ــ
      //
      // `toMap` تكتب المستند كاملاً، و`copyWith` بلا هذه الحقول تُنتج نسخةً
      // «غير محذوفة» من سجلٍّ محذوف — فأيُّ حفظٍ عليها يُحييه بلا أن يقصد
      // ذلك أحد ولا أن يُكتب في سجل التدقيق.
      deletedAt: deletedAt,
      deletedBy: deletedBy,
      deletedReason: deletedReason,
      convertedFromType: convertedFromType,
      convertedFromId: convertedFromId,
      convertedToType: convertedToType,
      convertedToId: convertedToId,
    );
  }

  Map<String, dynamic> toMap() => {
        'departmentId': departmentId,
        'name': name,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.name,
        'priority': priority.name,
        'progressPercent': progressPercent,
        'executorNames': executorNames,
        'createdByUid': createdByUid,
        'managerUids': managerUids,
        'executorUids': executorUids,
        // الحقل المفرد الموروث يُكتب دائماً متسقاً مع أول عنصر من القائمة.
        // اتساقه ليس تجميلاً: قاعدة الأمان تشترط أن يكون عضواً في القائمة،
        // وإلا صار باباً لإسناد المشروع لمن ليس فيه.
        'managerUid': managerUids.isEmpty ? null : managerUids.first,
        'sectionId': sectionId,
        // ــ أثرُ النقل يُكتب كما قُرئ، ولا يُختلق ــ
        //
        // والشرطُ هنا لا كحقول العقد: تلك تُكتب فارغةً لأنها **قيمةٌ** يملؤها
        // المستخدم، وهذان أثرُ فعلٍ يكتبه الخادم. ومشروعٌ لم يُنقل لا مفتاحَ
        // له أصلاً، وكتابةُ `null` عليه من العميل تعني أن العميل يقرّر أنه لم
        // يُنقل — وهو لا يقرّر ذلك.
        if (previousDepartmentId != null) 'previousDepartmentId': previousDepartmentId,
        if (departmentTransferredAt != null)
          'departmentTransferredAt': Timestamp.fromDate(departmentTransferredAt!),
        'categoryIds': categoryIds,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        // ــ حقولُ العقد تُكتب **دائماً ولو فارغة** ــ
        //
        // وهذا ليس تزيّداً: وقع في هذا المستودع مرّتين أن سجلاً وُلد ناقصاً
        // حقلاً فرُدّ أوّلُ تعديلٍ عليه — في الأعمال (`ba220b7`) وفي
        // `completedAt` على المهام. والسبب أن `affectedKeys` يشمل المفتاح
        // الذي يُضاف لأوّل مرّة ولو كان فارغاً.
        //
        // وقائمةُ `projects` اليوم قائمةُ **منع** لا سماح، فالخطر غيرُ قائم
        // الآن — لكنه يعود بأوّل تضييقٍ للقاعدة. راجع
        // `test_rules/project_contract.rules.test.mjs`.
        'contractDate': contractDate == null ? null : Timestamp.fromDate(contractDate!),
        'contractStartDate':
            contractStartDate == null ? null : Timestamp.fromDate(contractStartDate!),
        'contractEndDate':
            contractEndDate == null ? null : Timestamp.fromDate(contractEndDate!),
        'invoiceDueDate':
            invoiceDueDate == null ? null : Timestamp.fromDate(invoiceDueDate!),
        'durationDays': durationDays,
        'contractValue': contractValue,
        'contractorName': contractorName,
        // تُكتب دائماً ولو فارغة: `toMap` تُستعمل في تحديثٍ يكتب المستند
        // كاملاً، فحذفُ المفتاح عند الفراغ يُبقي علامةَ حذفٍ قديمة عالقة.
        'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
        'convertedFromType': convertedFromType,
        'convertedFromId': convertedFromId,
        'convertedToType': convertedToType,
        'convertedToId': convertedToId,
      };

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Project._fromMap(doc.id, doc.data() ?? const {});

  /// بناء مشروع من خريطة مباشرةً — للاختبارات، حيث لا يتوفر `DocumentSnapshot`.
  /// يستدعي **نفس** منطق القراءة لا نسخةً منه، فلا يختبر شيئاً غير ما يعمل.
  @visibleForTesting
  static Project fromMapForTest(String id, Map<String, dynamic> json) =>
      Project._fromMap(id, json);

  factory Project._fromMap(String id, Map<String, dynamic> json) {
    // توافق مع مستندات قديمة كانت تخزّن "executorName" كنص واحد فقط.
    final namesList = json['executorNames'] as List?;
    final legacyName = json['executorName'] as String?;
    return Project(
      id: id,
      departmentId: json['departmentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ProjectStatus.fromName(json['status'] as String? ?? ProjectStatus.onTrack.name),
      priority: PriorityLevel.fromName(json['priority'] as String? ?? PriorityLevel.medium.name),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      executorNames: namesList != null
          ? namesList.map((e) => e.toString()).toList()
          : (legacyName != null && legacyName.isNotEmpty ? [legacyName] : const []),
      createdByUid: json['createdByUid'] as String? ?? '',
      // المستندات التي كُتبت قبل القائمة تحمل الحقل المفرد وحده، فتُشتقّ منه
      // القائمة عند القراءة — فلا تحتاج بيانات المنصة القائمة أي ترحيل يدوي.
      managerUids: _uidList(json['managerUids'], legacy: json['managerUid'] as String?),
      executorUids: _uidList(json['executorUids']),
      sectionId: (json['sectionId'] as String?)?.isEmpty ?? true ? null : json['sectionId'] as String?,
      // وغيابُ المفتاح يُقرأ «لم يُنقل» — وهو الصادق: كلُّ ما كُتب قبل هذه
      // الدفعة لم يُنقل بهذا المسار، وما نُقل بالمسار القديم لا أثرَ له.
      previousDepartmentId:
          (json['previousDepartmentId'] as String?)?.isEmpty ?? true ? null : json['previousDepartmentId'] as String?,
      departmentTransferredAt: (json['departmentTransferredAt'] as Timestamp?)?.toDate(),
      // المستندات المكتوبة قبل التصنيفات — وهي كل مشاريع الوزارة المستوردة —
      // تفتقد الحقل، فتُقرأ بقائمة فارغة بلا ترحيل ولا انهيار.
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      categoryIds: (json['categoryIds'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      // الغيابُ يُقرأ `null` — «غير مسجّل» — لا صفراً ولا تاريخاً مختلقاً.
      contractDate: (json['contractDate'] as Timestamp?)?.toDate(),
      contractStartDate: (json['contractStartDate'] as Timestamp?)?.toDate(),
      contractEndDate: (json['contractEndDate'] as Timestamp?)?.toDate(),
      invoiceDueDate: (json['invoiceDueDate'] as Timestamp?)?.toDate(),
      durationDays: (json['durationDays'] as num?)?.toInt(),
      contractValue: (json['contractValue'] as num?)?.toDouble(),
      contractorName: json['contractorName'] as String? ?? '',
      deletedAt: (json['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: json['deletedBy'] as String?,
      deletedReason: json['deletedReason'] as String?,
      convertedFromType: json['convertedFromType'] as String?,
      convertedFromId: json['convertedFromId'] as String?,
      convertedToType: json['convertedToType'] as String?,
      convertedToId: json['convertedToId'] as String?,
    );
  }

  static List<String> _uidList(Object? raw, {String? legacy}) {
    final list = (raw as List?)?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (list != null && list.isNotEmpty) return list;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return const [];
  }
}
