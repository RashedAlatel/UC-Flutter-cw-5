#!/usr/bin/env bash
#
# حارس بوابات الاعتماد في الدالة الخلفية.
#
# ثلاث بوابات محصورة بمسؤول النظام (تسجيل عضو / تعديل موعد نهائي / إرسال
# بريد)، ورابعةٌ أضيقُ منها: **تعديل الطلب قبل اعتماده**. وهذه كلها في
# `functions/src/index.ts` — ملفٌ لا يقرؤه `flutter test` ولا `flutter analyze`
# ولا يوجد له مجموعة اختبارات في هذا المشروع.
#
# فهذا فحصٌ نصّي، وهو أضعف من اختبار حقيقي ويُقال ذلك صراحةً: لا يثبت أن
# الحراسة **تعمل**، بل يمنع أن تُحذف بصمت في تعديل لاحق. وقد سقطت حراسةٌ
# بهذه الطريقة من قبل (قائمة حزم Firebase)، فهذا النمط قائم في المنصة.
#
# الاستخدام:  ./tool/test/approval_gates_test.sh
set -uo pipefail

cd "$(dirname "$0")/../.."

SRC="functions/src/index.ts"
PASS=0
FAIL=0

want() {
  local name="$1" pattern="$2"
  if grep -q "$pattern" "$SRC"; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      لم يُعثر على: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

# نظيرُها لملفٍ آخر: الإجراء الجماعي في العميل، وهو الطرف الذي قد يلتفّ على
# البوابة لو نادى دالّة الإرسال مباشرةً بدل `sendOrRequestNotification`.
want_in() {
  local file="$1" name="$2" pattern="$3"
  if grep -q "$pattern" "$file"; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      لم يُعثر في $file على: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

# ونظيرُ `want_in` بنصٍّ حرفيّ لا تعبيرٍ نمطي.
#
# وسببُه أن `[` و`(` و`.` محارفُ معنى في `grep`، فنمطٌ فيه قائمةٌ حرفية
# (`["tasks", "risks"]`) يُقرأ صنفَ محارف ولا يطابق نفسه — فيسقط الحارس على
# شيفرةٍ صحيحة، أو أسوأ: يمرّ على شيفرةٍ حُذفت.
want_fixed_in() {
  local file="$1" name="$2" pattern="$3"
  if grep -F -q "$pattern" "$file"; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      لم يُعثر في $file على: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

# ونقيضُها: نمطٌ يجب ألّا يوجد.
reject_in() {
  local file="$1" name="$2" pattern="$3"
  if grep -q "$pattern" "$file"; then
    echo "  ✗ $name"
    echo "      وُجد في $file ما يجب ألّا يوجد: $pattern"
    FAIL=$((FAIL + 1))
  else
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  fi
}

echo "▶ حارس بوابات الاعتماد على الخادم"
echo ""

echo "تعديل الطلب قبل اعتماده محدود:"
# كان الشرطان هنا نصّين في `index.ts`: «غير مسؤول النظام يُردّ» و«النوعان
# اثنان». وقد انتقلا إلى `approval_override.ts` حين فُتح للمدير حقلُ
# التكليف — والحدّ يُقاس هناك طفرةً لا يُبحَث عنه نصّاً هنا.
#
# فالباقي هنا **ما لا تقيسه الوحدة**: أن يمرّ الاعتماد بها فعلاً (أدناه في
# باب التكليف)، وأن يُسجَّل التعديل في سجل التدقيق فيُعرف اعتمادٌ بعد تعديل
# من اعتمادٍ كما ورد.
want "والتعديل يُسجَّل في سجل التدقيق" 'تم اعتماد طلب بعد تعديله'
echo ""

echo "الإرسال المباشر للبريد لمسؤول النظام وحده:"
want "sendUserNotification تشترط requireAdmin" 'const auth = requireAdmin(request);'
want "ولا أثر لـrequireNotifyAccess" '^// كانت هنا `requireNotifyAccess`'
echo ""

echo "عضوية المشروع تُكتب عند الاعتماد:"
want "قائمة المديرين" 'managerUids,'
want "قائمة المنفّذين" 'executorUids,'
want "والحقل المفرد متسق مع أولهم" 'managerUid: managerUids.length ? managerUids\[0\] : null'
want "وتاريخ الإضافة يُكتب" 'createdAt: now(),'
echo ""

echo "المفتاح المجهول في مستند الأدوار يُقرأ من المبدئي لا منعاً:"
want "قراءة _knownKeys" 'data._knownKeys'
want "ودمج المبدئي لما لم يُعرف" 'unknownDefaults'
echo ""

REVIEW="lib/screens/late_alert_review_dialog.dart"
STORE="lib/data/app_store.dart"

echo "تنبيه التأخير الجماعي لا يلتفّ على بوابة البريد:"
want_in "$REVIEW" "يمرّ بـsendOrRequestNotification" 'store.sendOrRequestNotification('
reject_in "$REVIEW" "ولا ينادي دالّة الإرسال مباشرةً" "httpsCallable"
echo ""

echo "والعملية تُكتب في سجل التدقيق — من ومتى ولأي مشاريع ولأي مستلمين:"
want_in "$REVIEW" "اسم الإجراء يُمرَّر" 'auditAction:'
want_in "$REVIEW" "وتفصيله كذلك" 'auditDetails:'
want_in "$REVIEW" "وفيه أسماء المشاريع" 'projects.map((p) => p.name)'
want_in "$REVIEW" "وأسماء المستلمين" 'messages.map((m) => m.user.name)'
# ولولا هذا السطر لبقي مسار مسؤول النظام (الإرسال المباشر) بلا أثرٍ في السجل
# من العميل إطلاقاً — وهو أكثر المسارات استعمالاً.
want_in "$STORE" "والمسار المباشر يكتب في السجل أيضاً" 'await _log(auditAction ?? .إرسال إشعار., auditDetails);'
echo ""

RULES="firestore.rules"

# ــــ دورة الإغلاق: ثلاثة أبواب لا باب واحد ــــ
#
# كان العمل يُغلق من ثلاثة مواضع مستقلة: قائمة الحالة في النموذج، وبلوغ ١٠٠٪
# في التحديث اليومي، وسحبُ بطاقة كانبان. وإصلاحُ واحدٍ يترك الاثنين الآخرين
# باباً مفتوحاً — ولا يصيح شيء، لأن كل موضعٍ منها صحيحٌ في نفسه.
#
# والقاعدة على الخادم تحرسها كلها، لكن الواجهة التي تَعِد بما يُرفض تُنتج
# شكوى «الزرّ لا يعمل». فهذان الفحصان معاً: الحارس الحقيقي في الخادم،
# وهذه تمنع أن يعود مسارٌ يَعِد بالإغلاق ثم يُردّ.
echo "دورة الإغلاق على مرحلتين — المسارات الثلاثة:"
want_in "$STORE" "الإفادة بالإتمام لا تُغلق متى وُجد معتمِد" \
  "needsApproval ? TaskStatus.awaitingApproval.name : TaskStatus.done.name"
want_in "$STORE" "وبلوغ ١٠٠٪ في التحديث اليومي كذلك" 'final closesNow = full && !needsApproval;'
want_in "$STORE" "وسحبُ بطاقة كانبان كذلك" 'final gated = wantsClose &&'
want_in "$STORE" "والاعتماد وحده يكتب تاريخ الإغلاق" "Future<void> approveWorkClosure"
want_in "$STORE" "والردّ للتنفيذ يشترط سبباً" "throw ArgumentError('سبب الإعادة مطلوب')"
echo ""

echo "والخادم يرفض الإغلاق من غير معتمِده:"
want_in "$RULES" "دالّة الحراسة موجودة" 'function closureRespected()'
want_in "$RULES" "وتقرأ المعتمِد من المستند نفسه" "function approverOf(data)"
# مرّتان: في الأعمال وفي مهام المشاريع. وواحدةٌ تعني أن أحد الكيانين بلا حارس.
APPLIED="$(grep -c '&& closureRespected()' "$RULES")"
if [ "$APPLIED" = "2" ]; then
  echo "  ✔ ومطبَّقة على الأعمال ومهام المشاريع معاً"
  PASS=$((PASS + 1))
else
  echo "  ✗ ومطبَّقة على الأعمال ومهام المشاريع معاً"
  echo "      المتوقَّع تطبيقان، والموجود: $APPLIED"
  FAIL=$((FAIL + 1))
fi
echo ""

# ــــ فصل الدور الأساسي عن قيادة المشروع ــــ
#
# ثلاثة أبوابٍ أُغلقت، وكلها من الصنف الذي يعود بصمت: شرطٌ يُعاد إلى دالّة
# في القواعد، أو اسمُ دورٍ يُضاف إلى قائمة، فلا يصيح تحليلٌ ولا اختبارُ
# واجهة — ويعود «مدير مشروع» دوراً يسري على كل مشاريع المنصة.
echo "قيادة المشروع صفةٌ على المشروع لا دورٌ على الشخص:"
# **خارج التعليقات**: نصّ الدور مذكورٌ في شرح ما أُزيل وفي جدول رتب الإسناد
# (`roleRank`)، وكلاهما مشروع. الممنوع أن يعود **شرطاً يُنفَّذ**.
if grep -v '^[[:space:]]*//' "$RULES" | grep -q "role() == 'projectOfficer'"; then
  echo "  ✗ لا أثر لاشتراط الدور في القواعد"
  echo "      عاد شرط الدور إلى سطرٍ يُنفَّذ في $RULES"
  FAIL=$((FAIL + 1))
else
  echo "  ✔ لا أثر لاشتراط الدور في القواعد"
  PASS=$((PASS + 1))
fi
reject_in "$RULES" "ولا دالّة isOfficer" "function isOfficer()"
want_in "$RULES" "وتسجيل المرء نفسه لا يمسّ قائمة المديرين" "managersUnchanged()"
want_in "$RULES" "والتسجيل الذاتي يُكتب بأدنى الأدوار" "request.resource.data.role == 'employee'"
echo ""

echo "و«مدير مشروع» لا يُمنح دوراً أساسياً:"
want_in "$SRC" "قائمة الأدوار المُتاحة عند الاعتماد موجودة" "const GRANTABLE_ROLES"
if grep -q 'const GRANTABLE_ROLES.*projectOfficer' "$SRC"; then
  echo "  ✗ ولا تحوي الدور الموروث"
  echo "      وُجد projectOfficer في GRANTABLE_ROLES"
  FAIL=$((FAIL + 1))
else
  echo "  ✔ ولا تحوي الدور الموروث"
  PASS=$((PASS + 1))
fi
want_in "lib/models/enums.dart" "وقائمة الأدوار في العميل كذلك" "static const List<UserRole> assignable"
echo ""

echo "وأثر التعيين يُكتب بالاسم لا بالعدد:"
want_in "$SRC" "التعيين المباشر يُسجَّل" '"تعيين مدير مشروع"'
want_in "$SRC" "والإلغاء يُسجَّل" '"إلغاء تعيين مدير مشروع"'
want_in "$SRC" "والفروق تُحسب لا تُقدَّر" "const appointed = managerUids.filter"
echo ""

# ــــ حدود الاستثناء من بوابة البريد ــــ
#
# قرّر مسؤول النظام استثناءً **دائماً لتقرير السابعة صباحاً وحده**. وهو
# تعديلٌ صريح لقاعدةٍ وضعها هو، فيُبنى ضيّقاً — وأخطر ما فيه أن يتّسع بصمت:
# معاملٌ يُضاف يقبل نصّاً، أو مستلمٌ يُمرَّر من الطلب، فيصير الباب المفتوح
# للتقرير باباً لكل بريد.
JOB="functions/src/daily_report_job.ts"

echo "استثناء البريد لتقرير السابعة وحده — وحدودُه:"
want "المُرسِل مجدولٌ لا يقبل نداءً من العميل" 'export const dailyExecutiveReport = onSchedule'
want "وبتوقيت الكويت لا بتوقيت الخادم" '"Asia/Kuwait"'
want "وعلى السابعة صباحاً" 'schedule: "0 7 \* \* \*"'
# ولولا هذا لَأمكن لمن يستدعي «ولّد الآن» أن يمرّر موضوعاً أو جسماً أو
# مستلماً — فيصير التقرير غلافاً لبريدٍ يكتبه إنسان بلا اعتماد.
want_in "$SRC" "والتوليد اليدوي لا يقرأ من الطلب إلا خيار الإرسال" \
  'const {sendEmails} = (request.data ?? {}) as {sendEmails?: boolean};'
want_in "$SRC" "وهو محصور بمسؤول النظام" 'const auth = requireAdmin(request);'
want_in "$JOB" "وكل مستلمٍ يأخذ نطاقه هو" 'buildReport(snap, scope, dateKey, generatedAt)'
want_in "$JOB" "وكل تشغيلٍ يُكتب في سجل التدقيق" '"التقرير التنفيذي اليومي"'
echo ""

echo "وما بقي من البريد لم يُمسّ:"
# `sendUserNotification` هي الطريق الوحيد لبريدٍ يكتبه إنسان. وسقوط
# `requireAdmin` عنها يفتح البوابة كلها، ولا يصيح تحليلٌ ولا اختبار.
want "sendUserNotification ما زالت تشترط requireAdmin" \
  'export const sendUserNotification = onCall'
# **خارج التعليقات**: اسم الدالّة مذكورٌ في شرح حدود الاستثناء، وذلك مشروع.
# الممنوع أن يصير نداءً يُنفَّذ.
if grep -v '^[[:space:]]*\(//\|\*\)' "$JOB" | grep -q "sendUserNotification"; then
  echo "  ✗ والمُرسِل المجدول لا ينادي دالّة البريد للبشر"
  echo "      صار نداءً يُنفَّذ في $JOB"
  FAIL=$((FAIL + 1))
else
  echo "  ✔ والمُرسِل المجدول لا ينادي دالّة البريد للبشر"
  PASS=$((PASS + 1))
fi
reject_in "$JOB" "ولا يقرأ نصّاً من طلبٍ إطلاقاً" "request.data"
echo ""

echo "التقرير يُحسب مرةً واحدة على الخادم:"
# الحساب في Dart إلى جانب TypeScript يعني أن يفترق ما يُقرأ عمّا يُرسَل عند
# أول تعديل يُنسى في أحدهما — وهو ما بُني هذا كلّه لمنعه.
REPORT_MODEL="lib/models/daily_report.dart"
reject_in "$REPORT_MODEL" "ولا يُصنَّف في العميل" "critical :"
reject_in "$REPORT_MODEL" "ولا تُحسب أيام تأخير فيه" "delayDays"
want_in "$REPORT_MODEL" "بل يُقرأ كما كُتب" "class DailyReport"
echo ""

# ــــ حذف الحساب: السجل وحساب الدخول معاً ــــ
#
# النقطة التي أوقعت هذا العطل أول مرّة: حذف السجل من Firestore **لا يحذف
# حساب المصادقة**. فمن حُذف يبقى قادراً على تسجيل الدخول ويعود بسجلٍّ جديد.
# وثلاثة أشياء هنا كلها من الصنف الذي يعود بصمت: قاعدةٌ تُفتح، أو حذفٌ يقع
# بلا حذف المصادقة، أو شرطُ إعادة الإسناد يسقط.
echo "حذف الحساب يمسّ الاثنين معاً:"
want "حساب المصادقة يُحذف" 'await admin.auth().deleteUser(uid);'
want "والسجل بعده" 'await userRef.delete();'
want "ومحصورٌ بمسؤول النظام" 'export const deleteUserAccount = onCall'
want "ويُرفض ما دامت عليه مسؤوليات مفتوحة" 'if (blocked) throw new HttpsError("failed-precondition", blocked);'
want "ورسالةُ الرفض تسمّي ما يجب نقله" 'يقود \${deps.ledProjects.length} مشروعاً'
want "والتأكيد بكتابة الاسم يُفحص على الخادم" 'if ((confirmName ?? "").trim() !== name.trim())'
want "ومسؤول النظام لا يحذف نفسه" 'لا يحذف مسؤول النظام حسابه بنفسه'
want "والحذف يُكتب في سجل التدقيق" '"حذف حساب مستخدم نهائياً"'
# ولولا هذا لَأمكن أن يقع حذف السجل بلا حذف المصادقة عند أول إخفاق —
# وهو الوضع الوحيد الذي لا يُرى في المنصة إطلاقاً.
want "وإخفاق حذف المصادقة يمنع حذف السجل" 'ولم يُحذف السجل'
echo ""

echo "والقاعدة تمنع الحذف من العميل:"
want_in "$RULES" "على /users حذفٌ مغلق" 'allow delete: if false;'
echo ""

# التحويل من/إلى `approved`/`rejected`/`pending` لم ينكسر بإضافة مسار
# التوقيف — يبقى `setUserStatus` يضبط بطاقة الدخول وتعطيلها كما كان لكل
# حالةٍ **سوى** التوقيف، الذي صار حذفاً كاملاً (راجع القسم أدناه) فلا حاجة
# فيه لتعطيلٍ ولا لإبطال جلسات: الحذف يفعل الاثنين معاً وأقوى.
echo "والتعطيل خارج التوقيف لم ينكسر:"
want "حساب المصادقة يُعطَّل مع الحالة" 'await admin.auth().updateUser(uid, {disabled: !approved});'
want "والبطاقة تُعاد بلا اعتماد" 'approved,'
reject_in "$SRC" "ولم يعد إبطال الجلسات موجوداً — الحذف كافٍ ويسبقه" \
  "await admin.auth().revokeRefreshTokens(uid);"
echo ""

# ــــ التسجيل الذاتي يمرّ بالسجل المشترك ــــ
#
# عطلٌ وقع فعلاً: صارت قاعدة إنشاء `/users` تشترط دور «موظف»، وبقيت `signUp`
# تكتب `projectOfficer` — فكل تسجيلٍ جديد يُرفض، ويخرج صاحبه بحساب دخولٍ حيّ
# بلا سجل. ولم يصح شيء لأن **ما تكتبه `signUp` كان خارج مدى كل اختبار**:
# هي تنادي Firebase Auth وFirestore فلا تُستدعى في اختبار وحدة.
#
# فصار البناء في `signupUserRecord` وحدها، ويفحصها
# `test/signup_role_test.dart` مقابل ملف القواعد نفسه. وهذا الفحص يمنع أن
# يعود أحدٌ فيبني `AppUser` داخل `signUp` مباشرةً — فتخرج من مدى الاختبار
# من جديد بلا أن يصيح شيء.
echo "التسجيل الذاتي يمرّ بالسجل المشترك:"
want_in "$STORE" "الدالّة المشتركة موجودة" "static AppUser signupUserRecord"
want_in "$STORE" "و signUp تناديها لا تبني بنفسها" "final user = signupUserRecord("
want_in "$STORE" "وتكتب أدنى الأدوار" "role: UserRole.employee,"
echo ""

# ــــ استعادة كلمة المرور لا تفتح بوابة البريد ــــ
#
# الرسالة يولّدها Firebase ويرسلها بنفسه، ولا تمرّ بأي مُرسِلٍ في `functions/`.
# ولو بُنيت دالّةً خلفية لَصار في المنصة **مُرسِلُ بريدٍ ثانٍ يقبل عنواناً من
# الطلب** — وهو بالضبط اتّساع البوابة الذي حُرس في جولة التقرير اليومي.
echo "استعادة كلمة المرور تخرج من Firebase مباشرةً:"
want_in "$STORE" "الدالّة تنادي Firebase" "await _auth.sendPasswordResetEmail("
want_in "$STORE" "والبريد المجهول يُقرأ نجاحاً فلا تُكشف قائمة المسجَّلين" \
  "if (e.code == 'user-not-found' || e.code == 'invalid-email') return null;"
reject_in "$SRC" "ولا أثر لها في الدوال الخلفية" "PasswordReset"
want_in "$STORE" "والحساب الموقوف يُقال له إنه موقوف" "case 'user-disabled':"
echo ""

# ــــ حصر بريد التقرير ــــ
#
# أخطر ما في الحصر أن **يُقرأ ولا يُطبَّق**: حقلٌ يُكتب في الإعدادات، وحلقةُ
# إرسالٍ تمرّ على القائمة الكاملة رغمه. فتظهر الشاشة «محصورٌ بك وحدك» ويخرج
# البريد إلى الجميع — وهذا أسوأ من غياب الحصر، لأنه يُطَمئن.
DR="functions/src/daily_report.ts"
echo "حصر بريد التقرير يُطبَّق لا يُقرأ ويُهمَل:"
want_in "$DR" "دالّة الحصر موجودة" "export function emailTargets"
want_in "$DR" "وقائمةٌ فارغة تعني الجميع" "if (allowlist.length === 0) return reports;"
want_in "$JOB" "والحلقة تمرّ على المحصور لا على الكل" "for (const report of targets) {"
want_in "$JOB" "والقائمة تُقرأ من الإعدادات" "emailRecipientUids: strList(r.emailRecipientUids)"
want_in "$JOB" "والحصر يُذكر في سجل التدقيق" "البريد محصورٌ بـ"
echo ""

echo "وإعدادات التقرير ليست من المقروء عاماً:"
# `settings/{id}` قراءتها عامة لأجل ألوان الهوية على شاشة الدخول. ومستند
# التقرير يحمل معرّفات مستخدمين، فيُستثنى — وإلا قرأه أي أحد على الإنترنت.
want_in "$RULES" "الاستثناء قائم" "allow read: if id != 'dailyReport' || isAdmin();"
echo ""

# ــــ عضوية المشروع تُكتب من باب واحد ــــ
#
# عطلٌ ظهر عند مستخدم: صار انسحاب المدير من مشروعه مرفوضاً عند القاعدة في
# جولة فصل الدور (عمداً — ليُسجَّل من ألغى التعيين)، وبقيت `leaveProject`
# تكتب مباشرةً. فكان الزرّ يُرفض برسالة إنجليزية خام.
#
# والدرس أن تضييق القاعدة يلزمه **مسحُ كل مسارٍ يكتب**، لا المسار الذي
# ضُيّق من أجله وحده.
echo "عضوية المشروع تُكتب من باب واحد:"
# **عدّاً لا وجوداً**: `await _writeTeam(` موجودٌ في الملف على أي حال
# (تناديه دالّتان أخريان)، فالبحث عنه يمرّ ولو عاد الانسحاب إلى الكتابة
# المباشرة — وقد أثبتَت الطفرةُ ذلك. والمواضع المشروعة ثلاثة بالضبط:
# التعريف، ونداءُ `_writeTeam`، ونداءُ `joinProject` (وهو مباشرٌ عمداً،
# فالقاعدة تسمح بتسجيل المرء نفسه منفّذاً).
DIRECT_WRITES="$(grep -c '_writeMembership(' "$STORE")"
if [ "$DIRECT_WRITES" = "3" ]; then
  echo "  ✔ ولا يكتب العضوية مباشرةً إلا من يحقّ له"
  PASS=$((PASS + 1))
else
  echo "  ✗ ولا يكتب العضوية مباشرةً إلا من يحقّ له"
  echo "      المتوقَّع ٣ مواضع، والموجود: $DIRECT_WRITES"
  FAIL=$((FAIL + 1))
fi
want_in "$STORE" "والرفض يُترجَم لا يُعرض خاماً" "String describeWriteFailure(Object error)"
want_in "$STORE" "والترجمة تدلّ على بطاقة الدخول" "أقدم من صلاحياتك المسجَّلة"
# ولولا هذا لَبقي العميل يظنّ نفسه مسؤول نظام ببطاقةٍ لا تقول ذلك، فيكتب
# مباشرةً ويُردّ — وهي الحالة التي وقعت فعلاً.
want_in "$STORE" "وإن رُدَّت الكتابة المباشرة يُعاد الطلب من الباب المحروس" \
  "if (e.code != 'permission-denied') rethrow;"
echo ""

# ــــ ردّ البند لعدم الاختصاص ــــ
#
# هذا **ثقبٌ فُتح عمداً** في قاعدةٍ كانت تمنع المُسنَد إليه أن يمسّ الإسناد.
# وخطرُه أن يتّسع بتعديلٍ لاحق فيصير: «المُسنَد إليه يعدّل الإسناد» — أي
# يُحوّل بندَه إلى زميلٍ باسمه، أو يُفرّغ إسناد غيره.
#
# فالحارس هنا يحرس **ضيق** الاستثناء لا وجودَه: شرطاه معاً — التفريغ لا
# التحويل، والختمُ باسم الرادّ نفسه — وسقوطُ أيّهما يفتح ما وُصف أعلاه.
WORKS_SCREEN="lib/screens/works_list_screen.dart"
echo "ردّ البند لعدم الاختصاص استثناءٌ ضيّق:"
want_in "$RULES" "الاستثناء معرَّفٌ باسمه" "function isSelfDecline()"
want_in "$RULES" "ويُفرَّغ الإسناد ولا يُحوَّل" \
  "request.resource.data.get('assigneeUid', '') == ''"
want_in "$RULES" "ويُختم باسم الرادّ نفسه فلا يردّ أحدٌ عن غيره" \
  "== request.auth.uid"
echo ""

echo "والعميل يردّ كما تصف القاعدة:"
want_in "$STORE" "الأفعال لمن على مكتبه البند لا لمن يشرف عليه" \
  "bool isAssignedToMe(WorkItem work) =>"
want_in "$STORE" "وردُّ العمل يُفرّغ الإسناد" "'assigneeUid': '',"
want_in "$STORE" "ويختم سجلّ الردّ باسم الرادّ" "declinedByUid: currentUser?.id ?? '',"
want_in "$STORE" "ولا يُقبل ردٌّ بلا سبب" "throw ArgumentError('سبب عدم الاختصاص مطلوب');"
# ومهام المشاريع نظيرُ الأعمال: زرٌّ يظهر في شاشة ويغيب في أختها يُقرأ عطلاً.
want_in "$STORE" "ومهام المشاريع لها النظير نفسه" "Future<void> declineTask(ProjectTask task, String reason)"
want_in "$STORE" "وبدءُ العمل بضغطة لا بنموذج تعديلٍ لا يملكه الموظف" \
  "Future<void> startWork(WorkItem work)"
echo ""

# ــــ العمل الموجَّه لإدارةٍ أخرى ــــ
#
# كانت الشاشة تعرض إدارات المستخدم وحدها، فتعذّر توجيه عملٍ لإدارةٍ أخرى
# أصلاً. وفتحُ القائمة وحده لا يكفي: بلا مُسنَدٍ إليه لا يظهر البند في
# «المُسنَد إليّ» لأحد، ولا يعلم أحدٌ في تلك الإدارة أنه وصلها — فيُدفن.
echo "العمل الموجَّه لإدارةٍ أخرى يصل فعلاً:"
want_in "$WORKS_SCREEN" "والقائمة كل الإدارات لا إداراتي" "final departments = store.departments;"
want_in "$STORE" "والإنشاء خارج إدارتي يمرّ بطلبٍ لا بردٍّ من القاعدة" \
  "bool canCreateWorkIn(String? departmentId)"
want_in "$WORKS_SCREEN" "والشاشة تقرأ الحكم من مكانٍ واحد" "store.canCreateWorkIn("
# ــ ولا يُلزَم الطالب بتسمية منفّذ ــ
#
# كان يُلزَم، والعلّة أن العمل بلا مُسنَدٍ إليه يقع في فراغ. والعلّة صحيحة
# والعلاج كان خطأً: من يطلب من إدارةٍ أخرى لا يعرف اختصاصاتها، فإلزامه
# تخمينٌ باسم. والفراغ يُسدّ حيث هو — لا بإلزامٍ في غير موضعه.
#
# فيُحرَس الأمران معاً: أن الإلزام لم يعد، **وأن ما يقوم مقامه قائم**.
# ولولا الثاني لَكان هذا الحارس إذناً بحذف السطح الذي بُني بدلاً منه.
reject_in "$WORKS_SCREEN" "ولا يُلزَم الطالب بتسمية منفّذ" \
  "if (crossDept && _assigneeUid.isEmpty)"
want_in "$WORKS_SCREEN" "بل يُقال له إن مدير الإدارة يكلّف" "يكلّف مديرُ الإدارة"
want_in "$WORKS_SCREEN" "وما ينتظر التكليف يُعدّ" "ينتظر التكليف"
want_in "$WORKS_SCREEN" "ويُصفّى" "_assigneeFilter == _unassignedFilter"
echo ""

# ــــ التكليف عند الاعتماد: فتحةٌ في بابٍ مغلق ــــ
#
# كان تعديل الطلب قبل اعتماده محصوراً بمسؤول النظام كلّه، وسببُ الحصر أن
# الحمولة تحمل `dueDate` — فتعديلها **بابُ التفافٍ حول بوابة المواعيد
# النهائية**. وفُتح منه حقلٌ واحد: تكليفُ منفّذ على طلب عمل.
#
# وحدُّ الفتحة في وحدةٍ نقيّة لها اختباراتها (`approval_override.ts`)، وهي
# الحَكَم. وما هنا يمنع أمرين لا يقيسهما ذلك الاختبار:
#   • أن يعود `index.ts` إلى شرطٍ مدفون فيه فتصير الوحدة شيفرةً ميتة،
#   • وأن تُذكر مفاتيح أخرى في قائمة التفويض.
OVR="functions/src/approval_override.ts"
CENTER="lib/screens/decision_center_screen.dart"
echo "التكليف عند الاعتماد لا يوسّع ما وراءه:"
want_in "$SRC" "الحدّ يُقرأ من الوحدة لا من شرطٍ مدفون" "judgeOverride("
reject_in "$SRC" "ولم يعد في الملف شرطٌ موازٍ يلتفّ عليها" \
  "payloadOverride && !isAdminCaller"
want_in "$OVR" "والمفوَّض حقلُ التكليف وحده" 'workCreate: \["assigneeUid"\]'
reject_in "$OVR" "ولا الموعد النهائي" '"dueDate"'
# طلب المشروع يبقى بلا تفويض: حمولته تحمل موعداً كذلك.
reject_in "$OVR" "ولا حمولة طلب المشروع" "projectCreate: \["
echo ""

echo "والاسم يُشتقّ من المعرّف لا يُؤخذ من الحمولة:"
# وإلا كُتب **المعرّف الجديد مع الاسم القديم**: الواجهة ترسل `assigneeUid`
# وحده. عطلٌ كان نادراً، ويصير المسار الطبيعي متى كلّف المدير عند الاعتماد.
reject_in "$SRC" "لا يُكتب اسمٌ من الحمولة" "assigneeName: payload.assigneeName"
want_in "$SRC" "بل يُقرأ من سجلّ من أُسنِد إليه" \
  'workAssigneeName = String(aSnap.data()?.name'
want_in "$SRC" "ورتبةُ الإسناد تُفحص بمن اختار" "assigneeFromApprover ?"
echo ""

echo "والواجهة ترسل ما يقبله الخادم لا أكثر:"
want_in "$CENTER" "زرّ التكليف عند الاعتماد قائم" "اعتمد وكلّف"
want_in "$CENTER" "ويرسل مفتاحاً واحداً" "{'assigneeUid': uid}"
echo ""

# ــ التوقيف يحذف حساب الدخول، لا يُعطّله فحسب ــ
#
# كان `updateUser(uid, {disabled: true})`، فيبقى الحساب موجوداً في Firebase
# Auth والبريد محجوزاً به — فيُرفض تسجيلٌ جديد بنفس البريد. والحذف يحرّره
# فوراً. وهذا هو العطل الذي أُبلغ عنه: «من أُوقف يجب أن يُسمح له بالتسجيل
# من جديد».
#
# والفحص **داخل جسم `setUserStatus` وحده** لا على الملف كله: `deleteUser(uid)`
# عبارةٌ موجودة أصلاً في `deleteUserAccount` لغرضٍ آخر، فبحثٌ على الملف
# كاملاً يمرّ حتى لو رجع مسار التوقيف إلى `updateUser(disabled: true)` —
# وقد قِيست هذه الغفلة بعينها بطفرة فمرّت قبل هذا التضييق.
AM="functions/src/account_merge.ts"
SET_STATUS_FILE="$(mktemp)"
sed -n '/^export const setUserStatus/,/^});/p' "$SRC" > "$SET_STATUS_FILE"
echo "التوقيف يُحرِّر البريد، لا يُعطّله فحسب:"
if grep -q 'await admin.auth().deleteUser(uid);' "$SET_STATUS_FILE" \
    && ! grep -q 'await admin.auth().updateUser(uid, {disabled: true});' "$SET_STATUS_FILE"; then
  echo "  ✔ التوقيف يحذف حساب الدخول لا يُعطّله"
  PASS=$((PASS + 1))
else
  echo "  ✗ التوقيف يحذف حساب الدخول لا يُعطّله"
  echo "      لم يوجد الحذف داخل setUserStatus، أو عاد التعطيل القديم إليها"
  FAIL=$((FAIL + 1))
fi
rm -f "$SET_STATUS_FILE"
want_in "$SRC" "وإعادة تفعيل موقوفٍ تُرفض صراحةً" \
  "لا يمكن إعادة تفعيل هذا الحساب: حُذف حساب دخوله عند التوقيف"
echo ""

echo "والحذف الكامل يترك أثراً خفيفاً لمطابقةٍ لاحقة:"
want_in "$SRC" "يُكتب قبل محو السجل" 'collection("deletedAccounts").doc(uid).set('
want_in "$RULES" "ومقفلة تماماً أمام أي عميل" \
  "match /deletedAccounts/{uid} {"
reject_in "$AM" "والقرار من وحدةٍ نقيّة — لا اختيار أول نتيجة عند التعدّد" \
  "if (total < 1)"
echo ""

echo "وإعادة التسجيل تُعيد ربط الأعمال القديمة تلقائياً:"
want_in "$SRC" "الاعتماد يستدعي الدمج" "await mergeAccountsIfMatched("
want_in "$SRC" "والدمج ينقل أعمال العمل والمهام والمشاريع" \
  'db().collection("works").where("assigneeUid", "==", oldUid)'
echo ""

# ــ الحقل المفرد الموروث يُكتب مع القائمة، وإلا شُلّ المشروع ــ
#
# مستند المشروع يحمل `managerUids` **و**`managerUid`. وقواعد الأمان تقرأ
# المفرد: `legacyManagerConsistent()` تشترط أن يكون عضواً في القائمة،
# و`matchesRealProject()` تشترط أن يساويَه ما ينسخه التحديث اليومي الجديد.
# فكتابةُ القائمة وحدها — وهي ما وقع فعلاً في جولةٍ سابقة — تترك المشروع
# بثابتةٍ منقوضة: صاحبُ الحساب الجديد يرى مشروعه ولا يكتب فيه شيئاً.
#
# والفحص هنا على **اسم الدالّة النقيّة** لا على نصّ الكتابة: تفصيلُ الحمولة
# مُختبَرٌ في `functions/test/account_merge.test.mjs` بطفراتٍ تعضّ، وما
# يحرسه هذا السطر ألّا يعود الدمج يكتب القائمة بيده متجاوزاً الدالّة.
echo "والدمج يكتب المفرد الموروث مع القائمة — لا القائمة وحدها:"
want_in "$SRC" "حمولة العضوية من الدالّة النقيّة" \
  "projectMemberPatch(d.data(), oldUid, newUid)"
reject_in "$SRC" "ولا كتابة قائمةٍ يدوية تتجاوزها" \
  'merge(d.ref, {managerUids: uids})'
want_in "$SRC" "والتوابع تُصحَّح كذلك — لا تبقى نسختها على معرِّفٍ ميّت" \
  'staleChild("dailyUpdates")'
echo ""

# ــ «عدم بقاء أي قيود مرتبطة بالحساب السابق» ــ
echo "وقيود الحساب السابق تُشطب ولا تُورَّث:"
want_in "$SRC" "الشطب يقع على إعدادات التقرير" \
  "pruneUidFromReportSettings(settingsSnap.data()"
# والشطب **لا يعرف المعرِّف الجديد أصلاً**: دالّةٌ لا يصلها إلا القديم لا
# تستطيع أن تورِّث قيداً حتى لو أراد كاتبُها. والفحص على توقيعها وحده لا على
# الملف كله — فالملف يحمل `newUid` في دالّة العضوية لغرضٍ مشروع.
PRUNE_FILE="$(mktemp)"
sed -n '/^export function pruneUidFromReportSettings(/,/^}/p' "$AM" > "$PRUNE_FILE"
echo "  — الشطب لا يعرف المعرِّف الجديد:"
if [[ -s "$PRUNE_FILE" ]] && ! grep -q 'newUid' "$PRUNE_FILE"; then
  echo "  ✔ لا يُوضع الجديد مكان القديم في القوائم"
  PASS=$((PASS + 1))
else
  echo "  ✗ لا يُوضع الجديد مكان القديم في القوائم"
  echo "      إمّا لم توجد الدالّة، وإمّا صار المعرِّف الجديد يصلها"
  FAIL=$((FAIL + 1))
fi
rm -f "$PRUNE_FILE"
echo ""

# ــ الواجهة ترتيبٌ والخادم حراسة ــ
echo "والخادم يفحص حال الحساب قبل الإرسال:"
want_in "functions/src/notify.ts" "قرارٌ في دالّةٍ واحدة مُختبَرة" \
  "export function undeliverableReason("
want_in "functions/src/notify.ts" "ودالّة الإرسال تمرّ به فعلاً" \
  "const blocked = undeliverableReason(data);"
want_in "lib/models/app_user.dart" "وتعريفُ «من يُراسَل» واحدٌ في العميل" \
  "bool get isContactable =>"
echo ""

# ــ سجل التحديثات اليومية: يُقرأ بالقائمة، ويُحذف بحدّ ــ
#
# اشتراك المستندات التابعة كان يُصفّي لمدير المشروع بالحقل المفرد الموروث
# `managerUid` — أي أوّل المديرين وحده — فلا يصل المديرَ الثاني فصاعداً
# تحديثٌ واحد على مشروعه. وهو نظير عطل دمج الحسابات حرفاً بحرف.
# ــ الحذف يُفتح، والتعديل يبقى مغلقاً ــ
#
# التحديث اليومي أثرٌ لا يُنقّح بأثر رجعي: التصحيح حذفٌ مُسجَّل ثم إضافةٌ
# جديدة. ولو فُتح التعديل مع الحذف لَصار السجلُّ نصّاً يُعاد كتابته بعد شهر.
DU_FILE="$(mktemp)"
sed -n '/match \/dailyUpdates\/{id}/,/^    }/p' "$RULES" > "$DU_FILE"
echo "وحذف التحديث اليومي مفتوحٌ بحدّ، والتعديل مغلق:"
want_in "$DU_FILE" "الحذف لكاتبه ولمالك المشروع" \
  "allow delete: if canAccessProjectDocOrMember(resource.data)"
want_in "$DU_FILE" "وكاتبُه صراحةً" \
  "resource.data.get('authorUid', '') == request.auth.uid"
want_in "$DU_FILE" "والتعديل يبقى مردوداً على الجميع" "allow update: if false;"
# والمنفّذ ليس مالكاً: عضوية المشروع تشمله، ففتحُ الحذف لها يعني أن يمحو
# منفّذٌ تحديثَ مديره. وقد قِيست هذه بطفرةٍ على المحاكي فعضّت.
#
# والفحص على **سطور الحذف وحدها**: قاعدة الإنشاء فوقها تستعمل
# `isMemberOfRealProject` بحقّ — فالمنفّذ يكتب التحديث اليومي ولا يمحوه.
DU_DELETE="$(mktemp)"
sed -n '/allow delete:/,$p' "$DU_FILE" > "$DU_DELETE"
reject_in "$DU_DELETE" "ولا تُفتح لعضوية المشروع التنفيذية" "isMemberOfRealProject"
rm -f "$DU_FILE" "$DU_DELETE"
echo ""

# ــ ملفات المرفقات: العميل لا يمحوها، والخادم يمحوها بفحص ــ
echo "وملفات المرفقات لا يمحوها العميل:"
want_in "storage.rules" "قاعدة التخزين تبقى مغلقة" "allow update, delete: if false;"
want_in "$SRC" "والخادم يحذف التحديث ويمحوها معه" \
  "export const deleteDailyUpdate = onCall("
want_in "$SRC" "بعد فحص حقّ الحاذف على الخادم" "if (!mayDeleteDailyUpdate("
want_in "$SRC" "بمسارات تُفحص أولاً" "storagePathsToDelete(data.attachments"
want_in "lib/data/app_store.dart" "والعميل يمرّ بالدالّة لا بحذفٍ مباشر" \
  "httpsCallable('deleteDailyUpdate')"
reject_in "lib/data/app_store.dart" "ولا يحذف المستند بيده" \
  "collection('dailyUpdates').doc(update.id).delete()"

# ــ ولا يعود مُشغِّل Firestore إلى المنصة بلا قصد ــ
#
# كان محوُ الملفات في مُشغِّل `onDocumentDeleted`، فسقط نشرُه وحده من بين
# تسع عشرة دالّة — نُشرت البقية كلها بنجاح. ومُشغِّلات Firestore تحتاج
# **Eventarc** مفعَّلةً في المشروع بصلاحيات على حسابها الخدمي، وتحتاج أن
# تكون منطقة الدالّة مطابقة لموقع قاعدة البيانات. وليس شيءٌ من ذلك مهيّأً.
#
# فمن أراد مُشغِّلاً يوماً فليهيّئ ذلك أولاً **عن قصد**، لا أن يكتشفه في
# نشرٍ فاشل. والمنصة اليوم دوالُّ استدعاء ومجدولةٌ واحدة، لا غير.
echo "ولا مُشغِّل Firestore في المنصة — يحتاج Eventarc ومنطقةً مطابقة:"
reject_in "$SRC" "لا مُشغِّل حذف" "onDocumentDeleted("
reject_in "$SRC" "ولا استيراد لوحدة المُشغِّلات" "firebase-functions/v2/firestore"
# المسار يكتبه العميل، والمُشغِّل يعمل بصلاحية المدير. فبلا فحصٍ للبادئة
# يمحو موظفٌ ملفَ غيره بأن يضع مساره في مرفق تحديثٍ يحذفه.
want_in "functions/src/attachment_cleanup.ts" "والبادئة مبنيّةٌ على مشروع التحديث" \
  "path.startsWith(prefix)"
echo ""

# ــ عضوية المشروع بُعدٌ للقراءة، لا الدورُ الموروث ــ
#
# اشتراكُ توابع المشروع كان يُصفّي بدور «مدير مشروع» — وهو دورٌ **لا يُمنح
# لأحد**: `GRANTABLE_ROLES` ثلاثةٌ ليس هو منها. فأُصلح فرعٌ لا يمرّ به أحد،
# ولم يتغيّر شيء عند صاحب الشكوى. والعضوية هي الصلة الحقيقية.
echo "وتوابع المشروع تُقرأ بالعضوية:"
want_in "$STORE" "والاشتراك يمرّ بالقرار المُختبَر" "childScopeFilters("
want_in "lib/data/child_scope.dart" "قائمة المديرين" \
  "ChildFilter.arrayContains('managerUids', me)"
want_in "lib/data/child_scope.dart" "وقائمة المنفّذين" \
  "ChildFilter.arrayContains('executorUids', me)"
reject_in "lib/data/child_scope.dart" "ولا شرطَ دورٍ موروث" "officer"
# «بلا إدارة» و«يرى كل الإدارات» كانا يؤدّيان إلى تصفيةٍ فارغة — أي طلبِ
# المجموعة كاملةً، فتردّها القواعد بالكامل. وهما حالان مختلفان تماماً.
want_in "lib/data/child_scope.dart" "ويرى الكلَّ معاملٌ صريح" "if (viewsAll) return const"
echo ""

echo "والعضوية تُنسخ على التوابع لتقرأها القاعدة:"
# `isProjectMember` تقرأ القائمتين من المستند نفسه. و`executorUids` لم تكن
# تُنسخ قط، فكان المنفّذ ممنوعاً بالقاعدة لا بالاستعلام وحده.
if [ "$(grep -c "'executorUids': project" "$STORE")" -ge 4 ]; then
  echo "  ✔ تُكتب على التحديثات والمخاطر والعوائق والمهام"
  PASS=$((PASS + 1))
else
  echo "  ✗ تُكتب على التحديثات والمخاطر والعوائق والمهام"
  echo "      المتوقَّع أربعة مواضع على الأقل، والموجود: $(grep -c "'executorUids': project" "$STORE")"
  FAIL=$((FAIL + 1))
fi
want_in "$SRC" "وختمٌ لمرّةٍ واحدة للسجلات القديمة" \
  "export const stampChildMembership = onCall("
want_in "lib/screens/user_management_screen.dart" "وزرُّه في متناول مسؤول النظام" \
  "ختم عضوية المشاريع"
echo ""

# ــ العطل لا يبقى صامتاً ــ
echo "وسبب التعذّر يُقال، والفراغ يُفسَّر:"
reject_in "lib/screens/daily_update_form.dart" "لا ابتلاع للخطأ" "} catch (_) {"
want_in "lib/screens/daily_update_form.dart" "بل يُعرض نصُّه" "تعذّر حفظ التحديث: \$e"
want_in "$STORE" "والفراغ يفرّق بين أسبابه" "String? whyNoUpdates(Project project)"
want_in "lib/screens/project_detail_screen.dart" "والشاشة تقرؤه" "store.whyNoUpdates(project)"
echo ""

# ــ الدفعة الذرّية فُكّت ــ
#
# كانت خمس مجموعات في `batch` واحدة: رفضُ أيّها يُسقط التحديث اليومي نفسه،
# فيضيع عملُ يومٍ كامل بسبب طلب قرارٍ رُدّ.
echo "والتحديث اليومي لا يسقط بسقوط تابعٍ له:"
want_in "$STORE" "يُكتب أوّلاً وبمفرده" "await updateRef.set({"
want_in "$STORE" "وما تعذّر يُجمع ويُقال" "notRecorded.add("
want_in "lib/screens/daily_update_form.dart" "والواجهة تعرضه" "result.notRecorded"
echo ""

# ــ الحذف صار منطقياً، والنهائي استثناء ــ
#
# وكان الحذف نهائياً متسلسلاً بلا رجعة: يمحو المهام والتحديثات والمخاطر
# والعوائق مع المشروع. ولا سبيل إلى استعادة شيء — ولا لمسؤول النظام.
echo "الحذف المنطقي وثوابته الثلاث:"
want_in "$RULES" "من يحذف: داخل الإدارة وحدها" "function mayDeleteIn(deptId)"
want_in "$RULES" "والاستعادة لمسؤول النظام وحده" "&& isAdmin() && !wasConvertedDoc()"
want_in "$RULES" "والمحذوف مجمَّد" "function frozenWhileDeleted()"
# وهذا ما كشفه اختبارٌ عند أول تشغيل: مسارُ «المُسنَد إليه يحرّك تقدّم
# عمله» كان يمرّ بكتابة `deletedAt` — فيحذف الموظفُ عملَه بنفسه.
want_in "$RULES" "ولا تُمسّ حقول الحذف من التعديل العادي" "function deletionUntouched()"
# و`del` كانت بلا نطاق: حاملُها يمحو أعمال أي إدارة في الوزارة.
reject_in "$RULES" "و«حذف السجلات» لم تعد تفتح الحذف النهائي" \
  "allow delete: if isAdmin() || perm('del');"
echo ""

echo "والقسمة تقع في مَخرجٍ واحد لا في كل شاشة:"
want_in "$STORE" "دالّة القسمة موجودة ومُختبَرة" "static ({List<T> live, List<T> archived}) splitDeleted<T>("
want_in "$STORE" "وتوابعُ المحذوف تُسقَط" "static List<T> withoutArchivedParents<T>("
want_in "$STORE" "والمحذوف يُعلَّم لا يُمحى" "Future<String?> softDeleteProject("
want_in "$STORE" "والاستعادة تُردّ لغير مسؤول النظام" \
  "if (!isAdmin) return 'الاستعادة لمسؤول النظام وحده.';"
want_in "lib/screens/archived_items_screen.dart" "وشاشةُ الاستعادة قائمة" \
  "class ArchivedItemsScreen"
echo ""

# ــ سجل التدقيق: بنيةٌ تُصفّى، وكتابةٌ لا تُزوَّر ــ
echo "وسجل التدقيق يحمل نوعه وفاعله وفرقه:"
want_in "lib/models/audit_log_entry.dart" "النوع محفوظ" "final ChangeType type;"
want_in "lib/models/audit_log_entry.dart" "والفاعل بمعرّفه" "final String? actorUid;"
want_in "lib/models/audit_log_entry.dart" "و«قبل/بعد»" "final Map<String, dynamic>? before;"
want_in "lib/models/change_type.dart" "والفرق يُحسب لا يُخزَّن كاملاً" "diffMaps("
want_in "$STORE" "والفاعل يُكتب من المستخدم الحالي لا من المُنادي" "actorUid: currentUser?.id,"
echo ""

# ــــ الحدُّ بين القاعدة والنموذج ــــ
#
# هنا وقع عطلٌ كلّف المنصّة سجلَّها يوماً كاملاً: القاعدة اشترطت
# `timestamp == request.time` (وقتَ الخادم)، والتطبيق ظلّ يكتب
# `Timestamp.fromDate(DateTime.now())` (ساعةَ الجهاز). ولا يتطابقان أبداً —
# فرُدّ **كلُّ** سطرٍ يكتبه المتصفّح، وظهر للمستخدم «تعذر حذف المشروع» على
# حذفٍ تمّ فعلاً.
#
# ولم يمسكه شيء: اختبارُ القواعد يبني بيانَه بـ`serverTimestamp()`، فأثبت أن
# القاعدة صحيحة ولم يسأل هل يكتب التطبيقُ ما تشترطه. **والحدُّ بين الاثنين
# لم يعبره اختبار** — وهذا ما يحرسه ما يلي: الشرطان يتحرّكان معاً أو لا
# يتحرّك أحدهما.
echo "ووقتُ سطر التدقيق من الخادم لا من الجهاز:"
MODEL="lib/models/audit_log_entry.dart"
if grep -q "request.resource.data.timestamp == request.time" "$RULES"; then
  want_in "$MODEL" "القاعدة تشترط وقت الخادم — والنموذج يكتبه" \
    "'timestamp': FieldValue.serverTimestamp()"
  reject_in "$MODEL" "ولا يكتب ساعةَ الجهاز" "'timestamp': Timestamp.fromDate"
else
  echo "  ✗ القاعدة لم تعد تشترط وقت الخادم"
  echo "      سقط 'timestamp == request.time' من $RULES — فالوقت صار قابلاً للتزوير."
  FAIL=$((FAIL + 1))
fi

# ــ وسطرٌ يُردّ لا يُسقِط الفعل الذي وقع ــ
#
# `_log` تُنادى **بعد** أن يقع الفعل. فرفعُ خطئها إلى مُناديها يجعل حذفاً
# تمّ يُعرض فشلاً. وهذا حارسُ حذفٍ لا حارسُ صحّة: لا مُحاكي Firestore في
# المشروع، فلا سبيل إلى اختبارٍ حقيقي لها بلا اعتماديّةٍ جديدة.
want_in "$STORE" "ودالّة التسجيل تبتلع رفضَها ولا تُسقط الإجراء" \
  "      noteAuditWriteFailure(action, e);"
want_in "$STORE" "ولا تبتلعه صامتةً" "String? auditWriteFailure;"
want_in "lib/widgets/audit_write_banner.dart" "واللافتة تقوله" "class AuditWriteBanner"
want_in "lib/widgets/app_shell.dart" "وهي مركَّبة في الهيكل" \
  "store.auditWriteFailure != null"
echo ""

# ــ التحويل بين مشروعٍ وعمل ــ
#
# ثلاثة يحرسها هذا القسم، وكلٌّ منها بابٌ لو انفتح لم يُلاحَظ:
#
#   • الموعد النهائي ليس في نموذج تعديل المشروع. وهو بوابةُ اعتمادٍ لا
#     يفتحها شيء — والقاعدة تردّه، فعرضُ حقلٍ له يَعِد بما سيُردّ.
#   • والتحويل يمرّ بالخادم: عمليةٌ ذرّية من خطوتين، لو وقعت من العميل في
#     كتابتين لبقي السجل الواحد سجلَّين حيَّين عند انقطاع الاتصال.
#   • والمحوَّل لا يُستعاد بضغطة: له نسخةٌ حيّة، فاستعادتُه تُنتج الشيء
#     الواحد مرّتين في كل قائمة وتقرير.
echo "التحويل بين مشروعٍ وعمل:"
FORM="lib/screens/project_form_dialog.dart"
want_in "$FORM" "نموذج تعديل المشروع قائم" "class ProjectFormDialog"
reject_in "$FORM" "والموعد النهائي ليس فيه" "dueDate"
# ولا حقلَ حالةٍ للإدارة في النموذج: نقلُ مشروعٍ بين الإدارات يُخرجه من
# نطاق من ينقله، وله مسارُه القائم (نقل الأقسام).
reject_in "$FORM" "ولا نقلُ الإدارة" "_departmentId"
# والمتجر يكتب الحقول المقصودة وحدها لا المستند كاملاً: `toMap()` تحمل
# معها الموعد والإدارة والعضوية، و`Timestamp` يفقد ما دون الميكروثانية في
# رحلته إلى `DateTime` وإيابه — فيراه الخادم تغييراً في الموعد فيردّ الحفظ.
want_in "$STORE" "ودالّة الحفظ تكتب الحقول المقصودة وحدها" \
  "doc(project.id).update(after);"
want_in "$STORE" "والتحويل يمرّ بدالّة على الخادم" \
  "httpsCallable('convertRecord')"
want_in "functions/src/index.ts" "وهي تكتب وتؤرشف في دفعةٍ واحدة" "await batch.commit();"
want_in "functions/src/convert_record.ts" "ومقابلةُ الحقول وحدةٌ نقيّة" \
  "export function projectToWork("
want_in "functions/src/convert_record.ts" "والتحويل لمدير الإدارة ومسؤول النظام" \
  "export function mayConvertIn("
# والنمط مأخوذٌ من قائمة `deletionUntouched` بعينها لا من أي ذكرٍ للحقلين:
# `isDetachingConversion` تذكرهما أيضاً، فنمطٌ عامّ يمرّ على حذفهما من هنا.
want_in "$RULES" "وحقول التحويل خارج التعديل العادي" \
  "'convertedFromType', 'convertedFromId',"
want_in "$RULES" "ولا تُوسَم من باب الحذف" "function convertedLinkUnchanged()"
want_in "lib/screens/archived_items_screen.dart" "والمحوَّل يُعرض محوَّلاً" \
  "حُوّل إلى: \$convertedTo"
want_in "$STORE" "وفكُّ الارتباط خطوةٌ مستقلّة" "Future<String?> detachAndRestore("
echo ""

# ــ وتعديل العمل حقُّ الدور لا علَمٌ يُطفأ ــ
echo "وتعديل العمل حقٌّ لمدير الإدارة:"
want_in "$RULES" "في القاعدة" "(isDeptManager() || perm('mw'))"
want_in "$STORE" "وفي المتجر" "bool canEditWorkDetails(WorkItem work)"
want_in "lib/screens/works_list_screen.dart" "والنموذج يسأل عن السجل لا عن العلَم" \
  "store.canEditWorkDetails(widget.editing!)"
echo ""

# ــــ الطلب الواحد لا يصير طلبين ــــ
#
# ظهر كلُّ مشروعٍ يُطلَب مرّتين في مركز القرارات. والبطاقتان مستندان حقيقيّان
# لا تكراراً في العرض: كتابةُ الطلب نجحت ثم ارتفع خطأٌ بعدها، فجمدت النافذة
# على دوّارة بلا رسالة — فأعاد صاحبها المحاولة ظانّاً أنها فشلت.
#
# فيُغلق البابان: النافذة تتكلّم عند الفشل، والقاعدة تردّ المكرّر أيّاً كان
# سببُ الضغطة الثانية.
echo "الطلب الواحد لا يصير طلبين:"
want_in "$STORE" "قاعدةُ التكرار موجودة ونقيّة" \
  "static ApprovalRequest? findDuplicatePending("
# وكلُّ مسارٍ من الثلاثة يمرّ بها فعلاً: وجودُ القاعدة بلا استعمالٍ حراسةٌ
# على الورق. والفحص داخل جسم كل دالّة لا في الملف كلِّه.
want_within() {
  local name="$1" signature="$2" pattern="$3" window="${4:-26}"
  if grep -A "$window" "$signature" "$STORE" | grep -q "$pattern"; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      لم يُعثر على «${pattern}» داخل «${signature}»"
    FAIL=$((FAIL + 1))
  fi
}
want_within "وطلبُ المشروع يمرّ بها" \
  "Future<String?> submitProjectRequest(" "_duplicateRequestBlock("
want_within "وطلبُ العمل كذلك" \
  "Future<String?> submitWorkRequest(" "_duplicateRequestBlock("
want_within "وطلبُ الموعد النهائي كذلك" \
  "Future<String?> submitDeadlineChangeRequest(" "_duplicateRequestBlock("

# ــ والنافذة لا تجمد صامتة ــ
#
# وهذه دالّتان لا خمس: بقيّةُ نوافذ الإرسال تنادي دوالَّ متجرٍ تُعيد `String?`
# ولا ترفع شيئاً (`sendOrRequestNotification`، `submitFeedback`)، فهي محروسةٌ
# أصلاً. وتوسيعُ الجولة إليها تغييرٌ بلا أثر.
want_in "lib/screens/request_project_dialog.dart" "نافذةُ المشروع تلتقط خطأها" \
  "        _error = 'تعذّر الحفظ: \$e';"
want_in "lib/screens/request_deadline_change_dialog.dart" "ونافذةُ الموعد كذلك" \
  "        _error = 'تعذّر إرسال الطلب: \$e';"
echo ""

# ــــ ولا تسقط كتابةُ الموظف بسقوط تابعٍ لها ــــ
#
# كانت `addWorkUpdate` دفعةً ذرّية تجمع مستندَ التحديث مع تحديث نسبة العمل
# وحالته. ودفعةُ Firestore ذرّية — فردُّ كتابةِ `works` وحدها يُسقط معها ما
# كتبه الموظف، ولا يُقال له أيُّ الاثنين رُدّ. وهو العطل نفسه الذي أُصلح
# للتحديث اليومي على المشاريع ولم يُنقل إلى الأعمال.
echo "وتحديثُ العمل يُكتب أوّلاً وبمفرده:"
reject_within() {
  local name="$1" signature="$2" pattern="$3"
  if grep -A 40 "$signature" "$STORE" | grep -q "$pattern"; then
    echo "  ✗ $name"
    echo "      عاد «${pattern}» داخل «${signature}»"
    FAIL=$((FAIL + 1))
  else
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  fi
}
reject_within "لا دفعةَ ذرّية في تحديث العمل" \
  "addWorkUpdate({" "_db.batch()"
want_within "بل كتابةٌ أولى مفردة" \
  "addWorkUpdate({" "await ref.set("
want_within "وما تعذّر يُجمع ويُقال" \
  "addWorkUpdate({" "notRecorded.add(" 60
# والنمطُ نصُّ الرسالة لا اسمُ الحقل: `result.notRecorded` يبقى مذكوراً في
# سطر اللون ولو حُذف الفرعُ الذي يُظهرها — وقد جُرّب فمرّ.
want_in "lib/screens/work_update_form.dart" "والواجهة تعرضه" \
  "حُفظ التحديث، ولم يُسجَّل: "
# ودورةُ الإغلاق التي سُدّت لا تُفتح بالنقل: المنطق في دالّةٍ نقيّة تُقاس.
want_in "$STORE" "وحسابُ الحالة نقيٌّ يُقاس" \
  "workUpdateOutcome({"
echo ""

# ــــ العملُ لا يُولد ناقصاً، ولا يُكتب كاملاً عند التعديل ــــ
#
# دالّةُ الاعتماد كانت تبني مستند العمل بيدها فتنقصها حقول — ومنها حقولُ
# الحذف والتحويل السبعة. و`updateWork` كانت تكتب المستند كاملاً بـ`toMap()`
# وهي تكتب تلك السبعة دائماً. فتعديلُ عملٍ وُلد ناقصاً يُضيفها لأول مرّة،
# فتدخل في `affectedKeys`، وقاعدةُ `works` تمنع مسّها — فيُردّ الحفظ كلُّه.
# وكلُّ عملٍ أُنشئ باعتماد طلبٍ كان لا يُعدَّل إطلاقاً.
echo "والعملُ لا يُولد ناقصاً ولا يُكتب كاملاً عند التعديل:"
reject_within "التعديل لا يكتب المستند كاملاً" \
  "Future<void> updateWork(WorkItem work)" "update(work.toMap())"
want_within "بل حقول النموذج وحدها" \
  "Future<void> updateWork(WorkItem work)" "update(patch);" 45
want_in "functions/src/work_create.ts" "وبناءُ مستند العمل وحدةٌ نقيّة" \
  "export function buildWorkDoc("
want_in "functions/src/work_create.ts" "وحقول الحذف مكتوبةٌ فيه" "deletedReason: null,"
want_in "functions/src/work_create.ts" "وحقول التحويل كذلك" "convertedToId: null,"
want_in "$SRC" "والخادم يستعملها لا يبني بيده" "set(buildWorkDoc({"
# ودورةُ الإغلاق لا تبقى معطَّلةً في مسار الطلب: المعتمِد مقدّم الطلب.
want_in "functions/src/work_create.ts" "والمعتمِد مقدّم الطلب" \
  "export function closureForRequest("
echo ""

# ــــ البطاقةُ تُقرأ قراءةً واحدة ــــ
#
# الإدارةُ على بطاقة الدخول في موضعين: مفردٍ وقائمة. وكانت تُقرأ بطريقتين
# في المنصة الواحدة: قاعدةُ الأعمال تقبل الاثنين، و`canEditDept` تقبل
# القائمة وحدها، والعميلُ يقبل الاثنين. فمديرُ إدارةٍ بطاقتُه بالمفرد كان
# يعدّل أعمال إدارته ويُردّ عليه تعديلُ مشروعها — وهو ما بلّغ عنه.
echo "وبطاقةُ الإدارة تُقرأ قراءةً واحدة:"
want_in "$RULES" "القاعدة تقبل المفرد والقائمة" \
  "function canEditDept(deptId) { return isAdmin() || (isDeptManager() \&\& isMyDeptAny(deptId)); }"
reject_in "$RULES" "ولا تقتصر على القائمة" \
  "canEditDept(deptId) { return isAdmin() || (isDeptManager() \&\& isMyDeptOfManager(deptId)); }"
# ــ والعميلُ كذلك: والقراءةُ على `AppUser` لا في المتجر ــ
#
# كانت مكتوبةً في `app_store.dart` مرّتين (`myDepartmentIds`
# و`trackablePeople`)، فصارت مرّةً واحدةً على النموذج ويُحوَّل إليها
# الاثنان. وهذا الحارسُ يتبع الموضعَ الواحد لا أحدَ النسخ.
want_in "lib/models/app_user.dart" "والعميل كذلك — على النموذج" \
  "if (departmentIds.isNotEmpty) return departmentIds;"
want_in "lib/models/app_user.dart" "ويرجع إلى المفرد الموروث" \
  "return (one == null || one.isEmpty) ? const \[\] : \[one\];"
want_in "$STORE" "والمتجرُ يُحوّل إليها ولا يعيدها" \
  "currentUser?.allDepartmentIds"
reject_in "$STORE" "ولا نسخةَ ثانيةً في المتجر" "if (many.isNotEmpty) return many;"
# ورسالةُ الرفض تقول ما يُفعل لا رمزاً — راجع `readable_write_error_test.dart`.
want_in "$STORE" "ورسالةُ الرفض تسمّي العلاج" "static String readableWriteError("
echo ""

# ــــ التقارير الدورية: النطاقُ واحد، والمؤشرُ لا يُقرأ حكماً ــــ
#
# النطاقُ له ثلاثة أبواب — مدخلُ القائمة، والشاشة، والملفُّ المُصدَّر — وقد
# وقع في هذه المنصة أن انفتح بابٌ وأُغلق أخواه. فيُشترط أن يُبنى الثلاثةُ
# من تعريفٍ واحد في المتجر لا من ثلاثة شروطٍ متفرّقة.
echo "والتقارير الدورية بنطاقٍ واحد:"
want_in "$STORE" "تعريفُ من يفتح القسم في المتجر" \
  "bool get canViewPeriodicReports =>"
want_in "$STORE" "ومقارنةُ الإدارات لمن يقرأ الكلّ" \
  "bool get canCompareDepartments => canViewAllDepartments;"
want_in "lib/widgets/nav_entries.dart" "والقائمة تستعمله لا شرطاً ثانياً" \
  "if (store.canViewPeriodicReports) keys.add(NavKey.periodicReports);"
want_in "lib/screens/periodic_reports_screen.dart" "والشاشة كذلك" \
  "final compare = store.canCompareDepartments;"
# والتحفّظ نصٌّ واحد يُعرض ويُصدَّر — لا نسخةٌ في الشاشة تُنسى في الملفّ.
want_in "lib/reports/periodic_report.dart" "وتحفّظُ المؤشر نصٌّ واحد" \
  "const String kActivityDisclaimer ="
want_in "lib/screens/periodic_reports_screen.dart" "يُعرض على الشاشة" \
  "kActivityDisclaimer,"
want_in "lib/utils/report_export.dart" "ويُكتب في الملفّ" \
  "xls.TextCellValue(kActivityDisclaimer)"
# و«غير مسجّل» ليست صفراً: مهمةٌ أقدمُ من الحقل لا تُقرأ تقصيراً.
want_in "lib/models/project_task.dart" "والمهمةُ بلا تاريخٍ تقول إنها لا تعرف" \
  "bool? get finishedOnTime =>"
want_in "lib/utils/report_export.dart" "وتُصدَّر «غير مسجّل» لا خليةً فارغة" \
  "(غير مسجّل)"
# والتأخّر يُقاس بنهاية الفترة لا بيوم القراءة — وإلا تغيّر رقمُ تقريرٍ مضى.
want_in "lib/reports/periodic_report.dart" "والتأخّر يُقاس عند نهاية الفترة" \
  "bool isTaskLateAt(ProjectTask task, DateTime asOf) {"
reject_in "lib/reports/periodic_report.dart" "ولا بلحظة فتح الشاشة" \
  "isTaskLateAt(t, DateTime.now())"
# والنصُّ الخام لا يدخل مولّد PDF: همزةٌ محرّكةٌ في أوّله تُسقط الملفَّ كلَّه.
want_in "lib/utils/report_export.dart" "والنصُّ يُنقّى قبل PDF" \
  "static List<String> _safeRow(List<String> row)"
echo ""

# ــــ الجولة الثانية: «—» ليست صفراً، والمدّة إعدادٌ يُقرأ ــــ
#
# المبدأ نفسه الذي حكم «غير مسجّل»: العملُ لا يحمل مهامّ في هذه المنصة، فصفرٌ
# في خانة مهامّه **ادّعاءُ عدم** لا نقصُ بيان. وكذلك «لا أساس للمقارنة»:
# مشروعٌ بلا تحديثٍ قبل الفترة لم يبدأ من الصفر — لا نعرف أين كان.
echo "و«—» ليست صفراً في تقرير المشاريع:"
want_in "lib/reports/periodic_report.dart" "أعدادُ البند تقبل العدم" \
  "final int? tasksCompleted;"
want_in "lib/reports/periodic_report.dart" "والعملُ يُكتب عدماً لا صفراً" \
  "tasksCompleted: null,"
want_in "lib/utils/report_export.dart" "والتصدير يكتب «—» لا خليةً فارغة" \
  "v == null ? xls.TextCellValue('—') : xls.IntCellValue(v);"
want_in "lib/screens/periodic_reports_screen.dart" "والشاشة كذلك" \
  "v == null ? '—' : '\$v',"
want_in "lib/reports/periodic_report.dart" "و«لا أساس للمقارنة» لا صفر" \
  "progressAtStart == null ? null : progressNow - progressAtStart!;"
reject_in "lib/utils/report_export.dart" "ولا يُقرأ غيابُ الأساس صفراً في الملفّ" \
  "progressAtStart ?? 0"

# والمدّةُ إعدادٌ يُقرأ لا رقمٌ مكتوب: حقلٌ يُحفظ ولا يُقرأ أسوأ من عدمه.
echo "ومدّةُ الجمود إعدادٌ يُقرأ:"
want_in "lib/models/periodic_report_settings.dart" "الإعداد نموذجٌ مستقل" \
  "class PeriodicReportSettings {"
want_in "$STORE" "والمتجر يُمرّرها إلى المحرّك" \
  "inactiveAfterDays: periodicReportSettings.inactiveAfterDays,"
want_in "lib/reports/periodic_report.dart" "والمحرّك يقرؤها لا رقماً مكتوباً" \
  "days < input.inactiveAfterDays"
want_in "lib/screens/periodic_reports_screen.dart" "والمعيار يُعرض مع القائمة" \
  "\${report.inactiveAfterDays} أيام أو أكثر"
want_in "lib/utils/report_export.dart" "ويخرج مع الورقة كذلك" \
  "المعيار: بلا تحديث منذ \${report.inactiveAfterDays} أيام أو أكثر"

# والحالاتُ الأربع بالقاعدة التي اختِيرت: «يحتاج تدخل» متأخّرٌ ومعه مانع.
echo "وحالاتُ المشروع بقاعدتها:"
want_in "lib/reports/periodic_report.dart" "التدخّل يشترط التأخّر ومعه مانع" \
  "if (isLate \&\& (blocked || stalled)) return ReportItemStatus.needsIntervention;"
want_in "lib/reports/periodic_report.dart" "والمكتملُ لا يُطالَب بتحديث" \
  "if (isCompleted) return ReportItemStatus.normal;"

# والتصفيةُ تسري على التقرير كلِّه لا على جدولٍ واحد.
echo "والتصفيةُ تسري على التقرير كلِّه:"
want_in "lib/reports/periodic_report.dart" "المدخلاتُ تُصفّى قبل الحساب" \
  "final input = applyFilters(raw, filters, range);"
want_in "lib/reports/periodic_report.dart" "والإسقاطُ متسلسل" \
  "projectIds.contains(t.projectId) \&\&"

# ولا زرَّ ترويسةٍ ثانياً: المشترك موجود.
# `reject_in` على الاسم كلِّه لا على تعريف الصنف وحده: طفرةٌ استبدلت
# **استدعاءً** واحداً بـ`_BandButton` مرّت من حارسٍ يفحص التعريف — فوُسّع.
# والحارسُ الموجب («يوجد BandButton») غير قابلٍ للقياس هنا: يبقى ماراً ولو
# بقي استدعاءٌ واحدٌ صحيحاً، فحُذف بدل أن يُترك يطمئن بلا أن يحرس.
reject_in "lib/screens/periodic_reports_screen.dart" "ولا نسخةَ ثانيةً من زرّ الترويسة" \
  "_BandButton"
echo ""

# ــــ بياناتُ العقد: تُولد مكتوبةً، وغيابُها يُقال ولا يُملأ ــــ
#
# المفاتيحُ السبعة تُكتب **دائماً ولو فارغة**. ووقع في هذا المستودع مرّتين
# أن سجلاً وُلد ناقصاً مفتاحاً فرُدّ أوّلُ تعديلٍ عليه — في الأعمال
# (`ba220b7`) وفي `completedAt`. وقاعدةُ `projects` اليوم قائمةُ منعٍ لا
# سماح، فالخطر غيرُ قائم الآن ويعود بأوّل تضييق. راجع
# `test_rules/project_contract.rules.test.mjs`.
echo "وبياناتُ العقد تُولد مكتوبة:"
want_in "lib/models/project.dart" "المفاتيح السبعة في toMap" \
  "'contractorName': contractorName,"
want_in "lib/models/project.dart" "والمدّة تُكتب ولو فارغة" "'durationDays': durationDays,"
want_in "lib/models/project.dart" "والقيمة كذلك" "'contractValue': contractValue,"
reject_in "lib/models/project.dart" "ولا يسقط مفتاحٌ عند الفراغ" \
  "if (contractValue != null) 'contractValue'"
want_in "$SRC" "والخادمُ يكتبها عند الاعتماد" "contractorName: typeof payload.contractorName"
want_in "$SRC" "وتاريخاً لا يُفهم يُقرأ عدماً لا Invalid Date" \
  "if (Number.isNaN(parsed.getTime())) return null;"

# والغيابُ «غير مسجّل» لا صفرٌ ولا تاريخُ اليوم.
echo "وغيابُ العقد يُقال لا يُملأ:"
# والنمطُ يخصّ **قيمة العقد** وحدها: `progressPercent` يبدأ صفراً بحقّ —
# مشروعٌ لم يُنجَز منه شيء أُنجز صفراً، وذلك خبرٌ صادق. أمّا قيمةُ العقد
# فصفرُها ادّعاءُ رقمٍ لا نقصُ بيان. وحارسٌ يخلط الاثنين يمنع الصواب.
reject_in "lib/models/project.dart" "لا صفرَ لقيمةٍ غير مسجّلة" \
  "contractValue: (json\['contractValue'\] as num?)?.toDouble() ?? 0"
reject_in "lib/models/project.dart" "ولا تاريخَ اليوم لتاريخٍ غائب" \
  "contractDate: (json\['contractDate'\] as Timestamp?)?.toDate() ?? DateTime.now()"
# والنمطُ على **الدالّة** التي تقرّرها لا على العبارة: العبارةُ كانت مكتوبةً
# سبعَ مرّات، وطفرةٌ أسقطت إحداها نجت من الحارس. فجُمعت في موضعٍ واحد.
want_in "lib/screens/project_detail_screen.dart" "والشاشة تقولها في موضعٍ واحد" \
  "value: value ?? 'غير مسجّلة',"
want_in "lib/screens/project_form_dialog.dart" "والنموذجُ يقولها كذلك" \
  "ما لا يُملأ يبقى «غير مسجّل»"
# والمدّةُ منصوصةٌ لا مشتقّة من التاريخين — راجع `Project.durationDays`.
reject_in "lib/models/project.dart" "والمدّةُ لا تُشتقّ من التاريخين" \
  "durationDays => dueDate.difference(startDate)"
echo ""

# ــــ تعديلُ بيانات المشروع: ثلاثُ قوائمَ تُقرأ معاً ــــ
#
# الحقولُ المعتمَدة مكتوبةٌ في ثلاثة مواضع، ولكلٍّ سببُه:
#
#   * `lib/models/project_edit.dart`   — ما يعرضه النموذج ويحسب فروقه.
#   * `functions/src/approval_stage.ts` — ما يقبله الخادمُ عند التطبيق،
#     وقائمتُه **مغلقة** لأنها تُطبَّق بصلاحية المدير فتتجاوز كل قاعدة.
#   * `firestore.rules`                — ما يُمنع من الكتابة المباشرة،
#     وقائمتُها قائمةُ **منع** لئلا تُردّ حقولٌ تُضاف مستقبلاً.
#
# ولو افترقت الأولى عن الثانية: حقلٌ يعرضه النموذج ويرفضه الخادمُ عند
# الاعتماد النهائي — بعد أن مرّ الطلبُ بمرحلتين. أو حقلٌ يقبله الخادم ولا
# يُرى في جدول الفروق، فيُطبَّق ما لم يُعرض.
#
# ولو خرج حقلٌ من قائمة المنع في القاعدة: كُتب مباشرةً بلا اعتماد — وهو
# البابُ نفسُه الذي أُغلق في هذه الدفعة.
#
# **وهذا الحارسُ يقارن القوائمَ لا يبحث عن نصّ**: يستخرج الثلاثةَ ويقابلها،
# فطفرةٌ تُسقط حقلاً من إحداها تعضّ ولو بقيت الكلمةُ موجودةً في الملفّ.
echo "وقوائمُ الحقول المعتمَدة متطابقة:"

# والقائمةُ المرجعية مكتوبةٌ هنا **نسخةً رابعة**، وذلك مقصود: ثلاثُ نسخٍ
# تُقارن بواحدةٍ ثابتة، فمن أسقط حقلاً من إحداها أو دسّ فيها حقلاً عضّه
# الحارس. ولو قُورنت النسخُ الثلاث ببعضها لَمرّ حذفٌ وقع في ثلاثتها معاً.
#
# ولا يُستعمل هنا إلا `grep -F` و`grep -A` و`printf` — بلا تعابير نمطية ولا
# `sed` ولا `awk`. وسببُه مكتوبٌ في `build_web.sh`: حارسٌ كُتب على أدوات
# GNU وسقط على أدوات macOS **فأوقف نشر المستخدم**. وقد تكرّر ذلك في هذا
# الحارس نفسه، فأُخرجت منه كلُّ عبارةٍ تختلف بين الأداتين.
EDITABLE_FIELDS="name description priority categoryIds \
contractDate contractStartDate contractEndDate invoiceDueDate \
durationDays contractValue contractorName"

# الكتلةُ تُقتطع بالسطور التالية للترويسة لا بمدى `sed`: القائمتان في
# `project_edit.dart` بالتنسيق نفسه (`  'name',`)، فبحثٌ في الملفّ كلّه
# يجد الحقلَ في قائمة «الجوهري» ولو حُذف من قائمة «المعتمَد».
DART_BLOCK="$(grep -F -A 12 "const List<String> kEditableProjectFields = [" \
  lib/models/project_edit.dart)"
TS_BLOCK="$(grep -F -A 12 "export const EDITABLE_FIELDS" \
  functions/src/approval_stage.ts)"
RULES_BLOCK="$(grep -F -A 6 "hasAny(['dueDate', 'departmentId', 'createdByUid'," \
  firestore.rules)"

missing_dart=""
missing_ts=""
missing_rules=""
for field in $EDITABLE_FIELDS; do
  printf '%s\n' "$DART_BLOCK" | grep -F -q "'$field'," ||
    missing_dart="$missing_dart $field"
  printf '%s\n' "$TS_BLOCK" | grep -F -q "\"$field\"," ||
    missing_ts="$missing_ts $field"
  printf '%s\n' "$RULES_BLOCK" | grep -F -q "'$field'" ||
    missing_rules="$missing_rules $field"
done

# ــــ وحارسٌ لا يستطيع القياس لا يتّهم ــــ
#
# كتلةٌ خرجت **فارغة** ليست قائمةً ناقصة: هي إخفاقُ الحارس في القراءة —
# نمطٌ لم يطابق، أو أداةٌ تصرّفت على نظامٍ لا أراه غيرَ ما تصرّفت عندي.
# فيُقال ذلك بلفظه، **ولا يُوقَف النشر**: أداةٌ كُتبت لحماية المنصة يجب
# ألّا تكون هي ما يمنع إصلاحها من الوصول. وقد وقع ذلك مرّتين.
#
# أمّا كتلةٌ قُرئت فعلاً وخالفت، فتلك مخالفةٌ تُوقف — وهي المقصودة أصلاً.
WARN=0

# هل تعذّر القياس؟ يُقال ويُعاد `yes`، فيتخطّى النداءُ حكمَه.
unmeasured() {
  local name="$1" block="$2"
  if [ -z "$block" ]; then
    echo "  ⚠ تعذّر قياس: $name"
    echo "      لم تُقرأ الكتلة من الملفّ — النمط لم يطابق شيئاً."
    echo "      وهذا عطلٌ في الحارس لا في المنصة، ولا يُوقف النشر."
    WARN=$((WARN + 1))
    return 0
  fi
  return 1
}

list_report() {
  local name="$1" missing="$2" block="$3"
  unmeasured "$name" "$block" && return 0
  if [ -z "$missing" ]; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      حقولٌ مفقودة:$missing"
    echo "      وما قُرئ فعلاً:"
    printf '%s\n' "$block" | sed 's/^/        /'
    FAIL=$((FAIL + 1))
  fi
}

list_report "الأحدَ عشرَ حقلاً في العميل" "$missing_dart" "$DART_BLOCK"
list_report "وهي نفسُها في الخادم" "$missing_ts" "$TS_BLOCK"
list_report "وكلُّها ممنوعةٌ من الكتابة المباشرة في القاعدة" "$missing_rules" "$RULES_BLOCK"

# والاتجاهُ الآخر: لا يُدسّ حقلٌ زائد. فالعددُ يُقاس كما تُقاس الأسماء.
count_report() {
  local name="$1" count="$2" block="$3" expected="${4:-11}"
  unmeasured "$name" "$block" && return 0
  if [ "$count" = "$expected" ]; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      عُدَّ $count لا ١١، وما قُرئ:"
    printf '%s\n' "$block" | sed 's/^/        /'
    FAIL=$((FAIL + 1))
  fi
}

count_report "ولا حقلَ زائدٌ في العميل" \
  "$(printf '%s\n' "$DART_BLOCK" | grep -c "^  '")" "$DART_BLOCK"
count_report "ولا في الخادم" \
  "$(printf '%s\n' "$TS_BLOCK" | grep -c '^  "')" "$TS_BLOCK"

# والبواباتُ القائمةُ لا تمرّ من هذا المسار: لها مساراتُها، ولو قُبلت هنا
# لصارت هذه بابَ التفافٍ حولها.
for gate in dueDate departmentId managerUids; do
  if printf '%s\n' "$DART_BLOCK" | grep -F -q "'$gate',"; then
    echo "  ✗ و«${gate}» لا تمرّ من طلب التعديل"
    FAIL=$((FAIL + 1))
  else
    echo "  ✔ و«${gate}» لا تمرّ من طلب التعديل"
    PASS=$((PASS + 1))
  fi
done

# ــ ومسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة ــ
#
# في الخادم وفي مرآته في العميل معاً. وأخطرُ ما يُنقض هنا سطرٌ واحد:
# `if (isAdmin) return true;` في أوّل `canApprove` — كان موجوداً فعلاً،
# فيظهر الزرُّ ويردّه الخادم.
echo "والمرحلةُ هي الحَكَم لا الدور:"
want_in "functions/src/approval_stage.ts" "الخادمُ يشترط دورَ مدير الإدارة"   'if (actor.role !== "departmentManager") return false;'
want_in "functions/src/approval_stage.ts" "ولا يُطبَّق التغييرُ إلا عند الأخيرة"   "return nextStage(stage) === null;"
want_in "$SRC" "والفرعُ يعود قبل الختم عند المرحلة الأولى"   "if (!appliesAt(stage)) {"
want_in "$SRC" "وتبدُّلُ القيمة يُردّ باسم الحقل"   'stale.map(fieldLabel).join'
want_in "lib/data/app_store.dart" "والعميلُ يفحص النوعَ قبل isAdmin"   "if (r.type == ApprovalType.projectEdit) {"
# ــ وأخطرُ ما يُنقض هنا سطرٌ واحد ــ
#
# `if (isAdmin) return true;` أوّلَ `canApprove` — كان موجوداً فعلاً، فيظهر
# الزرُّ لمسؤول النظام على مرحلةٍ ليست له ثم يردّه الخادم.
#
# ويُقاس بالسطر التالي للترويسة: التعليقُ الذي فوق الفحص يقع بينهما اليوم،
# فالطفرةُ التي تدسّ السطرَ تدسّه ملاصقاً للقوس فتُلتقط.
NEXT_LINE="$(grep -F -A 1 "bool canApprove(ApprovalRequest r) {" \
  lib/data/app_store.dart | tail -1)"
case "$NEXT_LINE" in
  *"if (isAdmin) return true;"*)
    echo "  ✗ ولا يُفتح بابُ المسؤول على مرحلةٍ ليست له"
    echo "      أوّلُ سطرٍ في canApprove:$NEXT_LINE"
    FAIL=$((FAIL + 1))
    ;;
  *)
    echo "  ✔ ولا يُفتح بابُ المسؤول على مرحلةٍ ليست له"
    PASS=$((PASS + 1))
    ;;
esac
echo ""

# ــــ الجوهريُّ: نسختان تُقارنان بمرجعٍ ثابت ــــ
#
# القائمةُ تقرّر شيئين: ما يُميَّز بلونٍ للمعتمِد في البطاقة، **ومن يُشعَر**
# بعد الاعتماد. فحقلٌ يسقط منها يمرّ في سطرٍ يُشبه تصحيح إملاء، ولا يعلم به
# مديرُ الإدارة ولا مديرُ المشروع.
#
# وهي في موضعين: `kSensitiveProjectFields` في العميل و`SENSITIVE_FIELDS` على
# الخادم. وتُقارنان بالقائمة المرجعية أدناه لا ببعضهما — فحذفٌ وقع فيهما
# معاً يُلتقط.
echo "والقائمةُ الجوهرية واحدة:"

SENSITIVE_FIELDS="name departmentId managerUids startDate dueDate \
contractStartDate contractEndDate invoiceDueDate contractValue durationDays"

DART_SENSITIVE="$(grep -F -A 12 "const Set<String> kSensitiveProjectFields = {" \
  lib/models/project_edit.dart)"
TS_SENSITIVE="$(grep -F -A 12 "export const SENSITIVE_FIELDS" \
  functions/src/approval_stage.ts)"

missing_dart_s=""
missing_ts_s=""
for field in $SENSITIVE_FIELDS; do
  printf '%s\n' "$DART_SENSITIVE" | grep -F -q "'$field'," || missing_dart_s="$missing_dart_s $field"
  printf '%s\n' "$TS_SENSITIVE" | grep -F -q "\"$field\"," || missing_ts_s="$missing_ts_s $field"
done

list_report "العشرةُ الجوهرية في العميل" "$missing_dart_s" "$DART_SENSITIVE"
list_report "وهي نفسُها في الخادم" "$missing_ts_s" "$TS_SENSITIVE"

count_report "ولا حقلَ جوهريٌّ زائد في العميل" \
  "$(printf '%s\n' "$DART_SENSITIVE" | grep -c "^  '")" "$DART_SENSITIVE" 10
count_report "ولا في الخادم" \
  "$(printf '%s\n' "$TS_SENSITIVE" | grep -c '^  "')" "$TS_SENSITIVE" 10

# والإشعارُ يقع عند الجوهريّ، وعند المرحلة الأخيرة وحدها.
want_in "$SRC" "والإشعارُ يُسمّي ما تغيّر لا يقول «تغيّر شيء»" \
  "sensitive.map(fieldLabel).join"
echo ""

# ــــ نقلُ المشروع: التوابعُ تنتقل معه ــــ
#
# ــ العطلُ الذي أوجب هذا الحارس ــ
#
# المهامُّ والتحديثاتُ والمخاطرُ والعوائق تنسخ إدارةَ المشروع على نفسها،
# وقاعدةُ قراءتها تقرأ المنسوخ. فمن نقل المشروعَ وحده ترك مديرَ الإدارة
# الجديدة يرى المشروع ولا يرى مهامَّه. وهو ما كان يقع في `moveSectionToDepartment`
# ويُقاس في `test_rules/department_transfer.rules.test.mjs`.
#
# فيُحرس أن الأربعة تُختم، وأن النقل من الخادم لا من العميل.
echo "ونقلُ المشروع ينقل توابعَه:"
want_fixed_in "$SRC" "المجموعاتُ الأربع في موضعٍ واحد" \
  'const CHILD_COLLECTIONS = ["tasks", "dailyUpdates", "risks", "blockers"];'
want_fixed_in "$SRC" "والتوابعُ تُختم بالإدارة الجديدة" \
  'batch.update(child.ref, {departmentId: newDepartmentId});'
want_in "$SRC" "والقسمُ يُفرَّغ فلا يشير إلى إدارةٍ أخرى" "sectionId: null,"
want_in "$SRC" "وتاريخُ النقل يُسجَّل" "departmentTransferredAt: now(),"
want_in "$SRC" "ولإصلاح ما نُقل سابقاً دالّةٌ تُعاد بلا ضرر" \
  "export const restampChildDepartments"
# والنقلُ لا يقع من العميل: التوابعُ تُختم بصلاحية المدير وحدها.
want_in "lib/data/app_store.dart" "والعميلُ ينقل عبر الخادم لا بيده" \
  "httpsCallable('transferProjectDepartment')"
reject_in "lib/data/app_store.dart" "ولا يكتب الإدارة على المشروع مباشرةً" \
  "'departmentId': newDepartmentId"
echo ""

# ــــ وسجلُّ المشروع لا يُفتح على فراغ ــــ
#
# السجلُّ يُقرأ باستعلامٍ على `targetId`. فما لم تُختم الأفعالُ بهدفها لم
# يظهر منها شيء — وشاشةٌ تقول «لا تعديلات» على مشروعٍ عُدّل عشراً أسوأ من
# ألّا تُعرض.
echo "وأفعالُ المشروع تُختم بهدفها:"
# ــ والعددُ **مضبوطٌ** لا «على الأقلّ» ــ
#
# حدٌّ أدنى لا يكشف حذفَ واحدٍ من اثني عشر: يبقى فوق الحدّ فيمرّ. وقد قيس
# ذلك بطفرة، فصار العددُ مضبوطاً.
#
# ومن أضاف فعلاً جديداً يمسّ مشروعاً وختمه يرفع الرقم هنا **عن قصد**، ويُقرأ
# رفعُه في المراجعة — كما في حدّ قائمة الاستثناء في `audit_coverage_test.sh`.
STAMPED="$(grep -c "targetType: 'project'" lib/data/app_store.dart)"
if [ "$STAMPED" = "12" ]; then
  echo "  ✔ اثنا عشرَ فعلاً مختوماً في العميل"
  PASS=$((PASS + 1))
else
  echo "  ✗ اثنا عشرَ فعلاً مختوماً في العميل"
  echo "      عُدَّ $STAMPED لا ١٢ — أحُذف ختمٌ من فعلٍ يمسّ مشروعاً، أم أُضيف فعلٌ ولم يُرفع الرقم؟"
  FAIL=$((FAIL + 1))
fi
SERVER_STAMPED="$(grep -c 'targetType: "project"' "$SRC")"
if [ "$SERVER_STAMPED" = "5" ]; then
  echo "  ✔ وخمسةٌ على الخادم: الإنشاءُ والموعدُ والمديرُ والتعديلُ والنقل"
  PASS=$((PASS + 1))
else
  echo "  ✗ وخمسةٌ على الخادم"
  echo "      عُدَّ $SERVER_STAMPED لا ٥ — الإنشاءُ والموعدُ والمديرُ والتعديلُ والنقل"
  FAIL=$((FAIL + 1))
fi
# والفهرسُ يُنشر مع القواعد، وإلا لم يصل أبداً.
want_in "firestore.indexes.json" "وفهرسُ سجل المشروع موجود" '"collectionGroup": "auditLog"'
want_in "tool/deploy.sh" "والفهارسُ تُنشر مع القواعد" \
  "firestore:rules,firestore:indexes"
echo ""

echo "══════════════════════════════"
if [ "$WARN" -gt 0 ]; then
  echo "نجح: $PASS · فشل: $FAIL · تعذّر القياس: $WARN"
  echo "⚠ $WARN فحصاً لم يُقَس — أبلغ بالسطور المعلَّمة ⚠ حتى يُصلَح الحارس."
else
  echo "نجح: $PASS · فشل: $FAIL"
fi
[[ $FAIL -eq 0 ]] || exit 1
