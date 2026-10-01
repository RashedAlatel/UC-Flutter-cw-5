// سجل التدقيق — يُصفّى ويُقرأ، لا يُتصفَّح من أعلاه.
//
// ــــ لماذا التصفية جزءٌ من الميزة لا زينتُها ــــ
//
// طلبتَ **تسجيل كل تغيير**. والاثنان معاً لا أحدهما: سجلٌّ يحصي كل شيء بلا
// تصفية سجلٌّ لا يُقرأ. فمن أراد «كل عمليات الحذف في الشهر الماضي» كان
// أمامه ثلاثمئة سطرٍ صمّاء يقرؤها من أعلاها.
//
// وسطرُ التعديل يحمل «قبل ← بعد» بالحقول المتغيّرة وحدها — فيُعرف ما وقع
// بلا فتح المشروع ومقارنته بالذاكرة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/audit_log_entry.dart';
import '../models/change_type.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../utils/formatters.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  ChangeType? _type;
  String? _actorUid;
  String _query = '';

  bool _matches(AuditLogEntry e) {
    if (_type != null && e.type != _type) return false;
    if (_actorUid != null && e.actorUid != _actorUid) return false;
    if (_query.isEmpty) return true;
    final q = _query.trim();
    return e.action.contains(q) ||
        e.details.contains(q) ||
        e.userName.contains(q) ||
        (e.targetName ?? '').contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.auditLog;
    final entries = all.where(_matches).toList();

    // من فعل شيئاً في المدى المحمَّل — لا كلُّ موظفي الوزارة، فقائمةٌ بمئتَي
    // اسمٍ أكثرُهم بلا سطرٍ واحد ليست تصفية.
    final actors = <String, String>{};
    for (final e in all) {
      if (e.actorUid != null) actors[e.actorUid!] = e.userName;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'سجل التدقيق',
            subtitle: entries.length == all.length
                ? 'آخر ${all.length} عملية على المنصة'
                : '${entries.length} من ${all.length} عملية',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<ChangeType?>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'نوع التغيير',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                              for (final t in ChangeType.values)
                                DropdownMenuItem(value: t, child: Text(t.label)),
                            ],
                            onChanged: (v) => setState(() => _type = v),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _actorUid,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'من نفّذ',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('الجميع')),
                              for (final entry in actors.entries)
                                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                            ],
                            onChanged: (v) => setState(() => _actorUid = v),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'بحث في النص',
                              isDense: true,
                              prefixIcon: Icon(Icons.search_rounded, size: 18),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        if (_type != null || _actorUid != null || _query.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _type = null;
                              _actorUid = null;
                              _query = '';
                            }),
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                            label: const Text('إلغاء التصفية'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: entries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                all.isEmpty
                                    ? 'لا توجد سجلات بعد'
                                    : 'لا سجلّ يطابق التصفية — جرّب توسيعها.',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) => AuditEntryTile(entry: entries[i]),
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

/// سطرٌ واحد من السجل — **عامٌّ ليُعاد استعماله**.
///
/// يُعرض في شاشة السجل العامة وفي سجل تعديلات مشروعٍ بعينه. ونسختان منه
/// تفترقان بأول تعديل، فيقرأ مسؤول النظام السطرَ نفسَه بشكلين — وأشدُّ ما
/// يفترق فيه جدولُ «قبل ← بعد»، وهو موضعُ الحكم لا الزينة.
class AuditEntryTile extends StatelessWidget {
  final AuditLogEntry entry;
  const AuditEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(entry.action,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          // النوع شارةٌ تُقرأ بلمحة — وهو ما تُصفّى به القائمة.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(entry.type.label, style: const TextStyle(fontSize: 10.5)),
          ),
        ],
      ),
      subtitle: Text(entry.details, style: const TextStyle(fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(entry.userName,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          Text(Formatters.timeAgo(entry.timestamp),
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ],
      ),
    );

    if (!entry.hasDiff) return tile;

    // ما تغيّر يُطوى تحت السطر: القائمة تُقرأ بلمحة، والتفصيل لمن طلبه.
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(70, 0, 16, 12),
      title: tile.title!,
      subtitle: tile.subtitle,
      leading: tile.leading,
      trailing: tile.trailing,
      children: [_DiffTable(before: entry.before ?? {}, after: entry.after ?? {})],
    );
  }
}

class _DiffTable extends StatelessWidget {
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  const _DiffTable({required this.before, required this.after});

  static String _show(Object? v) {
    if (v == null) return '—';
    if (v is List) return v.isEmpty ? '—' : v.join('، ');
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final keys = {...before.keys, ...after.keys}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('$k:',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                Text(_show(before[k]),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.danger,
                      decoration: TextDecoration.lineThrough,
                    )),
                const Icon(Icons.arrow_back_rounded, size: 13, color: AppColors.textSecondary),
                Text(_show(after[k]),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.success)),
              ],
            ),
          ),
      ],
    );
  }
}
