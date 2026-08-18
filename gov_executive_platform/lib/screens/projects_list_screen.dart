import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets_section.dart';
import '../widgets/progress_bar.dart';
import '../widgets/status_chip.dart';
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
  String? _departmentFilter;
  String? _executorFilter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var projects = store.visibleProjects;

    if (_departmentFilter != null) {
      projects = projects.where((p) => p.departmentId == _departmentFilter).toList();
    }
    if (_executorFilter != null) {
      projects = projects.where((p) => p.executorNames.contains(_executorFilter)).toList();
    }
    projects = projects.toList()..sort((a, b) => a.name.compareTo(b.name));

    final departmentOptions = store.visibleDepartments.where((d) => store.projectsForDepartment(d.id).isNotEmpty).toList();
    final executorOptions = store.visibleProjects.expand((p) => p.executorNames).toSet().toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المشاريع', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('كل المشاريع ضمن نطاقك، بمعزل عن التنقل عبر الإدارات', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                ),
              ),
              if (store.isAdmin)
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const RequestProjectDialog()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مشروع'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
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
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _executorFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'تصفية حسب المنفذ', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المنفذين')),
                    ...executorOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  ],
                  onChanged: (v) => setState(() => _executorFilter = v),
                ),
              ),
              if (_departmentFilter != null || _executorFilter != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _departmentFilter = null;
                    _executorFilter = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('مسح الفلاتر'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('${projects.length} مشروع', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد مشاريع مطابقة', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...projects.map((p) => _ProjectRow(project: p)),
          const SizedBox(height: 28),
          CustomWidgetsSection(
            store: store,
            widgets: store.projectsPageWidgets,
            onSave: store.saveProjectsPageWidgets,
            canManage: store.canManageDashboard,
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(project.departmentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        if (dept != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(dept.icon, size: 12, color: dept.color),
                              const SizedBox(width: 4),
                              Text(dept.name, style: TextStyle(fontSize: 11.5, color: dept.color, fontWeight: FontWeight.w700)),
                            ],
                          )
                        else
                          const Text('بدون إدارة', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  StatusChip(status: project.status),
                ],
              ),
              const SizedBox(height: 12),
              LabeledProgressBar(value: project.progressPercent, label: 'نسبة الإنجاز'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (project.executorNames.isNotEmpty)
                    _InfoBit(icon: Icons.badge_outlined, text: 'المنفذ: ${project.executorLabel}'),
                  _InfoBit(icon: Icons.event_outlined, text: 'الاستحقاق: ${Formatters.shortDate(project.dueDate)}'),
                  _InfoBit(
                    icon: Icons.schedule_rounded,
                    text: project.delayDays > 0 ? 'متأخر ${project.delayDays} يوم' : 'ضمن الجدول الزمني',
                    color: project.delayDays > 0 ? AppColors.danger : AppColors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoBit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
