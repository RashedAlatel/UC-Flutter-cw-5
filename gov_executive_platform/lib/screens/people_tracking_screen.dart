import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/kpi_card.dart';
import '../widgets/notify_dialog.dart';
import '../widgets/progress_bar.dart';
import 'project_detail_screen.dart';

/// أعمدة جدول المقارنة القابلة للترتيب.
enum _SortBy {
  name('الاسم'),
  works('عدد الأعمال'),
  progress('متوسط الإنجاز'),
  overdue('المتأخر'),
  projects('عدد المشاريع');

  final String label;
  const _SortBy(this.label);
}

/// شاشة متابعة الأشخاص: جدول يقارن الجميع، والضغط على أي شخص يفتح ملف أدائه.
class PeopleTrackingScreen extends StatefulWidget {
  const PeopleTrackingScreen({super.key});

  @override
  State<PeopleTrackingScreen> createState() => _PeopleTrackingScreenState();
}

class _PeopleTrackingScreenState extends State<PeopleTrackingScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SortBy _sortBy = _SortBy.works;
  bool _descending = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = _query.trim().toLowerCase();

    var people = store.trackablePeople
        .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
        .toList();

    int cmp(AppUser a, AppUser b) {
      final sa = store.personStats(a);
      final sb = store.personStats(b);
      switch (_sortBy) {
        case _SortBy.name:
          return a.name.compareTo(b.name);
        case _SortBy.works:
          return sa.works.compareTo(sb.works);
        case _SortBy.progress:
          return sa.avgWorkProgress.compareTo(sb.avgWorkProgress);
        case _SortBy.overdue:
          return (sa.worksOverdue + sa.projectsOverdue).compareTo(sb.worksOverdue + sb.projectsOverdue);
        case _SortBy.projects:
          return sa.projects.compareTo(sb.projects);
      }
    }

    people.sort((a, b) => _descending ? cmp(b, a) : cmp(a, b));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('متابعة الأشخاص',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('${people.length} شخص ضمن نطاقك · اضغط على أي اسم لعرض ملف أدائه',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 18),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو البريد',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<_SortBy>(
                  initialValue: _sortBy,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ترتيب حسب', isDense: true),
                  items: _SortBy.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                  onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
                ),
              ),
              IconButton(
                icon: Icon(_descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 20),
                tooltip: _descending ? 'من الأعلى للأدنى' : 'من الأدنى للأعلى',
                onPressed: () => setState(() => _descending = !_descending),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (people.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا يوجد أشخاص ضمن نطاقك', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: people.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _PersonRow(user: people[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AppUser user;
  const _PersonRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.personStats(user);
    final dept = user.departmentId != null ? store.departmentById(user.departmentId!) : null;
    final overdue = s.worksOverdue + s.projectsOverdue;

    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(user.name)),
          body: PersonProfileScreen(user: user),
        ),
      )),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(user.name.isNotEmpty ? user.name.substring(0, 1) : '؟',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text('${user.role.label}${dept != null ? ' · ${dept.name}' : ''}',
          style: const TextStyle(fontSize: 11.5)),
      trailing: Wrap(
        spacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Stat(label: 'أعمال', value: '${s.works}'),
          _Stat(label: 'إنجاز', value: Formatters.percent(s.avgWorkProgress)),
          _Stat(label: 'مشاريع', value: '${s.projects}'),
          _Stat(label: 'متأخر', value: '$overdue', color: overdue > 0 ? AppColors.danger : null),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: color ?? AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// ملف أداء شخص واحد: مؤشراته، أعماله، مشاريعه، وزر مراسلته.
class PersonProfileScreen extends StatelessWidget {
  final AppUser user;
  const PersonProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.personStats(user);
    final works = store.worksOf(user);
    final projects = store.projectsOf(user);
    final dept = user.departmentId != null ? store.departmentById(user.departmentId!) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(user.name.isNotEmpty ? user.name.substring(0, 1) : '؟',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('${user.role.label}${dept != null ? ' · ${dept.name}' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(user.email, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (store.canSendNotifications)
                    ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => NotifyDialog(initialUsers: [user]),
                      ),
                      icon: const Icon(Icons.forward_to_inbox_rounded, size: 17),
                      label: const Text('مراسلة'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 820 ? 4 : (c.maxWidth > 520 ? 2 : 1);
            const spacing = 14.0;
            const itemHeight = 92.0;
            final itemWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: itemWidth / itemHeight,
              children: [
                KpiCard(title: 'أعماله', value: '${s.works}', icon: Icons.checklist_rounded, color: AppColors.primary),
                KpiCard(title: 'منجزة منها', value: '${s.worksDone}', icon: Icons.check_circle_outline_rounded, color: AppColors.success),
                KpiCard(title: 'متوسط الإنجاز', value: Formatters.percent(s.avgWorkProgress), icon: Icons.trending_up_rounded, color: AppColors.info),
                KpiCard(title: 'متأخر عن موعده', value: '${s.worksOverdue + s.projectsOverdue}', icon: Icons.schedule_rounded, color: AppColors.danger),
              ],
            );
          }),
          const SizedBox(height: 20),

          const Text('أعماله التشغيلية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (works.isEmpty)
            const Text('لا توجد أعمال مُسنَدة إليه', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5))
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: works.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final w = works[i];
                  return ListTile(
                    dense: true,
                    title: Text(w.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LabeledProgressBar(value: w.progressPercent, label: w.status.label),
                    ),
                    trailing: w.delayDays > 0
                        ? Text('متأخر ${w.delayDays} يوم',
                            style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w700))
                        : Text(Formatters.shortDate(w.dueDate), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),

          const Text('مشاريعه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            const Text('لا توجد مشاريع مرتبطة به', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5))
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: projects.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(p.name)),
                        body: ProjectDetailScreen(projectId: p.id),
                      ),
                    )),
                    title: Text(p.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LabeledProgressBar(value: p.progressPercent, label: p.effectiveStatus.label),
                    ),
                    trailing: p.delayDays > 0
                        ? Text('متأخر ${p.delayDays} يوم',
                            style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w700))
                        : Text(Formatters.shortDate(p.dueDate), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
