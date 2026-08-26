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
  local name="$1" signature="$2" pattern="$3"
  if grep -A 26 "$signature" "$STORE" | grep -q "$pattern"; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      لم يُعثر على «$pattern» داخل «$signature»"
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

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
