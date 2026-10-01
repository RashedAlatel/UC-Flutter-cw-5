// موظّفو إدارتي — ما يملكه مديرُ الإدارة في حقّ فريقه، **ولا شيء غيره**.
//
// ــــ لماذا شاشةٌ خاصّة لا نطاقٌ مضيَّق في شاشة المستخدمين ــــ
//
// تلك فيها ثمانيةُ أفعالٍ لمسؤول النظام وحده: إضافةُ مستخدم، وتغييرُ الدور،
// والصلاحيات، والحذف، وتغييرُ الحالة، وأزرارُ الإصلاح، والإشعار الجماعي،
// وإعادةُ ختم البطاقة. وتضييقُ نطاقها يعني إخفاءَ الثمانية بشروطٍ مكتوبة —
// **وشرطٌ واحد يُخطئ يفتح فعلاً لمن لا يملكه**.
//
// وهذه الشاشةُ لا تحمل شيئاً منها أصلاً. فما لا يُرسَم لا تُنسى حراستُه،
// وهو أسلمُ بناءً لا أسلمُ حراسة.
//
// ــــ وما فيها ــــ
//
// (١) قائمةُ موظّفي إدارته المعتمدين. والمعتمدون وحدهم: **طلبُ التسجيل
//     بوابةٌ لمسؤول النظام**، وعرضُ من لم يُعتمد يُوهم بأنّ لمدير الإدارة
//     فيه قراراً.
//
// (٢) تصحيحُ الاسم وتغييرُ القسم — مباشرةً وبأثرٍ مختوم. وكلاهما كان
//     **مستحيلاً على الجميع** قبل هذه الدفعة: القسمُ يُكتب عند الاعتماد ثم
//     يجمد، والاسمُ لا تمسّه دالّةٌ إطلاقاً.
//
// (٣) طلبُ نقلٍ إلى إدارةٍ أخرى — **طلبٌ لا فعل**: النقلُ يغيّر بطاقةَ دخول
//     الموظّف وما يراه من مشاريع الوزارة كلِّها، فلا يقع إلا باعتماد مسؤول
//     النظام.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../widgets/section_picker.dart';

class MyDepartmentUsersScreen extends StatefulWidget {
  const MyDepartmentUsersScreen({super.key});

  @override
  State<MyDepartmentUsersScreen> createState() => _MyDepartmentUsersScreenState();
}

