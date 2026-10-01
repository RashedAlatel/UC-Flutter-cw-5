/// فتحُ بلاغٍ أو طلبِ خدمة — **ولا يحتاج صلاحية**.
///
/// كلُّ موظّفٍ معتمدٍ يفتح بلاغَه بنفسه. وهذا قرارٌ صريح: مكتبُ الخدمة
/// الذي يسجّل نيابةً عن المتّصلين يفقد نصفَ بلاغاته — ما لم يُتّصل به —
/// فتصير أرقامُ حجم العمل أقلَّ من الحقيقة، ويُقاس الفريقُ بها.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';

Future<void> showTicketFormDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _TicketFormDialog());

class _TicketFormDialog extends StatefulWidget {
  const _TicketFormDialog();

  @override
  State<_TicketFormDialog> createState() => _TicketFormDialogState();
}

class _TicketFormDialogState extends State<_TicketFormDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  TicketKind _kind = TicketKind.incident;
  PriorityLevel _priority = PriorityLevel.medium;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final err = await store.openTicket(
      kind: _kind,
      title: _title.text,
      description: _description.text,
      priority: _priority,
      category: _category.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بلاغٌ جديد'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<TicketKind>(
                segments: [
                  for (final k in TicketKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              SizedBox(height: AppSpace.md),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'ما المشكلة؟',
                  hintText: 'الطابعة في الطابق الثاني لا تطبع',
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'تفاصيلُ تساعد على الحلّ',
                  hintText: 'متى بدأت؟ وهل جرّبتَ شيئاً؟',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              TextField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'التصنيف (اختياريّ)',
                  hintText: 'شبكة · طابعات · بريد · نظام',
                ),
              ),
              SizedBox(height: AppSpace.sm),
              // ــ والأولويّةُ يختارها الفاتح، ويصحّحها مكتبُ الخدمة ــ
              //
              // فصاحبُ المشكلة أعرفُ بأثرها عليه، ومكتبُ الخدمة أعرفُ
              // بموقعها من بقيّة الطابور. ولا يُترك الحقلُ للمكتب وحدَه:
              // بلاغٌ يوقف قاعةَ محكمةٍ يجب أن يُقال ذلك فيه من أوّله.
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'الأولويّة'),
                items: [
                  for (final p in PriorityLevel.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              if (_error != null) ...[
                SizedBox(height: AppSpace.sm),
                Text(_error!, style: AppText.label.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'يُرسَل…' : 'أرسِل البلاغ'),
        ),
      ],
    );
  }
}
