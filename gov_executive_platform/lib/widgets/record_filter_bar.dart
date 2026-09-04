// شريطُ التصفية — **واجهةٌ واحدة لثلاث شاشات**.
//
// ــــ لماذا ودجةٌ مشتركة ــــ
//
// الفلاترُ نفسُها تظهر في المشاريع والأعمال والبحث. ولو كُتبت في كلٍّ نسخةٌ
// لَافترقت: تُضاف «القسم» في واحدة وتُنسى في أختها، ويُصلَح خللٌ في عنوان
// حقلٍ في موضعٍ ويبقى في موضعين. وهو ما وقع فعلاً في المنصة قبل هذا الشريط:
// «تصفية حسب المستخدم» كانت تخلط المنفّذ بمدير المشروع في صفحة المشاريع
// وحدها.
//
// والقرارُ — أيُّ سجلٍّ يمرّ — ليس هنا بل في `record_filter.dart`. هذه
// تعرضُه وتُبلّغ ما اختير، لا أكثر.
import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/record_filter.dart';
import '../theme/app_theme.dart';
import 'filter_bar.dart';

/// أيُّ الحقول تُعرض — فصفحةُ الأعمال لا تعرض «التصنيف» ولا «مدير المشروع».
enum FilterField { query, department, section, executor, manager, projectStatus, workStatus, category, kind }

class RecordFilterBar extends StatefulWidget {
  final AppStore store;
  final RecordFilter filter;
  final ValueChanged<RecordFilter> onChanged;
  final Set<FilterField> fields;

  /// «٤١ من ١٨٤» — يُقال دائماً، فلا يُقرأ الفراغُ نقصاً في البيانات.
  final int shown;
  final int total;

  /// خياراتٌ إضافية في قائمة المنفّذ — قيمةٌ ← عنوان.
  ///
  /// وشاشةُ الأعمال وحدها تملؤها بـ«بانتظار التكليف»: وصفُ عملٍ لا مشروع،
  /// ولا معنى لعرضه في شاشة المشاريع.
  final Map<String, String> extraExecutorOptions;

  const RecordFilterBar({
    super.key,
    required this.store,
    required this.filter,
    required this.onChanged,
    required this.fields,
    required this.shown,
    required this.total,
    this.extraExecutorOptions = const {},
  });

  @override
  State<RecordFilterBar> createState() => _RecordFilterBarState();
}

class _RecordFilterBarState extends State<RecordFilterBar> {
  late final TextEditingController _searchCtrl =
      TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _has(FilterField f) => widget.fields.contains(f);

