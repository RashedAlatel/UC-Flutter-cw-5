import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/notify_templates.dart';
import '../theme/app_theme.dart';

/// نموذج إرسال إشعار (بريد/واتساب) مشترك بين صفحة المستخدمين وصفحة المشروع
/// وصفحة الأعمال.
///
/// عند تمرير [context] تظهر قوالب رسائل جاهزة تُعبَّأ تلقائياً باسم المشروع أو
/// العمل وموعده ونسبة إنجازه وأيام تأخيره، ويبقى النص قابلاً للتحرير قبل
/// الإرسال. بدونه يعمل النموذج كرسالة حرة كما كان.
class NotifyDialog extends StatefulWidget {
  final List<AppUser> initialUsers;
  final NotifyContext? context;

  const NotifyDialog({super.key, required this.initialUsers, this.context});

  @override
  State<NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<NotifyDialog> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  NotifyChannel _channel = NotifyChannel.email;
  late final Set<String> _selectedUids = widget.initialUsers.map((u) => u.id).toSet();
  late NotifyTemplate _template =
      widget.context == null ? NotifyTemplate.free : NotifyTemplate.deadlineReminder;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _applyTemplate(_template);
  }

  /// يملأ العنوان والنص من القالب. لا يُطبَّق إن كان المستخدم قد كتب نصاً
  /// بنفسه ولم يطلب تغيير القالب صراحةً — التبديل اليدوي وحده يستبدل النص.
  void _applyTemplate(NotifyTemplate t) {
    final c = widget.context;
    if (t == NotifyTemplate.free || c == null) return;
    _subjectCtrl.text = t.subjectFor(c);
    _messageCtrl.text = t.bodyFor(c);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedUids.isEmpty) {
      setState(() => _error = 'الرجاء اختيار مستلم واحد على الأقل');
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء كتابة نص الرسالة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recipients = store.users.where((u) => _selectedUids.contains(u.id)).toList();
    final error = await store.sendUserNotification(
      users: recipients,
      channel: _channel,
      subject: _subjectCtrl.text.trim().isEmpty ? 'إشعار من المنصة التنفيذية' : _subjectCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('تم إرسال الإشعار إلى ${recipients.length} مستخدم(ين) بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final single = widget.initialUsers.length == 1;
    final ctx = widget.context;

    return AlertDialog(
      title: Text(single ? 'مراسلة ${widget.initialUsers.first.name}' : 'إرسال إشعار'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ctx != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('بخصوص ${ctx.kind}: ${ctx.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NotifyTemplate>(
                  initialValue: _template,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نوع الرسالة'),
                  items: NotifyTemplate.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _template = v ?? _template;
                    if (_template == NotifyTemplate.free) {
                      _subjectCtrl.clear();
                      _messageCtrl.clear();
                    } else {
                      _applyTemplate(_template);
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (!single) ...[
                const Text('المستلمون', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 190),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: store.users
                          .map((u) => CheckboxListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                value: _selectedUids.contains(u.id),
                                title: Text(u.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                subtitle: Text(u.email, style: const TextStyle(fontSize: 10.5)),
                                onChanged: (v) => setState(() {
                                  if (v ?? false) {
                                    _selectedUids.add(u.id);
                                  } else {
                                    _selectedUids.remove(u.id);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<NotifyChannel>(
                initialValue: _channel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'قناة الإرسال'),
                items: NotifyChannel.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (v) => setState(() => _channel = v ?? _channel),
              ),
              const SizedBox(height: 12),
              if (_channel != NotifyChannel.whatsapp)
                TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'عنوان البريد (اختياري)')),
              const SizedBox(height: 12),
              TextField(controller: _messageCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'نص الرسالة')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إرسال'),
        ),
      ],
    );
  }
}
