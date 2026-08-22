import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/daily_report.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import 'project_detail_screen.dart';
import 'work_detail_screen.dart';

/// التقرير التنفيذي اليومي — **عرضاً فقط**.
///
/// ــــ لماذا لا تحسب هذه الشاشة شيئاً؟ ــــ
///
/// لأن التقرير نفسه يُرسل بالبريد. فلو حسبت الشاشة أبوابها بنفسها لَصار في
/// المنصة حسابان لشيء واحد، ولافترقا عند أول تعديل يُنسى في أحدهما — فيقرأ
/// المدير على الشاشة غير ما وصله في بريده، ولا يصيح شيء.
///
/// فالحساب على الخادم (`functions/src/daily_report.ts`)، والمستند يُكتب لكل
/// مستلم على حدة، وهذه الشاشة تقرؤه وتعرضه. وما يظهر هنا هو نصّ ما وصل
/// بالبريد حرفاً.
///
/// وكلُّ سطرٍ يُضغط: التقرير أداةُ تصرّفٍ لا نصُّ قراءة، فالضغط على اسم
/// المشروع أو المهمة يفتح صفحتها ليُتَّخذ الإجراء منها.
class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  Future<DailyReport?>? _future;
  bool _generating = false;

  /// اليوم المعروض. يبدأ اليوم، ويرجع بيومٍ إن لم يُولَّد بعد.
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    // القراءة تُطلق في `initState` لا في `build`: `build` يُنادى مع كل تحديث
    // من Firestore، وإطلاق الاستعلام فيه يعيد القراءة عشرات المرات.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    final store = context.read<AppStore>();
    setState(() => _future = store.loadMyDailyReport(_day));
  }

  void _shiftDay(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
    _reload();
  }

  void _generateNow() async {
    if (_generating) return;
    final store = context.read<AppStore>();
    setState(() => _generating = true);
    final error = await store.generateDailyReportNow();
    if (!mounted) return;
    setState(() => _generating = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر توليد التقرير: $error')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('وُلِّد تقرير اليوم. ولم يُرسل بريد — التوليد اليدوي للعرض.')),
    );
    final now = DateTime.now();
    setState(() => _day = DateTime(now.year, now.month, now.day));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'التقرير التنفيذي اليومي',
            subtitle: 'إدارةٌ بالاستثناء: ما يحتاج قراراً أو تدخّلاً أولاً — يصدر السابعة صباحاً',
            actions: [
              BandButton(
                label: 'اليوم السابق',
                icon: Icons.chevron_right_rounded,
                onPressed: () => _shiftDay(-1),
              ),
              BandButton(
                label: 'اليوم التالي',
                icon: Icons.chevron_left_rounded,
                onPressed: () => _shiftDay(1),
              ),
              if (store.isAdmin)
                BandButton(
                  label: _generating ? 'جارٍ التوليد…' : 'ولّد الآن',
                  icon: Icons.autorenew_rounded,
                  filled: true,
                  // الحارس في الدالّة لا في الزرّ: `BandButton.onPressed`
                  // غير قابل للعدم، فتعطيلُه بـnull لا يمرّ من نوعه.
                  onPressed: _generateNow,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: FutureBuilder<DailyReport?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _Notice(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.danger,
                    title: 'تعذّرت قراءة التقرير',
                    body: '${snapshot.error}',
                  );
                }
                final report = snapshot.data;
                if (report == null) return _missingNotice(store);
                return _ReportBody(report: report);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// لا صمت حين لا يوجد مستند.
  ///
  /// وثلاثةُ أسبابٍ محتملة يُقال كلٌّ منها في موضعه: يومٌ لم تأتِ سابعتُه
  /// بعد، أو يومٌ ماضٍ لم تكن الميزة تعمل فيه، أو إخفاقٌ في التوليد. ورسالةٌ
  /// واحدة غامضة تجعل المستخدم يظن المنصة معطّلة.
  Widget _missingNotice(AppStore store) {
    final now = DateTime.now();
    final isToday = _day.year == now.year && _day.month == now.month && _day.day == now.day;
    final beforeSeven = isToday && now.hour < 7;
    return _Notice(
      icon: Icons.schedule_rounded,
      color: AppColors.info,
      title: beforeSeven ? 'لم تأتِ السابعة صباحاً بعد' : 'لا يوجد تقرير لهذا اليوم',
      body: beforeSeven
          ? 'يصدر تقرير اليوم الساعة السابعة صباحاً بتوقيت الكويت. '
              'وتقرير الأمس متاح بزرّ «اليوم السابق».'
          : 'لم يُولَّد تقرير ${_formatDay(_day)} — إمّا أنه يومٌ سبق تشغيل التقارير، '
              'وإمّا أن التوليد أخفق.'
              '${store.isAdmin ? ' اضغط «ولّد الآن» لتوليد تقرير اليوم.' : ''}',
    );
  }
}

String _formatDay(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}

Color _colorOf(ReportSeverity s) => switch (s) {
      ReportSeverity.critical => AppColors.danger,
      ReportSeverity.needsAttention => AppColors.warning,
      ReportSeverity.normal => AppColors.success,
    };

class _ReportBody extends StatelessWidget {
  final DailyReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Summary(report: report),
        if (report.top.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          _SectionCard(
            title: 'أهم ${report.top.length} حالات',
            subtitle: 'مرتَّبة بالخطورة ثم بأيام التأخير',
            rows: report.top,
            emptyNote: '',
          ),
        ],
        for (final s in report.sections) ...[
          const SizedBox(height: AppSpace.lg),
          _SectionCard(title: s.title, rows: s.rows, emptyNote: s.emptyNote),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final DailyReport report;
  const _Summary({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'تقرير ${report.date}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                // نطاقُ التقرير يُقال صراحةً: التقرير ليس نفسه لكل قارئ،
                // ومن لا يعرف نطاقه يظنّ ما لا يراه غير موجود.
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text('النطاق: ${report.scopeLabel}'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(report.headline, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                _Count(
                  label: ReportSeverity.critical.label,
                  count: report.criticalCount,
                  color: AppColors.danger,
                ),
                _Count(
                  label: ReportSeverity.needsAttention.label,
                  count: report.attentionCount,
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Count({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ReportRow> rows;
  final String emptyNote;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.rows,
    required this.emptyNote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text('${rows.length}', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            if (rows.isEmpty)
              // الباب الفارغ **خبرٌ جيّد لا فراغ**، ولا يُحذف: حذفُه يجعل
              // القارئ لا يدري أفُحص الباب أم أُسقط.
              Text(emptyNote, style: const TextStyle(color: AppColors.textSecondary))
            else
              for (final row in rows) _Row(row: row),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ReportRow row;
  const _Row({required this.row});

  /// يفتح صفحة العنصر — بالمسارات نفسها التي يفتحها رابط البريد، لا بنسخةٍ
  /// منها. فما يُضغط على الشاشة يصل إلى ما يصل إليه الرابط حرفاً.
  void _open(BuildContext context) {
    final store = context.read<AppStore>();
    if (row.linkWorkId != null) {
      final work = store.works.where((w) => w.id == row.linkWorkId).firstOrNull;
      if (work == null) {
        _sayUnavailable(context, 'العمل');
        return;
      }
      openWorkDetail(context, work);
      return;
    }
    if (row.linkProjectId != null) {
      final project = store.projects.where((p) => p.id == row.linkProjectId).firstOrNull;
      if (project == null) {
        _sayUnavailable(context, 'المشروع');
        return;
      }
      openProjectDetail(context, project);
    }
  }

  /// لا صمت عند الضغط: التقرير يُحسب على الخادم بصلاحيات كاملة، وقد يذكر
  /// عنصراً حُذف بعد التوليد. وضغطةٌ لا يقع بعدها شيء تُقرأ عطلاً.
  void _sayUnavailable(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what لم يعد متاحاً — قد يكون حُذف بعد توليد التقرير.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(row.severity);
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm, horizontal: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                row.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: row.hasTarget ? AppColors.primary : AppColors.textPrimary,
                  decoration: row.hasTarget ? TextDecoration.underline : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.severity.label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (row.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(row.reason, style: const TextStyle(fontSize: 13)),
            ),
          if (row.fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: AppSpace.md,
                runSpacing: 2,
                children: [
                  for (final f in row.fields)
                    if (f.value.isNotEmpty && f.value != '—')
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${f.label}: ',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          TextSpan(text: f.value),
                        ]),
                        style: const TextStyle(fontSize: 12),
                      ),
                ],
              ),
            ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      // ما لا وجهة له لا يُلبَس ثوب ما يُضغط: `InkWell` بلا `onTap` يعطي
      // مؤشّر يدٍ ووميض ضغطٍ ثم لا يقع شيء.
      child: row.hasTarget
          ? InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(6),
              child: body,
            )
          : body,
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
