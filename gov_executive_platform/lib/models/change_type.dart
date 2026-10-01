/// أنواع التغيير في سجل التدقيق — وبها تقع التصفية.
///
/// ــــ لماذا تعدادٌ لا نصٌّ حرّ؟ ــــ
///
/// كان السجل نصّاً عربياً حرّاً في حقلَي `action` و`details`. وهو يُقرأ
/// سطراً سطراً، ولا يُصفّى: من أراد «كل عمليات الحذف في الشهر الماضي» لا
/// سبيل له إلا القراءة من الأعلى.
///
/// وطلبتَ **تسجيل كل تغيير** — ومعه **حقل تصفيةٍ بنوعه**. والاثنان معاً
/// لا أحدهما: سجلٌّ يحصي كل شيء بلا تصفية سجلٌّ لا يُقرأ.
///
/// والمفاتيح قصيرةٌ ثابتة تُكتب في Firestore، والأسماء العربية للعرض
/// وحده — فتغييرُ اسمٍ لا يُبطل سطراً مكتوباً.
library;

enum ChangeType {
  /// إنشاء سجلٍّ جديد: مشروع، عمل، مهمة، تحديث يومي…
  create$('create', 'إنشاء'),

  /// تعديل بيانات سجلٍّ قائم — وهو ما يحمل «قبل/بعد» غالباً.
  update$('update', 'تعديل'),

  /// حذفٌ منطقي يمكن التراجع عنه.
  softDelete('softDelete', 'حذف منطقي'),

  /// استعادةُ ما حُذف منطقياً — لمسؤول النظام وحده.
  restore('restore', 'استعادة'),

  /// حذفٌ نهائي لا رجعة فيه.
  hardDelete('hardDelete', 'حذف نهائي'),

  /// تحويل مشروعٍ إلى عمل أو العكس.
  convert('convert', 'تحويل'),

  /// تغييرٌ في العضوية أو الإسناد: فريق المشروع، مسؤول العمل…
  assignment('assignment', 'إسناد وعضوية'),

  /// البتّ في طلب: اعتماد أو رفض.
  approval('approval', 'اعتماد ورفض'),

  /// ما يمسّ الحسابات والصلاحيات والأدوار.
  account('account', 'حسابات وصلاحيات'),

  /// إرسال بريدٍ أو إشعار.
  notification('notification', 'مراسلات'),

  /// إعداداتُ المنصة وتقاريرها.
  settings('settings', 'إعدادات وتقارير'),

  /// ما لا يقع تحت ما سبق — وهو ما تحمله السطور القديمة كلُّها.
  other('other', 'أخرى');

  final String key;
  final String label;
  const ChangeType(this.key, this.label);

  /// يقرأ النوع من مفتاحه — ويردّ [other] لما لا يُعرف.
  ///
  /// ولا يُرمى استثناء: السطور المكتوبة قبل هذا التعداد لا تحمل الحقل
  /// إطلاقاً، وسطرٌ بنوعٍ مجهول أولى أن يُعرض تحت «أخرى» من أن يُسقط
  /// السجلَّ كلَّه عن الشاشة.
  static ChangeType fromKey(String? key) {
    for (final t in ChangeType.values) {
      if (t.key == key) return t;
    }
    return ChangeType.other;
  }
}

/// ما تغيّر بين حالتين — **الحقول المتغيّرة وحدها**.
///
/// ــــ لماذا لا يُحفظ المستند كاملاً مرّتين؟ ــــ
///
/// مستندُ مشروعٍ فيه عشرون حقلاً. وحفظُه كاملاً قبلَ التغيير وبعده يُضخّم
/// كل سطرٍ في السجل، **ويُخفي ما تغيّر فعلاً** بين ثمانية عشر حقلاً لم
/// تتغيّر. فمن يفتح السطر ليعرف «ماذا فعل» يقرأ جدولين متطابقين تقريباً.
///
/// فتُحسب الفروق هنا، وتُحفظ الخريطتان مقصورتين على المفاتيح المتغيّرة.
/// ويُعاد `null` حين لا يتغيّر شيء — فلا يُكتب سطرُ تعديلٍ لم يُعدَّل فيه
/// شيء، وهو ما يقع كثيراً حين يفتح المستخدم نموذجاً ويحفظه بلا تغيير.
({Map<String, dynamic> before, Map<String, dynamic> after})? diffMaps(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final changedBefore = <String, dynamic>{};
  final changedAfter = <String, dynamic>{};

  // اتحادُ المفاتيح لا مفاتيحُ إحداهما: الحقلُ الذي أُضيف والحقلُ الذي
  // أُزيل كلاهما تغييرٌ يُسجَّل.
  for (final key in {...before.keys, ...after.keys}) {
    final a = before[key];
    final b = after[key];
    if (_same(a, b)) continue;
    changedBefore[key] = a;
    changedAfter[key] = b;
  }

  if (changedBefore.isEmpty) return null;
  return (before: changedBefore, after: changedAfter);
}

/// مقارنةٌ تفهم القوائم والخرائط — لا `==` وحدها.
///
/// قوائمُ العضوية (`managerUids` و`executorUids`) تُبنى جديدةً في كل قراءة،
/// فـ`==` عليها تُرجع `false` دائماً ولو لم يتغيّر عضو. فلولا هذا لَامتلأ
/// السجل بـ«تعديلات» لم تقع.
bool _same(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_same(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}
