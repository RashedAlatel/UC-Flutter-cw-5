import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// حقل إدخال متعدد لأسماء الأشخاص المنفذين: اكتب اسماً واضغط إضافة أو Enter
/// ليتحوّل إلى شريحة (Chip) قابلة للحذف، ويمكن تكرار ذلك لأي عدد من الأشخاص.
class ExecutorsField extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  const ExecutorsField({super.key, required this.initial, required this.onChanged});

  @override
  State<ExecutorsField> createState() => _ExecutorsFieldState();
}

class _ExecutorsFieldState extends State<ExecutorsField> {
  late List<String> _names;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _names = List.of(widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final value = _ctrl.text.trim();
    if (value.isEmpty || _names.contains(value)) return;
    setState(() => _names.add(value));
    _ctrl.clear();
    widget.onChanged(_names);
  }

  void _remove(String name) {
    setState(() => _names.remove(name));
    widget.onChanged(_names);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(labelText: 'اسم المنفذ'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _add, icon: const Icon(Icons.add_rounded)),
          ],
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
