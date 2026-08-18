import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/risk.dart';

/// بيانات تجريبية (مشاريع/مهام/مخاطر/عوائق/تحديثات يومية) مرتبطة بالإدارات
/// الافتراضية (راجع default_departments.dart)، لإعطاء مسؤول النظام لمحة
/// كاملة عن لوحة القيادة والشاشات دون انتظار إدخال بيانات حقيقية.
/// كل المعرّفات ثابتة (demo_...) بحيث يكون توليدها متكرراً بأمان (merge)
/// دون تكرار السجلات عند إعادة الضغط على الزر.
class DemoData {
  static final DateTime _now = DateTime.now();

  static List<Project> projects() => [
        Project(
          id: 'demo_proj_1',
          departmentId: 'dept_strategy',
          name: 'تطوير الخطة الاستراتيجية 2026',
          description: 'إعداد وتحديث الخطة الاستراتيجية للجهة للسنوات الثلاث القادمة بالتنسيق مع جميع الإدارات.',
          startDate: _now.subtract(const Duration(days: 60)),
          dueDate: _now.add(const Duration(days: 20)),
          status: ProjectStatus.delayed,
          priority: PriorityLevel.high,
          progressPercent: 45,
          delayDays: 12,
          executorName: 'سلطان الكعبي',
        ),
        Project(
          id: 'demo_proj_2',
          departmentId: 'dept_it',
          name: 'ترقية البنية التحتية السحابية',
          description: 'نقل الأنظمة الأساسية إلى بيئة سحابية موحّدة وتحسين أداء الخدمات الرقمية.',
          startDate: _now.subtract(const Duration(days: 30)),
          dueDate: _now.add(const Duration(days: 45)),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: 70,
          delayDays: 0,
          executorName: 'مريم الحوسني',
        ),
        Project(
          id: 'demo_proj_3',
          departmentId: 'dept_hr',
          name: 'برنامج تطوير الكوادر الوطنية',
          description: 'برنامج تدريبي وتأهيلي لتطوير الكفاءات الوطنية داخل الجهة.',
          startDate: _now.subtract(const Duration(days: 40)),
          dueDate: _now.add(const Duration(days: 35)),
          status: ProjectStatus.atRisk,
          priority: PriorityLevel.high,
          progressPercent: 30,
          delayDays: 5,
          executorName: 'خالد المطيري',
        ),
        Project(
          id: 'demo_proj_4',
          departmentId: 'dept_finance',
          name: 'أتمتة دورة الموازنة السنوية',
          description: 'رقمنة دورة إعداد واعتماد الموازنة السنوية وربطها بالنظام المالي.',
          startDate: _now.subtract(const Duration(days: 90)),
          dueDate: _now.subtract(const Duration(days: 5)),
          status: ProjectStatus.completed,
          priority: PriorityLevel.medium,
          progressPercent: 100,
          delayDays: 0,
          executorName: 'نورة السويدي',
        ),
        Project(
          id: 'demo_proj_5',
          departmentId: 'dept_service',
          name: 'منصة خدمة المتعاملين الموحدة',
          description: 'توحيد قنوات خدمة المتعاملين ضمن منصة رقمية واحدة مع مؤشرات رضا فورية.',
          startDate: _now.subtract(const Duration(days: 25)),
          dueDate: _now.add(const Duration(days: 50)),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.critical,
          progressPercent: 55,
          delayDays: 0,
          executorName: 'فهد العامري',
        ),
      ];

