import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class ReportSnapshot {
  final String id;
  final ReportPeriod period;
  final DateTime generatedDate;
  final String executiveSummary; // ملخص تنفيذي مُولّد تلقائياً
  final double avgProgress;
  final double avgDelayDays;
  final int totalRisks;
  final int totalBlockers;
  final int pendingDecisions;
  final List<MapEntry<String, double>> departmentRanking; // اسم الإدارة -> نسبة الإنجاز
  String manualComment; // تعليق نصي يدوي قابل للتعديل

  ReportSnapshot({
    required this.id,
    required this.period,
    required this.generatedDate,
    required this.executiveSummary,
    required this.avgProgress,
    required this.avgDelayDays,
    required this.totalRisks,
    required this.totalBlockers,
    required this.pendingDecisions,
    required this.departmentRanking,
    this.manualComment = '',
  });

  Map<String, dynamic> toMap() => {
        'period': period.name,
        'generatedDate': Timestamp.fromDate(generatedDate),
        'executiveSummary': executiveSummary,
        'avgProgress': avgProgress,
        'avgDelayDays': avgDelayDays,
        'totalRisks': totalRisks,
        'totalBlockers': totalBlockers,
        'pendingDecisions': pendingDecisions,
        'departmentRanking': departmentRanking
            .map((e) => {'name': e.key, 'value': e.value})
            .toList(),
        'manualComment': manualComment,
      };

  factory ReportSnapshot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ReportSnapshot(
      id: doc.id,
      period: ReportPeriod.fromName(json['period'] as String? ?? ReportPeriod.weekly.name),
      generatedDate: (json['generatedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      executiveSummary: json['executiveSummary'] as String? ?? '',
      avgProgress: (json['avgProgress'] as num?)?.toDouble() ?? 0,
      avgDelayDays: (json['avgDelayDays'] as num?)?.toDouble() ?? 0,
      totalRisks: (json['totalRisks'] as num?)?.toInt() ?? 0,
      totalBlockers: (json['totalBlockers'] as num?)?.toInt() ?? 0,
      pendingDecisions: (json['pendingDecisions'] as num?)?.toInt() ?? 0,
      departmentRanking: ((json['departmentRanking'] as List?) ?? const [])
          .map((e) => MapEntry(e['name'] as String, (e['value'] as num).toDouble()))
          .toList(),
      manualComment: json['manualComment'] as String? ?? '',
    );
  }
}
