import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/user_deletion_report.dart';
import '../theme/app_theme.dart';
import '../widgets/command_band.dart';
import '../widgets/notify_dialog.dart';
import '../widgets/user_permissions_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  UserRole? _roleFilter;
  UserStatus? _statusFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// يختم عضوية المشاريع على توابعها، ويقول ماذا وقع.
  Future<void> _stampMembership(BuildContext context) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ختم عضوية المشاريع على توابعها'),
        content: const Text(
          'ينسخ مديري كل مشروع ومنفّذيه على مهامّه وتحديثاته اليومية ومخاطره '
          'وعوائقه، فيراها أعضاؤه. يلزم مرّةً واحدة بعد هذا التحديث، '
          'وإعادتُه لا تضرّ — لا يُكتب على مستندٍ مطابقٍ سلفاً.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (go != true) return;
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ الختم…')));
    final r = await store.stampChildMembership();
    messenger.showSnackBar(SnackBar(
      content: Text(r.error ??
          'فُحص ${r.scanned} مستنداً تابعاً، وخُتم منها ${r.stamped}.'),
      backgroundColor: r.error == null ? AppColors.success : AppColors.danger,
      duration: const Duration(seconds: 8),
    ));
  }

  /// يُعيد ختمَ إدارة كل مشروع على توابعه — إصلاحاً لما نُقل قبل هذه الدفعة.
  ///
  /// ــ العطلُ الذي يُصلحه ــ
  ///
  /// نقلُ قسمٍ إلى إدارة أخرى (أو تحويلُ إدارةٍ إلى قسم) كان ينقل المشاريع
  /// **ولا ينقل توابعها**: تبقى مهامُّها وتحديثاتُها ومخاطرُها وعوائقُها
  /// مختومةً بالإدارة القديمة. فمديرُ الإدارة الجديدة يرى المشروع ولا يرى
  /// مهامَّه، ومديرُ القديمة يراها وقد خرج المشروع من إدارته.
  ///
  /// ويُقاس في `test_rules/department_transfer.rules.test.mjs`.
  Future<void> _restampDepartments(BuildContext context) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة ختم إدارات التوابع'),
        content: const Text(
          'يفحص مهامّ كل مشروع وتحديثاته اليومية ومخاطره وعوائقه، ويُعيد ختم '
          'ما اختلفت إدارتُه عن إدارة مشروعه.\n\n'
          'ويلزم مرّةً واحدة إن كنتَ قد نقلتَ قسماً إلى إدارة أخرى أو حوّلتَ '
          'إدارةً إلى قسم قبل هذا التحديث: المشاريع انتقلت حينها ولم تنتقل '
          'توابعُها معها. وإعادتُه لا تضرّ — لا يُكتب على مستندٍ مطابقٍ سلفاً.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (go != true) return;
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ الفحص وإعادة الختم…')));
    final r = await store.restampChildDepartments();
    messenger.showSnackBar(SnackBar(
      // ويُقال العددُ حتى لو كان صفراً: «فُحص ٤٠٠ وأُصلح ٠» خبرٌ يطمئن،
      // و«تم» وحدها لا تقول أوقع شيءٌ أم لم يقع.
      content: Text(r.error ??
          'فُحص ${r.scanned} مستنداً تابعاً، وأُعيد ختم ${r.restamped} منها'
              '${r.orphaned > 0 ? '، و${r.orphaned} تابعٌ لمشروعٍ لم يعد موجوداً فتُرك' : ''}.'),
      backgroundColor: r.error == null ? AppColors.success : AppColors.danger,
      duration: const Duration(seconds: 8),
    ));
  }

  /// يُعيد كتابة كلّ حقل تاريخٍ خُزّن نصّاً في المشاريع — ختماً زمنياً.
  ///
  /// ــ العطلُ الذي يُصلحه ــ
  ///
  /// مستندٌ واحد حمل `contractEndDate` نصّاً — `'2026-05-17T00:00:00.000'` —
  /// فأخفى مشاريعَ الوزارة كلَّها يوماً كاملاً. كتبَه مسارُ اعتماد تعديل
  /// المشروع، وقد أُصلح. والقراءةُ حُصِّنت فلا تنهار، **لكنّ المكتوبَ يبقى
  /// نصّاً**: التقريرُ اليوميّ يُولَّد على الخادم ويقرأ المستند مباشرةً.
  Future<void> _repairDates(BuildContext context) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إصلاح تواريخ مخزَّنة نصّاً'),
        content: const Text(
          'يفحص كل مشروع، ويُعيد كتابة أي تاريخٍ خُزّن نصّاً ليصير تاريخاً '
          'حقيقياً في قاعدة البيانات.\n\n'
          'ويلزم مرّةً واحدة بعد هذا التحديث إن كنتَ قد اعتمدتَ طلبَ تعديل '
          'بيانات مشروعٍ من قبل. وإعادتُه لا تضرّ — لا يُكتب على مستندٍ '
          'سليمٍ أصلاً، ولا يُختلق تاريخٌ لنصٍّ لا يُقرأ تاريخاً.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (go != true) return;
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ فحص المشاريع…')));
    final r = await store.repairTextDates();
    messenger.showSnackBar(SnackBar(
      content: Text(r.error ??
          'فُحص ${r.scanned} مشروعاً، وأُصلحت تواريخ ${r.repaired} منها'
              '${r.unreadable > 0 ? '، و${r.unreadable} حقلاً نصُّه لا يُقرأ تاريخاً فتُرك كما هو' : ''}.'),
      backgroundColor: r.error == null ? AppColors.success : AppColors.danger,
      duration: const Duration(seconds: 8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    // على مستوى الوزارة (مئات الحسابات) لا تكفي قائمة مسطّحة: البحث يشمل
    // الاسم والبريد ورقم الجوال معاً، مع تصفية بالدور وبحالة الحساب.
    final q = _query.trim().toLowerCase();
    final users = store.users.where((u) {
      if (_roleFilter != null && u.role != _roleFilter) return false;
      if (_statusFilter != null && u.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();

    final pending = store.users.where((u) => u.status == UserStatus.pending).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommandBand(
            title: 'إدارة المستخدمين',
            subtitle: 'إجمالي ${store.users.length} حساب'
                '${pending > 0 ? ' · $pending بانتظار الاعتماد' : ''}',
            actions: [
              BandButton(
                label: 'إشعار جماعي',
                icon: Icons.forward_to_inbox_rounded,
                onPressed: () => showDialog(context: context, builder: (_) => const NotifyDialog(initialUsers: [])),
              ),
              // ــ ختمُ العضوية على توابع المشاريع ــ
              //
              // `executorUids` لم تكن تُنسخ على المهام والتحديثات والمخاطر
              // والعوائق قط. فمن كان منفّذاً في مشروع لا تعرفه القاعدةُ على
              // تحديثاته ولا يجده الاستعلام — فلا يصله شيء. والحقل يُكتب من
              // الآن على كل تابعٍ جديد، وهذا الزرّ لما كُتب قبل ذلك.
              //
              // يُضغط مرّةً بعد النشر، وإعادتُه بلا ضرر.
              BandButton(
                label: 'ختم عضوية المشاريع',
                icon: Icons.published_with_changes_rounded,
                onPressed: () => _stampMembership(context),
              ),
              // ــ وإعادةُ ختم الإدارات: إصلاحُ ما نُقل قبل هذه الدفعة ــ
              //
              // نقلُ الأقسام بين الإدارات كان ينقل المشاريع ولا ينقل توابعها.
              // يُضغط مرّةً، وإعادتُه بلا ضرر.
              BandButton(
                label: 'إعادة ختم إدارات التوابع',
                icon: Icons.drive_file_move_rtl_outlined,
                onPressed: () => _restampDepartments(context),
              ),
              // ــ وإصلاحُ التواريخ المخزَّنة نصّاً ــ
              //
              // مستندٌ واحد حمل تاريخاً نصّاً فأخفى مشاريعَ الوزارة كلَّها
              // يوماً. الكتابةُ أُصلحت والقراءةُ حُصِّنت، وهذا لما كُتب قبل
              // ذلك. يُضغط مرّةً، وإعادتُه بلا ضرر.
              BandButton(
                label: 'إصلاح تواريخ مخزَّنة نصّاً',
                icon: Icons.event_repeat_rounded,
                onPressed: () => _repairDates(context),
              ),
              BandButton(
                label: 'إضافة مستخدم مباشرة',
                icon: Icons.person_add_alt_rounded,
                filled: true,
                onPressed: () => showDialog(context: context, builder: (_) => const _UserFormDialog()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // ــــ الدور الموروث «مدير مشروع» ــــ
          //
          // لم يعد يُمنح: قيادة المشروع صارت مسؤوليةً داخل مشروع بعينه تُقرأ
          // من `managerUids` عليه. والحسابات الحاملة له تعمل كما هي، ولا
          // تُحوَّل تلقائياً — تحويلُ حساباتٍ حيّة دفعةً واحدة قرارُ مسؤول
          // النظام لا قرارُ نشرٍ يقع بلا أن يراه.
          //
          // واللافتة تظهر ما دام أحدٌ يحمله، وتختفي وحدها حين لا يبقى منه شيء.
          if (store.isAdmin && store.legacyProjectOfficers.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${store.legacyProjectOfficers.length} حساباً ما زال بالدور '
                    'الموروث «مدير مشروع»',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'هذا الدور لم يعد يُمنح: قيادة المشروع صارت تعييناً داخل مشروع '
                    'بعينه. والتحويل إلى «موظف» **لا يُفقد أحداً مشاريعه** — من كان '
                    'مديراً لمشروع يبقى مديراً له، ويفقد وحده صفة المدير في مشاريع '
                    'لا علاقة له بها.',
                    style: TextStyle(
                        fontSize: 11.5, height: 1.8, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const _LegacyRoleDialog(),
                    ),
                    icon: const Icon(Icons.published_with_changes_rounded, size: 17),
                    label: const Text('مراجعة الحسابات وتحويلها'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو البريد أو رقم الجوال',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<UserRole?>(
                      initialValue: _roleFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الدور', isDense: true),
                      items: [
                        const DropdownMenuItem<UserRole?>(value: null, child: Text('كل الأدوار')),
                        ...UserRole.values.map((r) => DropdownMenuItem<UserRole?>(value: r, child: Text(r.label))),
                      ],
                      onChanged: (v) => setState(() => _roleFilter = v),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<UserStatus?>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'حالة الحساب', isDense: true),
                      items: [
                        const DropdownMenuItem<UserStatus?>(value: null, child: Text('كل الحالات')),
                        ...UserStatus.values.map((s) => DropdownMenuItem<UserStatus?>(value: s, child: Text(s.label))),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                  Text(
                    'النتائج: ${users.length}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: users.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text('لا توجد حسابات مطابقة للبحث', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _UserRow(user: users[i]),
                  ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  final AppUser user;
  const _UserRow({required this.user});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _busy = false;
  bool _restamping = false;
  bool _resetting = false;

  /// يرسل للمستخدم رابط إعادة تعيين كلمة المرور على بريده المسجَّل.
  ///
  /// ولا إخفاءَ هنا خلافاً لشاشة الدخول: الحساب معروضٌ أمام مسؤول النظام في
  /// القائمة، فإخفاءُ وجوده عبثٌ. ويُسمّى المستخدم صراحةً ليتأكّد أن الرابط
  /// ذهب إلى من قصده لا إلى الصف المجاور.
  Future<void> _sendPasswordReset() async {
    setState(() => _resetting = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AppStore>().sendPasswordResetFor(widget.user);
    if (!mounted) return;
    setState(() => _resetting = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ??
          'أُرسل رابط إعادة تعيين كلمة المرور إلى "${widget.user.name}" '
              'على ${widget.user.email}.'),
    ));
  }

  Future<void> _toggleExempt() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final next = !widget.user.emailVerificationExempt;
    final error = await context.read<AppStore>().setEmailVerificationExempt(widget.user, next);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ??
          (next
              ? 'استُثني "${widget.user.name}" من شرط تأكيد البريد الوزاري.'
              : 'عاد شرط تأكيد البريد الوزاري على "${widget.user.name}".')),
    ));
  }

  Future<void> _restampClaims() async {
    setState(() => _restamping = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AppStore>().restampUserClaims(widget.user.id);
    if (!mounted) return;
    setState(() => _restamping = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ??
          'أُعيد ختم صلاحيات "${widget.user.name}". يلزم أن يُحدِّث صفحته أو '
              'يخرج ويدخل ليسري المفعول.'),
      duration: const Duration(seconds: 8),
    ));
  }

  // ولا يُنادى إلا للتحوّل **إلى** موقوف الآن — راجع `active` في `build`:
  // زرّ إعادة التفعيل الفوري حُذف لأن الخادم يرفضه دائماً بعد هذه الجولة
  // (التوقيف يحذف حساب الدخول، فلا يبقى ما يُعاد تفعيله). التفعيل من جديد
  // يمرّ بتسجيلٍ جديد يُدمَج تلقائياً — لا بهذا الزرّ.
  Future<void> _suspendActive() async {
    setState(() => _busy = true);
    final error = await context.read<AppStore>().setUserStatus(widget.user, UserStatus.suspended);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final store = context.watch<AppStore>();
    final dept = u.departmentId != null ? store.departmentById(u.departmentId!) : null;
    final active = u.status == UserStatus.approved;
    final roleLabel = u.role == UserRole.custom
        ? (store.customRoles.where((r) => r.id == u.customRoleId).isEmpty
            ? 'دور مخصص'
            : store.customRoles.firstWhere((r) => r.id == u.customRoleId).name)
        : u.role.label;
    final deptLabel = u.role == UserRole.departmentManager
        ? u.departmentIds.map((id) => store.departmentById(id)?.name).whereType<String>().join('، ')
        : dept?.name;

    // ليست `ListTile`: أفعال الصف سبعة أزرار، و`ListTile` تشترط أن يتّسع لها
    // `trailing` في سطر واحد فترمي استثناءً على الجوال — وهذا ما كان يقع
    // فعلاً، فتظهر الشاشة مكسورة لمن فتحها من هاتفه. وهنا تنزل الأفعال تحت
    // الاسم على الشاشة الضيّقة بدل أن تُزاحمه.
    final actions = <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (active ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(u.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? AppColors.success : AppColors.textSecondary)),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 19),
            tooltip: 'تعديل الدور',
            onPressed: () => showDialog(context: context, builder: (_) => _EditRoleDialog(user: u)),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded, size: 19),
            tooltip: 'إرسال إشعار',
            onPressed: () => showDialog(context: context, builder: (_) => NotifyDialog(initialUsers: [u])),
          ),
          // إعادة ختم بصمات الدخول من سجل المستخدم.
          //
          // قواعد الخادم تحتكم إلى بطاقة الدخول لا إلى السجل. فمستخدم بطاقته
          // قديمة أو غير مختومة يرى منصة خالية تماماً رغم أن سجلّه سليم. هذا
          // الزر ينسخ السجل إلى البطاقة **دون تغيير دوره أو حالته أو إداراته**،
          // فهو علاج لا صلاحية جديدة.
          // استثناء تأكيد البريد الوزاري — لمن لا يملك بريداً وزارياً عاملاً.
          IconButton(
            icon: Icon(
              widget.user.emailVerificationExempt
                  ? Icons.mark_email_read_rounded
                  : Icons.mark_email_unread_outlined,
              size: 19,
              color: widget.user.emailVerificationExempt ? AppColors.success : null,
            ),
            tooltip: widget.user.emailVerificationExempt
                ? 'مستثنى من تأكيد البريد — اضغط لإعادة الشرط'
                : 'استثناء من شرط تأكيد البريد الوزاري',
            onPressed: _busy ? null : _toggleExempt,
          ),
          // صلاحيات فردية تعلو على الدور — وهي ما يجعل المنح «لأي مستخدم»
          // ممكناً دون تغيير دوره ولا مساس بزملائه فيه.
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              size: 19,
              color: u.permissionOverrides.isEmpty ? null : AppColors.accent,
            ),
            tooltip: u.permissionOverrides.isEmpty
                ? 'صلاحيات فردية لهذا الحساب'
                : 'لهذا الحساب ${u.permissionOverrides.length} استثناء صلاحيات',
            onPressed: () => showDialog(context: context, builder: (_) => UserPermissionsDialog(user: u)),
          ),
          IconButton(
            icon: _restamping
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_lock_outlined, size: 19),
            tooltip: 'إعادة ختم الصلاحيات (يُصلح حساباً لا يرى بياناته)',
            onPressed: _restamping ? null : _restampClaims,
          ),
          // إرسال رابط إعادة تعيين كلمة المرور نيابةً عنه.
          //
          // يحلّ الحالة التي لا يحلّها رابط شاشة الدخول: موظفٌ يقول «الرسالة
          // لا تصلني» فيتصل بمسؤول النظام. وهو يحلّها **بلا أن يعرف كلمة
          // مروره ولا أن يضبطها له** — فلا تمرّ كلمة مرور أحدٍ بأحد.
          IconButton(
            icon: _resetting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.password_rounded, size: 19),
            tooltip: 'أرسل له رابط إعادة تعيين كلمة المرور',
            onPressed: _resetting ? null : _sendPasswordReset,
          ),
          // إيقاف الحساب — لمن هو مفعَّل. ولا نظير له بالاتجاه المعاكس:
          //
          // التوقيف يحذف حساب الدخول (`setUserStatus` على الخادم)، فلا يبقى
          // ما «يُعاد تفعيله» بضغطة. من أُوقف يُسجَّل من جديد بنفس بريده
          // فيُسمح له فوراً، وتُنقل أعماله ومهامّه تلقائياً إلى حسابه
          // الجديد عند اعتماد ذلك التسجيل — لا بزرٍّ هنا كان سيُردّ دائماً.
          if (u.status == UserStatus.approved)
            IconButton(
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.block_rounded, size: 19),
              tooltip: 'إيقاف الحساب',
              onPressed: _busy ? null : _suspendActive,
            ),
          if (u.status == UserStatus.suspended)
            Tooltip(
              message: u.mergedIntoUid != null
                  ? 'دُمج مع حسابٍ جديد سُجِّل بالبريد نفسه — أعماله ومهامّه نُقلت إليه.'
                  : 'حُذف حساب دخوله عند التوقيف. ليعود، يُسجَّل من جديد بنفس '
                      'بريده — يُسمح له فوراً، وتُنقل أعماله ومهامّه تلقائياً '
                      'إلى حسابه الجديد عند اعتماد تسجيله.',
              child: Icon(
                u.mergedIntoUid != null ? Icons.merge_type_rounded : Icons.info_outline_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
          // الحذف النهائي — آخر الأفعال وأحمرُها، ولا يُعرض لمسؤول النظام
          // على نفسه (والخادم يرفضه كذلك).
          if (u.id != store.currentUser?.id)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined, size: 19, color: AppColors.danger),
              tooltip: 'حذف الحساب نهائياً (هو وحساب الدخول معاً)',
              onPressed: () =>
                  showDialog(context: context, builder: (_) => _DeleteUserDialog(user: u)),
            ),
    ];

    final identity = Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(u.name.isNotEmpty ? u.name.substring(0, 1) : '?',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(u.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '$roleLabel${(deptLabel != null && deptLabel.isNotEmpty) ? ' · $deptLabel' : ''} · ${u.email}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: AppSpace.xs),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: AppSpace.xs),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        );
      }),
    );
  }
}

