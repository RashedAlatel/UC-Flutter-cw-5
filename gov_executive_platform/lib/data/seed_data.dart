import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/blocker.dart';
import '../models/daily_update.dart';
import '../models/decision_request.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import '../models/risk.dart';

/// بيانات تجريبية أولية لتشغيل المنصة دون الحاجة لخادم خلفي.
/// يمكن استبدال هذه الطبقة لاحقاً بواجهة API حقيقية دون تغيير باقي التطبيق.
class SeedData {
  static DateTime _daysAgo(int d) => DateTime.now().subtract(Duration(days: d));
  static DateTime _daysFromNow(int d) => DateTime.now().add(Duration(days: d));

  static List<Department> departments() => [
        const Department(
          id: 'dept_strategy',
          name: 'إدارة المشاريع الاستراتيجية',
          headName: 'أحمد المنصوري',
          colorValue: 0xFF0B3D66,
          icon: Icons.flag_rounded,
        ),
        const Department(
          id: 'dept_it',
          name: 'إدارة تقنية المعلومات',
          headName: 'خالد الزعابي',
          colorValue: 0xFF1565A6,
          icon: Icons.memory_rounded,
        ),
        const Department(
          id: 'dept_hr',
          name: 'إدارة الموارد البشرية',
          headName: 'فاطمة الكعبي',
          colorValue: 0xFF2E7D32,
          icon: Icons.people_alt_rounded,
        ),
        const Department(
          id: 'dept_finance',
          name: 'إدارة الشؤون المالية',
          headName: 'سلطان الشحي',
          colorValue: 0xFFC9A227,
          icon: Icons.account_balance_rounded,
        ),
        const Department(
          id: 'dept_service',
          name: 'إدارة خدمة المتعاملين',
          headName: 'مريم الشامسي',
          colorValue: 0xFFE0692B,
          icon: Icons.support_agent_rounded,
        ),
      ];

  static List<AppUser> users() => const [
        AppUser(
          id: 'u_admin',
          name: 'أحمد المنصوري',
          username: 'admin',
          password: 'admin123',
          role: UserRole.systemAdmin,
        ),
        AppUser(
          id: 'u_exec',
          name: 'سارة النعيمي',
          username: 'exec',
          password: 'exec123',
          role: UserRole.executiveViewer,
        ),
        AppUser(
          id: 'u_mgr_it',
          name: 'خالد الزعابي',
          username: 'mgr.it',
          password: 'mgr123',
          role: UserRole.departmentManager,
          departmentId: 'dept_it',
        ),
        AppUser(
          id: 'u_mgr_hr',
          name: 'فاطمة الكعبي',
          username: 'mgr.hr',
          password: 'mgr123',
          role: UserRole.departmentManager,
          departmentId: 'dept_hr',
        ),
        AppUser(
          id: 'u_mgr_finance',
          name: 'سلطان الشحي',
          username: 'mgr.finance',
          password: 'mgr123',
          role: UserRole.departmentManager,
          departmentId: 'dept_finance',
        ),
        AppUser(
          id: 'u_mgr_strategy',
          name: 'موزة الفلاسي',
          username: 'mgr.strategy',
          password: 'mgr123',
          role: UserRole.departmentManager,
          departmentId: 'dept_strategy',
        ),
        AppUser(
          id: 'u_mgr_service',
          name: 'مريم الشامسي',
          username: 'mgr.service',
          password: 'mgr123',
          role: UserRole.departmentManager,
          departmentId: 'dept_service',
        ),
        AppUser(
          id: 'u_officer_it',
          name: 'راشد السويدي',
          username: 'officer.it',
          password: 'off123',
          role: UserRole.projectOfficer,
          departmentId: 'dept_it',
        ),
        AppUser(
          id: 'u_officer_hr',
          name: 'شيخة الظاهري',
          username: 'officer.hr',
          password: 'off123',
          role: UserRole.projectOfficer,
          departmentId: 'dept_hr',
        ),
      ];

