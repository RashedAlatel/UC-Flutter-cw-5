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
  });

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
    bool clearSection = false,
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
    );
  }

  static List<String> _uidList(Object? raw, {String? legacy}) {
    final list = (raw as List?)?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (list != null && list.isNotEmpty) return list;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return const [];
  }
}
