// شاشةُ البحث الموحّدة — المشاريعُ والأعمالُ في مكانٍ واحد.
//
// ــــ لماذا شاشةٌ ثالثة ــــ
//
// «نوعُ السجل: مشروع أو عمل» فلترٌ لا معنى له داخل صفحة المشاريع ولا داخل
// صفحة الأعمال — كلٌّ منهما تعرض نوعاً واحداً أصلاً. فهو يعني شاشةً تجمع
// الاثنين، وهي هذه.
//
// ــــ ولا بوابةَ لها ــــ
//
// نطاقُها `visibleProjects` و`visibleWorks` — أي ما يراه صاحبُه في الشاشتين
// أصلاً. فهي طريقٌ آخر إلى ما يملكه لا بابٌ إلى ما لا يملك، ولم تُمسّ لها
// قاعدةٌ ولا صلاحية.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/record_filter.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/command_band.dart';
import '../widgets/record_filter_bar.dart';
import 'project_detail_screen.dart';
import 'work_detail_screen.dart';

/// يفتح تفاصيلَ سجلٍّ في صفحةٍ فوق البحث — **فتبقى النتائجُ خلفَه**.
///
/// وهو ما طلبتَه: «عدم فقدان الفلاتر عند فتح مشروع ثم العودة». والرجوعُ
/// يُعيد الشاشةَ كما تُركت لأنها لم تُبنَ من جديد.
void _open(BuildContext context, String title, Widget body) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
  ));
}

/// مفتاحُ خانة الفلتر لهذه الشاشة — راجع `AppStore.recordFilterFor`.
const String kSearchFilterKey = 'search';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final filter = store.recordFilterFor(kSearchFilterKey);
    final input = store.recordFilterInput();
    final out = applyRecordFilter(filter, input);

    final total = input.projects.length + input.works.length;
    final shown = out.projects.length + out.works.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommandBand(
            title: 'البحث',
            subtitle: 'ابحث في المشاريع والأعمال معاً، وصفِّ بأكثر من شرطٍ في وقتٍ واحد',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecordFilterBar(
                  store: store,
                  filter: filter,
                  shown: shown,
                  total: total,
                  fields: const {
                    FilterField.query,
                    FilterField.department,
                    FilterField.section,
                    FilterField.executor,
                    FilterField.manager,
                    FilterField.projectStatus,
                    FilterField.workStatus,
                    FilterField.category,
                    FilterField.kind,
                  },
                  onChanged: (f) => store.setRecordFilter(kSearchFilterKey, f),
                ),
                const SizedBox(height: 8),
                // ــ وحدودُ البيانات تُقال لا تُترك تُستنتج ــ
                //
                // العملُ بلا قسمٍ وبلا مديرِ مشروع. فاختيارُ أيّهما يُخرج
                // الأعمالَ كلَّها — وهو صحيح، لكن فراغاً صامتاً يُقرأ عطلاً.
                if (filter.sectionId != null || filter.managerUid != null)
                  _Note(
                    filter.sectionId != null
                        ? 'الأعمالُ لا تتبع أقساماً، فاختيارُ قسمٍ يعرض المشاريع وحدها.'
                        : 'الأعمالُ ليس لها مديرُ مشروع — لها مُسنَدٌ إليه، فاختيارُ '
                            'مديرٍ يعرض المشاريع وحدها.',
                  ),
                const SizedBox(height: 16),
                if (shown == 0)
                  const _Empty()
                else ...[
                  if (out.projects.isNotEmpty) ...[
                    _GroupTitle('المشاريع', out.projects.length),
                    for (final p in out.projects)
                      _Row(
                        title: p.name,
                        subtitle: [
                          store.departmentById(p.departmentId)?.name ?? 'بدون إدارة',
                          if (store.sectionPathLabel(p.sectionId).isNotEmpty)
                            store.sectionPathLabel(p.sectionId),
                          'يستحق ${Formatters.date(p.dueDate)}',
                        ].join(' · '),
                        badge: p.effectiveStatus.label,
                        color: AppColors.statusColor(p.effectiveStatus.name),
                        onTap: () => _open(context, p.name, ProjectDetailScreen(projectId: p.id)),
                      ),
                    const SizedBox(height: 18),
                  ],
                  if (out.works.isNotEmpty) ...[
                    _GroupTitle('الأعمال', out.works.length),
                    for (final w in out.works)
                      _Row(
                        title: w.title,
                        subtitle: [
                          store.departmentById(w.departmentId)?.name ?? 'بدون إدارة',
                          w.assigneeName.isEmpty ? 'لم يُسنَد' : w.assigneeName,
                          'يستحق ${Formatters.date(w.dueDate)}',
                        ].join(' · '),
                        badge: w.status.label,
                        color: AppColors.info,
                        onTap: () => _open(context, w.title, WorkDetailScreen(workId: w.id)),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, height: 1.7, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

class _GroupTitle extends StatelessWidget {
  final String label;
  final int count;
  const _GroupTitle(this.label, this.count);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('$label ($count)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
      );
}

class _Row extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  const _Row({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'لا سجلَّ يطابق ما اخترت. جرّب إزالة أحد الفلاتر — '
              'وزرُّ إعادة الضبط أعلاه يزيلها كلَّها.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.8),
            ),
          ),
        ),
      );
}
