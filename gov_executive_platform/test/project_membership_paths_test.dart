// مسارات كتابة عضوية المشروع — أيُّها محروس وأيُّها يكتب مباشرةً.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// في جولة فصل الدور عن قيادة المشروع صار **انسحاب المدير من مشروعه مرفوضاً**
// عند القاعدة، عمداً: طُلب أن يُسجَّل «من ألغى التعيين ومتى»، والكتابةُ
// المباشرة من العميل لا تمرّ بمن يكتب ذلك. فأُضيفت `revokeProjectManager`
// تمرّ بدالّة `setProjectTeam`، وكُتب اختبار قواعد يؤكّد رفض الكتابة
// المباشرة.
//
// **ونُسيت `leaveProject`.** فبقيت تكتب مباشرةً، فصار زرّ «انسحب من
// المشروع» يُرفض لكل مدير مشروع ليس مسؤول نظام — برسالة إنجليزية خام.
//
// ولم يصح شيء: اختبار القواعد يفحص **القاعدة** (وهي تعمل كما قُصد لها)،
// ولا اختبار واحد كان يمرّ على **أيّ مسارٍ في العميل يكتب العضوية**. وهذه
// الفجوة بالضبط ما يسدّه هذا الملف.
//
// وفحصٌ نصّي، ويُقال ذلك صراحةً: هذه الدوالّ تنادي Firestore وCloud
// Functions فلا تُستدعى في اختبار وحدة. فهو لا يثبت أن الانسحاب **يعمل**،
// بل يمنع أن يعود مسارٌ يكتب العضوية من وراء الحارس.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';

String storeSource() => File('lib/data/app_store.dart').readAsStringSync();

/// جسمُ دالّةٍ بعينها، من توقيعها إلى التي تليها.
///
/// ولا يُفحص الملف كله: `_writeMembership` مذكورة فيه بحقّ — داخل
/// `_writeTeam` نفسها — فالبحث العام يمرّ دائماً ولا يفحص شيئاً.
String bodyOf(String name) {
  final src = storeSource();
  final start = src.indexOf(name);
  expect(start, greaterThan(0), reason: 'لم تُعثر الدالّة $name');
  final next = src.indexOf('\n  /// ', start);
  return src.substring(start, next > start ? next : src.length);
}

void main() {
  group('الانسحاب من المشروع يمرّ بالمسار المحروس', () {
    test('leaveProject تنادي _writeTeam', () {
      expect(
        bodyOf('Future<String?> leaveProject('),
        contains('_writeTeam('),
        reason: 'الانسحاب يجب أن يمرّ بالمسار الذي يفحص ويُسجّل',
      );
    });

    // وهذا هو الشرط الحقيقي: لو نادت الاثنين لَبقيت الكتابة المباشرة قائمة
    // ومرّ الاختبار الأول وهو لا يفحص شيئاً.
    test('ولا تكتب العضوية مباشرةً', () {
      expect(
        bodyOf('Future<String?> leaveProject('),
        isNot(contains('_writeMembership(')),
        reason: 'الكتابة المباشرة هي ما ترفضه القاعدة على غير مسؤول النظام',
      );
    });

    test('وجارتها في البطاقة تفعل الشيء نفسه', () {
      final body = bodyOf('Future<String?> setProjectMemberRole(');
      expect(body, contains('_writeTeam('));
      expect(body, isNot(contains('_writeMembership(')));
    });

    // وتعيينُ المدير المفرد كذلك: توثيقُه يقول «مسؤول النظام فقط»، والقولُ
    // ليس فحصاً — فلو نودي من مسارٍ آخر لَرُفض كما رُفض الانسحاب.
    test('وتعيين المدير المفرد كذلك', () {
      final body = bodyOf('Future<void> setProjectManager(');
      expect(body, contains('_writeTeam('));
      expect(body, isNot(contains('_writeMembership(')));
    });

    // `_writeMembership` تبقى موجودة — يستعملها `_writeTeam` نفسه.
    test('و_writeTeam هي من تكتب مباشرةً', () {
      expect(bodyOf('Future<void> _writeTeam('), contains('_writeMembership('));
    });

    // وتسجيلُ المرء نفسه **منفّذاً** يكتب مباشرةً بحقّ: القاعدة تسمح به
    // صراحةً (`isSelfMembershipChange`)، وتحويلُه إلى الدالّة يُبطل ميزةً
    // مقصودة — أن ينضمّ الموظف لمشروع إدارته بلا وسيط.
    test('وانضمامُ المرء منفّذاً يبقى مباشراً عمداً', () {
      expect(bodyOf('Future<String?> joinProject('), contains('_writeMembership('));
    });
  });

  group('رسالة المنع تُقال بالعربية وتدلّ على العلاج', () {
    test('منعُ الصلاحية يُترجَم', () {
      final msg = describeWriteFailure(
        Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.'),
      );
      expect(msg, isNot(contains('permission-denied')));
      expect(msg, contains('بطاقة الدخول'));
      expect(msg, contains('إعادة ختم الصلاحيات'));
    });

    // ولا يُبتلع كل خطأ في رسالةٍ واحدة: خطأ الشبكة ليس منعَ صلاحية، ومن
    // يُقال له «راجع صلاحياتك» وهو مقطوع الاتصال يبحث في المكان الخطأ.
    test('وما ليس منعاً يبقى كما هو', () {
      final msg = describeWriteFailure(Exception('network request failed'));
      expect(msg, contains('network request failed'));
      expect(msg, isNot(contains('بطاقة الدخول')));
    });
  });
}
