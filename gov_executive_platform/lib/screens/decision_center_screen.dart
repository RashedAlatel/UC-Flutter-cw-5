import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/approval_request.dart';
import '../models/assignment_policy.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../utils/formatters.dart';
import '../widgets/field_changes_table.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommandBand(
            title: 'مركز القرارات التنفيذية',
            subtitle: 'كل طلبات تسجيل الأعضاء وإضافة المشاريع وتعديل المواعيد النهائية وإرسال البريد والقرارات التنفيذية تمر من هنا، مرتبة حسب الأولوية وتأثير التأخير.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
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
            // الدور المعروض هنا مقروء من حمولة الطلب، أي من الحقل نفسه الذي
            // ستكتبه الدالة الخلفية في بطاقة الدخول. العنوان والوصف أعلاه
            // نصّان كتبهما مُقدّم الطلب، فلو خالفا الحمولة ظهر الخلاف هنا
            // قبل الضغط على «موافقة».
            if (r.grantedRoleLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'سيُمنح عند الموافقة دور: ${r.grantedRoleLabel}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
            if (r.notifyPreview != null) ...[
              const SizedBox(height: 12),
              _NotifyPreviewPanel(preview: r.notifyPreview!, store: store),
            ],
            // طلب تغيير مدير المشروع: من كان ومن سيصير — جنباً إلى جنب.
            // ولا يُقرأ المدير الحالي من المشروع وقت العرض بل من الحمولة:
            // مسؤول النظام يبتّ بعد يوم أو يومين، وما يراه يجب أن يكون ما
            // كان وقت الطلب لا ما صار إليه بعده.
            if (r.type == ApprovalType.managerChange) ...[
              const SizedBox(height: 12),
              _ManagerChangePanel(request: r),
            ],
            // طلبُ تعديل بيانات المشروع: الفروقُ ومسارُ الطلب.
            //
            // ولا يُكتفى بالوصف: هو نصٌّ كتبه الطالب، والحمولةُ هي ما
            // يُطبَّق. راجع `editChanges` في `approval_request.dart`.
            if (r.type == ApprovalType.projectEdit) ...[
              const SizedBox(height: 12),
              _ProjectEditPanel(request: r),
            ],
            // نقلُ المشروع بين الإدارتين: القديمةُ والجديدة جنباً إلى جنب،
            // ومعهما ما يقع عند الاعتماد — فلا يوقّع المسؤول على أثرٍ لا يعرفه.
            // ــ نقلُ موظّف: من، ومن أين، وإلى أين، وماذا يقع ــ
            //
            // ولا يُترك المعتمِد يقرأ «طلب نقل موظّف: فلان» ويضغط: النقلُ
            // يغيّر بطاقةَ دخوله وما يراه من مشاريع الوزارة كلِّها.
            if (r.type == ApprovalType.userTransfer) ...[
              const SizedBox(height: 12),
              _UserTransferPanel(request: r),
            ],
            if (r.type == ApprovalType.departmentTransfer) ...[
              const SizedBox(height: 12),
              _DepartmentTransferPanel(request: r),
            ],
            // ــ تعيين مدير مشروع: ما الذي يُمنَح باعتماد هذا الطلب؟ ــ
            //
            // المعتمِد مدير إدارة لا مسؤول نظام، وقد لا يعرف ماذا تعني
            // «قيادة المشروع» في المنصة. فتُذكر آثارها صراحةً قبل الضغط —
            // اعتمادٌ لا يعرف صاحبه ماذا منح ليس اعتماداً.
            if (r.type == ApprovalType.projectManagerAppointment) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'باعتماد هذا الطلب يصير «${r.requestedByName}» مديراً '
                      'لهذا المشروع — وداخله وحده.',
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.8, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'فيطّلع على تفاصيله ومهامه كاملة، ويُسنِد المهام لمنفّذيه، '
                      'ويتابع تحديثاتهم اليومية، وينشئ العوائق والمخاطر، ويعتمد ما '
                      'يُنجَز فيه. ولا يتغيّر دوره الأساسي، ولا يمسّ ذلك مشروعاً آخر.',
                      style: TextStyle(
                          fontSize: 11.5, height: 1.8, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
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
                  // ــــ «إعادة للتعديل»: بابٌ ثالث ليس رفضاً ــــ
                  //
                  // ولولاه لكان أمام المعتمِد بابان: يعتمد تعديلاً فيه خطأٌ
                  // واحد، أو يرفضه فيبدأ الطالبُ من الصفر. وأكثرُ ما يُردّ
                  // من هذه الطلبات يُردّ لحقلٍ واحد.
                  //
                  // وهو لهذا النوع وحده: الطلباتُ الأخرى لا مسارَ لتصحيحها
                  // وإعادةِ إرسالها من صفحتها، فإعادتُها تترك صاحبَها
                  // بطلبٍ حيٍّ لا يعرف ماذا يفعل به.
                  if (r.type == ApprovalType.projectEdit) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _returnForRevision(context),
                        icon: const Icon(Icons.undo_rounded, size: 16, color: AppColors.info),
                        label: const Text('إعادة للتعديل', style: TextStyle(color: AppColors.info)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.info)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // «عدّل ثم اعتمد» لمسؤول النظام وحده وعلى نوعين اثنين.
                  // والحراسة على الخادم لا هنا: `approveRequest` ترفض
                  // `payloadOverride` من غيره ومن غير هذين النوعين.
                  if (store.isAdmin &&
                      (r.type == ApprovalType.projectCreate || r.type == ApprovalType.workCreate)) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _editThenApprove(context, r),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('عدّل ثم اعتمد'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // ــــ «اعتمد وكلّف»: حقلٌ واحد لمن يبتّ في طلب العمل ــــ
                  //
                  // الطلب يصل من إدارةٍ أخرى بلا منفّذ — وذلك مقصود: من طلبه
                  // لا يعرف اختصاصات إدارتك. فالتكليف هنا، عند البتّ، لا في
                  // خطوةٍ ثانية تُنسى.
                  //
                  // وهو **حقلٌ واحد** لا الحمولة: تعديل الموعد النهائي يبقى
                  // لمسؤول النظام، وإلا صار بابَ التفافٍ حول بوابته. وحدُّ
                  // ذلك على الخادم في `approval_override.ts`، وما هنا ترتيبُ
                  // واجهة لا حراسة.
                  if (!store.isAdmin && r.type == ApprovalType.workCreate) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _assignThenApprove(context, r),
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                        label: const Text('اعتمد وكلّف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
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

  /// «اعتمد وكلّف» — يختار المعتمِد المنفّذ ويعتمد في خطوة.
  ///
  /// ويمرّ بالطريق نفسه: `payloadOverride` بمفتاحٍ واحد. فلا مسار ثانٍ
  /// للاعتماد يفترق عن الأول بأول تعديل.
  Future<void> _assignThenApprove(BuildContext context, ApprovalRequest r) async {
    final uid = await showDialog<String>(
      context: context,
      builder: (_) => _AssignOnApproveDialog(request: r),
    );
    if (uid == null || !context.mounted) return;
    await _approveWith(context, r, {'assigneeUid': uid});
  }

  Future<void> _editThenApprove(BuildContext context, ApprovalRequest r) async {
    final override = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditRequestDialog(request: r),
    );
    if (override == null || !context.mounted) return;
    await _approveWith(context, r, override);
  }

  /// الاعتماد بتجاوزٍ على الحمولة — مشتركٌ بين «عدّل ثم اعتمد» و«اعتمد وكلّف».
  Future<void> _approveWith(
    BuildContext context,
    ApprovalRequest r,
    Map<String, dynamic> override,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().approveRequest(r, payloadOverride: override);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  /// يُعيد الطلبَ لمقدّمه بملاحظة — **والملاحظةُ مطلوبة هنا لا اختيارية**.
  ///
  /// وإعادةٌ بلا سبب تُبقي الطلبَ يدور: يقرأ صاحبُه «أُعيد إليك» ولا يعرف
  /// ماذا يصحّح، فيُعيد إرساله كما هو. والرفضُ يُنهي، أما هذه فتَعِد بجولةٍ
  /// ثانية — فلتكن الجولةُ الثانية مبنيّةً على شيء.
  void _returnForRevision(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final noteCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('إعادة الطلب للتعديل'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'يعود الطلب إلى مقدّمه ليصحّحه ويعيد إرساله — ولا يُرفض، '
                    'ولا يتغيّر شيء في المشروع.',
                    style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      labelText: 'ما الذي يُصحَّح؟',
                      helperText: 'يصل مقدّم الطلب مع الإشعار',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: noteCtrl.text.trim().isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        final error = await context
                            .read<AppStore>()
                            .returnRequestForRevision(widget.request, noteCtrl.text.trim());
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _error = error;
                        });
                      },
                child: const Text('إعادة للتعديل'),
              ),
            ],
          ),
        );
      },
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
      // «معاد للتعديل» ليس رفضاً، فلا يُلوَّن بلونه: الطلبُ حيٌّ عند مقدّمه
      // ينتظر تصحيحاً — وهي حالُ متابعةٍ لا حالُ انتهاء.
      case DecisionStatus.returnedForRevision:
        color = AppColors.info;
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

