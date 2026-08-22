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

echo "تعديل الطلب قبل اعتماده محصور بمسؤول النظام:"
want "الرفض عند غياب صفة مسؤول النظام" 'payloadOverride && !isAdminCaller'
want "ومقصور على نوعَي المشروع والعمل" 'data.type !== "projectCreate" && data.type !== "workCreate"'
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
if [ "$(grep -c '&& closureRespected();' "$RULES")" = "2" ]; then
  echo "  ✔ ومطبَّقة على الأعمال ومهام المشاريع معاً"
  PASS=$((PASS + 1))
else
  echo "  ✗ ومطبَّقة على الأعمال ومهام المشاريع معاً"
  echo "      المتوقَّع تطبيقان، والموجود: $(grep -c '&& closureRespected();' "$RULES")"
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

# التعطيل قائمٌ ويعمل، ولم تمسّه هذه الجولة. وهذه الفحوص تمنع أن يسقط في
# تعديلٍ لاحق للحذف — فكلاهما يقع في `setUserStatus` وجوارها.
echo "والتعطيل لم ينكسر:"
want "حساب المصادقة يُعطَّل مع الحالة" 'await admin.auth().updateUser(uid, {disabled: !approved});'
want "والجلسات القائمة تُبطَل" 'await admin.auth().revokeRefreshTokens(uid);'
want "والبطاقة تُعاد بلا اعتماد" 'approved,'
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

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
