import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/department.dart';
import '../models/department_section.dart';
import '../models/enums.dart';
import '../models/registration_policy.dart';
import '../theme/app_theme.dart';
import '../theme/brand.dart';
import '../widgets/ministry_logo.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole _requestedRole = UserRole.employee;
  String? _departmentId;
  String? _sectionId;
  String? _error;
  bool _busy = false;

  /// الأدوار التي يطلبها الموظف عند التسجيل.
  ///
  /// «موظف» أولاً وهو الافتراضي: أكثر المسجّلين موظفون، وهو **أدنى** الأدوار
  /// صلاحيةً — فمن سها عن تغيير الاختيار طلب أقلّها لا أكثرها.
  ///
  /// وهذا كله **طلب** لا منح: سجل المستخدم يُكتب دائماً بدور واحد ثابت
  /// (راجع `signUp`)، وقاعدة `/users/{uid}` تمنع المسجِّل من ترقية نفسه.
  /// الدور المطلوب يمرّ في طلب الاعتماد، ولا يصير دوراً فعلياً إلا بختم
  /// مسؤول النظام.
  static const _selectableRoles = [
    UserRole.employee,
    UserRole.departmentManager,
    UserRole.executiveViewer,
    UserRole.projectOfficer,
  ];

  /// يُنشأ مرة واحدة فقط. لو تُرِك داخل build() لأعاد FutureBuilder إطلاق
  /// استعلام Firestore مع كل setState (تغيير الدور، ظهور رسالة خطأ...) —
  /// وهو استهلاك بلا داعٍ يتضاعف مع مئات الموظفين أثناء فترة التسجيل.
  late final Future<List<Department>> _departmentsFuture = _loadDepartments();

  /// الأقسام تُحمَّل كاملةً مرة واحدة وتُصفّى محلياً بالإدارة المختارة: عددها
  /// عشرات لا آلاف، واستعلام جديد مع كل تغيير للإدارة استهلاك بلا فائدة.
  late final Future<List<DepartmentSection>> _sectionsFuture = _loadSections();

  /// سياسة التسجيل تُقرأ مرة واحدة: نطاقات البريد المقبولة تُعرض للموظف
  /// **قبل** أن يكتب بريده، فلا يُرفض طلبه بعد تعبئة النموذج كاملاً.
  RegistrationPolicy _policy = const RegistrationPolicy();

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final policy = await context.read<AppStore>().loadRegistrationPolicy();
    if (!mounted) return;
    setState(() => _policy = policy);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final needsDept = _requestedRole != UserRole.executiveViewer;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'الرجاء تعبئة جميع الحقول المطلوبة');
      return;
    }
    if (needsDept && _departmentId == null) {
      setState(() => _error = 'الرجاء اختيار الإدارة');
      return;
    }
    // فحص النطاق هنا لطفٌ بالموظف لا حراسة: الحراسة الفعلية على الخادم عند
    // الاعتماد، لأن أي فحص في المتصفح يمكن تجاوزه.
    if (!_policy.allows(_emailCtrl.text)) {
      setState(() => _error =
          'يلزم التسجيل ببريدك الوزاري (${_policy.domainsLabel}). البريد المُدخل خارج النطاقات المقبولة.');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().signUp(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          requestedRole: _requestedRole,
          requestedDepartmentId: needsDept ? _departmentId : null,
          requestedSectionId: needsDept ? _sectionId : null,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    // نجح التسجيل: أغلق شاشة التسجيل (كانت مُدرجة فوق الجذر عبر Navigator.push)
    // حتى تظهر شاشة "بانتظار الموافقة" التي يعرضها الجذر تلقائياً الآن.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final needsDept = _requestedRole != UserRole.executiveViewer;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        const MinistryLogo(size: 66),
                        const SizedBox(height: 10),
                        const Text(Brand.state,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const Text(Brand.ministry,
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.4)),
                        const SizedBox(height: 8),
                        Container(height: 2, width: 40, color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'سيتم إرسال طلب حسابك إلى مسؤول النظام للمراجعة، ولن تتمكن من الدخول إلا بعد الموافقة.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني الوزاري',
                        helperText: _policy.allowedEmailDomains.isEmpty
                            ? null
                            : 'يجب أن ينتهي بـ ${_policy.domainsLabel}',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم الجوال (لواتساب)', hintText: '+9655xxxxxxx'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
                    const SizedBox(height: 12),
                    TextField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      initialValue: _requestedRole,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الدور المطلوب'),
                      items: _selectableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                      onChanged: (v) => setState(() {
                        _requestedRole = v ?? _requestedRole;
                        _departmentId = null;
                        _sectionId = null;
                      }),
                    ),
                    if (needsDept) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<List<Department>>(
                        future: _departmentsFuture,
                        builder: (context, snapshot) {
                          final depts = snapshot.data ?? const [];
                          return DropdownButtonFormField<String>(
                            initialValue: _departmentId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'الإدارة'),
                            items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                            // تغيير الإدارة يُسقط القسم: قسمٌ من إدارة أخرى
                            // لا معنى له، وتركه يُرسل بياناتٍ متناقضة.
                            onChanged: (v) => setState(() {
                              _departmentId = v;
                              _sectionId = null;
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<DepartmentSection>>(
                        future: _sectionsFuture,
                        builder: (context, snapshot) {
                          final all = snapshot.data ?? const <DepartmentSection>[];
                          final mine = _departmentId == null
                              ? const <DepartmentSection>[]
                              : (all.where((x) => x.departmentId == _departmentId).toList()
                                ..sort((a, b) => a.order.compareTo(b.order)));
                          return DropdownButtonFormField<String?>(
                            initialValue: _sectionId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'القسم (اختياري)',
                              helperText: _departmentId == null
                                  ? 'اختر الإدارة أولاً'
                                  : (mine.isEmpty ? 'لا توجد أقسام مسجّلة لهذه الإدارة' : null),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('بدون قسم')),
                              ...mine.map((x) => DropdownMenuItem<String?>(
                                    value: x.id,
                                    child: Text(_sectionLabel(x, all), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: mine.isEmpty ? null : (v) => setState(() => _sectionId = v),
                          );
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('إرسال طلب التسجيل', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Department>> _loadDepartments() async {
    final snap = await FirebaseFirestore.instance.collection('departments').orderBy('name').get();
    return snap.docs.map(Department.fromDoc).toList();
  }

  Future<List<DepartmentSection>> _loadSections() async {
    final snap = await FirebaseFirestore.instance.collection('sections').get();
    return snap.docs.map(DepartmentSection.fromDoc).toList();
  }

  /// اسم القسم مسبوقاً بقسمه الأعلى إن كان فرعياً، فيميّز الموظف بين قسمين
  /// متشابهي الاسم تحت قسمين مختلفين.
  String _sectionLabel(DepartmentSection section, List<DepartmentSection> all) {
    if (section.parentId == null) return section.name;
    final parent = all.where((x) => x.id == section.parentId);
    return parent.isEmpty ? section.name : '${parent.first.name} ← ${section.name}';
  }
}
