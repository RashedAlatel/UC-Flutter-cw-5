// حمولةُ سطر التدقيق — كما تصل إلى Firestore، لا كما نظنّها.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// قاعدةُ `auditLog` تشترط `request.resource.data.timestamp == request.time`
// — أي وقتَ **الخادم**. وكان التطبيق يكتب `Timestamp.fromDate(DateTime
// .now())`، أي ساعةَ **الجهاز**. ولا يتطابق الرقمان أبداً ولو ضُبطت الساعة
// إلى الميلي‑ثانية.
//
// فرُدّ كلُّ سطرٍ يكتبه المتصفّح — لا سطرٌ بعينه — منذ لحظة نشر القاعدة.
// وظهر ذلك للمستخدم رسالةً كاذبة: «تعذر حذف المشروع» على حذفٍ تمّ فعلاً.
//
// ــــ ولماذا لم يمسكه اختبار القواعد ــــ
//
// `test_rules/audit_log.rules.test.mjs` يمرّ، لكنه يبني بيانَه بنفسه
// بـ`serverTimestamp()`. فهو أثبت أن **القاعدة** صحيحة، ولم يسأل قط: **هل
// يكتب التطبيقُ ما تشترطه القاعدة؟** والحدُّ بين الاثنين هو موضع العطل.
//
// وهذا الملف يقف على ذلك الحدّ من جهة التطبيق: يفحص الحمولةَ التي يبنيها
// النموذج نفسه — لا نسخةً منها — ويشترط أن يكون الوقتُ ختمَ خادمٍ لا قيمةً
// محسوبة هنا.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/audit_log_entry.dart';
import 'package:gov_exec_platform/models/change_type.dart';

AuditLogEntry entry({Map<String, dynamic>? before, Map<String, dynamic>? after}) => AuditLogEntry(
      id: 'a1',
      userName: 'مسؤول النظام',
      action: 'حذف مشروع',
      details: 'حذف المشروع "س" حذفاً نهائياً',
      timestamp: DateTime(2020, 1, 1),
      type: ChangeType.hardDelete,
      actorUid: 'u-admin',
      targetType: 'project',
      targetId: 'p1',
      targetName: 'س',
      before: before,
      after: after,
    );

void main() {
  group('الوقت يأتي من الخادم', () {
    test('الحمولة تحمل ختمَ الخادم', () {
      expect(entry().toMap()['timestamp'], isA<FieldValue>());
    });

    // الشرط المقابل، وهو ما يبيت العطل: أيُّ قيمةٍ محسوبةٍ هنا تُردّ.
    test('ولا تحمل وقتاً محسوباً في الجهاز', () {
      final t = entry().toMap()['timestamp'];
      expect(t, isNot(isA<Timestamp>()));
      expect(t, isNot(isA<DateTime>()));
    });

    // وحقلُ الصنف يبقى قابلاً للقراءة: الشاشة تعرضه بعد `fromDoc`.
    test('وحقل الصنف يبقى تاريخاً يُقرأ ويُعرض', () {
      expect(entry().timestamp, DateTime(2020, 1, 1));
    });
  });

  group('وبقية ما تشترطه القاعدة', () {
    final map = entry().toMap();

    // `keys().hasAll(['userName','action','details','type'])`
    test('الحقول الأربعة المطلوبة موجودة', () {
      for (final key in ['userName', 'action', 'details', 'type']) {
        expect(map.containsKey(key), isTrue, reason: 'الحقل $key مفقود');
      }
    });

    // `type is string && type.size() > 0`
    test('والنوع نصٌّ غير فارغ', () {
      expect(map['type'], isA<String>());
      expect((map['type'] as String).isNotEmpty, isTrue);
    });

    // ولكل قيمة في التعداد، لا للنوع المُختار في هذا الاختبار وحده: نوعٌ
    // مفتاحُه فارغ يُردّ سطرُه، ولا يظهر ذلك إلا يوم يُستعمل.
    test('ولا مفتاحَ فارغ في التعداد كلِّه', () {
      for (final t in ChangeType.values) {
        expect(t.key.isNotEmpty, isTrue, reason: 'النوع ${t.name} بلا مفتاح');
      }
    });

    // `actorUid == request.auth.uid` — والمفتاح يُكتب حين يوجد الفاعل.
    test('والفاعل مكتوبٌ بمعرّفه', () {
      expect(map['actorUid'], 'u-admin');
    });
  });

  group('و«قبل/بعد» لا تكسر الحمولة', () {
    test('تُحذف مفاتيحُها حين لا فرق', () {
      final map = entry().toMap();
      expect(map.containsKey('before'), isFalse);
      expect(map.containsKey('after'), isFalse);
    });

    test('وتُكتب حين يوجد فرق', () {
      final map = entry(before: {'name': 'أ'}, after: {'name': 'ب'}).toMap();
      expect(map['before'], {'name': 'أ'});
      expect(map['after'], {'name': 'ب'});
    });
  });
}
