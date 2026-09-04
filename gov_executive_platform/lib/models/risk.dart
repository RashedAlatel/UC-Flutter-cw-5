import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class ProjectRisk {
  final String id;
  final String projectId;
  final String departmentId;
  final String description;
  final RiskLevel level;
  final ItemStatus status;
  final DateTime dateRaised;

  const ProjectRisk({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.description,
    required this.level,
    required this.status,
    required this.dateRaised,
  });

  ProjectRisk copyWith({ItemStatus? status}) => ProjectRisk(
        id: id,
        projectId: projectId,
        departmentId: departmentId,
        description: description,
        level: level,
        status: status ?? this.status,
        dateRaised: dateRaised,
      );

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'description': description,
        'level': level.name,
        'status': status.name,
        'dateRaised': Timestamp.fromDate(dateRaised),
      };

  factory ProjectRisk.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ProjectRisk(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      level: RiskLevel.fromName(json['level'] as String? ?? RiskLevel.medium.name),
      status: ItemStatus.fromName(json['status'] as String? ?? ItemStatus.open.name),
      dateRaised: (json['dateRaised'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
