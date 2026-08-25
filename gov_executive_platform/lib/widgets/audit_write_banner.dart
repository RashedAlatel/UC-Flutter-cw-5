// لافتة تُعلن أن إجراءً وقع ولم يُكتب سطرُه في سجل التدقيق.
//
// ــــ لماذا لافتةٌ لا رسالةُ خطأ ــــ
//
// حين تُردّ كتابةُ السطر يكون الفعل قد وقع فعلاً: المشروع حُذف، والعمل
// عُدّل. فقولُ «فشل الحذف» كذبٌ يدفع المستخدم إلى إعادة المحاولة على شيءٍ لم
// يعد موجوداً — وهو ما وقع بالضبط حين شُدّدت قاعدة `auditLog` وبقي التطبيق
// يكتب ساعةَ الجهاز.
//
// وابتلاعُ الرفض بصمتٍ أسوأ: سطرٌ يسقط من سجلٍّ حكومي بلا أن يعلم به أحد
// يناقض ما بُني `tool/test/audit_coverage_test.sh` كلُّه لأجله. فالإجراء
// يمضي، واللافتة تقول إن أثره لم يُكتب — ولا توقف شيئاً.
//
// ولا وُسِّعت `DataAccessBanner`: توثيقُها يقول صراحةً إنها لافتةُ **رفض
// القراءة**، وحشرُ حالةِ كتابةٍ فيها يجعل اسمها يكذب.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

class AuditWriteBanner extends StatelessWidget {
  const AuditWriteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final failure = store.auditWriteFailure;
    if (failure == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 19, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تمّ الإجراء، ولم يُكتب سطرُه في سجل التدقيق',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 4),
                // السببُ الخام يُعرض كما هو: «permission-denied» يُقرأ رفضَ
                // صلاحية، وانقطاعُ الشبكة يُقرأ انقطاعاً — والفرق يغيّر ما
                // يفعله مسؤول النظام تالياً.
                Text(
                  failure,
                  style: const TextStyle(fontSize: 11.5, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'إخفاء',
            visualDensity: VisualDensity.compact,
            onPressed: () => context.read<AppStore>().dismissAuditWriteFailure(),
          ),
        ],
      ),
    );
  }
}
