import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

/// اختيار الأشخاص المنفذين من قائمة مستخدمي المنصة المسجَّلين (بدل كتابة
/// اسم حر)، بشريحة قابلة للحذف لكل اسم مختار وقائمة منسدلة للإضافة.
class ExecutorsField extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  const ExecutorsField({super.key, required this.initial, required this.onChanged});

  @override
  State<ExecutorsField> createState() => _ExecutorsFieldState();
}

class _ExecutorsFieldState extends State<ExecutorsField> {
  late List<String> _names;

  @override
  void initState() {
    super.initState();
    _names = List.of(widget.initial);
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
    final userNames = store.users.map((u) => u.name).toSet().toList()..sort();
    // أسماء مضافة سابقاً (بيانات قديمة مثلاً) قد لا تطابق أي مستخدم مسجَّل
    // حالياً — تبقى معروضة كشريحة عادية دون أن تُفقد، لكنها لا تظهر في
    // القائمة المنسدلة لتفادي التكرار.
    final available = userNames.where((n) => !_names.contains(n)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            initialValue: null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'إضافة منفذ من المستخدمين المسجّلين'),
            items: available.isEmpty
                ? const [DropdownMenuItem(value: null, child: Text('لا يوجد مستخدمون آخرون لإضافتهم'))]
                : available.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: available.isEmpty ? null : (v) => v == null ? null : _add(v),
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