/// معاينة البريد الذي سيخرج عند الاعتماد.
///
/// عنوانُ الطلب ووصفُه نصّان يكتبهما الطالب، والحمولة هي ما تُرسله الدالة
/// الخلفية. فلو اكتفى مسؤول النظام بالعنوان لاعتمد بريداً يخرج باسم الوزارة
/// دون أن يقرأ حرفاً منه. وهذه اللوحة تعرض ما سيُرسل: قناتَه ومستلميه ونصَّه.
class _NotifyPreviewPanel extends StatelessWidget {
  final NotifyPreview preview;
  final AppStore store;
  const _NotifyPreviewPanel({required this.preview, required this.store});

  @override
  Widget build(BuildContext context) {
    // الأسماء لا المعرّفات: «u-4f2c» لا يُقرأ، ومسؤول النظام يقرّر بناءً على
    // من يصله البريد. ومعرّف بلا حساب يُعرض كما هو لا يُخفى.
    final names = preview.recipientUids
        .map((uid) => store.users.where((u) => u.id == uid).map((u) => u.name).firstOrNull ?? uid)
        .toList();
    final shown = names.take(6).toList();
    final rest = names.length - shown.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // بلا const: `AppColors.primary` لون هوية قابل للتغيير من
              // «إعدادات المظهر»، فليس ثابتاً وقت الترجمة.
              Icon(Icons.mark_email_read_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سيُرسل عند الموافقة عبر ${preview.channel.label} إلى ${names.length} مستلم(ين)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rest > 0 ? '${shown.join('، ')} و$rest غيرهم' : shown.join('، '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.7),
          ),
          if (preview.sampleSubject.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('العنوان: ${preview.sampleSubject}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 8),
          // نصوص مختلفة بين المستلمين (تنبيه المتأخرات يسرد لكلٍّ مشاريعه):
          // يُقال ذلك صراحةً، وإلا ظنّ القارئ أن ما يراه يصل الجميع.
          if (preview.varied)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'نصّ كل مستلم مخصَّص له. وهذا نموذج من الرسائل:',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
            child: Text(preview.sampleBody, style: const TextStyle(fontSize: 12, height: 1.8)),
          ),
        ],
      ),
    );
  }
}

