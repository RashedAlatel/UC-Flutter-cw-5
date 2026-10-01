#!/usr/bin/env bash
#
# هل يميّز سكربت النشر «التخزين غير مفعَّل» عن «فشل لسبب آخر» فعلاً؟
#
# كانت الرسالة واحدة لكل فشل: «على الأرجح أن Storage غير مفعَّل» — فمن فشل
# نشره لخطأ في القواعد أو لانقطاع شبكة يُصرَف عن سببه إلى سببٍ مُخمَّن.
# وهذا الاختبار يغذّي الدالة بنصوص حقيقية ويشترط أن تفصلها.
#
# التشغيل:  ./tool/test/storage_message_test.sh
set -uo pipefail

cd "$(dirname "$0")/../.."

# تُستخرج الدالة من السكربت نفسه لا تُنسخ هنا: نسخةٌ ثانية تفترق عن الأصل
# بأول تعديل، فيمرّ الاختبار على شيء لا يعمل به أحد.
eval "$(sed -n '/^storage_not_enabled()/,/^}/p' tool/deploy.sh)"

pass=0
fail=0

check() {
  local name="$1" text="$2" want="$3"
  if storage_not_enabled "$text"; then got="yes"; else got="no"; fi
  if [ "$got" = "$want" ]; then
    printf '  ✔ %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  ✘ %s — توقّعنا «%s» فجاء «%s»\n' "$name" "$want" "$got"; fail=$((fail + 1))
  fi
}

echo "تمييز رسالة التخزين:"

# النصّ الحقيقي الذي وصل المستخدم من Firebase.
check "رسالة «غير مفعَّل» الحقيقية" \
  "Error: Firebase Storage has not been set up on project 'project-management-syste-8e599'. Go to https://console.firebase.google.com/project/project-management-syste-8e599/storage and click 'Get Started' to set up Firebase Storage." \
  yes

check "صيغة «لا يوجد bucket افتراضي»" \
  "Error: No default bucket found for this project." \
  yes

# وهذه أسبابٌ أخرى تماماً: نسبتها إلى التعطيل تُضيّع وقت من يشخّص.
check "خطأ في القواعد نفسها" \
  "Error: Compilation errors in storage.rules: [E] 12:4 - Unexpected token 'allow'." \
  no

check "صلاحية ناقصة" \
  "Error: HTTP Error: 403, The caller does not have permission" \
  no

check "انقطاع شبكة" \
  "Error: Failed to make request to https://firebaserules.googleapis.com — ETIMEDOUT" \
  no

printf '\n%d ناجح، %d فاشل\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
