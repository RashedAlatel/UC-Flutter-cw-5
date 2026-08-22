import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/dashboard_metric.dart';
import '../models/dashboard_widget_config.dart';
import '../models/department.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/command_band.dart';
import '../widgets/custom_widget_view.dart';
import '../widgets/focused_project_card.dart';
import '../widgets/pinned_work_card.dart';
import '../widgets/kpi_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
import 'customize_dashboard_dialog.dart';
import 'decision_center_screen.dart';
import 'department_detail_screen.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // فلاتر سريعة تؤثر على "أعلى المشاريع" وجدول التفاصيل فقط، بينما تبقى
  // المؤشرات الرئيسية والرسوم البيانية تعرض إجمالي النطاق المرئي كاملاً.
  ProjectStatus? _statusFilter;
  String? _deptFilter;

  bool _arranging = false;

  /// الترتيب يُحفظ على **لوحة المستخدم نفسه** دائماً.
  ///
  /// وهذا مقصود: لو حُفظ على اللوحة العامة لغيّر مسؤولُ النظام لوحةَ كل من
  /// لم يخصّص لوحته، بسحبةٍ ظنّها تخصّه وحده. أما اللوحة العامة ولوحات
  /// الأدوار فتُضبطان من نافذة «تخصيص اللوحة» حيث يختار الطبقة صراحةً.
  Future<void> _persist(AppStore store, List<DashboardWidgetConfig> next) async {
    await store.saveMyDashboardWidgets(next);
  }

  /// إعادة ترتيب **داخل مجموعة جزئية** مع حفظ مواضع الباقين.
  ///
  /// صارت اللوحة مجموعتين تُرتَّبان مستقلتين: مؤشرات في الشريط، وبطاقات
  /// أسفله. وكلتاهما تُحفظ في قائمة واحدة. فلو أُعيد الترتيب بالمواضع الخام
  /// لأفسد سحبُ بطاقةٍ ترتيبَ المؤشرات — لأن موضع «الثانية في اللوحة» ليس
  /// الموضع الثاني في القائمة الكاملة.
  ///
  /// فالمواضع التي تشغلها المجموعة تبقى لها، ويوضع فيها ترتيبها الجديد.
  static List<DashboardWidgetConfig> _movedWithin(
    List<DashboardWidgetConfig> all,
    List<DashboardWidgetConfig> subset,
    int from,
    int to,
  ) {
    if (from < 0 || from >= subset.length) return all;
    final reordered = List<DashboardWidgetConfig>.from(subset);
    final item = reordered.removeAt(from);
    reordered.insert(to.clamp(0, reordered.length), item);

    final ids = subset.map((w) => w.id).toSet();
    final out = List<DashboardWidgetConfig>.from(all);
    var next = 0;
    for (var i = 0; i < out.length; i++) {
      if (ids.contains(out[i].id)) out[i] = reordered[next++];
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scoped = !store.canViewAllDepartments;
    final projects = store.visibleProjects;

    // شريط الفلاتر يؤثر على كامل نطاق اللوحة (المؤشرات والرسوم البيانية
    // وقوائم المشاريع معاً) بدل الاقتصار على ودجات بعينها، حتى يكون سلوكه
    // متوقعاً: كل ما تراه أسفل الشريط يعكس الفلتر المُختار فعلياً.
    final filteredProjects = projects
        .where((p) => _statusFilter == null || p.effectiveStatus == _statusFilter)
        .where((p) => _deptFilter == null || p.departmentId == _deptFilter)
        .toList();

    // ترتيب الإدارات يقارن الإدارات ببعضها، فلا معنى لتضييقه بفلتر الإدارة
    // نفسه (سيُظهر عندها عموداً واحداً فقط ويُفرغ البقية) — يتأثر بفلتر
    // الحالة فقط، بينما تبقى المقارنة شاملة كل الإدارات المرئية.
    final rankingProjects = projects.where((p) => _statusFilter == null || p.effectiveStatus == _statusFilter).toList();

    final statusCounts = <String, int>{
      for (final s in ProjectStatus.values) s.label: filteredProjects.where((p) => p.effectiveStatus == s).length,
    };
    final statusColors = {
      for (final s in ProjectStatus.values) s.label: AppColors.statusColor(s.name),
    };
    final filterDepartments = store.visibleDepartments;

    final kpiWidgets = store.dashboardWidgets.where((w) => w.type.isKpi).toList();
    final boardWidgets = store.dashboardWidgets.where((w) => !w.type.isKpi).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الشريط القيادي بعرض الصفحة كاملاً — ولذلك زال الحشو الخارجي عن
          // العمود وانتقل إلى ما تحته: شريطٌ بهوامش بيضاء على جانبيه يبدو
          // بطاقةً لا ترويسة.
          CommandBand(
            eyebrow: '${Brand.state} — ${Brand.ministry}',
            title: scoped ? 'لوحة قيادة إدارتي' : 'لوحة القيادة المركزية',
            subtitle: scoped
                ? 'مؤشرات فورية على أداء مشاريع إدارتك'
                : 'مؤشرات فورية على أداء الخطة الاستراتيجية ومشاريع الوزارة',
            actions: [
              // التخصيص متاح لكل مستخدم معتمَد: كلٌّ يعدّل لوحته هو. أما لوحات
              // الأدوار واللوحة العامة فلا تظهر في النافذة إلا لمن يملك
              // صلاحية "التحكم بلوحة القيادة".
              // وضع الترتيب: السحب على الصفحة نفسها بدل قائمة في نافذة.
              // ترتيب اللوحة قرارٌ بصري، ولا يُتّخذ إلا أمام ما يُرى.
              BandButton(
                label: _arranging ? 'إنهاء الترتيب' : 'ترتيب اللوحة',
                icon: _arranging ? Icons.check_rounded : Icons.dashboard_customize_outlined,
                active: _arranging,
                onPressed: () => setState(() => _arranging = !_arranging),
              ),
              BandButton(
                label: 'تخصيص اللوحة',
                icon: Icons.tune_rounded,
                filled: true,
                onPressed: () => showDialog(context: context, builder: (_) => const CustomizeDashboardDialog()),
              ),
            ],
            metrics: [
              for (var i = 0; i < kpiWidgets.length; i++)
                _bandMetric(store, kpiWidgets, i, filteredProjects),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const _LastUpdatedBar(),
          if (!store.isAdmin) ...[
            const SizedBox(height: 16),
            const _BootstrapAdminBanner(),
          ],
          if (store.isAdmin && store.projects.isEmpty) ...[
            const SizedBox(height: 16),
            const _DemoDataBanner(),
          ],
          // "مثبّت لك": ما خصّه مسؤول النظام بهذا المستخدم تحديداً — يسبق
          // القسم العام لأنه شخصي وأوثق صلة به.
          if (store.myFocusProjects.isNotEmpty || store.myFocusWorks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text('مثبّت لك',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 640 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: (constraints.maxWidth - 14 * (cols - 1)) / cols / 220,
                children: [
                  ...store.myFocusProjects.map((p) => FocusedProjectCard(project: p)),
                  ...store.myFocusWorks.map((w) => PinnedWorkCard(work: w)),
                ],
              );
            }),
          ],
          // المشاريع تحت التركيز أعلى اللوحة: أول ما يراه القيادي عند الدخول،
          // قبل الفلاتر والمؤشرات العامة.
          if (store.focusedProjects.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('مشاريع تحت التركيز',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 640 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: (constraints.maxWidth - 14 * (cols - 1)) / cols / 220,
                children: store.focusedProjects.map((p) => FocusedProjectCard(project: p)).toList(),
              );
            }),
          ],
          const SizedBox(height: 18),
          _FilterBar(
            statusFilter: _statusFilter,
            deptFilter: _deptFilter,
            departments: filterDepartments,
            onStatusChanged: (s) => setState(() => _statusFilter = s),
            onDeptChanged: (d) => setState(() => _deptFilter = d),
          ),
          const SizedBox(height: 26),
          // المؤشرات لم تعد أسفل هذا العنوان — انتقلت إلى الشريط القيادي.
          // وباختصاره زال كذلك اقتطاعه على الهاتف إلى «المؤشرات ولوحات الت…».
          const _SectionTitle('لوحات التحليل'),
          const SizedBox(height: 14),
          if (_arranging) ...[
            const _ArrangeHint(),
            const SizedBox(height: 12),
          ],
          // لوحةٌ بلا ودجة واحدة كانت **صفحة بيضاء صامتة**: عنوانٌ ثم فراغ
          // إلى آخر التمرير، ولا شيء يقول للمستخدم أن لوحته فارغة ولا كيف
          // يملؤها. وهذا يقع بسهولة — يكفي أن يحذف ودجاته من «تخصيص اللوحة».
          if (boardWidgets.isEmpty)
            _EmptyBoardNotice(
              onAdd: () => showDialog(
                context: context,
                builder: (_) => const CustomizeDashboardDialog(),
              ),
            )
          else
          _WidgetBoard(
            widgets: boardWidgets,
            arranging: _arranging,
            onReorder: (from, to) =>
                _persist(store, _movedWithin(store.dashboardWidgets, boardWidgets, from, to)),
            onWidth: (id, width) => _persist(
              store,
              [
                for (final w in store.dashboardWidgets) w.id == id ? w.copyWith(width: width) : w,
              ],
            ),
            onMetric: (id, metric) => _persist(
              store,
              [
                for (final w in store.dashboardWidgets) w.id == id ? w.copyWith(metric: metric) : w,
              ],
            ),
            onRemove: (id) => _persist(store, store.dashboardWidgets.where((w) => w.id != id).toList()),
            builder: (w) => _buildWidget(
                context, w, store, scoped, rankingProjects, statusCounts, statusColors, filteredProjects),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// مؤشر واحد داخل الشريط، مع لباس وضع الترتيب حين يكون مُفعَّلاً.
  Widget _bandMetric(
    AppStore store,
    List<DashboardWidgetConfig> kpis,
    int index,
    List<Project> filteredProjects,
  ) {
    final config = kpis[index];
    final kpi = _kpiData(config.type, store, filteredProjects);
    final metric = KpiMetric(
      title: kpi.title,
      value: kpi.value,
      color: kpi.color,
      emphasize: kpi.emphasize,
    );
    if (!_arranging) return metric;
    return _ArrangeableCard(
      index: index,
      config: config,
      compact: true,
      onReorder: (from, to) => _persist(store, _movedWithin(store.dashboardWidgets, kpis, from, to)),
      onWidth: (_, _) {},
      onMetric: (_, _) {},
      onRemove: (id) => _persist(store, store.dashboardWidgets.where((w) => w.id != id).toList()),
      child: metric,
    );
  }

  /// ترتيب الإدارات بمقياس هذا الودجت.
  ///
  /// يُحسب لكل ودجت على حدة لا مرةً واحدة للصفحة: صار في اللوحة أن توضع
  /// «الإدارات حسب الإنجاز» و«الإدارات حسب التأخير» جنباً إلى جنب، فلا يوجد
  /// «ترتيب» واحد للصفحة أصلاً.
  static List<MapEntry<Department, double>> _departmentRanking(
    AppStore store,
    List<Project> scope,
    DashboardMetric metric,
  ) {
    final list = store.departments
        .where((d) => store.canViewDepartment(d.id))
        .map((d) => MapEntry(
              d,
              AppStore.metricValue(metric, scope.where((p) => p.departmentId == d.id).toList()),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// المشاريع التي تُعرض عند الضغط على عمود — تتبع المقياس.
  ///
  /// كان الضغط يعرض «المتأخرة» دائماً مهما كان العمود. ومع مقياسٍ يقيس
  /// الاكتمال يصير ذلك تناقضاً صريحاً بين ما يقيسه العمود وما يفتحه.
  static ({String label, List<Project> list}) _peekFor(DashboardMetric metric, List<Project> scope) {
    switch (metric) {
      case DashboardMetric.delayedRate:
        return (
          label: 'المتأخرة',
          list: scope.where((p) => p.effectiveStatus == ProjectStatus.delayed).toList()
        );
      case DashboardMetric.completedRate:
        return (
          label: 'المكتملة',
          list: scope.where((p) => p.effectiveStatus == ProjectStatus.completed).toList()
        );
      case DashboardMetric.avgProgress:
      case DashboardMetric.projectCount:
        return (label: '', list: scope);
    }
  }

  /// حساب مؤشر واحد — **المصدر الوحيد** لعنوانه ورقمه ولونه.
  ///
  /// يقرأ منه موضعان: بطاقة `KpiCard` على اللوحة، و`KpiMetric` داخل الشريط
  /// القيادي. ولولا توحيدهما لانفصل الرقمان بأول تعديل على أحدهما — وهو ما
  /// حدث فعلاً بين `departmentRanking` في المخزن ونسخته داخل هذه الشاشة.
  ///
  /// و[emphasize] تقول: هل يُلوَّن الرقم بلون المعنى في الشريط؟ الأرقام
  /// المحايدة (الإجمالي، الأولوية) تبقى بلون النص، فلا يصير الشريط قوس قزح
  /// ويفقد اللونُ دلالته.
  static ({String title, String value, IconData icon, Color color, bool emphasize}) _kpiData(
    DashboardWidgetType type,
    AppStore store,
    List<Project> projects,
  ) {
    switch (type) {
      case DashboardWidgetType.kpiAvgProgress:
        return (
          title: 'نسبة الإنجاز العام',
          value: Formatters.percent(AppStore.metricValue(DashboardMetric.avgProgress, projects)),
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
          emphasize: false,
        );
      case DashboardWidgetType.kpiAvgDelay:
        final avgDelay = projects.isEmpty
            ? 0.0
            : projects.map((p) => p.delayDays).reduce((a, b) => a + b) / projects.length;
        return (
          title: 'متوسط التأخير عن الخطة',
          value: '${avgDelay.toStringAsFixed(1)} يوم',
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          emphasize: avgDelay > 0,
        );
      case DashboardWidgetType.kpiProjectCount:
        return (
          title: 'إجمالي عدد المشاريع',
          value: '${projects.length}',
          icon: Icons.folder_copy_rounded,
          color: AppColors.primary,
          emphasize: false,
        );
      case DashboardWidgetType.kpiHighPriority:
        final high = projects
            .where((p) => p.priority == PriorityLevel.high || p.priority == PriorityLevel.critical)
            .length;
        return (
          title: 'المشاريع عالية الأولوية',
          value: '$high',
          icon: Icons.priority_high_rounded,
          color: AppColors.priorityColor('high'),
          emphasize: false,
        );
      case DashboardWidgetType.kpiOpenRisks:
        final ids = projects.map((p) => p.id).toSet();
        final count = store.risks.where((r) => ids.contains(r.projectId) && r.status == ItemStatus.open).length;
        return (
          title: 'المخاطر القائمة',
          value: '$count',
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          emphasize: count > 0,
        );
      case DashboardWidgetType.kpiOpenBlockers:
        final ids = projects.map((p) => p.id).toSet();
        final count = store.blockers.where((b) => ids.contains(b.projectId) && b.status == ItemStatus.open).length;
        return (
          title: 'العوائق النشطة',
          value: '$count',
          icon: Icons.block_rounded,
          color: const Color(0xFFE0692B),
          emphasize: count > 0,
        );
      case DashboardWidgetType.kpiPendingApprovals:
        return (
          title: 'طلبات بانتظار القيادة',
          value: '${store.pendingApprovalsCount}',
          icon: Icons.gavel_rounded,
          color: AppColors.info,
          emphasize: store.pendingApprovalsCount > 0,
        );
      default:
        // لا يُستدعى إلا لأنواع المؤشرات؛ مذكور ليكتمل التفريع.
        return (title: '', value: '', icon: Icons.help_outline, color: AppColors.textSecondary, emphasize: false);
    }
  }

  Widget _buildWidget(
    BuildContext context,
    DashboardWidgetConfig config,
    AppStore store,
    bool scoped,
    List<Project> rankingProjects,
    Map<String, int> statusCounts,
    Map<String, Color> statusColors,
    List<Project> filteredProjects,
  ) {
    final metric = config.metric;
    switch (config.type) {
      // كل بطاقات المؤشرات تمرّ من مصدر حساب واحد ([_kpiData])، فلا يفترق
      // الرقم بين البطاقة على اللوحة والمؤشر في الشريط القيادي.
      case DashboardWidgetType.kpiAvgProgress:
      case DashboardWidgetType.kpiAvgDelay:
      case DashboardWidgetType.kpiProjectCount:
      case DashboardWidgetType.kpiHighPriority:
      case DashboardWidgetType.kpiOpenRisks:
      case DashboardWidgetType.kpiOpenBlockers:
      case DashboardWidgetType.kpiPendingApprovals:
        final kpi = _kpiData(config.type, store, filteredProjects);
        return KpiCard(title: kpi.title, value: kpi.value, icon: kpi.icon, color: kpi.color);
      case DashboardWidgetType.deptBarChart:
        final ranking = _departmentRanking(store, rankingProjects, metric);
        return _ChartCard(
          title: '${scoped ? 'أداء إدارتي' : 'ترتيب الإدارات'} حسب: ${metric.label}',
          subtitle: metric.hint,
          height: 300,
          child: ranking.isEmpty
              ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppColors.textSecondary)))
              : DepartmentBarChart(
                  ranking: ranking,
                  unit: metric.unit,
                  onDepartmentTap: (dept) {
                    final peek = _peekFor(
                      metric,
                      store.visibleProjects.where((p) => p.departmentId == dept.id).toList(),
                    );
                    _showProjectsPeek(
                      context,
                      title: 'مشاريع "${dept.name}"${peek.label.isEmpty ? '' : ' ${peek.label}'}',
                      projects: peek.list,
                    );
                  },
                ),
        );
      case DashboardWidgetType.topUsersChart:
        return _TopUsersCard(
          store: store,
          metric: metric,
          scope: rankingProjects,
          onPersonTap: (user, projects) {
            final peek = _peekFor(metric, projects);
            _showProjectsPeek(
              context,
              title: 'مشاريع ${user.name}${peek.label.isEmpty ? '' : ' ${peek.label}'}',
              projects: peek.list,
            );
          },
        );
      case DashboardWidgetType.statusPieChart:
        return _ChartCard(
          title: 'توزيع حالة المشاريع',
          subtitle: 'اضغط على أي قطاع أو تسمية لعرض مشاريعها',
          height: 260,
          child: StatusDonutChart(
            data: statusCounts,
            colors: statusColors,
            onSectionTap: (label) {
              final status = ProjectStatus.values.firstWhere((s) => s.label == label, orElse: () => ProjectStatus.onTrack);
              _showProjectsPeek(
                context,
                title: 'مشاريع بحالة "$label"',
                projects: store.visibleProjects.where((p) => p.effectiveStatus == status).toList(),
              );
            },
          ),
        );
      case DashboardWidgetType.pendingApprovalsList:
        return _PendingDecisionsCard(store: store);
      case DashboardWidgetType.departmentRankingList:
        return _DepartmentRankingList(
          store: store,
          ranking: _departmentRanking(store, rankingProjects, metric),
          metric: metric,
        );
      case DashboardWidgetType.recentUpdatesList:
        return _RecentUpdatesCard(store: store);
      case DashboardWidgetType.topProjectsList:
        return _TopProjectsCard(store: store, projects: filteredProjects);
      case DashboardWidgetType.projectsTable:
        return _ProjectsTableCard(store: store, projects: filteredProjects);
      case DashboardWidgetType.custom:
        final spec = config.custom;
        return spec == null ? const SizedBox.shrink() : CustomWidgetCard(store: store, spec: spec);
    }
  }
}

