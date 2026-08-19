import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../screens/account_diagnostics_screen.dart';
import '../theme/app_theme.dart';

/// لافتة تُعلن أن الخادم رفض قراءة بعض بيانات المستخدم.
///
/// كانت مستمعات Firestore بلا معالج خطأ، فرفض الصلاحية يعود صامتاً وتبقى
/// الشاشات فارغة بلا سبب — فيظن المستخدم أن لا بيانات لديه بينما هي محجوبة
/// عنه. هذه اللافتة تقول الحقيقة، وتقود إلى شاشة «تشخيص حسابي» التي تكشف
/// الاختلاف بين سجل المستخدم وبطاقة دخوله وتُصلحه بضغطة.
class DataAccessBanner extends StatelessWidget {
  const DataAccessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.hasDataErrors) return const SizedBox.shrink();

    final permissions = store.hasPermissionErrors;
    final names = store.dataErrors.keys.take(4).join('، ');
    final more = store.dataErrors.length > 4 ? ' و${store.dataErrors.length - 4} غيرها' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissions
                      ? 'صلاحيات حسابك غير مكتملة — بعض بياناتك محجوبة عنك'
                      : 'تعذّر تحميل بعض البيانات من الخادم',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.danger),
                ),
                const SizedBox(height: 6),
                Text(
                  permissions
                      ? 'ما تراه الآن ناقص، وليس فارغاً لعدم وجود بيانات. رُفضت قراءة: $names$more.'
                      : 'رُفضت قراءة: $names$more. تأكد من اتصال الشبكة ثم أعد المحاولة.',
                  style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountDiagnosticsScreen()),
                  ),
                  icon: const Icon(Icons.medical_information_outlined, size: 16),
                  label: const Text('تشخيص حسابي'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
