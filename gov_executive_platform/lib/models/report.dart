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

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period.name,
        'generatedDate': generatedDate.toIso8601String(),
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

  factory ReportSnapshot.fromJson(Map<String, dynamic> json) => ReportSnapshot(
        id: json['id'] as String,
        period: ReportPeriod.fromName(json['period'] as String),
        generatedDate: DateTime.parse(json['generatedDate'] as String),
        executiveSummary: json['executiveSummary'] as String,
        avgProgress: (json['avgProgress'] as num).toDouble(),
        avgDelayDays: (json['avgDelayDays'] as num).toDouble(),
        totalRisks: json['totalRisks'] as int,
        totalBlockers: json['totalBlockers'] as int,
        pendingDecisions: json['pendingDecisions'] as int,
        departmentRanking: (json['departmentRanking'] as List)
            .map((e) => MapEntry(e['name'] as String, (e['value'] as num).toDouble()))
            .toList(),
        manualComment: json['manualComment'] as String? ?? '',
      );
}
