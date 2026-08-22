import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/assignment_policy.dart';
import '../theme/app_theme.dart';
import 'person_picker.dart';

/// اختيار الأشخاص المنفذين من قائمة مستخدمي المنصة المسجَّلين (بدل كتابة
/// اسم حر)، بشريحة قابلة للحذف لكل اسم مختار وقائمة منسدلة للإضافة.
class ExecutorsField extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  /// إدارة المشروع، فيُقصر البحث على من ينتمي إليها — و null تعني بلا نطاق.
  final String? departmentId;

  const ExecutorsField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.departmentId,
  });

  @override
  State<ExecutorsField> createState() => _ExecutorsFieldState();
}

class _ExecutorsFieldState extends State<ExecutorsField> {
  late List<String> _names;
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _names = List.of(widget.initial);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _add(String name) {
    if (_names.contains(name)) return;
    setState(() => _names.add(name));
    widget.onChanged(_names);
  }

  void _remove(String name) {
    setState(() => _names.remove(name));
    widget.onChanged(_names);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // أسماء مضافة سابقاً (بيانات قديمة مثلاً) قد لا تطابق أي مستخدم مسجَّل
    // حالياً — تبقى معروضة كشريحة عادية دون أن تُفقد، لكنها لا تظهر في
    // نتائج البحث لتفادي التكرار.
    //
    // ــ ولماذا بحثٌ لا قائمة منسدلة؟ ــ
    //
    // القائمة المنسدلة تعرض مئتي اسم بالترتيب الأبجدي، فمن يبحث عن زميله
    // يُمرّر عشرات الشاشات — وهو ما اشتُكي منه عند إضافة مشروع. والبحث
    // يوحّد صور الهمزة والتاء المربوطة، فمن يكتب «احمد» يجد «أحمد».
    //
    // ــ ولماذا تُصفّى القائمة بالرتبة وهي تكتب **أسماءً** لا معرّفات؟ ــ
    //
    // لأن الاسم المكتوب يصير سطراً في المشروع يُقرأ على أنه إسناد. فمن لا
    // يحقّ له إسناد المسؤول التنفيذي بحسابه لا يُلتفّ على ذلك بكتابة اسمه.
    // والأسماء الحرّة القديمة تبقى كما هي — القاعدة تحكم ما يُضاف من الآن.
    final query = _query.text;
    final available = eligibleAssignees(
      allUsers: store.users,
      actor: store.currentUser,
      departmentId: widget.departmentId,
    )
        .where((u) => !_names.contains(u.name))
        .where((u) => personMatches(u, query,
            departmentName: store.departmentById(u.departmentId ?? '')?.name))
        .toList();
    const maxShown = 12;
    final shown = available.take(maxShown).toList();
    final hidden = available.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'إضافة منفذ من المستخدمين المسجّلين',
            hintText: 'ابحث بالاسم أو البريد أو الإدارة',
            hintStyle: const TextStyle(fontSize: 12),
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    tooltip: 'مسح البحث',
                    onPressed: () => setState(_query.clear),
                  ),
          ),
        ),
        if (available.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              query.trim().isEmpty
                  ? 'لا يوجد مستخدمون آخرون لإضافتهم'
                  : 'لا أحد يطابق «${query.trim()}»',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 168),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final u in shown)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: Text(u.name,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        store.departmentById(u.departmentId ?? '')?.name ?? 'بلا إدارة',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      onTap: () {
                        _add(u.name);
                        setState(_query.clear);
                      },
                    ),
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Text(
                        'و$hidden غيرهم يطابقون — تابع الكتابة لتضييق النتائج.',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_names.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _names
                .map((n) => Chip(
                      label: Text(n, style: const TextStyle(fontSize: 12.5)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => _remove(n),
                      backgroundColor: AppColors.background,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