  static List<Project> projects() => [
        Project(
          id: 'proj_strategy_1',
          departmentId: 'dept_strategy',
          name: 'خطة التحول الاستراتيجي 2026',
          description: 'إعداد وتنفيذ خارطة الطريق الاستراتيجية للوزارة للسنوات الثلاث القادمة',
          startDate: _daysAgo(60),
          dueDate: _daysFromNow(45),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.critical,
          progressPercent: 68,
          delayDays: 0,
        ),
        Project(
          id: 'proj_strategy_2',
          departmentId: 'dept_strategy',
          name: 'برنامج قياس الأداء المؤسسي',
          description: 'تطوير منظومة مؤشرات الأداء الرئيسية على مستوى الوزارة',
          startDate: _daysAgo(40),
          dueDate: _daysFromNow(20),
          status: ProjectStatus.atRisk,
          priority: PriorityLevel.high,
          progressPercent: 45,
          delayDays: 4,
        ),
        Project(
          id: 'proj_it_1',
          departmentId: 'dept_it',
          name: 'مشروع التحول الرقمي الشامل',
          description: 'رقمنة الخدمات الحكومية الأساسية وربطها بمنصة النافذة الواحدة',
          startDate: _daysAgo(90),
          dueDate: _daysFromNow(30),
          status: ProjectStatus.delayed,
          priority: PriorityLevel.critical,
          progressPercent: 52,
          delayDays: 12,
        ),
        Project(
          id: 'proj_it_2',
          departmentId: 'dept_it',
          name: 'تحديث البنية التحتية السحابية',
          description: 'ترحيل الأنظمة الحكومية إلى البنية السحابية الآمنة',
          startDate: _daysAgo(30),
          dueDate: _daysFromNow(60),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.high,
          progressPercent: 38,
          delayDays: 0,
        ),
        Project(
          id: 'proj_hr_1',
          departmentId: 'dept_hr',
          name: 'برنامج تطوير القيادات الحكومية',
          description: 'إعداد برنامج تدريبي متكامل لتأهيل الكوادر القيادية',
          startDate: _daysAgo(50),
          dueDate: _daysFromNow(15),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: 74,
          delayDays: 0,
        ),
        Project(
          id: 'proj_hr_2',
          departmentId: 'dept_hr',
          name: 'مشروع رقمنة ملفات الموظفين',
          description: 'أرشفة ورقمنة كافة ملفات الموظفين وربطها بنظام الموارد البشرية',
          startDate: _daysAgo(25),
          dueDate: _daysFromNow(35),
          status: ProjectStatus.atRisk,
          priority: PriorityLevel.medium,
          progressPercent: 30,
          delayDays: 3,
        ),
        Project(
          id: 'proj_finance_1',
          departmentId: 'dept_finance',
          name: 'تحديث نظام الموازنة العامة',
          description: 'تطوير نظام إعداد ومتابعة الموازنة السنوية للوزارة',
          startDate: _daysAgo(70),
          dueDate: _daysFromNow(10),
          status: ProjectStatus.atRisk,
          priority: PriorityLevel.high,
          progressPercent: 61,
          delayDays: 6,
        ),
        Project(
          id: 'proj_finance_2',
          departmentId: 'dept_finance',
          name: 'مشروع الفوترة الإلكترونية',
          description: 'التحول الكامل للفوترة الإلكترونية مع المتعاملين الخارجيين',
          startDate: _daysAgo(20),
          dueDate: _daysFromNow(50),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.medium,
          progressPercent: 42,
          delayDays: 0,
        ),
        Project(
          id: 'proj_service_1',
          departmentId: 'dept_service',
          name: 'مبادرة تحسين رضا المتعاملين',
          description: 'برنامج شامل لرفع مستوى رضا المتعاملين عن الخدمات المقدمة',
          startDate: _daysAgo(45),
          dueDate: _daysFromNow(25),
          status: ProjectStatus.onTrack,
          priority: PriorityLevel.high,
          progressPercent: 80,
          delayDays: 0,
        ),
        Project(
          id: 'proj_service_2',
          departmentId: 'dept_service',
          name: 'مركز الاتصال الموحد',
          description: 'إنشاء مركز اتصال موحد لخدمة جميع قطاعات الوزارة',
          startDate: _daysAgo(15),
          dueDate: _daysFromNow(75),
          status: ProjectStatus.delayed,
          priority: PriorityLevel.medium,
          progressPercent: 18,
          delayDays: 8,
        ),
      ];

