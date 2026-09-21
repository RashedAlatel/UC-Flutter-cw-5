/// إحصاء ارتباطات مستخدمٍ قبل حذفه نهائياً.
///
/// ــــ لماذا يُحسب على الخادم؟ ــــ
///
/// لأن العميل لا يقرأ كل المجموعات: قواعد Firestore تُصفّي ما يصله بنطاق
/// قارئه. فإحصاءٌ يُبنى هنا يقول «لا شيء على هذا الحساب» لمن يقود خمسة
/// مشاريع في إدارةٍ لا يراها مسؤول الشاشة — ثم يُحذف الحساب على ذلك.
///
/// فيُحسب في `inspectUserForDeletion` بصلاحيات المسؤول، ويُقرأ هنا كما هو.
library;

class NamedRef {
  final String id;
  final String label;
  const NamedRef({required this.id, required this.label});
}

class UserDeletionReport {
  /// مشاريع يقودها — أولُ ما يمنع الحذف.
  final List<NamedRef> ledProjects;

  /// مشاريع هو منفّذ فيها — لا تمنع الحذف، وتُعرض ليُعرف أثره.
  final int memberProjects;

  /// أعمال مُسنَدة إليه غير مغلقة.
  final List<NamedRef> openWorks;

  /// مهام مشاريع غير مغلقة.
  final int openTasks;

  /// تحديثات يومية كتبها — **لا تُحذف**: هي سجلّ الوزارة لا بيانات شخصية.
  final int dailyUpdates;

  /// طلبات معلّقة قدّمها.
  final int pendingRequests;

  /// سببُ المنع كما صاغه الخادم، أو null إن كان الحذف ممكناً.
  ///
  /// يأتي من الخادم لا يُصاغ هنا: هو نفسه النصّ الذي سيرفض به الحذفَ لو
  /// جُرِّب، فلا يعد المستخدمَ بشيءٍ ثم يُرفض بغيره.
  final String? blockingReason;

  const UserDeletionReport({
    required this.ledProjects,
    required this.memberProjects,
    required this.openWorks,
    required this.openTasks,
    required this.dailyUpdates,
    required this.pendingRequests,
    required this.blockingReason,
  });

  bool get canDelete => blockingReason == null;

  /// هل على هذا الحساب أثرٌ يُذكر أصلاً؟ حسابٌ بلا أثر يُحذف بلا قلق،
  /// وحسابٌ بأثرٍ الأولى إيقافه.
  bool get hasHistory =>
      memberProjects > 0 || dailyUpdates > 0 || pendingRequests > 0 ||
      ledProjects.isNotEmpty || openWorks.isNotEmpty || openTasks > 0;

  static List<NamedRef> _refs(Object? raw, String labelKey) => [
        for (final e in (raw as List? ?? const []))
          if (e is Map)
            NamedRef(
              id: e['id'] as String? ?? '',
              label: e[labelKey] as String? ?? '',
            ),
      ];

  factory UserDeletionReport.fromMap(Map<String, dynamic> m) => UserDeletionReport(
        ledProjects: _refs(m['ledProjects'], 'name'),
        memberProjects: (m['memberProjects'] as num?)?.toInt() ?? 0,
        openWorks: _refs(m['openWorks'], 'title'),
        openTasks: (m['openTasks'] as num?)?.toInt() ?? 0,
        dailyUpdates: (m['dailyUpdates'] as num?)?.toInt() ?? 0,
        pendingRequests: (m['pendingRequests'] as num?)?.toInt() ?? 0,
        blockingReason: m['blockingReason'] as String?,
      );
}