  /// قيمةٌ مختارة **ليست بين الخيارات** تُقرأ «لا شيء».
  ///
  /// ــ وهذا عطلُ انهيارٍ لا تجميل ــ
  ///
  /// `DropdownButtonFormField` **يرمي** إن كانت قيمتُه ليست في عناصره. وذلك
  /// يقع في العمل: قسمٌ مختارٌ ثم مُسحت إدارتُه، أو مستخدمٌ مختارٌ ثم أُوقف
  /// حسابُه، أو تصنيفٌ حُذف — والفلترُ يبقى في المتجر طولَ الجلسة، فيبقى
  /// معه الانهيار. فتُقرأ القيمةُ الغائبة عدماً وتُعرض القائمةُ سليمة.
  String? _amongOptions(String? value, Iterable<String> ids) =>
      value != null && ids.contains(value) ? value : null;
  void _emit(RecordFilter next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final f = widget.filter;

    final departments = store.visibleDepartments;
    final sections = f.departmentId == null
        ? const []
        : store.sections.where((s) => s.departmentId == f.departmentId).toList();
    final users = store.users.where((u) => u.status == UserStatus.approved).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterBar(
          fields: [
            if (_has(FilterField.query))
              (
                preferredWidth: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'بحث بالاسم أو الوصف',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: f.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () {
                              _searchCtrl.clear();
                              _emit(f.copyWith(query: ''));
                            },
                          ),
                  ),
                  onChanged: (v) => _emit(f.copyWith(query: v)),
                ),
              ),
            if (_has(FilterField.department))
              (
                preferredWidth: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: _amongOptions(f.departmentId, departments.map((d) => d.id)),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الإدارة', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الإدارات')),
                    ...departments.map(
                        (d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                  ],
                  // ــ وتبديلُ الإدارة يُسقط القسم ــ
                  //
                  // القسمُ تابعٌ لإدارته، فبقاؤه بعد تبديلها يُنتج تقاطعاً
                  // فارغاً أبداً ولا يفهم المستخدم لماذا.
                  onChanged: (v) => _emit(v == null
                      ? f.copyWith(clear: {'departmentId', 'sectionId'})
                      : f.copyWith(departmentId: v, clear: {'sectionId'})),
                ),
              ),
            if (_has(FilterField.section))
              (
                preferredWidth: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: _amongOptions(f.sectionId, sections.map((s) => s.id)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'القسم',
                    isDense: true,
                    // قسمٌ بلا إدارةٍ لا معنى له: الأقسامُ تحت الإدارات.
                    helperText: f.departmentId == null ? 'اختر إدارةً أولاً' : null,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الأقسام')),
                    ...sections.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(store.sectionPathLabel(s.id),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: f.departmentId == null
                      ? null
                      : (v) => _emit(v == null
                          ? f.copyWith(clear: {'sectionId'})
                          : f.copyWith(sectionId: v)),
                ),
              ),
            if (_has(FilterField.executor))
              (
                preferredWidth: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: _amongOptions(f.executorUid,
                      [...widget.extraExecutorOptions.keys, ...users.map((u) => u.id)]),
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'المنفّذ', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل المنفّذين')),
                    ...widget.extraExecutorOptions.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ...users.map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.name, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    if (v == null) return _emit(f.copyWith(clear: {'executor'}));
                    // الخيارُ الخاصّ ليس حساباً، فلا اسمَ يُقرن به.
                    if (widget.extraExecutorOptions.containsKey(v)) {
                      return _emit(f.copyWith(executorUid: v, clear: {}));
                    }
                    final u = users.firstWhere((e) => e.id == v);
                    _emit(f.copyWith(executorUid: u.id, executorName: u.name));
                  },
                ),
              ),
            if (_has(FilterField.manager))
              (
                preferredWidth: 210,
                child: _userDropdown(
                  label: 'مدير المشروع',
                  empty: 'كل المديرين',
                  value: _amongOptions(f.managerUid, users.map((u) => u.id)),
                  users: users,
                  onChanged: (u) => _emit(u == null
                      ? f.copyWith(clear: {'managerUid'})
                      : f.copyWith(managerUid: u.id)),
                ),
              ),
            if (_has(FilterField.projectStatus))
              (
                preferredWidth: 190,
                child: DropdownButtonFormField<ProjectStatus?>(
                  initialValue: f.projectStatus,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'حالة المشروع', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                    ...ProjectStatus.values.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label))),
                  ],
                  onChanged: (v) => _emit(v == null
                      ? f.copyWith(clear: {'projectStatus'})
                      : f.copyWith(projectStatus: v)),
                ),
              ),
            if (_has(FilterField.workStatus))
              (
                preferredWidth: 190,
                child: DropdownButtonFormField<TaskStatus?>(
                  initialValue: f.workStatus,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'حالة التنفيذ', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل الحالات')),
                    ...TaskStatus.values.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label))),
                  ],
                  onChanged: (v) => _emit(v == null
                      ? f.copyWith(clear: {'workStatus'})
                      : f.copyWith(workStatus: v)),
                ),
              ),
            if (_has(FilterField.category) && store.categories.isNotEmpty)
              (
                preferredWidth: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: _amongOptions(f.categoryId, store.categories.map((c) => c.id)),
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'التصنيف', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('كل التصنيفات')),
                    ...store.categories.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => _emit(v == null
                      ? f.copyWith(clear: {'categoryId'})
                      : f.copyWith(categoryId: v)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _quickRow(f),
        const SizedBox(height: 10),
        _footer(f),
      ],
    );
  }

  Widget _userDropdown({
    required String label,
    required String empty,
    required String? value,
    required List<AppUser> users,
    required ValueChanged<AppUser?> onChanged,
  }) =>
      DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem(value: null, child: Text(empty)),
          ...users.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.name, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: (v) =>
            onChanged(v == null ? null : users.firstWhere((u) => u.id == v)),
      );

  /// الحالاتُ السريعة — ومعنى كلٍّ مكتوبٌ في تلميحها.
  ///
  /// ولا يُترك المعنى يُستنتج: «يحتاج متابعة» ليست درجةَ الخطورة في التقرير
  /// اليومي، فتُقال بلفظها كي لا يُقرأ الرقمُ على غير وجهه.
  Widget _quickRow(RecordFilter f) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_has(FilterField.kind))
            for (final k in RecordKind.values)
              FilterChip(
                label: Text(k.label),
                selected: f.kinds.contains(k),
                onSelected: (on) {
                  final next = {...f.kinds};
                  on ? next.add(k) : next.remove(k);
                  _emit(f.copyWith(kinds: next));
                },
              ),
          for (final q in QuickState.values)
            Tooltip(
              message: q.meaning,
              child: FilterChip(
                label: Text(q.label),
                selected: f.quick == q,
                onSelected: (on) => _emit(
                    on ? f.copyWith(quick: q) : f.copyWith(clear: {'quick'})),
              ),
            ),
        ],
      );

  /// «٤١ من ١٨٤» وزرُّ إعادة الضبط.
  ///
  /// والعددُ يُقال دائماً لا عند التصفية وحدها: قائمةٌ قصيرةٌ بلا رقمٍ
  /// يُفسّرها تُقرأ نقصاً في البيانات — وقد قرأها مسؤولُ النظام كذلك مرّةً.
  Widget _footer(RecordFilter f) => Row(
        children: [
          Text(
            widget.shown == widget.total
                ? '${widget.total} سجلاً'
                : '${widget.shown} من ${widget.total}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (f.isNotEmpty)
            TextButton.icon(
              onPressed: () => _emit(const RecordFilter()),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
              label: Text('إعادة ضبط الفلاتر (${f.activeCount})'),
            ),
        ],
      );
}