  static List<ProjectTask> tasks() {
    final list = <ProjectTask>[];
    void addTasks(String projectId, List<(String, String, TaskStatus, double, int, PriorityLevel)> defs) {
      for (final d in defs) {
        list.add(ProjectTask(
          id: '${projectId}_t${list.length}',
          projectId: projectId,
          title: d.$1,
          assigneeName: d.$2,
          status: d.$3,
          progressPercent: d.$4,
          lastUpdated: _daysAgo(d.$5),
          dueDate: _daysFromNow(10),
          priority: d.$6,
        ));
      }
    }

    addTasks('proj_strategy_1', [
      ('إعداد وثيقة التوجهات الاستراتيجية', 'موزة الفلاسي', TaskStatus.done, 100, 5, PriorityLevel.high),
      ('ورش عمل مع الإدارات', 'موزة الفلاسي', TaskStatus.done, 100, 3, PriorityLevel.medium),
      ('صياغة مؤشرات الأداء الاستراتيجية', 'سعيد الكندي', TaskStatus.inProgress, 60, 1, PriorityLevel.high),
      ('مراجعة الخطة مع القيادة التنفيذية', 'أحمد المنصوري', TaskStatus.review, 80, 2, PriorityLevel.critical),
      ('اعتماد الخطة النهائية', 'أحمد المنصوري', TaskStatus.todo, 0, 10, PriorityLevel.critical),
    ]);
    addTasks('proj_strategy_2', [
      ('تحديد مؤشرات الأداء الرئيسية', 'سعيد الكندي', TaskStatus.done, 100, 6, PriorityLevel.high),
      ('بناء لوحة قياس الأداء', 'هند البلوشي', TaskStatus.inProgress, 45, 1, PriorityLevel.high),
      ('اختبار النظام مع الإدارات التجريبية', 'هند البلوشي', TaskStatus.blocked, 20, 2, PriorityLevel.medium),
      ('تدريب مسؤولي الإدارات', 'موزة الفلاسي', TaskStatus.todo, 0, 15, PriorityLevel.medium),
    ]);
    addTasks('proj_it_1', [
      ('تحليل متطلبات الخدمات الرقمية', 'راشد السويدي', TaskStatus.done, 100, 8, PriorityLevel.high),
      ('تطوير واجهة النافذة الواحدة', 'راشد السويدي', TaskStatus.inProgress, 55, 1, PriorityLevel.critical),
      ('ربط الخدمات مع الجهات الشريكة', 'علياء المهيري', TaskStatus.blocked, 30, 3, PriorityLevel.critical),
      ('اختبار الأمن السيبراني', 'خالد الزعابي', TaskStatus.todo, 0, 20, PriorityLevel.high),
      ('إطلاق تجريبي محدود', 'راشد السويدي', TaskStatus.todo, 0, 25, PriorityLevel.medium),
    ]);
    addTasks('proj_it_2', [
      ('تقييم مزودي الخدمات السحابية', 'خالد الزعابي', TaskStatus.done, 100, 10, PriorityLevel.medium),
      ('ترحيل بيئة الاختبار', 'علياء المهيري', TaskStatus.inProgress, 40, 2, PriorityLevel.high),
      ('إعداد سياسات النسخ الاحتياطي', 'راشد السويدي', TaskStatus.todo, 0, 12, PriorityLevel.medium),
    ]);
    addTasks('proj_hr_1', [
      ('تصميم المنهج التدريبي', 'شيخة الظاهري', TaskStatus.done, 100, 7, PriorityLevel.medium),
      ('اختيار المدربين المعتمدين', 'شيخة الظاهري', TaskStatus.done, 100, 4, PriorityLevel.low),
      ('تنفيذ الدفعة التدريبية الأولى', 'فاطمة الكعبي', TaskStatus.inProgress, 70, 1, PriorityLevel.high),
      ('تقييم أثر التدريب', 'شيخة الظاهري', TaskStatus.todo, 0, 18, PriorityLevel.medium),
    ]);
    addTasks('proj_hr_2', [
      ('جرد ملفات الموظفين الورقية', 'شيخة الظاهري', TaskStatus.done, 100, 9, PriorityLevel.low),
      ('مسح ضوئي وأرشفة الملفات', 'فاطمة الكعبي', TaskStatus.inProgress, 35, 2, PriorityLevel.medium),
      ('ربط الأرشيف بنظام الموارد البشرية', 'شيخة الظاهري', TaskStatus.blocked, 10, 1, PriorityLevel.high),
    ]);
    addTasks('proj_finance_1', [
      ('تحليل الفجوات في النظام الحالي', 'سلطان الشحي', TaskStatus.done, 100, 12, PriorityLevel.medium),
      ('تطوير وحدة إعداد الموازنة', 'مروان الحمادي', TaskStatus.inProgress, 65, 1, PriorityLevel.high),
      ('ربط النظام بوزارة المالية', 'سلطان الشحي', TaskStatus.blocked, 40, 3, PriorityLevel.critical),
      ('تدريب المستخدمين النهائيين', 'مروان الحمادي', TaskStatus.todo, 0, 8, PriorityLevel.medium),
    ]);
    addTasks('proj_finance_2', [
      ('اختيار منصة الفوترة الإلكترونية', 'سلطان الشحي', TaskStatus.done, 100, 6, PriorityLevel.medium),
      ('تكامل النظام مع بوابة الدفع', 'مروان الحمادي', TaskStatus.inProgress, 42, 2, PriorityLevel.high),
      ('تجربة تشغيل محدودة', 'سلطان الشحي', TaskStatus.todo, 0, 20, PriorityLevel.medium),
    ]);
    addTasks('proj_service_1', [
      ('استبيان قياس رضا المتعاملين', 'مريم الشامسي', TaskStatus.done, 100, 11, PriorityLevel.medium),
      ('تحليل نتائج الاستبيان', 'مريم الشامسي', TaskStatus.done, 100, 5, PriorityLevel.medium),
      ('تنفيذ خطة تحسين الخدمة', 'عبدالله النقبي', TaskStatus.inProgress, 80, 1, PriorityLevel.high),
      ('قياس الأثر بعد التحسين', 'مريم الشامسي', TaskStatus.todo, 0, 22, PriorityLevel.medium),
    ]);
    addTasks('proj_service_2', [
      ('دراسة الجدوى لمركز الاتصال', 'مريم الشامسي', TaskStatus.done, 100, 14, PriorityLevel.low),
      ('تجهيز البنية التقنية للمركز', 'عبدالله النقبي', TaskStatus.blocked, 15, 2, PriorityLevel.high),
      ('توظيف وتدريب فريق المركز', 'مريم الشامسي', TaskStatus.todo, 0, 30, PriorityLevel.medium),
    ]);

    return list;
  }