/// «اعتمد وكلّف»: يسمّي المعتمِدُ منفّذاً ثم يعتمد — حقلٌ واحد لا حمولة.
///
/// وهي الخطوة التي يقوم عليها ترتيب العمل: الطلب يصل الإدارة بلا منفّذ لأن
/// من طلبه لا يعرف اختصاصاتها، فمديرُها يكلّف من يختصّ عند البتّ. ولولا
/// هذه لَنزل العمل «غير مُسنَد» وانتظر خطوةً ثانية تُنسى.
class _AssignOnApproveDialog extends StatefulWidget {
  final ApprovalRequest request;
  const _AssignOnApproveDialog({required this.request});

  @override
  State<_AssignOnApproveDialog> createState() => _AssignOnApproveDialogState();
}

class _AssignOnApproveDialogState extends State<_AssignOnApproveDialog> {
  late String _uid = widget.request.payload['assigneeUid']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final deptId = widget.request.departmentId ?? '';
    // المعيار الموحّد لا تصفيةٌ محلّية: من يحقّ لي إسنادُه، في هذه الإدارة.
    final candidates = eligibleAssignees(
      allUsers: store.users,
      actor: store.currentUser,
      departmentId: deptId,
    );
    final suggested = widget.request.payload['assigneeName']?.toString() ?? '';

