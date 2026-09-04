import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class ProjectBlocker {
  final String id;
  final String projectId;
  final String departmentId;
  final String description;
  final ItemStatus status;
  final DateTime dateRaised;

  const ProjectBlocker({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.description,
    required this.status,
    required this.dateRaised,
  });

  ProjectBlocker copyWith({ItemStatus? status}) => ProjectBlocker(
        id: id,
        projectId: projectId,
        departmentId: departmentId,
        description: description,
        status: status ?? this.status,
        dateRaised: dateRaised,
      );

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'description': description,
        'status': status.name,
        'dateRaised': Timestamp.fromDate(dateRaised),
      };

  factory ProjectBlocker.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ProjectBlocker(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: ItemStatus.fromName(json['status'] as String? ?? ItemStatus.open.name),
      dateRaised: (json['dateRaised'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
