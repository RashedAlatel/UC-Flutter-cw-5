import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/decision_request.dart';
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
  DecisionStatus? _filter = DecisionStatus.pending;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var decisions = store.decisions.where((d) => store.canViewDepartment(d.departmentId)).toList();
    if (_filter != null) {
      decisions = decisions.where((d) => d.status == _filter).toList();
    }
    decisions.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return b.delayImpactDays.compareTo(a.delayImpactDays);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مركز القرارات التنفيذية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('جميع الطلبات المعلقة مرتبة حسب الأولوية وتأثير التأخير على المشروع', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(label: 'بانتظار القرار', selected: _filter == DecisionStatus.pending, onTap: () => setState(() => _filter = DecisionStatus.pending)),
              _FilterChip(label: 'تمت الموافقة', selected: _filter == DecisionStatus.approved, onTap: () => setState(() => _filter = DecisionStatus.approved)),
              _FilterChip(label: 'مرفوض', selected: _filter == DecisionStatus.rejected, onTap: () => setState(() => _filter = DecisionStatus.rejected)),
              _FilterChip(label: 'الكل', selected: _filter == null, onTap: () => setState(() => _filter = null)),
            ],
          ),
          const SizedBox(height: 18),
          if (decisions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('لا توجد طلبات ضمن هذا التصنيف', style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...decisions.map((d) => _DecisionCard(decision: d)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

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

class _DecisionCard extends StatelessWidget {
  final DecisionRequest decision;
  const _DecisionCard({required this.decision});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dept = store.departmentById(decision.departmentId);
    final project = store.projectById(decision.projectId);

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
                PriorityChip(priority: decision.priority),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(decision.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
                _DecisionStatusBadge(status: decision.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(decision.description, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.6)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.account_balance_rounded, text: dept?.name ?? ''),
                _InfoChip(icon: Icons.folder_copy_outlined, text: project?.name ?? ''),
                _InfoChip(icon: Icons.person_outline_rounded, text: decision.requestedBy),
                _InfoChip(icon: Icons.event_outlined, text: Formatters.shortDate(decision.requestedDate)),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  text: 'أثر التأخير: ${decision.delayImpactDays} يوم',
                  color: AppColors.danger,
                ),
              ],
            ),
            if (decision.resolutionNote != null && decision.resolutionNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(decision.resolutionNote!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
            if (decision.status == DecisionStatus.pending && store.canResolveDecisions) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _resolve(context, decision, DecisionStatus.rejected),
                      icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.danger),
                      label: const Text('رفض', style: TextStyle(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resolve(context, decision, DecisionStatus.approved),
                      icon: const Icon(Icons.check_rounded, size: 17),
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

  void _resolve(BuildContext context, DecisionRequest decision, DecisionStatus status) {
    showDialog(
      context: context,
      builder: (ctx) {
        final noteCtrl = TextEditingController();
        return AlertDialog(
          title: Text(status == DecisionStatus.approved ? 'الموافقة على القرار' : 'رفض القرار'),
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
              onPressed: () {
                context.read<AppStore>().resolveDecision(decision, status, note: noteCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }
}

class _DecisionStatusBadge extends StatelessWidget {
  final DecisionStatus status;
  const _DecisionStatusBadge({required this.status});

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