  static List<ProjectRisk> risks() => [
        ProjectRisk(
          id: 'risk_1',
          projectId: 'proj_it_1',
          description: 'تأخر الجهات الشريكة في تسليم واجهات الربط البرمجي (API)',
          level: RiskLevel.high,
          status: ItemStatus.open,
          dateRaised: _daysAgo(5),
        ),
        ProjectRisk(
          id: 'risk_2',
          projectId: 'proj_finance_1',
          description: 'احتمالية تعارض النظام الجديد مع أنظمة وزارة المالية القديمة',
          level: RiskLevel.medium,
          status: ItemStatus.open,
          dateRaised: _daysAgo(8),
        ),
        ProjectRisk(
          id: 'risk_3',
          projectId: 'proj_service_2',
          description: 'نقص الكوادر المؤهلة لتشغيل مركز الاتصال',
          level: RiskLevel.high,
          status: ItemStatus.open,
          dateRaised: _daysAgo(3),
        ),
        ProjectRisk(
          id: 'risk_4',
          projectId: 'proj_strategy_2',
          description: 'ضعف التزام بعض الإدارات بتزويد البيانات في الوقت المحدد',
          level: RiskLevel.medium,
          status: ItemStatus.resolved,
          dateRaised: _daysAgo(20),
        ),
        ProjectRisk(
          id: 'risk_5',
          projectId: 'proj_hr_2',
          description: 'تسرب بيانات محتمل أثناء عملية الأرشفة الرقمية',
          level: RiskLevel.low,
          status: ItemStatus.open,
          dateRaised: _daysAgo(2),
        ),
      ];

