import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../models/project_category.dart';
import '../models/project_sort.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../widgets/filter_bar.dart';
import '../widgets/meta_row.dart';
import '../utils/formatters.dart';
import '../utils/platform_url.dart';
import '../widgets/custom_widgets_section.dart';
import '../widgets/progress_bar.dart';
import '../widgets/project_actions.dart';
import '../widgets/status_chip.dart';
import 'late_alert_review_dialog.dart';
import 'project_detail_screen.dart';
import 'request_project_dialog.dart';

/// شاشة موحّدة لعرض جميع المشاريع (ضمن النطاق المسموح به للمستخدم) بمعزل
/// عن التنقل عبر الإدارات، مع فلاتر حسب الإدارة والشخص المنفذ.
class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _departmentFilter;

  /// معرّف حساب لا اسم نصّي: التصفية بالاسم كانت تُسقط من هو عضو في المشروع
  /// بحسابه دون أن يرد اسمه في `executorNames`. والمطابقة تقع بـ`projectsOf`
  /// وهي تعرف الصفتين معاً.
  String? _userFilter;
  ProjectStatus? _statusFilter;
  String? _categoryFilter;
  // المبدئي «الأهم أولاً» لا «الاسم»: الصفحة تُفتح للسؤال «ما الذي يحتاجني
  // الآن؟»، والترتيب الأبجدي لا يجيب عنه.
  ProjectSort _sort = ProjectSort.smart;

  /// المشاريع المحدَّدة للإجراء الجماعي — معرّفات لا كائنات.
  ///
  /// والمعرّف لا الكائن لأن قائمة المشاريع تُعاد بناؤها مع كل تحديث من
  /// Firestore: كائنٌ محفوظ يصير نسخةً قديمة بلا أن يظهر ذلك، فيُرسَل تنبيهٌ
  /// بنسبة إنجاز لم تعد صحيحة.
  final Set<String> _selected = {};

  bool get _hasFilters =>
      _departmentFilter != null ||
      _userFilter != null ||
      _statusFilter != null ||
      _categoryFilter != null ||
      _query.isNotEmpty;

  void _clearFilters() => setState(() {
        _departmentFilter = null;
        _userFilter = null;
        _statusFilter = null;
        _selected.clear();
        _categoryFilter = null;
        _searchCtrl.clear();
        _query = '';
      });

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// يعرض ما سيتغيّر **قبل** أن يتغيّر: تعديل عشرات المستندات دفعةً واحدة
  /// دون أن يرى مسؤول النظام ماذا سيمسّه ليس قراراً بل مقامرة.
  Future<void> _reconcileStatuses(BuildContext context, AppStore store) async {
    final stale = store.projectsWithStaleStatus;
    final sample = stale.take(5).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مطابقة الحالات المخزّنة'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stale.length} مشروعاً حالته المخزّنة تخالف تاريخ استحقاقه. '
                  'المنصة تعرض الحالة الصحيحة أصلاً؛ هذه المطابقة تكتبها في السجل '
                  'حتى تتفق معها التقارير المُصدَّرة.',
                  style: const TextStyle(fontSize: 13, height: 1.9, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                for (final p in sample)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${p.name}: ${p.status.label} ← ${p.effectiveStatus.label}',
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                  ),
                if (stale.length > sample.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('و${stale.length - sample.length} غيرها…',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('طابِق')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = await store.reconcileProjectStatuses();
    messenger.showSnackBar(SnackBar(content: Text('طوبقت حالة $count مشروعاً.')));
  }

  /// يفتح نافذة مراجعة تنبيه التأخير على المشاريع المُعطاة.
  ///
  /// ــــ لماذا لا يُرسل من هنا مباشرةً؟ ــــ
  ///
  /// كان الزرّ يعرض سؤالاً فيه عددان وثمانية أسماء ثم يُرسل. وهو لا يكفي
  /// لإجراءٍ جماعي: من ضغط «تنبيه ٤٧ مشروعاً» لا يستطيع أن يستثني مشروعاً
  /// سُلِّم أمس، ولا شخصاً في إجازة. فصار القرار في نافذة مراجعة تُري كل
  /// شيء وتسمح باستبعاد أيٍّ منه — راجع `LateAlertReviewDialog`.
  void _reviewLateAlert(BuildContext context, List<Project> projects) {
    if (projects.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => LateAlertReviewDialog(
        projects: projects,
        // العنوان يُقرأ **هنا** لا في بناء الرسالة: هذا موضعٌ يعمل في
        // المتصفح، وبناء الرسالة يعمل في الاختبارات كذلك حيث `Uri.base`
        // مجلّد عمل لا عنوان منصة.
        baseUrl: platformBaseUrl(),
      ),
    );
  }

  /// عنوان الفراغ — **يسمّي النطاق** بدل عبارة عامة.
  ///
  /// «لا توجد مشاريع» جوابٌ لا يفرّق بين ثلاث حالات مختلفة تماماً: حسابٌ
  /// بلا إدارة، وإدارةٌ لا مشاريع فيها، وتصفيةٌ لم تطابق. وذكرُ اسم الإدارة
  /// يحسم الأمر بنظرة: إن كان الاسم صحيحاً فالإدارة فارغة، وإن كان غيره
  /// فالحساب مرتبط بإدارة أخرى — وكلاهما يُقرأ من الشاشة بلا سؤال وجواب.
  String _emptyHeadline(AppStore store) {
    if (store.canViewAllDepartments) {
      return store.projects.isEmpty ? 'لا توجد مشاريع مسجّلة بعد' : 'لا توجد مشاريع مطابقة لبحثك';
    }
    if (store.myDepartmentIds.isEmpty) return 'لا توجد إدارة مرتبطة بحسابك';
    if (store.visibleProjects.isNotEmpty) return 'لا توجد مشاريع مطابقة لبحثك';
    final names = store.myDepartmentIds
        .map((id) => store.departmentById(id)?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return 'لا توجد مشاريع في نطاقك بعد';
    return 'إدارتك: ${names.join('، ')} — لا مشاريع مسجّلة فيها بعد';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var projects = store.visibleProjects;

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      projects = projects
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.executorNames.any((e) => e.toLowerCase().contains(q)))
          .toList();
    }
    if (_departmentFilter != null) {
      projects = projects.where((p) => p.departmentId == _departmentFilter).toList();
    }
    if (_userFilter != null) {
      final user = store.users.where((u) => u.id == _userFilter).firstOrNull;
      // `projectsOf` تعرف العضوية بالحساب **والاسم النصي** معاً، فلا تُسقط
      // مشاريع الوزارة المستوردة التي تحمل اسم المنفّذ بلا حساب يقابله.
      final theirs = user == null ? const <String>{} : store.projectsOf(user).map((p) => p.id).toSet();
      projects = projects.where((p) => theirs.contains(p.id)).toList();
    }
    if (_statusFilter != null) {
      // الحالة الفعلية لا المخزَّنة — وهي مصدر الحقيقة الوحيد في المنصة،
      // وبها وحدها تتفق التصفية مع الشارة المعروضة على البطاقة نفسها.
      projects = projects.where((p) => p.effectiveStatus == _statusFilter).toList();
    }
    if (_categoryFilter != null) {
      projects = projects.where((p) => p.categoryIds.contains(_categoryFilter)).toList();
    }

    final sortedProjects = sortProjects(
      projects: projects,
      sort: _sort,
      lastUpdateOf: store.lastUpdateByProject,
    );
    final lateProjects =
        projects.where((p) => p.effectiveStatus == ProjectStatus.delayed).toList();
    // ــ متى تظهر مربّعات التحديد؟ ــ
    //
    // مع فلتر «متأخر» وحده. وليس تضييقاً بلا سبب: الإجراء الجماعي الوحيد
    // اليوم تنبيهُ تأخير، ومربّع تحديدٍ على مشروعٍ ليس متأخراً يَعِد بإجراء
    // لا وجود له. ومتى وُجد إجراء آخر وُسِّع الشرط عندها.
    final selectionMode = store.canBulkDelayAlert && _statusFilter == ProjectStatus.delayed;

    final departmentOptions = store.visibleDepartments.where((d) => store.projectsForDepartment(d.id).isNotEmpty).toList();
    final userOptions = store.users.where((u) => u.status == UserStatus.approved).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'المشاريع',
            subtitle: 'كل المشاريع ضمن نطاقك، بمعزل عن التنقل عبر الإدارات',
            actions: [
              // تنبيه المتأخرات: يحمل عدد ما سيمسّه، ولا يظهر إن لم يوجد
              // متأخر ضمن المعروض — زرٌّ لا يفعل شيئاً يُضلّل.
              //
              // والصلاحية `bla` لا `ntf`: الأولى تنبيهُ متأخرين بنصٍّ تبنيه
              // المنصة، والثانية رسالةٌ حرّة إلى أي مستخدم في الوزارة. ودمجُ
              // البابين كان يعني منح الثاني لمن أردنا له الأول.
              if (store.canBulkDelayAlert && lateProjects.isNotEmpty)
                BandButton(
                  label: 'تنبيه ${lateProjects.length} مشروعاً متأخراً',
                  icon: Icons.mark_email_unread_outlined,
                  onPressed: () => _reviewLateAlert(context, lateProjects),
                ),
              if (store.isAdmin)
                BandButton(
                  label: 'التصنيفات',
                  icon: Icons.sell_outlined,
                  onPressed: () => showDialog(context: context, builder: (_) => const _CategoriesDialog()),
                ),
              // مطابقة الحالات المخزّنة مع تواريخ الاستحقاق.
              //
              // العرض يستعمل الحالة الفعلية دائماً، فالمنصة متسقة بدون هذا
              // الزر. لكن الحقل المخزَّن يخرج مع التقارير المُصدَّرة ويقرؤه
              // أي نظام آخر، فمطابقته تمنع أن يقرأ الخارج حالةً غير التي
              // يراها المستخدم على الشاشة.
              if (store.isAdmin && store.projectsWithStaleStatus.isNotEmpty)
                BandButton(
                  label: 'مطابقة ${store.projectsWithStaleStatus.length} حالة مخزّنة',
                  icon: Icons.rule_rounded,
                  onPressed: () => _reconcileStatuses(context, store),
                ),
              // الزر لكل من ينتمي لإدارة، لا لمسؤول النظام وحده: الموظف
              // **يطلب** والطلب ليس منحاً، والبتّ محكوم بـ canApprove.
              // ومن مُنِح «إنشاء المشاريع» في نطاق هذه الإدارة يُنشئ مباشرةً.
              if (store.canRequestNewProject(store.currentUser?.departmentId ?? ''))
                BandButton(
                  label: store.canCreateIn(store.currentUser?.departmentId) || store.isAdmin
                      ? 'إضافة مشروع'
                      : 'طلب إضافة مشروع',
                  icon: Icons.add_rounded,
                  filled: true,
                  onPressed: () => showDialog(context: context, builder: (_) => const RequestProjectDialog()),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          FilterBar(
            fields: [
              (
                preferredWidth: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المشروع أو المنفذ',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              (
                preferredWidth: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _departmentFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب الإدارة', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                    ...departmentOptions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _departmentFilter = v),
                ),
              ),
              (
                preferredWidth: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _userFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب المستخدم', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المستخدمين')),
                    ...userOptions.map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.name, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _userFilter = v),
                ),
              ),
              (
                preferredWidth: 200,
                child: DropdownButtonFormField<ProjectStatus?>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب الحالة', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                    ...ProjectStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                  ],
                  onChanged: (v) => setState(() {
                    _statusFilter = v;
                    // تبدُّل الفلتر يُسقط التحديد: مشروعٌ حُدِّد ثم خرج من
                    // المعروض يبقى في المجموعة صامتاً، فيُرسَل تنبيهه مع
                    // دفعةٍ أخرى ولا يرى المُرسِل اسمه على الشاشة.
                    _selected.clear();
                  }),
                ),
              ),
              // حقل التصنيف لا يظهر قبل تعريف تصنيف واحد على الأقل: قائمةٌ
              // خيارها الوحيد «كل التصنيفات» تشغل مكاناً ولا تفعل شيئاً.
              if (store.categories.isNotEmpty)
                (
                  preferredWidth: 200,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'تصفية حسب التصنيف', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('كل التصنيفات')),
                      ...store.categories.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                ),
              (
                preferredWidth: 190,
                child: DropdownButtonFormField<ProjectSort>(
                  initialValue: _sort,
                  isExpanded: true,
                  // «ترتيب حسب» لا «التصنيف»: المستخدم هنا لا يغيّر فئة
                  // المشروع، بل يقرّر ما الذي يظهر أولاً.
                  decoration: const InputDecoration(labelText: 'ترتيب حسب', isDense: true),
                  items: ProjectSort.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _sort = v ?? _sort),
                ),
              ),
              if (_hasFilters)
                (
                  preferredWidth: 150,
                  child: TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('مسح الفلاتر'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (selectionMode) ...[
            _SelectionBar(
              matching: lateProjects,
              selected: _selected,
              onSelectAll: () => setState(() {
                _selected
                  ..clear()
                  ..addAll(lateProjects.map((p) => p.id));
              }),
              onClear: () => setState(_selected.clear),
              onSend: () => _reviewLateAlert(
                context,
                lateProjects.where((p) => _selected.contains(p.id)).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('${projects.length} مشروع', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          // مشاريع الوزارة المستوردة لا تحمل تاريخ إضافة، فتُرتَّب بتاريخ
          // بدئها. ويُقال ذلك بدل إيهام دقّةٍ لا وجود لها — من يرتّب
          // بالأحدث يحقّ له أن يعرف أن بعض الصف مرتَّب بمقياس آخر.
          if (_sort.usesCreatedAt && projects.any((p) => p.createdAt == null)) ...[
            const SizedBox(height: 6),
            Text(
              '${projects.where((p) => p.createdAt == null).length} مشروعاً لا يحمل تاريخ إضافة '
              '(مستورد من ملفات الوزارة) — يقع في آخر القائمة في هذا الترتيب.',
              style: AppText.micro.copyWith(color: AppColors.textSecondary, height: 1.7),
            ),
          ],
          const SizedBox(height: 10),
          // «لا توجد مشاريع مطابقة» جوابٌ خاطئ حين لا يكون للحساب إدارة أصلاً:
          // نطاق المستخدم عندها **فارغ بنيوياً** لا مُصفّى، فيبحث عن عطل ليس
          // موجوداً. ونفرّق كذلك بين نطاق خالٍ وتصفية لم تطابق شيئاً.
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_off_outlined, size: 34, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      _emptyHeadline(store),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    // ــ وما وصل من الخادم يُقال، فالصفرُ خبرٌ لا لغز ــ
                    //
                    // راجع [AppStore.projectsArrivalNote]: «لا توجد مشاريع»
                    // جملةٌ تصف القائمة ولا تصف الحال.
                    if (store.projectsArrivalNote != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        store.projectsArrivalNote!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
                      ),
                    ],
                    if (store.myDepartmentIds.isEmpty && !store.canViewAllDepartments) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'مشاريعك تُعرض بحسب إدارتك. اطلب من مسؤول النظام ربط حسابك بإدارتك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.7),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...sortedProjects.map((p) => _ProjectRow(
                  project: p,
                  selectable: selectionMode,
                  selected: _selected.contains(p.id),
                  onSelected: () => setState(() {
                    if (!_selected.remove(p.id)) _selected.add(p.id);
                  }),
                )),
          const SizedBox(height: 28),
          CustomWidgetsSection(
            store: store,
            widgets: store.projectsPageWidgets,
            onSave: store.saveProjectsPageWidgets,
            canManage: store.canManageDashboard,
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «متأخر ٧ أيام» أو «متبقي ٣ أيام» — بصيغة العربية لا بصيغة واحدة جامدة.
String _dueLabel(Project project) {
  if (project.effectiveStatus == ProjectStatus.completed) return 'مكتمل';
  final late = project.delayDays;
  if (late > 0) return 'متأخر ${_days(late)}';
  final left = project.remainingDays;
  if (left == 0) return 'يستحق اليوم';
  return 'متبقي ${_days(left)}';
}

/// تمييز العدد في العربية: يومٌ، ويومان، وثلاثةُ أيام… وما جاوز العشرة يوماً.
String _days(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n <= 10) return '$n أيام';
  return '$n يوماً';
}

Color _dueColor(Project project) {
  if (project.effectiveStatus == ProjectStatus.completed) return AppColors.success;
  if (project.delayDays > 0) return AppColors.danger;
  // أسبوعٌ أو أقل تحذير لا اطمئنان: هو آخر ما يمكن التصرّف فيه.
  return project.remainingDays <= 7 ? AppColors.warning : AppColors.success;
}

/// شريط الإجراء الجماعي — يظهر مع فلتر «متأخر».
///
/// ــــ لماذا يقول «كل المتأخرة المطابقة» صراحةً؟ ــــ
///
/// لأن «تحديد الكل» في أكثر المنصات يعني **ما ظهر على الشاشة** لا ما طابق
/// الفلتر، فيظنّ المستخدم أنه نبّه سبعةً وأربعين وقد نبّه عشرة. والصفحة هنا
/// تعرض كل المطابق بلا تقسيم صفحات، فالتحديد يشمله كلّه — ويُقال ذلك بالعدد
/// لا بالضمني، فلا يبقى للظنّ موضع.
class _SelectionBar extends StatelessWidget {
  final List<Project> matching;
  final Set<String> selected;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onSend;

  const _SelectionBar({
    required this.matching,
    required this.selected,
    required this.onSelectAll,
    required this.onClear,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final count = matching.where((p) => selected.contains(p.id)).length;
    final all = count == matching.length && matching.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                count == 0 ? 'لم يُحدَّد شيء' : 'حُدِّد $count من ${matching.length}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              if (!all)
                OutlinedButton.icon(
                  onPressed: onSelectAll,
                  icon: const Icon(Icons.select_all_rounded, size: 16),
                  label: Text('تحديد جميع المشاريع المتأخرة الـ${matching.length}'),
                ),
              if (count > 0)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('إلغاء التحديد'),
                ),
              if (count > 0)
                FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.mark_email_unread_outlined, size: 16),
                  label: Text('إرسال تنبيه التأخير ($count)'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'التحديد يشمل كل المشاريع المتأخرة المطابقة للفلتر الحالي (${matching.length})، '
            'لا ما يظهر أمامك على الشاشة فقط.',
            style: const TextStyle(fontSize: 11, height: 1.7, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  final bool selectable;
  final bool selected;
  final VoidCallback? onSelected;

  const _ProjectRow({
    required this.project,
    this.selectable = false,
    this.selected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(project.departmentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // الحدّ الملوّن على المحدَّد: من يمرّر أربعين بطاقة يحتاج أن يرى ما
      // اختاره بنظرة، لا أن يقرأ مربّعاً صغيراً في طرف كل بطاقة.
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primary, width: 1.6),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // في وضع التحديد تفتح النقرةُ المشروعَ كما كانت — والتحديد بمربّعه
        // وحده. وجعلُ النقرة تُحدِّد يمنع الدخول إلى المشروع للتحقّق منه قبل
        // تنبيه مسؤوليه، وهو أوّل ما يفعله من يراجع.
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(project.name)),
            body: ProjectDetailScreen(projectId: project.id),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectable)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Checkbox(
                        value: selected,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (_) => onSelected?.call(),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        // شارة الإدارة تُقتطع ولا تخرج: الشارة والأزرار على
                        // يمين البطاقة لا تترك للعنوان على شاشة الهاتف إلا
                        // نحو سبعين بكسل، فاسم إدارة عادي يتجاوزها.
                        if (dept != null)
                          MetaChip(icon: dept.icon, text: dept.name, color: dept.color)
                        else
                          const Text('بدون إدارة', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  StatusChip(status: project.effectiveStatus),
                  // ــــ إجراءات المسؤول في قائمة واحدة لا أزرارٍ متجاورة ــــ
                  //
                  // كانت زرّين، فأضفتُ ثالثاً (التصنيفات) فتجاوز الصفُّ عرض
                  // آيفون SE بسبعة بكسلات. وهذه المرة الثانية التي يقع فيها
                  // هذا في المنصة — الأولى كانت سبعة أزرار في صفّ إدارة
                  // المستخدمين. فالعلاج هنا ليس إعادة الحساب لثلاثة أزرار،
                  // بل بنيةٌ لا يزيد عرضها بزيادة الإجراءات أصلاً.
                  //
                  // ونجمة التركيز تبقى **ظاهرة** بلا ضغط: هي حالة تُقرأ لا
                  // إجراء يُنقر، وإخفاؤها في قائمة يُفقد المسؤول معرفةَ ما
                  // هو تحت التركيز بنظرة.
                  if (store.isAdmin) ...[
                    if (store.isFocused(project.id))
                      // بلا const: `AppColors.accent` لون هوية قابل للتغيير.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.star_rounded, size: 18, color: AppColors.accent),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 19, color: AppColors.textSecondary),
                      tooltip: 'إجراءات المشروع',
                      onSelected: (value) {
                        switch (value) {
                          case 'tags':
                            showDialog(
                              context: context,
                              builder: (_) => _ProjectTagsDialog(project: project),
                            );
                          case 'focus':
                            store.toggleFocusedProject(project);
                          case 'delete':
                            confirmDeleteProject(context, project);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'tags',
                          child: Row(children: [
                            Icon(Icons.sell_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('التصنيفات'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'focus',
                          child: Row(children: [
                            Icon(
                              store.isFocused(project.id) ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(store.isFocused(project.id) ? 'إزالة من التركيز' : 'وضع تحت التركيز'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            SizedBox(width: 10),
                            Text('حذف المشروع', style: TextStyle(color: AppColors.danger)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              MetaRow(
                runSpacing: 6,
                children: [
                  MetaChip(icon: Icons.event_outlined, text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  // ــ المدة لا التاريخ ــ
                  //
                  // كان يُكتب «ضمن الجدول الزمني» لكل من لم يتأخر — وهي عبارة
                  // لا تفرّق بين مشروعٍ بقي له ثلاثة أيام وآخر بقي له سنة.
                  // فمن أراد أن يعرف كم بقي كان يقرأ تاريخ الاستحقاق ويحسب
                  // المدة بنفسه في كل مرة.
                  MetaChip(
                    icon: Icons.schedule_rounded,
                    text: _dueLabel(project),
                    color: _dueColor(project),
                  ),
                ],
              ),
              if (project.executorNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                MetaLine(icon: Icons.badge_outlined, text: 'المنفذ: ${project.executorSummary}'),
              ],
              // الوسوم من `categoriesOf` لا من `categoryIds` مباشرةً: تلك
              // معرّفات قد يشير بعضها إلى تصنيف محذوف، والدالة تُسقطه.
              if (store.categoriesOf(project).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in store.categoriesOf(project))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: c.color.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          c.name,
                          style: AppText.label.copyWith(color: AppColors.textPrimary, fontSize: 10.5),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


/// إدارة قائمة التصنيفات — لمسؤول النظام وحده.
///
/// القائمة مركزية لا حرّة لكل مستخدم: لو كتب كلٌّ وسمه بنفسه لتفرّقت
/// «رقمنة» و«الرقمنة» و«رقمنه» على ثلاثة وسوم، وصارت التصفية بها بلا معنى.
class _CategoriesDialog extends StatefulWidget {
  const _CategoriesDialog();

  @override
  State<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<_CategoriesDialog> {
  late List<ProjectCategory> _items;
  final _newCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _loaded = false;

  /// ألوان الوسوم من لوحة الرسوم القائمة — لا ألوان الدلالة (نجاح/خطر): تلك
  /// تحمل معنىً وظيفياً، ووسمٌ أحمر يوحي بخطر لا وجود له.
  static final _palette = AppColors.chartPalette;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _items = List.of(context.read<AppStore>().categories);
    _loaded = true;
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    if (_items.any((c) => c.name == name)) {
      setState(() => _error = 'التصنيف «$name» موجود بالفعل');
      return;
    }
    setState(() {
      _items.add(ProjectCategory(
        id: 'c${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        colorValue: _palette[_items.length % _palette.length].toARGB32(),
      ));
      _newCtrl.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final error = await context.read<AppStore>().saveCategories(_items);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصنيفات المشاريع'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'التصنيف يقطع الهيكل التنظيمي: مبادرة واحدة قد تشمل مشاريع من عدة إدارات. '
                'والمشروع يحمل أكثر من تصنيف.',
                style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCtrl,
                      decoration: const InputDecoration(labelText: 'تصنيف جديد', isDense: true),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _add, icon: const Icon(Icons.add_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 14),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('لا توجد تصنيفات بعد', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ..._items.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            tooltip: 'حذف التصنيف',
                            // الحذف من القائمة وحدها. والمعرّف قد يبقى مكتوباً
                            // على مشاريع، و`groupProjects` تُسقط المعرّف الذي
                            // لا تصنيف له فيقع المشروع في «بلا تصنيف» — بدل
                            // مجموعةٍ بلا اسم أو مسحٍ لعشرات المستندات هنا.
                            onPressed: () => setState(() => _items.remove(c)),
                          ),
                        ],
                      ),
                    )),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

/// اختيار تصنيفات مشروع بعينه.
class _ProjectTagsDialog extends StatefulWidget {
  final Project project;
  const _ProjectTagsDialog({required this.project});

  @override
  State<_ProjectTagsDialog> createState() => _ProjectTagsDialogState();
}

class _ProjectTagsDialogState extends State<_ProjectTagsDialog> {
  late final Set<String> _selected = widget.project.categoryIds.toSet();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return AlertDialog(
      title: Text('تصنيفات ${widget.project.name}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (store.categories.isEmpty)
                const Text(
                  'لا توجد تصنيفات معرَّفة. يضيفها مسؤول النظام من زرّ «التصنيفات» أعلى الصفحة.',
                  style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in store.categories)
                      FilterChip(
                        label: Text(c.name),
                        selected: _selected.contains(c.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selected.add(c.id);
                          } else {
                            _selected.remove(c.id);
                          }
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy || store.categories.isEmpty
              ? null
              : () async {
                  setState(() => _busy = true);
                  final navigator = Navigator.of(context);
                  await store.setProjectCategories(widget.project, _selected.toList());
                  if (mounted) navigator.pop();
                },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