/// نافذة سفلية تعرض قائمة مشاريع مُصفّاة (بالضغط على قطاع/عمود برسم بياني)،
/// مع إمكانية فتح أي مشروع منها مباشرة.
void _showProjectsPeek(BuildContext context, {required String title, required List<Project> projects}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                  Text('${projects.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: projects.isEmpty
                  ? const Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(p.name)),
                                  body: ProjectDetailScreen(projectId: p.id),
                                ),
                              ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                      StatusChip(status: p.effectiveStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LabeledProgressBar(value: p.progressPercent, label: 'نسبة الإنجاز'),
                                  if (p.executorLabel.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('المنفذ: ${p.executorLabel}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «الأشخاص حسب المشاريع»: من عليه أكثر المشاريع، بأي مقياس اخترته.
///
/// المصدر [AppStore.trackablePeople] وهو **مقيَّد بالصلاحية أصلاً**: كل
/// المعتمَدين لمن يرى كل الإدارات، وموظفو إداراته لمدير الإدارة، وفارغٌ لمن
/// دون ذلك. فالبطاقة تقول ذلك صراحةً بدل أن تظهر رسماً خالياً يُقرأ عطلاً.
class _TopUsersCard extends StatelessWidget {
  final AppStore store;
  final DashboardMetric metric;

  /// نطاق المشاريع بعد فلتر الحالة — يُقاطَع بمشاريع الشخص، فيتبع الرسمُ
  /// شريطَ الفلاتر كبقية اللوحة.
  final List<Project> scope;
  final void Function(AppUser user, List<Project> projects) onPersonTap;

  const _TopUsersCard({
    required this.store,
    required this.metric,
    required this.scope,
    required this.onPersonTap,
  });

  /// أكثر ثمانية أشخاص — لا كل الموظفين: بطاقةٌ بمائتي عمود لا تُقرأ.
  static const int _limit = 8;

  @override
  Widget build(BuildContext context) {
    final people = store.trackablePeople;
    final ids = scope.map((p) => p.id).toSet();
    final rows = <({AppUser user, List<Project> projects, double value})>[];
    for (final user in people) {
      final mine = store.projectsOf(user).where((p) => ids.contains(p.id)).toList();
      if (mine.isEmpty) continue; // من لا مشروع له لا يُزاحم الأسماء في الرسم
      rows.add((user: user, projects: mine, value: AppStore.metricValue(metric, mine)));
    }
    rows.sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(_limit).toList();

    return _ChartCard(
      title: 'الأشخاص حسب: ${metric.label}',
      subtitle: metric.hint,
      height: 300,
      child: people.isEmpty
          ? const Center(
              child: Text(
                'لا تملك صلاحية متابعة أشخاص',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          : top.isEmpty
              ? const Center(
                  child: Text('لا يوجد أشخاص مسجَّلون على مشاريع',
                      style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                )
              : RankedBarChart(
                  bars: [
                    for (var i = 0; i < top.length; i++)
                      (
                        label: top[i].user.name,
                        color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                        value: top[i].value,
                      ),
                  ],
                  unit: metric.unit,
                  onTap: (i) => onPersonTap(top[i].user, top[i].projects),
                ),
    );
  }
}

/// شريط فلاتر سريعة (حالة المشروع كأزرار كبسولية + الإدارة كقائمة منسدلة)
/// بحسب التصميم المرجعي المعتمد. يؤثر فقط على "أعلى المشاريع" وجدول
/// التفاصيل، بينما تبقى المؤشرات والرسوم البيانية تعرض النطاق الكامل.
class _FilterBar extends StatelessWidget {
  final ProjectStatus? statusFilter;
  final String? deptFilter;
  final List<Department> departments;
  final ValueChanged<ProjectStatus?> onStatusChanged;
  final ValueChanged<String?> onDeptChanged;

  const _FilterBar({
    required this.statusFilter,
    required this.deptFilter,
    required this.departments,
    required this.onStatusChanged,
    required this.onDeptChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 20,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(label: 'الكل', selected: statusFilter == null, onTap: () => onStatusChanged(null)),
                ...ProjectStatus.values.map(
                  (s) => _StatusPill(label: s.label, selected: statusFilter == s, onTap: () => onStatusChanged(s)),
                ),
              ],
            ),
            if (departments.length > 1)
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: deptFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الإدارة', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                    ...departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: onDeptChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// قائمة "أعلى المشاريع تقدماً" بأعمدة أفقية (بنفس أسلوب DepartmentBarChart)،
/// تُبنى من نفس نطاق المشاريع بعد تطبيق الفلاتر السريعة.
class _TopProjectsCard extends StatelessWidget {
  final AppStore store;
  final List<Project> projects;
  const _TopProjectsCard({required this.store, required this.projects});

  @override
  Widget build(BuildContext context) {
    final top = projects.toList()..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    final items = top.take(3).toList();
    return _ChartCard(
      title: 'أعلى المشاريع تقدماً',
      height: 210,
      child: items.isEmpty
          ? const Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final p = items[i];
                final value = p.progressPercent.clamp(0, 100);
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text(p.name)), body: ProjectDetailScreen(projectId: p.id)),
                  )),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(p.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: [
                            Container(height: 18, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4))),
                            FractionallySizedBox(
                              widthFactor: value / 100,
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 36, child: Text('${value.toStringAsFixed(0)}٪', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// جدول تفصيلي بالمشاريع (بحسب النطاق المفلتَر)، بنفس أسلوب جداول أدوات BI.
/// جدول تفاصيل المشاريع.
///
/// **مهم:** ارتفاع هذه البطاقة مُقيَّد عمداً. قبل ذلك كانت ترسم صفاً لكل مشروع
/// بلا سقف، فمع بيانات الوزارة (٦٥ مشروعاً) كان ارتفاعها وحده ~٢٩٠٠ بكسل ويجعل
/// لوحة القيادة ~٥٨٠٠ بكسل (نحو سبع شاشات هاتف). وبما أن الجدول عريض ويُمرَّر
/// أفقياً، كانت الشريحة المرئية منه على الهاتف فارغة بصرياً في معظم ارتفاعها —
/// وهو ما ظهر للمستخدم كـ"صفحة فارغة إلى ما لا نهاية"، وحجب أي ودجت مضاف بعده.
class _ProjectsTableCard extends StatelessWidget {
  final AppStore store;
  final List<Project> projects;
  const _ProjectsTableCard({required this.store, required this.projects});

  /// أقصى عدد صفوف تُعرض داخل البطاقة؛ الباقي عبر "عرض كل المشاريع".
  static const int _maxRows = 25;

  @override
  Widget build(BuildContext context) {
    final shown = projects.take(_maxRows).toList();
    final hidden = projects.length - shown.length;
    final narrow = MediaQuery.of(context).size.width < 720;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل المشاريع (${projects.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary))),
              )
            // على الشاشات الضيقة الجدول العريض يُقصّ ويظهر فراغاً؛ نعرض بدله
            // قائمة بطاقات رأسية مقروءة بالكامل بلا تمرير أفقي.
            else if (narrow)
              SizedBox(
                height: 420,
                child: ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 18),
                  itemBuilder: (context, i) => _CompactProjectRow(store: store, project: shown[i]),
                ),
              )
            else
              SizedBox(
                height: 420,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 44,
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(label: Text('اسم المشروع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الإدارة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('التقدم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('الاستحقاق', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                    DataColumn(label: Text('المنفذ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5))),
                  ],
                  rows: shown.map((p) {
                    final dept = store.departmentById(p.departmentId);
                    return DataRow(
                      onSelectChanged: (_) => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(appBar: AppBar(title: Text(p.name)), body: ProjectDetailScreen(projectId: p.id)),
                      )),
                      cells: [
                        DataCell(SizedBox(width: 190, child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(dept?.name ?? 'بدون إدارة', style: const TextStyle(fontSize: 11.5))),
                        DataCell(StatusChip(status: p.effectiveStatus)),
                        DataCell(Text(Formatters.percent(p.progressPercent), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                        DataCell(Text(Formatters.shortDate(p.dueDate), style: const TextStyle(fontSize: 11.5))),
                        DataCell(SizedBox(width: 120, child: Text(p.executorLabel, style: const TextStyle(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                    );
                  }).toList(),
                    ),
                  ),
                ),
              ),
            if (hidden > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'يُعرض $_maxRows مشروعاً من ${projects.length} — افتح صفحة "المشاريع" لعرضها كلها مع البحث والتصفية.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// صف مشروع مضغوط للشاشات الضيقة — بديل الجدول العريض الذي كان يُقصّ أفقياً.
class _CompactProjectRow extends StatelessWidget {
  final AppStore store;
  final Project project;
  const _CompactProjectRow({required this.store, required this.project});

  @override
  Widget build(BuildContext context) {
    final dept = store.departmentById(project.departmentId);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(project.name)), body: ProjectDetailScreen(projectId: project.id)),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(project.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              StatusChip(status: project.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${dept?.name ?? 'بدون إدارة'} · ${Formatters.percent(project.progressPercent)} · ${Formatters.shortDate(project.dueDate)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;
  const _ChartCard({required this.title, this.subtitle, required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 14),
            SizedBox(height: subtitle != null ? height - 68 : height - 50, child: child),
          ],
        ),
      ),
    );
  }
}

class _PendingDecisionsCard extends StatelessWidget {
  final AppStore store;
  const _PendingDecisionsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final decisions = store.pendingApprovalsSorted.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('قرارات مطلوبة من القيادة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('مركز القرارات التنفيذية')),
                      body: const DecisionCenterScreen(),
                    ),
                  )),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const Divider(height: 20),
            if (decisions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد قرارات معلقة حالياً', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...List.generate(decisions.length, (i) {
                final d = decisions[i];
                final dept = d.departmentId != null ? store.departmentById(d.departmentId!) : null;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: i == decisions.length - 1 ? 0 : 1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          Formatters.arabicOrdinal(i + 1),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${d.type.label}] ${d.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                PriorityChip(priority: d.priority),
                                Text(
                                  '${dept?.name ?? 'عام'}${d.delayImpactDays > 0 ? ' · أثر التأخير: ${d.delayImpactDays} يوم' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DepartmentRankingList extends StatelessWidget {
  final AppStore store;
  final List ranking;
  final DashboardMetric metric;
  const _DepartmentRankingList({required this.store, required this.ranking, required this.metric});

  /// سقف شريط التقدّم: النسبة تُقاس على ١٠٠، والعدد على أكبر قيمة في القائمة
  /// — وإلا ظهرت إدارةٌ بثلاثة مشاريع بشريط شبه فارغ بلا معنى.
  double get _ceiling {
    if (metric.unit == DashboardMetricUnit.percent) return 100;
    final maxValue = ranking.fold<double>(0, (a, e) => (e.value as double) > a ? e.value as double : a);
    return maxValue <= 0 ? 1 : maxValue;
  }

  @override
  Widget build(BuildContext context) {
    final ceiling = _ceiling;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ترتيب الإدارات حسب: ${metric.label}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Divider(height: 20),
            ...List.generate(ranking.length, (i) {
              final entry = ranking[i];
              final dept = entry.key;
              final value = entry.value as double;
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(dept.name)),
                    body: DepartmentDetailScreen(departmentId: dept.id),
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: i == ranking.length - 1 ? 0 : 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: dept.color.withValues(alpha: 0.15),
                        child: Text('${i + 1}', style: TextStyle(color: dept.color, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: (value / ceiling).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(dept.color),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        child: Text(
                            metric.unit == DashboardMetricUnit.percent
                                ? Formatters.percent(value)
                                : value.toStringAsFixed(0),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RecentUpdatesCard extends StatelessWidget {
  final AppStore store;
  const _RecentUpdatesCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final updates = store.recentUpdates;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أحدث التحديثات اليومية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Divider(height: 20),
            if (updates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد تحديثات بعد', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...List.generate(updates.length, (i) {
                final u = updates[i];
                final project = store.projectById(u.projectId);
                return InkWell(
                  onTap: project == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text(project.name)),
                              body: ProjectDetailScreen(projectId: project.id),
                            ),
                          )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: i == updates.length - 1 ? 0 : 1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 3, margin: const EdgeInsets.only(left: 10), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3))),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(u.authorName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(Formatters.timeAgo(u.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(u.achievements, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (project != null) ...[
                                const SizedBox(height: 5),
                                Text(project.name, style: TextStyle(fontSize: 10.5, color: AppColors.accent, fontWeight: FontWeight.w700)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// شريط "آخر تحديث" أعلى اللوحة: البيانات محدّثة لحظياً أصلاً عبر Firestore،
/// وزر التحديث هنا يعيد ختم الوقت المعروض ليؤكد للمستخدم حداثة الصفحة.
class _LastUpdatedBar extends StatefulWidget {
  const _LastUpdatedBar();

  @override
  State<_LastUpdatedBar> createState() => _LastUpdatedBarState();
}

class _LastUpdatedBarState extends State<_LastUpdatedBar> {
  DateTime _time = DateTime.now();

  String _label() {
    final h = _time.hour % 12 == 0 ? 12 : _time.hour % 12;
    final m = _time.minute.toString().padLeft(2, '0');
    final period = _time.hour >= 12 ? 'م' : 'ص';
    return '${Formatters.date(_time)} — $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sync_rounded, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        // `Expanded` بدل `Text` حرّ ثم `Spacer`: التاريخ والوقت بالعربية أطول
        // من عرض الهاتف، فكان السطر يتجاوز الشاشة بمائة بكسل تقريباً — وهو
        // عطلٌ قائم لم يظهر لأن اللوحة لم تُصيَّر قط بمقاس هاتف في الاختبارات.
        Expanded(
          child: Text('آخر تحديث: ${_label()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _time = DateTime.now());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('البيانات محدّثة لحظياً بشكل تلقائي'), duration: Duration(seconds: 2)),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// شريط استرجاع يظهر لأي مستخدم مفعّل ليس مسؤول نظام، طالما لم يُعيَّن أي
/// مسؤول نظام للمنصة بعد. يعالج الحالة التي قد يعلق فيها أول مستخدم بدور
/// مختلف عن "مسؤول نظام" (مثلاً بسبب خطأ اتصال مؤقت أثناء أول محاولة)، لأن
/// شاشة "بانتظار الموافقة" التي تحتوي زر التعيين لا تظهر بعد تفعيل الحساب.
class _BootstrapAdminBanner extends StatefulWidget {
  const _BootstrapAdminBanner();

  @override
  State<_BootstrapAdminBanner> createState() => _BootstrapAdminBannerState();
}

class _BootstrapAdminBannerState extends State<_BootstrapAdminBanner> {
  bool _checking = true;
  bool _needed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final needed = await context.read<AppStore>().checkBootstrapNeeded();
    if (!mounted) return;
    setState(() {
      _needed = needed;
      _checking = false;
    });
  }

  Future<void> _becomeAdmin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().bootstrapFirstAdmin();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _needed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_needed) return const SizedBox.shrink();
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لا يوجد مسؤول نظام مُفعّل بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك تعيين نفسك كأول مسؤول نظام لمرة واحدة، ثم إدارة باقي الحسابات والصلاحيات من مركز القرارات.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _becomeAdmin,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.admin_panel_settings_rounded, size: 16),
                    label: const Text('تعيين نفسي كأول مسؤول نظام'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط يظهر لمسؤول النظام فقط طالما لا توجد أي مشاريع بعد، لتوليد بيانات
/// تجريبية كاملة (إدارات + مشاريع + مهام + مخاطر/عوائق + تحديثات + قرار
/// تنفيذي واحد) بضغطة واحدة، حتى يمكن معاينة لوحة القيادة وبقية الشاشات
/// فوراً دون انتظار إدخال بيانات حقيقية.
class _DemoDataBanner extends StatefulWidget {
  const _DemoDataBanner();

  @override
  State<_DemoDataBanner> createState() => _DemoDataBannerState();
}

class _DemoDataBannerState extends State<_DemoDataBanner> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppStore>().seedDemoData();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر توليد البيانات التجريبية، حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return Card(
      color: AppColors.info.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.dataset_outlined, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لا توجد مشاريع بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك توليد بيانات تجريبية (إدارات ومشاريع ومهام وتحديثات) بضغطة واحدة، لمعاينة لوحة القيادة وبقية الشاشات فوراً.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.dataset_outlined, size: 16),
                    label: const Text('توليد بيانات تجريبية للاختبار'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// لافتة وضع الترتيب: تقول ما يستطيعه المستخدم الآن، وأين يُحفظ ما يفعله.
class _ArrangeHint extends StatelessWidget {
  const _ArrangeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'اسحب أي بطاقة من مقبضها إلى مكانها، واضبط عرضها من القائمة عليها. '
        'الترتيب يُحفظ في لوحتك أنت وحدك — ولضبط لوحة دور أو اللوحة العامة '
        'استخدم «تخصيص اللوحة».',
        style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textPrimary),
      ),
    );
  }
}

/// منفذ معاينة للشبكة وحدها — راجع `test/render_board_preview.dart`.
///
/// الشبكة خاصة بهذا الملف، ومعاينتها بصرياً تحتاج بناءها بمعزل عن بيانات
/// اللوحة كلها. وبديل ذلك تصيير اللوحة كاملةً بستين مشروعاً، وهو بطيء إلى
/// حدّ تجاوز المهلة — فلا يُراجَع التخطيط بالعين إطلاقاً.
@visibleForTesting
class DashboardWidgetBoardPreview extends StatelessWidget {
  final List<DashboardWidgetConfig> widgets;
  final bool arranging;
  final Widget Function(DashboardWidgetConfig) builder;

  const DashboardWidgetBoardPreview({
    super.key,
    required this.widgets,
    required this.arranging,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => _WidgetBoard(
        widgets: widgets,
        arranging: arranging,
        onReorder: (_, _) {},
        onWidth: (_, _) {},
        onMetric: (_, _) {},
        onRemove: (_) {},
        builder: builder,
      );
}

/// شبكة ودجات اللوحة: عروضٌ نسبية، وسحبٌ مباشر في وضع الترتيب.
///
/// `Wrap` لا `GridView.count`: العمود الثابت يفرض عرضاً واحداً على الجميع،
/// وهو ما جعل جدول المشاريع يُعرض بنصف عرض الشاشة فلا تُقرأ أعمدته.
class _WidgetBoard extends StatelessWidget {
  final List<DashboardWidgetConfig> widgets;
  final bool arranging;
  final void Function(int from, int to) onReorder;
  final void Function(String id, DashboardWidgetWidth width) onWidth;
  final void Function(String id, DashboardMetric metric) onMetric;
  final void Function(String id) onRemove;
  final Widget Function(DashboardWidgetConfig) builder;

  const _WidgetBoard({
    required this.widgets,
    required this.arranging,
    required this.onReorder,
    required this.onWidth,
    required this.onMetric,
    required this.onRemove,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 18.0;
      final total = constraints.maxWidth;

      // العرض كسرٌ من السطر، لا عدد أعمدة من شبكة ثابتة: بطاقتان بنصف العرض
      // تصطفّان لأن ٢×(١/٢) = سطر كامل بالضبط.
      //
      // وتُضيَّق الخيارات على الشاشات الصغيرة: الثلث على شاشة متوسطة لا يعرض
      // شيئاً مقروءاً فيصير نصفاً، وعلى الجوال كل بطاقة بعرض كامل.
      double widthOf(DashboardWidgetConfig w) {
        if (total <= 720) return total;
        var denominator = w.width.denominator;
        if (total <= 1150 && denominator > 2) denominator = 2;
        return (total - spacing * (denominator - 1)) / denominator;
      }

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < widgets.length; i++)
            SizedBox(
              width: widthOf(widgets[i]),
              child: arranging
                  ? _ArrangeableCard(
                      index: i,
                      config: widgets[i],
                      onReorder: onReorder,
                      onWidth: onWidth,
                      onMetric: onMetric,
                      onRemove: onRemove,
                      child: builder(widgets[i]),
                    )
                  : builder(widgets[i]),
            ),
        ],
      );
    });
  }
}

/// بطاقة في وضع الترتيب: مقبض سحب، وهدف إفلات، وضبط عرض، وحذف.
class _ArrangeableCard extends StatelessWidget {
  final int index;
  final DashboardWidgetConfig config;
  final void Function(int from, int to) onReorder;
  final void Function(String id, DashboardWidgetWidth width) onWidth;
  final void Function(String id, DashboardMetric metric) onMetric;
  final void Function(String id) onRemove;
  final Widget child;

  /// لباسٌ مصغَّر للمؤشرات داخل الشريط القيادي: مقبض وحذف فقط، بألوان تُقرأ
  /// على خلفية الهوية الداكنة. ولا قائمة عرض فيه — «ثلث/نصف/كامل» بلا معنى
  /// داخل شريطٍ يوزّع أعمدته بنفسه.
  final bool compact;

  const _ArrangeableCard({
    required this.index,
    required this.config,
    required this.onReorder,
    required this.onWidth,
    required this.onMetric,
    required this.onRemove,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onReorder(d.data, index),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovering ? AppColors.accent : AppColors.border,
              width: hovering ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // السحب من المقبض وحده: لو كانت البطاقة كلها قابلة للسحب
                  // لتعذّر استعمال ما بداخلها من أزرار وتمرير.
                  Draggable<int>(
                    data: index,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(config.type.label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    childWhenDragging: const Icon(Icons.drag_indicator_rounded, color: AppColors.border),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(config.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  // المقياس أولاً: هو ما يقرّر **معنى** البطاقة، والعرضُ شكلها.
                  if (config.type.hasMetric)
                    PopupMenuButton<DashboardMetric>(
                      tooltip: 'مقياس البطاقة',
                      initialValue: config.metric,
                      onSelected: (m) => onMetric(config.id, m),
                      itemBuilder: (_) => [
                        for (final m in DashboardMetric.values)
                          PopupMenuItem(value: m, child: Text(m.label)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.straighten_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(config.metric.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  PopupMenuButton<DashboardWidgetWidth>(
                    tooltip: 'عرض البطاقة',
                    initialValue: config.width,
                    onSelected: (w) => onWidth(config.id, w),
                    itemBuilder: (_) => [
                      for (final w in DashboardWidgetWidth.values)
                        PopupMenuItem(value: w, child: Text(w.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.aspect_ratio_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(config.width.label,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إزالة من لوحتي',
                    icon: const Icon(Icons.close_rounded, size: 17),
                    onPressed: () => onRemove(config.id),
                  ),
                ],
              ),
              // لا تفاعل مع محتوى البطاقة أثناء الترتيب: الضغط هنا للترتيب
              // لا للتنقل، وفتح شاشة أخرى في منتصف السحب يفقد المستخدم مكانه.
              IgnorePointer(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompact(BuildContext context) {
    final fg = AppColors.onBrand(AppColors.primary);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onReorder(d.data, index),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: hovering ? AppColors.accent : fg.withValues(alpha: 0.22),
              width: hovering ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Draggable<int>(
                    data: index,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(config.type.label,
                            style: AppText.label.copyWith(color: AppColors.onBrand(AppColors.accent))),
                      ),
                    ),
                    childWhenDragging: Icon(Icons.drag_indicator_rounded, size: 17, color: fg.withValues(alpha: 0.3)),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(Icons.drag_indicator_rounded, size: 17, color: fg.withValues(alpha: 0.66)),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => onRemove(config.id),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.close_rounded, size: 15, color: fg.withValues(alpha: 0.66)),
                    ),
                  ),
                ],
              ),
              IgnorePointer(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// عنوان قسم داخل اللوحة: نص بوزن واحد يسبقه خيط ذهبي.
///
/// اللوحة كانت أقساماً متلاصقة بلا فواصل، فيقرؤها الناظر كتلةً واحدة. والخيط
/// الذهبي هو العنصر نفسه المستعمل في شاشة الدخول وترويسة اللوحة — تكراره
/// المقصود هو ما يجعل الشاشات تبدو منصةً واحدة لا شاشات جُمعت.
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        // `Flexible` لا نصٌّ حرّ: `Row` يعطي ابنه عرضاً غير محدود، فعنوانٌ
        // أطول قليلاً يتجاوز حدّ الشاشة على الجوال ويظهر شريط التجاوز.
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }
}


/// لوحة بلا ودجات — تقول ذلك وتدلّ على الطريق، بدل صفحة بيضاء صامتة.
class _EmptyBoardNotice extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBoardNotice({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 32, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text(
            'لوحتك بلا رسوم ولا قوائم',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'المؤشرات أعلاه تبقى ظاهرة دائماً. أما الرسوم والقوائم فتُضاف من هنا.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('أضف ودجة'),
          ),
        ],
      ),
    );
  }
}
