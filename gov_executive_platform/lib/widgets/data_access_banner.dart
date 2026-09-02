import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/role_permissions.dart';
import '../theme/app_theme.dart';

/// لافتة تُعلن أن الخادم رفض قراءة بعض بيانات المستخدم.
///
/// كانت مستمعات Firestore بلا معالج خطأ، فرفض الصلاحية يعود صامتاً وتبقى
/// الشاشات فارغة بلا سبب — فيظن المستخدم أن لا بيانات لديه بينما هي محجوبة
/// عنه. هذه اللافتة تقول الحقيقة، وتسمّي الصلاحية الناقصة إن عُرفت، وتُصلح
/// اختلاف بطاقة الدخول بضغطة واحدة.
class DataAccessBanner extends StatefulWidget {
  const DataAccessBanner({super.key});

  @override
  State<DataAccessBanner> createState() => _DataAccessBannerState();
}

class _DataAccessBannerState extends State<DataAccessBanner> {
  /// الصلاحيات الممنوحة في الإعدادات والغائبة عن البطاقة. تُقرأ من البطاقة
  /// نفسها (عملية غير متزامنة) فتُحفظ في الحالة بدل إعادة قراءتها كل إطار.
  List<RolePermission> _pending = const [];

  bool _syncing = false;
  String? _syncError;

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    final error = await context.read<AppStore>().syncMyClaims();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncError = error;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final store = context.read<AppStore>();
    if (!store.hasPermissionErrors) return;
    final pending = await store.pendingPermissions();
    if (!mounted) return;
    setState(() => _pending = pending);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.hasDataErrors) return const SizedBox.shrink();

    // ــ اللافتةُ لا تقرّر، بل تعرض قراراً يُقاس ــ
    //
    // صنفُ العطل ونصُّه في [AppStore.describeDataErrors] — دالّةٌ نقيّة
    // تُقلب قواعدُها بطفرة. وكانت الأصنافُ الأربعة تُقال جملةً واحدة
    // («تعذّر تحميل بعض البيانات») فلا يعرف أحدٌ أيَّها وقع ولا ما يفعله.
    final report = AppStore.describeDataErrors(store.dataErrors, store.docCounts);
    final permissions = store.hasPermissionErrors;

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
                  report.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.danger),
                ),
                const SizedBox(height: 6),
                Text(
                  report.body,
                  style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
                ),
                // إرشاد صريح بدل رسالة عامة: أكثر أسباب الرفض شيوعاً أن
                // مسؤول النظام منح صلاحية ولم تصل بطاقة دخول المستخدم بعد.
                // وحين نعرف الصلاحية الناقصة بعينها نسمّيها — فاسمها أنفع
                // للمستخدم ولمسؤول النظام من اسم مجموعة بيانات.
                if (permissions) ...[
                  const SizedBox(height: 6),
                  Text(
                    _pending.isEmpty
                        ? 'إن كان مسؤول النظام قد منحك صلاحية حديثاً فقد لا تكون بطاقة دخولك '
                            'حُدِّثت بعد — اضغط «مزامنة صلاحيات حسابي» أدناه.'
                        : 'صلاحية ${_pending.map((p) => '«${p.label}»').join(' و')} ممنوحة لدورك '
                            'لكنها لم تصل بطاقة دخولك بعد — اضغط «مزامنة صلاحيات حسابي» أدناه.',
                    style: const TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                // زر إصلاح لا شاشة تشخيص: أُزيلت شاشة التشخيص بطلب مسؤول
                // النظام، ولا يجوز أن يذهب معها **طريق الخروج** من العطل.
                // فبقي الفعل نفسه في ضغطة واحدة مكان الزر الذي كان يقود إليها.
                OutlinedButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(_syncing ? 'جارٍ المزامنة…' : 'مزامنة صلاحيات حسابي'),
                ),
                // ــ وطريقُ الخروج الثاني يُقال ــ
                //
                // ختمُ الخادم قد يُخفق هو نفسه (دالّةٌ غير منشورة، أو شبكة)
                // — وهو ما وقع. وحينها يبقى للمستخدم بابٌ واحد لا يحتاج
                // الخادمَ: رمزٌ جديد بخروجٍ ودخول.
                if (report.kind == DataTrouble.claims) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'وإن لم تُجدِ المزامنة فسجّل خروجاً ثم دخولاً — يُجدَّد بها '
                    'رمزُ دخولك من أصله.',
                    style: TextStyle(fontSize: 12, height: 1.8, color: AppColors.textSecondary),
                  ),
                ],
                if (_syncError != null) ...[
                  const SizedBox(height: 6),
                  Text('تعذّرت المزامنة: $_syncError',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
