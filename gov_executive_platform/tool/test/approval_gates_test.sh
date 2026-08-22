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

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