    return AlertDialog(
      title: const Text('اعتمد وكلّف'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يُعتمد الطلب ويُسنَد العمل لمن تختاره في خطوة واحدة. '
              'وما سوى المنفّذ يُعتمد كما ورد في الطلب.',
              style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
            ),
            // اقتراحُ الطالب يُعرض ولا يُفرض: قد يكون أصاب، وقد سمّى من لا
            // يختصّ — والقرار لمن يعرف إدارته.
            if (suggested.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('اقترح مقدّم الطلب: $suggested',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: candidates.any((u) => u.id == _uid) ? _uid : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ'),
              items: candidates
                  .map((u) => DropdownMenuItem<String>(value: u.id, child: Text(u.name)))
                  .toList(),
              onChanged: (v) => setState(() => _uid = v ?? ''),
            ),
            if (candidates.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                emptyAssigneeReason(
                  allUsers: store.users,
                  actor: store.currentUser,
                  departmentId: deptId,
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.warning, height: 1.7),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          // بلا اسمٍ لا معنى للزرّ: من أراد الاعتماد بلا تكليف فـ«موافقة»
          // إلى جانبه تفعل ذلك.
          onPressed: _uid.isEmpty ? null : () => Navigator.pop(context, _uid),
          child: const Text('اعتمد وكلّف'),
        ),
      ],
    );
  }
}

/// تعديل حمولة طلبٍ قبل اعتماده — لمسؤول النظام وحده.
///
/// وهي حاجة عملية: يصل الطلب باسم صحيح ومنفّذ خاطئ، أو بموعد لا يناسب خطة
/// الإدارة. وكان البديل رفضَه وطلبَ إعادة تقديمه — دورةٌ كاملة لتصحيح حقل.
///
/// والحراسة **على الخادم**: `approveRequest` ترفض `payloadOverride` من غير
/// مسؤول النظام ومن غير `projectCreate` و`workCreate`. وإخفاء الزرّ هنا
/// ترتيبٌ للواجهة لا حراسة.
class _EditRequestDialog extends StatefulWidget {
  final ApprovalRequest request;
  const _EditRequestDialog({required this.request});