  static List<ProjectBlocker> blockers() => [
        ProjectBlocker(
          id: 'blocker_1',
          projectId: 'proj_it_1',
          description: 'انتظار موافقة أمنية من الجهة التنظيمية لإتمام الربط',
          status: ItemStatus.open,
          dateRaised: _daysAgo(4),
        ),
        ProjectBlocker(
          id: 'blocker_2',
          projectId: 'proj_finance_1',
          description: 'توقف مؤقت بسبب عدم توفر بيئة اختبار من وزارة المالية',
          status: ItemStatus.open,
          dateRaised: _daysAgo(6),
        ),
        ProjectBlocker(
          id: 'blocker_3',
          projectId: 'proj_service_2',
          description: 'تأخر إجراءات التوظيف الحكومي لفريق المركز',
          status: ItemStatus.open,
          dateRaised: _daysAgo(9),
        ),
        ProjectBlocker(
          id: 'blocker_4',
          projectId: 'proj_hr_2',
          description: 'عطل في جهاز المسح الضوئي عالي السرعة',
          status: ItemStatus.resolved,
          dateRaised: _daysAgo(15),
        ),
      ];

  static List<DecisionRequest> decisions() => [
        DecisionRequest(
          id: 'dec_1',
          projectId: 'proj_it_1',
          departmentId: 'dept_it',
          title: 'اعتماد ميزانية إضافية للربط الأمني مع الجهات الشريكة',
          description:
              'يتطلب إتمام مشروع التحول الرقمي اعتماد ميزانية إضافية بقيمة 450,000 درهم لتغطية متطلبات الربط الآمن مع 6 جهات حكومية شريكة.',
          priority: PriorityLevel.critical,
          delayImpactDays: 20,
          status: DecisionStatus.pending,
          requestedBy: 'خالد الزعابي',
          requestedDate: _daysAgo(3),
        ),
        DecisionRequest(
          id: 'dec_2',
          projectId: 'proj_finance_1',
          departmentId: 'dept_finance',
          title: 'الموافقة على تمديد الاتفاقية مع وزارة المالية لبيئة الاختبار',
          description:
              'يتطلب استمرار العمل توقيع اتفاقية مستوى خدمة جديدة مع وزارة المالية لتوفير بيئة اختبار مستقرة.',
          priority: PriorityLevel.high,
          delayImpactDays: 15,
          status: DecisionStatus.pending,
          requestedBy: 'سلطان الشحي',
          requestedDate: _daysAgo(5),
        ),
        DecisionRequest(
          id: 'dec_3',
          projectId: 'proj_service_2',
          departmentId: 'dept_service',
          title: 'الموافقة على استقدام 8 موظفين لمركز الاتصال الموحد',
          description:
              'يتطلب إطلاق مركز الاتصال الموحد استكمال إجراءات التوظيف العاجل لثمانية موظفين لتشغيل المركز ضمن الجدول الزمني المعتمد.',
          priority: PriorityLevel.high,
          delayImpactDays: 30,
          status: DecisionStatus.pending,
          requestedBy: 'مريم الشامسي',
          requestedDate: _daysAgo(2),
        ),
        DecisionRequest(
          id: 'dec_4',
          projectId: 'proj_hr_2',
          departmentId: 'dept_hr',
          title: 'اعتماد سياسة خصوصية بيانات الأرشفة الرقمية',
          description: 'يتطلب استكمال مشروع رقمنة الملفات اعتماد سياسة رسمية لحماية خصوصية بيانات الموظفين.',
          priority: PriorityLevel.medium,
          delayImpactDays: 7,
          status: DecisionStatus.pending,
          requestedBy: 'فاطمة الكعبي',
          requestedDate: _daysAgo(6),
        ),
        DecisionRequest(
          id: 'dec_5',
          projectId: 'proj_strategy_2',
          departmentId: 'dept_strategy',
          title: 'إلزام جميع الإدارات بتزويد بيانات الأداء أسبوعياً',
          description: 'قرار قيادي بإلزام جميع مديري الإدارات برفع بيانات مؤشرات الأداء أسبوعياً عبر المنصة.',
          priority: PriorityLevel.medium,
          delayImpactDays: 10,
          status: DecisionStatus.approved,
          requestedBy: 'موزة الفلاسي',
          requestedDate: _daysAgo(18),
          resolutionNote: 'تمت الموافقة وتعميم القرار على جميع الإدارات.',
        ),
      ];