  static List<ProjectTask> tasks() => [
        ProjectTask(
          id: 'demo_task_1',
          projectId: 'demo_proj_1',
          departmentId: 'dept_strategy',
          title: 'جمع مدخلات الإدارات للخطة',
          assigneeName: 'سلطان الكعبي',
          status: TaskStatus.done,
          progressPercent: 100,
          lastUpdated: _now.subtract(const Duration(days: 10)),
          dueDate: _now.subtract(const Duration(days: 8)),
          priority: PriorityLevel.medium,
        ),
        ProjectTask(
          id: 'demo_task_2',
          projectId: 'demo_proj_1',
          departmentId: 'dept_strategy',
          title: 'صياغة المستهدفات الاستراتيجية',
          assigneeName: 'عائشة النعيمي',
          status: TaskStatus.blocked,
          progressPercent: 40,
          lastUpdated: _now.subtract(const Duration(days: 2)),
          dueDate: _now.add(const Duration(days: 5)),
          priority: PriorityLevel.high,
        ),
        ProjectTask(
          id: 'demo_task_3',
          projectId: 'demo_proj_2',
          departmentId: 'dept_it',
          title: 'ترحيل قواعد البيانات',
          assigneeName: 'مريم الحوسني',
          status: TaskStatus.inProgress,
          progressPercent: 65,
          lastUpdated: _now.subtract(const Duration(days: 1)),
          dueDate: _now.add(const Duration(days: 15)),
          priority: PriorityLevel.medium,
        ),
        ProjectTask(
          id: 'demo_task_4',
          projectId: 'demo_proj_2',
          departmentId: 'dept_it',
          title: 'اختبار الأداء تحت الحمل',
          assigneeName: 'يوسف الظاهري',
          status: TaskStatus.todo,
          progressPercent: 0,
          lastUpdated: _now.subtract(const Duration(days: 3)),
          dueDate: _now.add(const Duration(days: 30)),
          priority: PriorityLevel.low,
        ),
        ProjectTask(
          id: 'demo_task_5',
          projectId: 'demo_proj_3',
          departmentId: 'dept_hr',
          title: 'تحديد المسارات التدريبية',
          assigneeName: 'خالد المطيري',
          status: TaskStatus.review,
          progressPercent: 80,
          lastUpdated: _now.subtract(const Duration(days: 4)),
          dueDate: _now.add(const Duration(days: 3)),
          priority: PriorityLevel.high,
        ),
        ProjectTask(
          id: 'demo_task_6',
          projectId: 'demo_proj_3',
          departmentId: 'dept_hr',
          title: 'التعاقد مع جهات التدريب',
          assigneeName: 'هند الكتبي',
          status: TaskStatus.blocked,
          progressPercent: 20,
          lastUpdated: _now.subtract(const Duration(days: 6)),
          dueDate: _now.add(const Duration(days: 10)),
          priority: PriorityLevel.high,
        ),
        ProjectTask(
          id: 'demo_task_7',
          projectId: 'demo_proj_4',
          departmentId: 'dept_finance',
          title: 'ربط النظام المالي بالبوابة',
          assigneeName: 'نورة السويدي',
          status: TaskStatus.done,
          progressPercent: 100,
          lastUpdated: _now.subtract(const Duration(days: 20)),
          dueDate: _now.subtract(const Duration(days: 15)),
          priority: PriorityLevel.medium,
        ),
        ProjectTask(
          id: 'demo_task_8',
          projectId: 'demo_proj_5',
          departmentId: 'dept_service',
          title: 'دمج قنوات التواصل الاجتماعي',
          assigneeName: 'فهد العامري',
          status: TaskStatus.inProgress,
          progressPercent: 55,
          lastUpdated: _now.subtract(const Duration(hours: 20)),
          dueDate: _now.add(const Duration(days: 20)),
          priority: PriorityLevel.high,
        ),
        ProjectTask(
          id: 'demo_task_9',
          projectId: 'demo_proj_5',
          departmentId: 'dept_service',
          title: 'إطلاق استبيان رضا المتعاملين',
          assigneeName: 'شمة الشامسي',
          status: TaskStatus.todo,
          progressPercent: 0,
          lastUpdated: _now.subtract(const Duration(days: 5)),
          dueDate: _now.add(const Duration(days: 40)),
          priority: PriorityLevel.medium,
        ),
        ProjectTask(
          id: 'demo_task_10',
          projectId: 'demo_proj_2',
          departmentId: 'dept_it',
          title: 'توثيق دليل التشغيل',
          assigneeName: 'يوسف الظاهري',
          status: TaskStatus.done,
          progressPercent: 100,
          lastUpdated: _now.subtract(const Duration(days: 12)),
          dueDate: _now.subtract(const Duration(days: 10)),
          priority: PriorityLevel.low,
        ),
      ];