/// إرسال إشعار (بريد و/أو واتساب) لمستخدم واحد (عبر زر الصف) أو لعدة
/// مستخدمين دفعة واحدة (عبر زر "إشعار جماعي" أعلى الشاشة).
class _RoleFields extends StatelessWidget {
  final UserRole role;
  final String? customRoleId;
  final String? departmentId;
  final List<String> departmentIds;
  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<String?> onCustomRoleChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<List<String>> onDepartmentIdsChanged;

  const _RoleFields({
    required this.role,
    required this.customRoleId,
    required this.departmentId,
    required this.departmentIds,
    required this.onRoleChanged,
    required this.onCustomRoleChanged,
    required this.onDepartmentChanged,
    required this.onDepartmentIdsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isManagerRole = role == UserRole.departmentManager;
    final needsSingleDept = role == UserRole.projectOfficer;
    final isCustom = role == UserRole.custom;
    // ــ «مدير مشروع» لا يُمنح بعد اليوم ــ
    //
    // يسقط من القائمة إلا لمن يحمله أصلاً: حسابٌ حيٌّ دورُه كذلك يجب أن
    // تُفتح شاشته بلا انهيار، وأن يبقى الدور مرئياً حتى يقرّر مسؤول النظام
    // تحويله. ومتى حُوِّل لم يعد يُختار.
    final selectableRoles = UserRole.values
        .where((r) => !r.isLegacy || r == role)
        .where((r) => r != UserRole.custom || store.customRoles.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<UserRole>(
          initialValue: role,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الدور'),
          items: selectableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
          onChanged: (v) => onRoleChanged(v ?? role),
        ),
        if (isCustom) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: customRoleId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الدور المخصص'),
            items: store.customRoles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
            onChanged: onCustomRoleChanged,
          ),
        ],
        // ــ حقلُ الإدارة لكلّ الأدوار إلا مديرَ الإدارة ــ
        //
        // كان يُعرض لدورين فقط، فالموظفُ الذي لم يختر إدارتَه عند التسجيل
        // لا سبيلَ إلى ضمّه إلى واحدة. وهي رؤيةُ مشاريع إدارته كلِّها،
        // فبقاؤه بلا إدارةٍ يعني منصّةً شبه فارغة أمامه.
        //
        // ومديرُ الإدارة وحده يُستثنى: إدارتُه **قائمةٌ** لا مفرد، وتُختار
        // أدناه بمربّعات — وعرضُ الحقلين معاً يجعل الاثنين يتنازعان.
        if (!isManagerRole) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: departmentId,
            isExpanded: true,
            // ومطلوبةٌ لمدير المشروع الموروث وحده — يُفحص عند الحفظ.
            decoration: InputDecoration(
                labelText: needsSingleDept ? 'الإدارة' : 'الإدارة (اختياري)'),
            items: [
              // و«بلا إدارة» خيارٌ صريح لا فراغ: مسؤولُ النظام والتنفيذي
              // بلا إدارةٍ بطبعهما، ومن أراد نزعَها يقولها لا يتركها.
              const DropdownMenuItem<String>(value: null, child: Text('بلا إدارة')),
              ...store.departments
                  .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
            ],
            onChanged: onDepartmentChanged,
          ),
        ],
        // مدير الإدارة قد يدير أكثر من إدارة واحدة، لذا يُختار له بمربعات
        // اختيار متعددة بدل قائمة منسدلة بخيار واحد.
        if (isManagerRole) ...[
          const SizedBox(height: 12),
          const Text('الإدارات (يمكن اختيار أكثر من إدارة)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(
              child: Column(
                children: store.departments
                    .map((d) => CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          value: departmentIds.contains(d.id),
                          title: Text(d.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          onChanged: (v) {
                            final next = List<String>.from(departmentIds);
                            if (v ?? false) {
                              next.add(d.id);
                            } else {
                              next.remove(d.id);
                            }
                            onDepartmentIdsChanged(next);
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// أيُّ إدارةٍ مفردة تُرسَل مع الدور — **قاعدةٌ واحدةٌ تُقاس وحدها**.
///
/// ــ العطلُ الذي أوجدها ــ
///
/// كانت مكتوبةً في موضع الإرسال شرطاً مضمَّناً:
/// `(needsSingleDept || role == custom) ? _departmentId : null`. فالموظفُ —
/// وهو أكثرُ الحسابات — يُرسل عنه `null` دائماً، والخادمُ يكتبها. فكلُّ
/// تعديلِ دورٍ على موظّف كان **يمحو إدارته صامتاً**.
///
/// وصارت: تُرسَل إدارةُ من إدارتُه مفردة، ولا تُرسَل لمدير الإدارة —
/// إدارتُه في القائمة لا في المفرد.
String? departmentIdForSubmit({required UserRole role, required String? departmentId}) =>
    role == UserRole.departmentManager ? null : departmentId;

/// نافذةُ تعديل الدور — **عامّةٌ ليُقاس ما تعرضه**.
typedef EditRoleDialog = _EditRoleDialog;

class _EditRoleDialog extends StatefulWidget {
  final AppUser user;
  const _EditRoleDialog({required this.user});

  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  late UserRole _role = widget.user.role;
  late String? _customRoleId = widget.user.customRoleId;
  late String? _departmentId = widget.user.departmentId;
  late List<String> _departmentIds = List<String>.from(widget.user.departmentIds);
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final isManagerRole = _role == UserRole.departmentManager;
    final needsSingleDept = _role == UserRole.projectOfficer;
    if (needsSingleDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    if (isManagerRole && _departmentIds.isEmpty) {
      setState(() => _error = 'الرجاء اختيار إدارة واحدة على الأقل');
      return;
    }
    if (_role == UserRole.custom && _customRoleId == null) {
      setState(() => _error = 'الرجاء اختيار الدور المخصص');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().setUserRole(
          widget.user,
          role: _role,
          customRoleId: _role == UserRole.custom ? _customRoleId : null,
          departmentId: departmentIdForSubmit(role: _role, departmentId: _departmentId),
          departmentIds: isManagerRole ? _departmentIds : null,
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث دور المستخدم')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل دور ${widget.user.name}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoleFields(
                role: _role,
                customRoleId: _customRoleId,
                departmentId: _departmentId,
                departmentIds: _departmentIds,
                onRoleChanged: (v) => setState(() => _role = v),
                onCustomRoleChanged: (v) => setState(() => _customRoleId = v),
                onDepartmentChanged: (v) => setState(() => _departmentId = v),
                onDepartmentIdsChanged: (v) => setState(() => _departmentIds = v),
              ),
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog();

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.employee;
  String? _customRoleId;
  String? _departmentId;
  List<String> _departmentIds = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isManagerRole = _role == UserRole.departmentManager;
    final needsSingleDept = _role == UserRole.projectOfficer;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء تعبئة جميع الحقول');
      return;
    }
    if (needsSingleDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    if (isManagerRole && _departmentIds.isEmpty) {
      setState(() => _error = 'الرجاء اختيار إدارة واحدة على الأقل');
      return;
    }
    if (_role == UserRole.custom && _customRoleId == null) {
      setState(() => _error = 'الرجاء اختيار الدور المخصص');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().adminCreateUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          role: _role,
          customRoleId: _role == UserRole.custom ? _customRoleId : null,
          departmentId: (needsSingleDept || _role == UserRole.custom) ? _departmentId : null,
          departmentIds: isManagerRole ? _departmentIds : null,
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
    return AlertDialog(
      title: const Text('إضافة مستخدم مباشرة (بدون طلب تسجيل)'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 12),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال (لواتساب)', hintText: '+9655xxxxxxx')),
              const SizedBox(height: 12),
              TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور المبدئية')),
              const SizedBox(height: 12),
              _RoleFields(
                role: _role,
                customRoleId: _customRoleId,
                departmentId: _departmentId,
                departmentIds: _departmentIds,
                onRoleChanged: (v) => setState(() => _role = v),
                onCustomRoleChanged: (v) => setState(() => _customRoleId = v),
                onDepartmentChanged: (v) => setState(() => _departmentId = v),
                onDepartmentIdsChanged: (v) => setState(() => _departmentIds = v),
              ),
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إضافة'),
        ),
      ],
    );
  }
}

/// مراجعة الحسابات الحاملة للدور الموروث «مدير مشروع» وتحويلها.
///
/// ــــ لماذا شاشةُ مراجعةٍ لا زرُّ «حوّل الجميع»؟ ــــ
///
/// لأن التحويل يمسّ حساباتٍ حيّة في وزارة. ومسؤول النظام يحتاج أن يرى، قبل
/// كل تحويل، **كم مشروعاً يقوده صاحبه فعلاً**: من يقود ثلاثة مشاريع يبقى
/// مديراً لها بعد التحويل، ومن لا يقود شيئاً يفقد صفةً لم تكن تقابل عملاً.
/// وزرٌّ واحد يفعل ذلك بالجملة يُخفي هذا الفرق تماماً.
class _LegacyRoleDialog extends StatefulWidget {
  const _LegacyRoleDialog();

  @override
  State<_LegacyRoleDialog> createState() => _LegacyRoleDialogState();
}

class _LegacyRoleDialogState extends State<_LegacyRoleDialog> {
  String? _busyUid;
  String? _error;

  Future<void> _convert(AppStore store, AppUser user) async {
    setState(() {
      _busyUid = user.id;
      _error = null;
    });
    final err = await store.convertLegacyOfficerToEmployee(user);
    if (!mounted) return;
    setState(() {
      _busyUid = null;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final legacy = store.legacyProjectOfficers;

    return AlertDialog(
      title: const Text('الدور الموروث: مدير مشروع'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'التحويل إلى «موظف» يُبقي كل عضويات المشاريع كما هي: قيادة المشروع '
                'تُقرأ من تسجيل الشخص مديراً عليه، لا من دوره في الهيكل.',
                style: TextStyle(fontSize: 12.5, height: 1.9, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (legacy.isEmpty)
                const Text('لم يبقَ حسابٌ بالدور الموروث.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              for (final u in legacy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700)),
                            Text(
                              'يقود ${store.projects.where((p) => p.managerUids.contains(u.id)).length} مشروعاً '
                              '· ${store.departmentById(u.departmentId ?? '')?.name ?? 'بلا إدارة'}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_busyUid == u.id)
                        const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        OutlinedButton(
                          onPressed: _busyUid != null ? null : () => _convert(store, u),
                          child: const Text('تحويل إلى موظف'),
                        ),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      ],
    );
  }
}

/// نافذة الحذف النهائي: تُحصي أولاً، ثم تسأل، ثم تحذف.
///
/// ــــ ثلاثة قرارات فيها، وكلٌّ منها لسبب ــــ
///
/// ١) **الإحصاء قبل الزرّ**: الحذف النهائي لا يُلغى بـ«تراجع». فلا يُعرض
///    زرُّه قبل أن يُقال بالضبط ما على هذا الحساب — كم مشروعاً يقود، وكم
///    عملاً عليه، وكم تحديثاً كتب.
///
/// ٢) **كتابة الاسم للتأكيد**: قائمة مئتَي موظف، وصفوفها متشابهة، وضغطةٌ
///    واحدة بالخطأ تمحو الحساب الخطأ. والخادم يفحص الاسم أيضاً — فالتأكيد
///    حارسٌ لا تجميل.
///
/// ٣) **الإيقاف معروضٌ بجانبه دائماً**: هو الخيار الصحيح في أغلب الحالات —
///    يمنع الدخول ويحفظ الأثر كاملاً. والحذف لمن لا سجلّ له يُحفظ.
class _DeleteUserDialog extends StatefulWidget {
  final AppUser user;
  const _DeleteUserDialog({required this.user});

  @override
  State<_DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<_DeleteUserDialog> {
  final _confirmCtrl = TextEditingController();
  UserDeletionReport? _report;
  String? _loadError;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<AppStore>().inspectUserForDeletion(widget.user.id);
      if (!mounted) return;
      setState(() => _report = r);
    } catch (e) {
      if (!mounted) return;
      // ولا يُعرض زرّ الحذف حين يخفق الإحصاء: الحذف بلا معرفة ما يمسّه هو
      // بالضبط ما بُنيت هذه النافذة لمنعه.
      setState(() => _loadError = e.toString());
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final store = context.read<AppStore>();
    final error = await store.deleteUserAccount(widget.user.id, _confirmCtrl.text);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حُذف حساب «${widget.user.name}» من المنصة ومن حساب الدخول معاً.')),
    );
  }

  Future<void> _suspend() async {
    setState(() => _deleting = true);
    final error =
        await context.read<AppStore>().setUserStatus(widget.user, UserStatus.suspended);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('أُوقف حساب «${widget.user.name}» — لا يستطيع الدخول، وأثره باقٍ كاملاً. '
          'وإن سُجِّل من جديد بنفس بريده، سيُسمح له فوراً وتُنقل أعماله إلى حسابه الجديد تلقائياً.'),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final nameMatches = _confirmCtrl.text.trim() == widget.user.name.trim();

    return AlertDialog(
      title: Text('حذف حساب «${widget.user.name}» نهائياً'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // النقطة التقنية التي يجهلها أكثر من يضغط «حذف»: محو السجل
              // وحده يترك حساب الدخول حيّاً، فيعود صاحبه بحسابٍ جديد.
              const _DeleteNote(
                icon: Icons.info_outline_rounded,
                color: AppColors.info,
                text: 'الحذف هنا يمحو سجل المستخدم **وحساب الدخول معاً**، فلا يبقى '
                    'قادراً على تسجيل الدخول. ولا يُلغى بعد تنفيذه.',
              ),
              const SizedBox(height: AppSpace.md),
              if (_loadError != null)
                _DeleteNote(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                  text: 'تعذّر إحصاء ارتباطات هذا الحساب، فلا يُعرض زرّ الحذف: '
                      'الحذف بلا معرفة ما يمسّه هو الخطر نفسه.\n$_loadError',
                )
              else if (r == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                const Text('ما على هذا الحساب:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpace.xs),
                _Stat(label: 'مشاريع يقودها', value: r.ledProjects.length),
                if (r.ledProjects.isNotEmpty)
                  _Names(names: [for (final p in r.ledProjects) p.label]),
                _Stat(label: 'مشاريع هو منفّذ فيها', value: r.memberProjects),
                _Stat(label: 'أعمال مُسنَدة إليه غير مغلقة', value: r.openWorks.length),
                if (r.openWorks.isNotEmpty)
                  _Names(names: [for (final w in r.openWorks) w.label]),
                _Stat(label: 'مهام مشاريع غير مغلقة', value: r.openTasks),
                _Stat(label: 'تحديثات يومية كتبها', value: r.dailyUpdates),
                _Stat(label: 'طلبات معلّقة قدّمها', value: r.pendingRequests),
                const SizedBox(height: AppSpace.md),
                if (!r.canDelete)
                  _DeleteNote(
                    icon: Icons.block_rounded,
                    color: AppColors.warning,
                    text: r.blockingReason!,
                  )
                else ...[
                  if (r.hasHistory)
                    const _DeleteNote(
                      icon: Icons.history_rounded,
                      color: AppColors.warning,
                      text: 'لهذا الحساب سجلّ عمل. والتحديثات اليومية لا تُحذف — '
                          'هي سجلّ الوزارة، ويبقى اسم كاتبها عليها. '
                          'والأولى في هذه الحالة **إيقاف** الحساب لا حذفه.',
                    ),
                  const SizedBox(height: AppSpace.md),
                  Text('للتأكيد اكتب اسم المستخدم كما هو مسجَّل: ${widget.user.name}'),
                  const SizedBox(height: AppSpace.xs),
                  TextField(
                    controller: _confirmCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'اسم المستخدم',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        // الإيقاف معروضٌ دائماً: هو الخيار الصحيح في أغلب الحالات، وعرضُه
        // هنا يجعل من فتح النافذة يخرج بالقرار الأصوب بلا أن يغلقها ويبحث.
        if (widget.user.status == UserStatus.approved)
          TextButton(
            onPressed: _deleting ? null : _suspend,
            child: const Text('أوقف الحساب بدل حذفه'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: (r != null && r.canDelete && nameMatches && !_deleting) ? _delete : null,
          child: Text(_deleting ? 'جارٍ الحذف…' : 'احذف نهائياً'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text('$value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: value > 0 ? AppColors.textPrimary : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

/// الأسماء لا الأعداد: «يقود ٣ مشاريع» لا يقول لمن يقرأها أيّها، ونقلُ
/// المسؤولية يحتاج أن يعرفها.
class _Names extends StatelessWidget {
  final List<String> names;
  const _Names({required this.names});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpace.md, bottom: 4),
      child: Text(
        names.map((n) => '«$n»').join('، '),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _DeleteNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _DeleteNote({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(text.replaceAll('**', ''), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
