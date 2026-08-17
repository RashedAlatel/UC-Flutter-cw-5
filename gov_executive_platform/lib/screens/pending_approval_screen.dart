import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _checkingBootstrap = true;
  bool _bootstrapNeeded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBootstrap();
  }

  Future<void> _checkBootstrap() async {
    final store = context.read<AppStore>();
    if (store.currentUser?.status != UserStatus.pending) {
      setState(() => _checkingBootstrap = false);
      return;
    }
    final needed = await store.checkBootstrapNeeded();
    if (!mounted) return;
    setState(() {
      _bootstrapNeeded = needed;
      _checkingBootstrap = false;
    });
  }

  Future<void> _becomeFirstAdmin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppStore>().bootstrapFirstAdmin();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final status = user?.status ?? UserStatus.pending;

    final (icon, color, title, message) = switch (status) {
      UserStatus.pending => (
          Icons.hourglass_top_rounded,
          AppColors.warning,
          'حسابك بانتظار الموافقة',
          'تم إرسال طلب تسجيلك إلى مسؤول النظام. سيتم تفعيل حسابك بعد المراجعة والموافقة، وستتمكن حينها من الدخول إلى المنصة تلقائياً.',
        ),
      UserStatus.rejected => (
          Icons.block_rounded,
          AppColors.danger,
          'تم رفض طلب التسجيل',
          'للاستفسار عن سبب الرفض، يرجى التواصل مع مسؤول النظام في وزارتك.',
        ),
      UserStatus.suspended => (
          Icons.pause_circle_outline_rounded,
          AppColors.textSecondary,
          'الحساب موقوف حالياً',
          'تم إيقاف هذا الحساب من قبل مسؤول النظام. يرجى التواصل معه لإعادة التفعيل.',
        ),
      UserStatus.approved => (
          Icons.check_circle_outline_rounded,
          AppColors.success,
          'تم تفعيل الحساب',
          'جارٍ تحميل المنصة...',
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.7), textAlign: TextAlign.center),
                    if (status == UserStatus.rejected && user != null) _ResolutionNote(uid: user.id),
                    if (status == UserStatus.pending && !_checkingBootstrap && _bootstrapNeeded) ...[
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            const Text('لا يوجد مسؤول نظام مُفعّل في المنصة بعد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 6),
                            const Text('يمكنك تعيين نفسك كأول مسؤول نظام لمرة واحدة فقط، ثم إدارة باقي الحسابات من لوحة التحكم.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            if (_error != null) Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : _becomeFirstAdmin,
                                icon: _busy
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.admin_panel_settings_rounded, size: 18),
                                label: const Text('تعيين نفسي كأول مسؤول نظام'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => store.logout(),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('تسجيل الخروج'),
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
}

class _ResolutionNote extends StatelessWidget {
  final String uid;
  const _ResolutionNote({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('approvalRequests')
          .where('requestedByUid', isEqualTo: uid)
          .where('type', isEqualTo: 'registration')
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs;
        if (docs == null || docs.isEmpty) return const SizedBox.shrink();
        final note = docs.first.data()['resolutionNote'] as String?;
        if (note == null || note.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: Text(note, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ),
        );
      },
    );
  }
}
