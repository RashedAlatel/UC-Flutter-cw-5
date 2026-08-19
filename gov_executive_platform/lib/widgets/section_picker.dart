import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department_section.dart';

/// منتقي قسم داخل إدارة: قائمتان متتاليتان (القسم ثم القسم الفرعي).
///
/// القيمة المُعادة هي معرّف **أعمق** قسم مختار — فإن اختار المستخدم قسماً
/// فرعياً كانت هي معرّفه، وإن اكتفى بالقسم كانت معرّف القسم، وإن لم يختر
/// شيئاً كانت null بمعنى "تحت الإدارة مباشرةً".
///
/// تظهر القائمة الثانية فقط حين يكون للقسم المختار أقسام فرعية، فلا تُزحم
/// الشاشة على الإدارات التي تكتفي بمستوى واحد.
class SectionPicker extends StatefulWidget {
  final String departmentId;
  final String? initialSectionId;
  final ValueChanged<String?> onChanged;

  /// نص التسمية الأول — يختلف بين "القسم" في نموذج المشروع و"نقل إلى" في
  /// نافذة النقل.
  final String label;

  const SectionPicker({
    super.key,
    required this.departmentId,
    required this.onChanged,
    this.initialSectionId,
    this.label = 'القسم',
  });

  @override
  State<SectionPicker> createState() => _SectionPickerState();
}

class _SectionPickerState extends State<SectionPicker> {
  String? _topId;
  String? _childId;

  @override
  void initState() {
    super.initState();
    _syncFrom(widget.initialSectionId);
  }

  @override
  void didUpdateWidget(SectionPicker old) {
    super.didUpdateWidget(old);
    // تغيّر الإدارة يُبطل أي قسم مختار: أقسام إدارة لا تصلح لإدارة أخرى.
    if (old.departmentId != widget.departmentId) {
      setState(() {
        _topId = null;
        _childId = null;
      });
      widget.onChanged(null);
    }
  }

  /// يفكّ معرّف قسم واحد إلى (قسم، قسم فرعي) لملء القائمتين.
  void _syncFrom(String? sectionId) {
    final store = context.read<AppStore>();
    final section = store.sectionById(sectionId);
    if (section == null) {
      _topId = null;
      _childId = null;
      return;
    }
    if (section.parentId == null) {
      _topId = section.id;
      _childId = null;
    } else {
      _topId = section.parentId;
      _childId = section.id;
    }
  }

  void _emit() => widget.onChanged(_childId ?? _topId);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tops = store.sectionsOf(widget.departmentId);
    if (tops.isEmpty) return const SizedBox.shrink();

    final children = _topId == null ? <DepartmentSection>[] : store.sectionsOf(widget.departmentId, parentId: _topId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: tops.any((s) => s.id == _topId) ? _topId : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: '${widget.label} (اختياري)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('تحت الإدارة مباشرةً')),
            ...tops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
          ],
          onChanged: (v) {
            setState(() {
              _topId = v;
              _childId = null;
            });
            _emit();
          },
        ),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: children.any((s) => s.id == _childId) ? _childId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'القسم الفرعي (اختياري)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('بدون قسم فرعي')),
              ...children.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
            ],
            onChanged: (v) {
              setState(() => _childId = v);
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