  static List<DailyUpdate> dailyUpdates() => [
        DailyUpdate(
          id: 'du_1',
          projectId: 'proj_it_1',
          departmentId: 'dept_it',
          authorName: 'خالد الزعابي',
          date: _daysAgo(1),
          achievements: 'إنجاز تطوير واجهة النافذة الواحدة بنسبة إضافية 10٪ واختبار الربط مع جهتين شريكتين.',
          completedTasks: ['اختبار الربط مع الجهة الأولى', 'مراجعة تصميم الواجهة'],
          newRisks: ['تأخر الجهات الشريكة في تسليم واجهات الربط البرمجي (API)'],
          blockers: ['انتظار موافقة أمنية من الجهة التنظيمية لإتمام الربط'],
          decisionsRequired: ['اعتماد ميزانية إضافية للربط الأمني مع الجهات الشريكة'],
          progressPercent: 52,
        ),
        DailyUpdate(
          id: 'du_2',
          projectId: 'proj_service_1',
          departmentId: 'dept_service',
          authorName: 'مريم الشامسي',
          date: _daysAgo(1),
          achievements: 'تنفيذ 60٪ من خطة تحسين الخدمة وعقد ورشتي عمل مع فرق الميدان.',
          completedTasks: ['تحليل نتائج الاستبيان', 'خطة تحسين المرحلة الأولى'],
          newRisks: [],
          blockers: [],
          decisionsRequired: [],
          progressPercent: 80,
        ),
        DailyUpdate(
          id: 'du_3',
          projectId: 'proj_finance_1',
          departmentId: 'dept_finance',
          authorName: 'سلطان الشحي',
          date: _daysAgo(2),
          achievements: 'استكمال تطوير 65٪ من وحدة إعداد الموازنة.',
          completedTasks: ['تطوير شاشة إدخال البنود'],
          newRisks: ['احتمالية تعارض النظام الجديد مع أنظمة وزارة المالية القديمة'],
          blockers: ['توقف مؤقت بسبب عدم توفر بيئة اختبار من وزارة المالية'],
          decisionsRequired: ['الموافقة على تمديد الاتفاقية مع وزارة المالية لبيئة الاختبار'],
          progressPercent: 61,
        ),
      ];
}
