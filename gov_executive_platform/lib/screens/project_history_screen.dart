// سجلُّ تعديلات مشروعٍ بعينه — منذ إنشائه.
//
// ــــ ولماذا استعلامٌ مستقلّ لا تصفيةُ السجل المحمَّل ــــ
//
// `AppStore.auditLog` نافذةٌ متحرّكة بآخر ألف سطرٍ من المنصة كلِّها.
// ومشروعٌ عمرُه سنة تكون سطورُه قد خرجت منها من زمان، فتصفيتُها تُخرج
// «لا تعديلات» على مشروعٍ عُدّل عشراً — وهو أسوأ من ألّا يُعرض شيء: يقرؤه
// المسؤول خبراً لا نقصَ عرض.
//
// و«منذ الإنشاء» لا تصحّ على نافذة.
//
// ــــ ولمسؤول النظام وحده ــــ
//
// بقرارك. وقاعدةُ `auditLog` تقرأ لمسؤول النظام وحده أصلاً
// (`allow read: if isAdmin()`)، فهذه الشاشة مرآةُ القاعدة لا حارسُها: لو
// فُتحت لغيره لَرأى شاشةً فارغةً بخطأ صلاحية، لا سجلاً.
//
// وأسطرُه **لا تُعدَّل ولا تُحذف ولا لمسؤول النظام** — `allow update, delete:
// if false`. وهو شرطُك: «لا يمكن التعديل على السجل».
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/audit_log_entry.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import 'audit_log_screen.dart';

/// يفتح سجلَّ تعديلات المشروع في صفحةٍ مستقلّة.
void showProjectHistory(BuildContext context, Project project) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('سجل تعديلات المشروع')),
      body: ProjectHistoryScreen(project: project),
    ),
  ));
}

class ProjectHistoryScreen extends StatefulWidget {
  final Project project;
  const ProjectHistoryScreen({super.key, required this.project});

  @override
  State<ProjectHistoryScreen> createState() => _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends State<ProjectHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<AuditLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await context.read<AppStore>().projectHistory(widget.project.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _entries = result.entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: widget.project.name,
            subtitle: _loading
                ? 'يُقرأ سجل التعديلات…'
                : 'كل ما وقع على هذا المشروع منذ إنشائه — ${_entries.length} عملية',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error!, onRetry: _load)
                else if (_entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'لا تعديلات مسجّلة على هذا المشروع بعد.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        // السطرُ نفسُه المعروض في السجل العام — لا نسخةٌ ثانية.
                        itemBuilder: (context, i) => AuditEntryTile(entry: _entries[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// خطأُ القراءة يُقال ويُعاد المحاولة — ولا يُترك فراغاً يُقرأ «لا تعديلات».
///
/// وأشهرُ سببٍ له في أول يومٍ بعد النشر: **الفهرس يُبنى**. وهو ينتهي وحده في
/// دقائق، فيُقال ذلك بدل رسالةٍ خام من Firestore لا يفهمها أحد.
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final building = message.contains('index') ||
        message.contains('الفهرس') ||
        message.contains('failed-precondition');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              building ? 'الفهرس قيد البناء' : 'تعذّرت قراءة السجل',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              building
                  ? 'سجل تعديلات المشروع يحتاج فهرساً في قاعدة البيانات، وهو يُبنى '
                      'تلقائياً بعد النشر ويستغرق دقائق. أعد المحاولة بعد قليل — '
                      'ولا شيء ناقصٌ في بياناتك.'
                  : message,
              style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
