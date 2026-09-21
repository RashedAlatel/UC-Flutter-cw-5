/// بلاغٌ أو طلبُ خدمة — **مستندٌ واحدٌ لصنفين**.
///
/// ــــ ولماذا مجموعةٌ واحدة لا مجموعتان ــــ
///
/// العطلُ («الطابعة لا تعمل») وطلبُ الخدمة («أحتاج ترخيصَ برنامج») يفترقان
/// في المعنى ويتّفقان في **دورة الحياة كلِّها**: يُفتح، يُسنَد، يُعالَج، قد
/// ينتظر المستفيد، يُحلّ، يُغلق. ومدّةُ الاستجابة تُقاس فيهما بالطريقة
/// نفسِها.
///
/// فلو شُقّا مجموعتين لَصار لكلٍّ قاعدةُ أمانٍ ومستمعٌ وشاشةٌ ومرشِّح —
/// أربعةُ مواضعَ تنحرف إحداها عن أختها في أوّل تعديل. وحقلٌ واحد [kind]
/// يفرّق بينهما حيث يجب أن يفترقا: في التسمية والتقرير.
library;

import 'enums.dart';
import 'safe_read.dart';

/// صنفُ الطلب — عطلٌ أصاب ما كان يعمل، أو طلبٌ لشيءٍ جديد.
enum TicketKind {
  incident('بلاغُ عطل'),
  serviceRequest('طلبُ خدمة');

  final String label;
  const TicketKind(this.label);

  static TicketKind fromName(String name) => TicketKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => TicketKind.incident,
      );
}

/// حالةُ البلاغ.
///
/// و«بانتظار المستفيد» ليست زينةً: هي الحالةُ التي **توقف ساعةَ الحلّ**،
/// فتُسجَّل مدّتُها في `waitingMs` ويُزاح بها الموعد. ولولاها لَحُسبت مدّةُ
/// انتظارِ جوابِ المستفيد على الفنّيّ، واتُّهم بتجاوزٍ لم يفعله.
enum TicketStatus {
  open('مفتوح'),
  inProgress('قيد المعالجة'),
  waitingOnReporter('بانتظار المستفيد'),
  resolved('حُلَّ'),
  closed('مُغلق');

  final String label;
  const TicketStatus(this.label);

  static TicketStatus fromName(String name) => TicketStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TicketStatus.open,
      );

  /// هل ما زال في طابور العمل؟ — والمحلولُ خرج منه وإن لم يُغلق بعد.
  bool get isActive => this == open || this == inProgress || this == waitingOnReporter;
}

class Ticket {
  final String id;
  final TicketKind kind;
  final String title;
  final String description;

  /// تصنيفٌ حرٌّ (شبكة، طابعات، بريد، نظام…) — نصٌّ لا تعداد، فتصنيفاتُ
  /// كلّ وزارةٍ تختلف ولا تُفرض من الشيفرة.
  final String category;

  final PriorityLevel priority;
  final TicketStatus status;

  /// ــ المُبلِّغ ــ
  ///
  /// وهو **المالك**: يقرأ بلاغَه بمِلكيّته إيّاه لا بمفتاح صلاحية. واسمُه
  /// وإدارتُه منسوخان للعرض بلا قراءةٍ ثانية — كما في [WorkItem].
  final String reporterUid;
  final String reporterName;
  final String reporterDepartmentId;

  /// الفنّيُّ المُسنَد إليه — وفارغٌ يعني **بلا مُسنَد**، وهو مرشِّحٌ في
  /// الطابور لا حالةٌ ناقصة.
  final String assigneeUid;
  final String assigneeName;

  /// ــ الأوقاتُ الأربعة ــ
  ///
  /// [createdAt] تفرضه القاعدةُ `request.time`، فلا يُزوَّر. والثلاثةُ
  /// الباقية تُختم عند الانتقال، وتبقى `null` قبله — ولا تُختلق.
  final DateTime createdAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  final String resolutionNote;

  /// جوابُ المستفيد حين يُسأل — الحقلُ الوحيد الذي يكتبه غيرُ المعالِج.
  final String reporterReply;

  /// المشكلةُ التي يندرج تحتها هذا البلاغ — أو فارغٌ.
  ///
  /// والربطُ هنا لا في مستند المشكلة: حقلٌ واحدٌ يحتاج كتابةً واحدةً عند
  /// الربط والفكّ، وقائمةٌ هناك تحتاج كتابتين متّسقتين — راجع `problem.dart`.
  final String problemId;

  /// ــ كم انتظر البلاغُ جوابَ صاحبه، مجموعاً بالمللي ثانية ــ
  ///
  /// يُزاد عند الخروج من [TicketStatus.waitingOnReporter]، وتقرؤه ساعةُ
  /// الحلّ لتُزيح الموعدَ بقدره. وهو **فعلٌ مسجَّل** كـ[firstResponseAt]،
  /// لا هدفٌ ولا علَمُ تجاوز — راجع `lib/itsm/sla.dart`.
  final int waitingMs;

  /// متى بدأ الانتظارُ الجاري — و`null` تعني أنّ الدورَ ليس على المستفيد.
  final DateTime? waitingSince;

