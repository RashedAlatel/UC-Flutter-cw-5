/// أسبوعُ العمل في الوزارة، والعطلُ الرسميّة.
///
/// ــــ ولماذا وحدةٌ وحدَها ــــ
///
/// لأنّ السؤال «أهذا يومُ عمل؟» يُسأل في خمسة مواضع: التقويمُ يصبغ به
/// اليومَ، وعدُّ «لم يسجّل» يتخطّى به العطل، والتقريرُ الأسبوعيُّ يقسم به،
/// والشهريُّ كذلك، وشاشةُ الموظّف تقول به «اليومُ عطلة».
///
/// ولو تكرّر الجوابُ في كلّ موضعٍ لَانحرف: يكفي أن يُنسى تسجيلُ عطلةٍ في
/// أحدها. وقد وقع مثلُه في هذه المنصة مرّتين — في تعريف «متأخر» وفي حساب
/// الإدارات.
///
/// ــــ والجمعةُ والسبتُ عطلةُ الأسبوع ــــ
///
/// أيامُ العمل الأحدُ إلى الخميس، وهو قرارُ مسؤول النظام. **وبلا هذا يصير
/// كلُّ جمعةٍ وسبتٍ غياباً جماعيّاً** في التقارير: مئتا موظّفٍ يتغيّبون
/// يومين في كلّ أسبوع.
library;

/// نظيرةُ `isWorkingDay` في `functions/src/status_scope.ts`.
///
/// ومكتوبةٌ مرّتين بلغتين — لا مفرّ: الخادمُ يفحص عند الكتابة، والشاشةُ
/// تصبغ التقويمَ قبل أن تسأل الخادم. ويحرس تطابقَهما اختبارُ
/// `work_week_test.dart` الذي يقيس الأيامَ نفسَها التي يقيسها
/// `status_scope.test.mjs`.
class WorkWeek {
  /// أيامُ نهاية الأسبوع بترقيم Dart: الجمعةُ ٥ والسبتُ ٦.
  static const Set<int> weekend = {DateTime.friday, DateTime.saturday};

  /// مفتاحُ اليوم `yyyy-mm-dd` — صيغةُ التخزين نفسُها.
  static String keyOf(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// يومٌ بلا وقت — مفتاحُ المقارنة.
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// أهذا يومُ عملٍ في الوزارة؟
  ///
  /// و[holidayKeys] مفاتيحُ الأيام المسجّلة عطلاً رسميّة.
  static bool isWorkingDay(DateTime day, Set<String> holidayKeys) {
    if (holidayKeys.contains(keyOf(day))) return false;
    return !weekend.contains(day.weekday);
  }

  /// أهذا يومُ نهايةِ أسبوع؟ — يُفرَّق عن العطلة الرسميّة في التقويم.
  ///
  /// والفرقُ يُقال للقارئ: «الجمعة» ليست «عيد الفطر». ولو جُمعا في لونٍ
  /// واحدٍ لَبدا شهرُ رمضان كأنّه كلُّه عطلةٌ رسميّة.
  static bool isWeekend(DateTime day) => weekend.contains(day.weekday);

  /// أيامُ العمل بين تاريخين — الطرفان داخلان.
  ///
  /// وهي مقامُ كلّ نسبةٍ في التقارير: «حضر ١٨ من ٢٢ يومَ عمل». ولو قُسم على
  /// أيام الشهر كلِّها لَظهر أكثرُ الموظّفين دون السبعين بالمئة أبداً.
  static List<DateTime> workingDaysBetween(
    DateTime from,
    DateTime to,
    Set<String> holidayKeys,
  ) {
    final days = <DateTime>[];
    var cursor = dayOnly(from);
    final last = dayOnly(to);
    // حدٌّ أعلى مكتوب: مدىً مقلوبٌ أو خطأٌ في التاريخ كان سيدور بلا نهاية
    // ويُجمّد الواجهة — وهو نمطُ الحارس في `DepartmentSection.levelIn`.
    var guard = 0;
    while (!cursor.isAfter(last) && guard++ < 3660) {
      if (isWorkingDay(cursor, holidayKeys)) days.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }
}