class _MyDepartmentUsersScreenState extends State<MyDepartmentUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // القاعدةُ هي الحَكَم، وهذه مرآتُها: شاشةٌ تَعِد بفعلٍ يُردّ عند الضغط
    // أسوأ من شاشةٍ لا تُعرض.
    if (!store.canManageDepartmentUsers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'هذه الشاشة لمدير الإدارة — وتعرض موظّفي إدارته.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final q = _query.trim().toLowerCase();
    final members = store.myDepartmentMembers
        .where((u) =>
            q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'موظّفو إدارتي',
            subtitle: '${store.myDepartmentMembers.length} موظّفاً معتمَداً — '
                'تصحيحُ الاسم والقسم، وطلبُ النقل بين الإدارات',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث بالاسم أو البريد',
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 19),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 16),
                if (members.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          store.myDepartmentMembers.isEmpty
                              // ــ ويُفرَّق بين الفراغين ــ
                              //
                              // «لا نتيجة لبحثك» على إدارةٍ لا موظّف فيها
                              // يُقرأ عطلاً. والثاني يقول أين يُضاف الناس.
                              ? 'لا موظّفين معتمَدين في إدارتك بعد. '
                                  'ويُعتمد التسجيلُ من مسؤول النظام.'
                              : 'لا موظّف يطابق بحثك.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.8),
                        ),
                      ),
                    ),
                  )
                else
                  for (final u in members) _MemberCard(user: u),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final AppUser user;
  const _MemberCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pending = store.pendingUserTransferFor(user);
    final section = store.sectionPathLabel(user.sectionId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          user.role.label,
                          user.email,
                          section.isEmpty ? 'تحت الإدارة مباشرةً' : section,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showDialog(
                      context: context, builder: (_) => _EditMemberDialog(user: user)),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('تعديل'),
                ),
                // ــ وطلبُ النقل يُخفى ما دام طلبٌ معلّقاً ــ
                //
                // ولولا ذلك لَقدّم المدير طلباً ثانياً يظنّ الأولَ ضائعاً —
                // وهو ما وقع في «المشروع يُضاف مرّتين».
                if (pending == null)
                  TextButton.icon(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _TransferRequestDialog(user: user)),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('طلب نقل'),
                  ),
              ],
            ),
            if (pending != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'طلبُ نقلٍ معلّق لدى مسؤول النظام — '
                  'إلى "${store.departmentById(pending.payload['toDepartmentId'] as String? ?? '')?.name ?? 'إدارة أخرى'}". '
                  'ولا يُنقل الموظّف حتى يُعتمد.',
                  style: const TextStyle(fontSize: 11.5, height: 1.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// تصحيحُ الاسم وتغييرُ القسم — الحقلان اللذان تقبلهما `updateUserProfile`.
class _EditMemberDialog extends StatefulWidget {
  final AppUser user;
  const _EditMemberDialog({required this.user});

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final _nameCtrl = TextEditingController(text: widget.user.name);
  late String? _sectionId = widget.user.sectionId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().updateUserProfile(
          widget.user,
          name: _nameCtrl.text,
          sectionId: _sectionId,
          clearSection: _sectionId == null,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dept = widget.user.departmentId ?? '';
    return AlertDialog(
      title: const Text('تعديل بيانات الموظّف'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  helperText: 'يُصحَّح هنا إن سُجّل ناقصاً — ويُحفظ في سجل التدقيق',
                ),
              ),
              const SizedBox(height: 16),
              if (dept.isNotEmpty)
                SectionPicker(
                  departmentId: dept,
                  initialSectionId: _sectionId,
                  onChanged: (v) => setState(() => _sectionId = v),
                ),
              const SizedBox(height: 10),
              // ــ وما لا يُعدَّل من هنا يُقال ــ
              //
              // فلا يبحث المديرُ عن حقلٍ ليس له، ولا يظنّ الشاشةَ ناقصة.
              const Text(
                'والدورُ والصلاحياتُ وحالةُ الحساب لمسؤول النظام. '
                'ونقلُ الموظّف إلى إدارةٍ أخرى يُرفع طلباً.',
                style: TextStyle(fontSize: 11.5, height: 1.7, color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: (_busy || _nameCtrl.text.trim().isEmpty) ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}

/// طلبُ نقلِ موظّفٍ إلى إدارةٍ أخرى — **يُرفع ولا يُنفَّذ**.
class _TransferRequestDialog extends StatefulWidget {
  final AppUser user;
  const _TransferRequestDialog({required this.user});

  @override
  State<_TransferRequestDialog> createState() => _TransferRequestDialogState();
}

class _TransferRequestDialogState extends State<_TransferRequestDialog> {
  String? _toDepartmentId;
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().submitUserTransferRequest(
          user: widget.user,
          toDepartmentId: _toDepartmentId!,
          reason: _reasonCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('رُفع طلبُ النقل إلى مسؤول النظام للاعتماد'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final others = store.departments
        .where((d) => d.id != widget.user.departmentId)
        .toList();

    return AlertDialog(
      title: const Text('طلب نقل موظّف'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _toDepartmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نقل إلى إدارة', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('اختر الإدارة')),
                  ...others.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                ],
                onChanged: (v) => setState(() => _toDepartmentId = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reasonCtrl,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'سبب النقل',
                  helperText: 'يُقرأ في مركز القرارات وفي سجل التدقيق',
                ),
              ),
              const SizedBox(height: 12),
              // ــ ويُقال ما سيقع قبل الضغط ــ
              const Text(
                'لن يُنقل الموظّف الآن: يُرفع طلبٌ إلى مسؤول النظام. '
                'وباعتماده يتغيّر ما يراه من مشاريع وأعمال، ويُصفَّر قسمُه '
                'لأن أقسام إدارةٍ لا تصلح لإدارةٍ أخرى.',
                style: TextStyle(fontSize: 11.5, height: 1.8, color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: (_busy || _toDepartmentId == null || _reasonCtrl.text.trim().isEmpty)
              ? null
              : _send,
          child: Text(_busy ? 'جارٍ الإرسال…' : 'رفع الطلب للاعتماد'),
        ),
      ],
    );
  }
}