  /// مدّةُ الانتظار حتّى لحظةٍ بعينها: المسجَّلُ، ومعه الجاري إن كان.
  ///
  /// و`isAfter` تحرس من السالب: ساعةُ جهازٍ متأخّرةٌ عن الخادم تُنتج فرقاً
  /// سالباً **يُقصّر** المهلة بدل أن يُطيلها — أي يتّهم الفنّيّ بتجاوزٍ
  /// سببُه ساعةُ حاسوبٍ لا عملُه.
  Duration waitingUpTo(DateTime instant) {
    var ms = waitingMs < 0 ? 0 : waitingMs;
    final since = waitingSince;
    if (since != null && instant.isAfter(since)) {
      ms += instant.difference(since).inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  /// ــ الحذف المنطقيّ ــ نظيرُه في [WorkItem] بالاصطلاح نفسِه.
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;
  bool get isAssigned => assigneeUid.isNotEmpty;

  const Ticket({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    this.category = '',
    required this.priority,
    required this.status,
    required this.reporterUid,
    required this.reporterName,
    this.reporterDepartmentId = '',
    this.assigneeUid = '',
    this.assigneeName = '',
    required this.createdAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.resolutionNote = '',
    this.reporterReply = '',
    this.problemId = '',
    this.waitingMs = 0,
    this.waitingSince,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  /// ــ ولماذا يُكتب المستندُ كاملاً ولا يُرقَّع ــ
  ///
  /// [toMap] تكتب الوثيقةَ كلَّها. فحقلٌ جديدٌ يُضاف إلى الصنف ولا يُضاف
  /// إلى [copyWith] **يُمحى من المستند في أوّل تعديل**. وقد وقع ذلك في
  /// `project.dart` ثلاث مرّات. فكلُّ حقلٍ هنا له نظيرُه هناك.
  Ticket copyWith({
    TicketKind? kind,
    String? title,
    String? description,
    String? category,
    PriorityLevel? priority,
    TicketStatus? status,
    String? reporterUid,
    String? reporterName,
    String? reporterDepartmentId,
    String? assigneeUid,
    String? assigneeName,
    DateTime? createdAt,
    DateTime? firstResponseAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    String? resolutionNote,
    String? reporterReply,
    String? problemId,
    int? waitingMs,
    DateTime? waitingSince,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      Ticket(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        reporterUid: reporterUid ?? this.reporterUid,
        reporterName: reporterName ?? this.reporterName,
        reporterDepartmentId: reporterDepartmentId ?? this.reporterDepartmentId,
        assigneeUid: assigneeUid ?? this.assigneeUid,
        assigneeName: assigneeName ?? this.assigneeName,
        createdAt: createdAt ?? this.createdAt,
        firstResponseAt: firstResponseAt ?? this.firstResponseAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        closedAt: closedAt ?? this.closedAt,
        resolutionNote: resolutionNote ?? this.resolutionNote,
        reporterReply: reporterReply ?? this.reporterReply,
        problemId: problemId ?? this.problemId,
        waitingMs: waitingMs ?? this.waitingMs,
        waitingSince: waitingSince ?? this.waitingSince,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority.name,
        'status': status.name,
        'reporterUid': reporterUid,
        'reporterName': reporterName,
        'reporterDepartmentId': reporterDepartmentId,
        'assigneeUid': assigneeUid,
        'assigneeName': assigneeName,
        'createdAt': createdAt,
        'firstResponseAt': firstResponseAt,
        'resolvedAt': resolvedAt,
        'closedAt': closedAt,
        'resolutionNote': resolutionNote,
        'reporterReply': reporterReply,
        'problemId': problemId,
        'waitingMs': waitingMs,
        'waitingSince': waitingSince,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  /// ــ ولا حقلَ يُقرأ بـ`as` ــ
  ///
  /// راجع `safe_read.dart`: مستندٌ واحدٌ حمل تاريخاً نصّاً فأسقط مئةً
  /// وأربعةً وثمانين مشروعاً يوماً كاملاً. فكلُّ تاريخٍ هنا بـ[readDate]،
  /// وكلُّ نصٍّ بـ[readText].
  factory Ticket.fromMap(String id, Map<String, dynamic> j) => Ticket(
        id: id,
        kind: TicketKind.fromName(readText(j['kind'])),
        title: readText(j['title']),
        description: readText(j['description']),
        category: readText(j['category']),
        priority: PriorityLevel.fromName(
            readText(j['priority']).isEmpty ? PriorityLevel.medium.name : readText(j['priority'])),
        status: TicketStatus.fromName(readText(j['status'])),
        reporterUid: readText(j['reporterUid']),
        reporterName: readText(j['reporterName']),
        reporterDepartmentId: readText(j['reporterDepartmentId']),
        assigneeUid: readText(j['assigneeUid']),
        assigneeName: readText(j['assigneeName']),
        // ولا يُختلق وقتُ الفتح: مستندٌ بلا `createdAt` يُقرأ بأقدم وقتٍ
        // ممكن لا بوقت القراءة — فساعةُ المدّة عليه تبدأ حيث بدأ فعلاً.
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        firstResponseAt: readDate(j['firstResponseAt']),
        resolvedAt: readDate(j['resolvedAt']),
        closedAt: readDate(j['closedAt']),
        resolutionNote: readText(j['resolutionNote']),
        reporterReply: readText(j['reporterReply']),
        problemId: readText(j['problemId']),
        waitingMs: (readNum(j['waitingMs']) ?? 0).round(),
        waitingSince: readDate(j['waitingSince']),
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
