import 'package:cloud_firestore/cloud_firestore.dart';

class DailyUpdate {
  final String id;
  final String projectId;
  final String departmentId;
  final String authorUid;
  final String authorName;
  final DateTime date;
  final String achievements; // الإنجازات
  final List<String> completedTasks; // المهام المنجزة
  final List<String> newRisks; // المخاطر الجديدة
  final List<String> blockers; // العوائق
  final List<String> decisionsRequired; // القرارات المطلوبة من القيادة
  final double progressPercent; // نسبة التقدم عند التحديث

  const DailyUpdate({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.authorUid,
    required this.authorName,
    required this.date,
    required this.achievements,
    required this.completedTasks,
    required this.newRisks,
    required this.blockers,
    required this.decisionsRequired,
    required this.progressPercent,
  });

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'authorUid': authorUid,
        'authorName': authorName,
        'date': Timestamp.fromDate(date),
        'achievements': achievements,
        'completedTasks': completedTasks,
        'newRisks': newRisks,
        'blockers': blockers,
        'decisionsRequired': decisionsRequired,
        'progressPercent': progressPercent,
      };

  factory DailyUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return DailyUpdate(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      achievements: json['achievements'] as String? ?? '',
      completedTasks: List<String>.from(json['completedTasks'] as List? ?? const []),
      newRisks: List<String>.from(json['newRisks'] as List? ?? const []),
      blockers: List<String>.from(json['blockers'] as List? ?? const []),
      decisionsRequired: List<String>.from(json['decisionsRequired'] as List? ?? const []),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}