  static List<ProjectRisk> risks() => [
        ProjectRisk(
          id: 'demo_risk_1',
          projectId: 'demo_proj_1',
          departmentId: 'dept_strategy',
          description: 'تأخر بعض الإدارات في تسليم مدخلاتها للخطة الاستراتيجية.',
          level: RiskLevel.high,
          status: ItemStatus.open,
          dateRaised: _now.subtract(const Duration(days: 6)),
        ),
        ProjectRisk(
          id: 'demo_risk_2',
          projectId: 'demo_proj_3',
          departmentId: 'dept_hr',
          description: 'محدودية الموازنة المخصصة لجهات التدريب الخارجية.',
          level: RiskLevel.medium,
          status: ItemStatus.open,
          dateRaised: _now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<ProjectBlocker> blockers() => [
        ProjectBlocker(
          id: 'demo_blocker_1',
          projectId: 'demo_proj_3',
          departmentId: 'dept_hr',
          description: 'بانتظار اعتماد قائمة جهات التدريب المعتمدة من الجهات المختصة.',
          status: ItemStatus.open,
          dateRaised: _now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<DailyUpdate> dailyUpdates() => [
        DailyUpdate(
          id: 'demo_update_1',
          projectId: 'demo_proj_1',
          departmentId: 'dept_strategy',
          authorUid: 'demo',
          authorName: 'سلطان الكعبي',
          date: _now.subtract(const Duration(days: 1)),
          achievements: 'تم الانتهاء من جمع مدخلات 4 إدارات من أصل 5، والعمل جارٍ على صياغة المستهدفات.',
          completedTasks: const ['جمع مدخلات الإدارات للخطة'],
          newRisks: const [],
          blockers: const [],
          decisionsRequired: const [],
          progressPercent: 45,
        ),
        DailyUpdate(
          id: 'demo_update_2',
          projectId: 'demo_proj_5',
          departmentId: 'dept_service',
          authorUid: 'demo',
          authorName: 'فهد العامري',
          date: _now,
          achievements: 'تم دمج قناتي الهاتف والدردشة، والعمل متواصل على دمج منصات التواصل الاجتماعي.',
          completedTasks: const [],
          newRisks: const [],
          blockers: const [],
          decisionsRequired: const [],
          progressPercent: 55,
        ),
      ];

  /// طلب "قرار تنفيذي عام" تجريبي واحد فقط، لمعاينة مركز القرارات وودجة
  /// "قرارات مطلوبة من القيادة" في لوحة القيادة. لا يمس أبداً بوابات الموافقة
  /// الثلاث (تسجيل عضو/مشروع/موعد نهائي) التي تبقى منفصلة تماماً.
  static Map<String, dynamic> decisionRequest({required String requestedByUid, required String requestedByName}) => {
        'type': ApprovalType.decision.name,
        'status': DecisionStatus.pending.name,
        'title': 'اعتماد تمديد نطاق منصة خدمة المتعاملين',
        'description': 'مثال تجريبي: هل تتم الموافقة على توسيع نطاق منصة خدمة المتعاملين لتشمل قنوات إضافية؟',
        'priority': PriorityLevel.medium.name,
        'delayImpactDays': 0,
        'departmentId': 'dept_service',
        'projectId': 'demo_proj_5',
        'requestedByUid': requestedByUid,
        'requestedByName': requestedByName,
        'requestedDate': Timestamp.fromDate(_now),
        'resolutionNote': null,
        'resolvedDate': null,
        'payload': const {},
      };
}
