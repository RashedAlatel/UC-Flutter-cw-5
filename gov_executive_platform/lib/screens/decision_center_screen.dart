import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/approval_request.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/status_chip.dart';

class DecisionCenterScreen extends StatefulWidget {
  const DecisionCenterScreen({super.key});

  @override
  State<DecisionCenterScreen> createState() => _DecisionCenterScreenState();
}

class _DecisionCenterScreenState extends State<DecisionCenterScreen> {
  DecisionStatus? _statusFilter = DecisionStatus.pending;
  ApprovalType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var requests = store.approvalRequests.toList();
    if (_statusFilter != null) {
      requests = requests.where((r) => r.status == _statusFilter).toList();
    }
    if (_typeFilter != null) {
      requests = requests.where((r) => r.type == _typeFilter).toList();
    }
    requests.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return b.delayImpactDays.compareTo(a.delayImpactDays);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مركز القرارات التنفيذية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'كل طلبات تسجيل الأعضاء وإضافة المشاريع وتعديل المواعيد النهائية والقرارات التنفيذية تمر من هنا، مرتبة حسب الأولوية وتأثير التأخير.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'بانتظار القرار', selected: _statusFilter == DecisionStatus.pending, onTap: () => setState(() => _statusFilter = DecisionStatus.pending)),
              _Chip(label: 'تمت الموافقة', selected: _statusFilter == DecisionStatus.approved, onTap: () => setState(() => _statusFilter = DecisionStatus.approved)),
              _Chip(label: 'مرفوض', selected: _statusFilter == DecisionStatus.rejected, onTap: () => setState(() => _statusFilter = DecisionStatus.rejected)),
              _Chip(label: 'كل الحالات', selected: _statusFilter == null, onTap: () => setState(() => _statusFilter = null)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'الكل', selected: _typeFilter == null, onTap: () => setState(() => _typeFilter = null)),
              for (final t in ApprovalType.values)
                _Chip(label: t.label, selected: _typeFilter == t, onTap: () => setState(() => _typeFilter = t)),
            ],
          ),
          const SizedBox(height: 18),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد طلبات ضمن هذا التصنيف', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...requests.map((r) => _RequestCard(request: r)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
      backgroundColor: AppColors.background,
    );
  }
}

class _RequestCard extends StatefulWidget {
  final ApprovalRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final r = widget.request;
    final dept = r.departmentId != null ? store.departmentById(r.departmentId!) : null;
    final project = r.projectId != null ? store.projectById(r.projectId!) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(r.type.label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                PriorityChip(priority: r.priority),
                const SizedBox(width: 10),
                Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                _StatusBadge(status: r.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(r.description, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.6)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                if (dept != null) _InfoChip(icon: Icons.account_balance_rounded, text: dept.name),
                if (project != null) _InfoChip(icon: Icons.folder_copy_outlined, text: project.name),
                _InfoChip(icon: Icons.person_outline_rounded, text: r.requestedByName),
                _InfoChip(icon: Icons.event_outlined, text: Formatters.shortDate(r.requestedDate)),
                if (r.delayImpactDays > 0)
                  _InfoChip(icon: Icons.schedule_rounded, text: 'أثر التأخير: ${r.delayImpactDays} يوم', color: AppColors.danger),
              ],
            ),
            if (r.resolutionNote != null && r.resolutionNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(r.resolutionNote!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
            if (r.status == DecisionStatus.pending && store.canApprove(r)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _resolve(context, approve: false),
                      icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.danger),
                      label: const Text('رفض', style: TextStyle(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _resolve(context, approve: true),
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 17),
                      label: const Text('موافقة'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resolve(BuildContext context, {required bool approve}) {
    showDialog(
      context: context,
      builder: (ctx) {
        final noteCtrl = TextEditingController();
        return AlertDialog(
          title: Text(approve ? 'الموافقة على الطلب' : 'رفض الطلب'),
          content: SizedBox(
            width: 380,
            child: TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() {
                  _busy = true;
                  _error = null;
                });
                final store = context.read<AppStore>();
                final error = approve
                    ? await store.approveRequest(widget.request, note: noteCtrl.text.trim())
                    : await store.rejectRequest(widget.request, note: noteCtrl.text.trim());
                if (!mounted) return;
                setState(() {
                  _busy = false;
                  _error = error;
                });
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DecisionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case DecisionStatus.pending:
        color = AppColors.warning;
        break;
      case DecisionStatus.approved:
        color = AppColors.success;
        break;
      case DecisionStatus.rejected:
        color = AppColors.danger;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
