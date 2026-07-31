class DailyUpdate {
  final String id;
  final String projectId;
  final String departmentId;
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
    required this.authorName,
    required this.date,
    required this.achievements,
    required this.completedTasks,
    required this.newRisks,
    required this.blockers,
    required this.decisionsRequired,
    required this.progressPercent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'departmentId': departmentId,
        'authorName': authorName,
        'date': date.toIso8601String(),
        'achievements': achievements,
        'completedTasks': completedTasks,
        'newRisks': newRisks,
        'blockers': blockers,
        'decisionsRequired': decisionsRequired,
        'progressPercent': progressPercent,
      };

  factory DailyUpdate.fromJson(Map<String, dynamic> json) => DailyUpdate(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        departmentId: json['departmentId'] as String,
        authorName: json['authorName'] as String,
        date: DateTime.parse(json['date'] as String),
        achievements: json['achievements'] as String,
        completedTasks: List<String>.from(json['completedTasks'] as List),
        newRisks: List<String>.from(json['newRisks'] as List),
        blockers: List<String>.from(json['blockers'] as List),
        decisionsRequired: List<String>.from(json['decisionsRequired'] as List),
        progressPercent: (json['progressPercent'] as num).toDouble(),
      );
}