  @override
  State<_EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<_EditRequestDialog> {
  late final Map<String, dynamic> _payload = Map<String, dynamic>.from(widget.request.payload);
  late final bool _isProject = widget.request.type == ApprovalType.projectCreate;

  late final _nameCtrl = TextEditingController(
      text: (_isProject ? _payload['name'] : _payload['title'])?.toString() ?? '');
  late final _descCtrl = TextEditingController(text: _payload['description']?.toString() ?? '');
  late DateTime _dueDate =
      DateTime.tryParse(_payload['dueDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30));
  late PriorityLevel _priority = PriorityLevel.fromName(_payload['priority']?.toString() ?? 'medium');
  late final Set<String> _managerUids = _uidSet(_payload['managerUids']);
  late final Set<String> _executorUids = _uidSet(_payload['executorUids']);
  late String _assigneeUid = _payload['assigneeUid']?.toString() ?? '';

  static Set<String> _uidSet(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet() : <String>{};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// الحقول **المتغيّرة وحدها** تُرسل.
  ///
  /// إرسال الحمولة كاملة يجعل كل اعتماد يبدو تعديلاً في سجل التدقيق، فيضيع
  /// التمييز بين «اعتُمد كما طُلب» و«اعتُمد بعد تعديل» — وهو التمييز الذي
  /// من أجله كُتب هذا كلّه.
  Map<String, dynamic> _diff() {
    final out = <String, dynamic>{};
    void put(String key, Object? value) {
      final before = _payload[key];
      final same = before is List && value is List
          ? before.map((e) => e.toString()).toList().toString() == value.toString()
          : before == value;
      if (!same) out[key] = value;
    }

    put(_isProject ? 'name' : 'title', _nameCtrl.text.trim());
    put('description', _descCtrl.text.trim());
    put('dueDate', _dueDate.toIso8601String());
    put('priority', _priority.name);
    if (_isProject) {
      put('managerUids', _managerUids.toList());
      put('executorUids', _executorUids.toList());
    } else {
      put('assigneeUid', _assigneeUid);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final deptId = widget.request.departmentId ?? '';
    final candidates = store.users
        .where((u) =>
            u.status == UserStatus.approved &&
            (deptId.isEmpty || u.departmentId == deptId || u.departmentIds.contains(deptId)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      title: Text(_isProject ? 'تعديل طلب المشروع' : 'تعديل طلب العمل'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ما تعدّله هنا هو ما سيُنفَّذ عند الاعتماد، ويُسجَّل في سجل التدقيق '
                'بوصفه اعتماداً بعد تعديل.',
                style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: _isProject ? 'اسم المشروع' : 'اسم العمل'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PriorityLevel>(
                initialValue: _priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: PriorityLevel.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('الاستحقاق: ${Formatters.shortDate(_dueDate)}',
                      style: const TextStyle(fontSize: 12.5))),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: const Text('تغيير'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isProject) ...[
                _UidPicker(
                  label: 'مديرو المشروع',
                  candidates: candidates,
                  selected: _managerUids,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 10),
                _UidPicker(
                  label: 'المنفّذون (حسابات)',
                  candidates: candidates,
                  selected: _executorUids,
                  onChanged: () => setState(() {}),
                ),
              ] else
                DropdownButtonFormField<String>(
                  initialValue: candidates.any((u) => u.id == _assigneeUid) ? _assigneeUid : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المسؤول عن التنفيذ'),
                  items: candidates
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _assigneeUid = v ?? ''),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            final diff = _diff();
            // بلا تغيير: يُعاد كما هو فيُعتمد اعتماداً عادياً لا «بعد تعديل».
            Navigator.pop(context, diff.isEmpty ? <String, dynamic>{} : diff);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('اعتمد بالتعديل'),
        ),
      ],
    );
  }
}

class _UidPicker extends StatelessWidget {
  final String label;
  final List<AppUser> candidates;
  final Set<String> selected;
  final VoidCallback onChanged;

  const _UidPicker({
    required this.label,
    required this.candidates,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final u in candidates)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    value: selected.contains(u.id),
                    title: Text(u.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onChanged: (v) {
                      if (v == true) {
                        selected.add(u.id);
                      } else {
                        selected.remove(u.id);
                      }
                      onChanged();
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «من → إلى» لطلب تغيير مدير المشروع.
class _ManagerChangePanel extends StatelessWidget {
  final ApprovalRequest request;
  const _ManagerChangePanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final payload = request.payload;
    final currentNames = (payload['currentManagerNames'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final newName = payload['newManagerName']?.toString() ?? 'غير معروف';
    final reason = payload['reason']?.toString().trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نقل قيادة المشروع', style: AppText.label),
          const SizedBox(height: 8),
          _ChangeLine(
            label: 'المدير الحالي',
            value: currentNames.isEmpty ? 'بلا مدير' : currentNames.join('، '),
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 6),
          _ChangeLine(
            label: 'المدير المقترح',
            value: newName,
            icon: Icons.person_add_alt_1_outlined,
            emphasis: true,
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ChangeLine(label: 'السبب', value: reason, icon: Icons.notes_rounded),
          ],
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasis;
  const _ChangeLine({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.7),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// طلبُ تعديل بيانات المشروع في مركز القرارات: **ما يُطبَّق، ومن بتّ فيه**.
///
/// ــــ ولماذا ثلاثة أشياء لا شيءٌ واحد ــــ
///
/// * **الفروق** — القيمةُ الحالية إلى الجديدة، والجوهريُّ مميَّز. وبها يبتّ
///   المعتمِد فيما يُطبَّق لا فيما وُصف.
/// * **السبب** — يكتبه الطالب، ويُقرأ قبل «موافقة» لا بعدها.
/// * **مسارُ الطلب** — من طلب، ومن وافق قبلي، ومن ينتظره الآن. ومسارٌ
///   بمرحلتين لا يُرى منه إلا المرحلةُ الحالية يجعل مسؤول النظام يوقّع بلا
///   أن يعرف أوافق مديرُ الإدارة أم لم يصله الطلبُ بعد.
class _ProjectEditPanel extends StatelessWidget {
  final ApprovalRequest request;
  const _ProjectEditPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final changes = request.editChanges;
    final reason = request.payload['reason']?.toString().trim() ?? '';
    final trail = request.stageTrail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldChangesTable(
            changes: changes,
            title: 'ما سيُطبَّق على المشروع',
            emptyText: 'الطلب لا يحمل تغييراً — لا يُعتمد، ويُعاد لمقدّمه.',
          ),
          if (request.hasSensitiveEdit) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.priority_high_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'الحقول المعلَّمة جوهرية: تغيّر التزاماً أو مسؤوليةً أو موعداً.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.warning, height: 1.7),
                  ),
                ),
              ],
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChangeLine(label: 'السبب', value: reason, icon: Icons.notes_rounded),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Text('مسار الطلب', style: AppText.label),
          const SizedBox(height: 6),
          _ChangeLine(
            label: 'قدّمه',
            value: '${request.requestedByName} · ${Formatters.shortDate(request.requestedDate)}',
            icon: Icons.person_outline_rounded,
          ),
          for (final step in trail) ...[
            const SizedBox(height: 6),
            _ChangeLine(
              label: step.stage.label,
              value: '${step.byName} · ${step.actionLabel} · ${Formatters.shortDate(step.at)}',
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
          // ومن ينتظره الآن — للطلب الحيّ وحده: طلبٌ بُتّ فيه لا ينتظر أحداً،
          // وقولُ «بانتظار فلان» عنه يُقرأ تعليقاً لا أثراً.
          if (request.status == DecisionStatus.pending) ...[
            const SizedBox(height: 6),
            _ChangeLine(
              label: 'بانتظار',
              value: request.stage.label,
              icon: Icons.hourglass_empty_rounded,
              emphasis: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// «من إدارة → إلى إدارة» لطلب نقل المشروع، ومعه أثرُ الاعتماد.
///
/// والأسماءُ من **الحمولة** لا من المشروع وقت العرض: مسؤول النظام يبتّ بعد
/// يومٍ أو يومين، وما يراه يجب أن يكون ما كان وقت الطلب — كما في
/// [_ManagerChangePanel] حرفاً بحرف.
class _DepartmentTransferPanel extends StatelessWidget {
  final ApprovalRequest request;
  const _DepartmentTransferPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final payload = request.payload;
    final from = payload['oldDepartmentName']?.toString() ?? 'غير معروفة';
    final to = payload['newDepartmentName']?.toString() ?? 'غير معروفة';
    final reason = payload['reason']?.toString().trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نقل المشروع بين الإدارات', style: AppText.label),
          const SizedBox(height: 8),
          _ChangeLine(
            label: 'الإدارة الحالية',
            value: from,
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 6),
          _ChangeLine(
            label: 'الإدارة المستقبِلة',
            value: to,
            icon: Icons.account_balance_rounded,
            emphasis: true,
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ChangeLine(label: 'السبب', value: reason, icon: Icons.notes_rounded),
          ],
          const SizedBox(height: 10),
          // ما يقع عند الضغط — بالحرف، وقبل الضغط لا بعده.
          const Text(
            'باعتماد هذا الطلب ينتقل المشروع وكلُّ ما فيه: مهامُّه وتحديثاته '
            'اليومية ومخاطره وعوائقه ومرفقاته — لا يُحذف منها شيء. ويكسب مديرُ '
            'الإدارة المستقبِلة رؤيتَها وإدارتَها، ويفقدها مديرُ الإدارة '
            'الحالية. ويُفرَّغ القسمُ داخل الإدارة، ويُسجَّل تاريخ النقل.',
            style: TextStyle(fontSize: 11.5, height: 1.8, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// بطاقةُ طلب نقل موظّف — تقول أثرَ الاعتماد قبل الضغط.
class _UserTransferPanel extends StatelessWidget {
  final ApprovalRequest request;
  const _UserTransferPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    String dept(String? id) =>
        store.departmentById(id ?? '')?.name ?? (id == null || id.isEmpty ? 'بلا إدارة' : id);

    final from = dept(request.payload['fromDepartmentId'] as String?);
    final to = dept(request.payload['toDepartmentId'] as String?);
    final name = request.payload['userName'] as String? ?? 'الموظّف';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نقلُ "$name": من "$from" إلى "$to"',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 6),
          const Text(
            'وباعتماد هذا الطلب تتغيّر بطاقةُ دخوله فوراً: يرى مشاريعَ الإدارة '
            'الجديدة ولا يرى مشاريعَ القديمة. ويُصفَّر قسمُه لأن أقسام إدارةٍ '
            'لا تصلح لإدارةٍ أخرى.',
            style: TextStyle(fontSize: 11.5, height: 1.8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
