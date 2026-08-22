#!/usr/bin/env bash
#
# جدول رتبة الإسناد مكتوب في **ثلاثة** مواضع، ولا سبيل لمشاركته بينها:
# لغاتٌ ثلاث ومحرّكاتٌ ثلاثة (Dart في المتصفح، TypeScript على الدوال، لغة
# قواعد Firestore على الخادم).
#
# ــــ ولماذا حارسٌ لهذا بالذات؟ ــــ
#
# لأن الاختلاف بينها **لا يُنتج خطأ**: تُترجم الثلاثة وتعمل، ويبقى العطل
# صامتاً حتى يجد مستخدمٌ اسماً في قائمته ثم يُرفض إسناده على الخادم بلا سبب
# مفهوم — أو أسوأ: تُصفّى الواجهة ويقبل الخادم، فيبقى الباب مفتوحاً ويُظنّ
# مغلقاً.
#
# فهذا الحارس يقرأ الرتبة لكل دور من المواضع الثلاثة ويشترط تطابقها.
set -uo pipefail
cd "$(dirname "$0")/../.."

DART="lib/models/assignment_policy.dart"
TS="functions/src/index.ts"
RULES="firestore.rules"

PASS=0
FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ✘ $1"; FAIL=$((FAIL + 1)); }

# الرتبة في Dart: `case UserRole.<role>:` يتلوها `return <n>;`
dart_rank() {
  awk -v role="$1" '
    $0 ~ ("case UserRole\\." role ":") { want = 1; next }
    want && /return [0-9]+;/ { gsub(/[^0-9]/, ""); print; exit }
  ' "$DART"
}

# الرتبة في TypeScript: سطرٌ `<role>: <n>,` داخل ASSIGN_RANK.
ts_rank() {
  awk -v role="$1" '
    /const ASSIGN_RANK/ { inside = 1; next }
    inside && /^};/ { exit }
    inside && $0 ~ ("^  " role ": ") { gsub(/[^0-9]/, ""); print; exit }
  ' "$TS"
}

# الرتبة في القواعد: `r == '<role>' ? <n>` — وآخر سطرٍ بلا شرط هو الافتراضي.
rules_rank() {
  awk -v role="$1" '
    $0 ~ ("r == ." role ". \\? [0-9]") {
      match($0, /\? [0-9]+/); print substr($0, RSTART + 2, RLENGTH - 2); exit
    }
  ' "$RULES"
}

echo "▶ حارس تطابق جدول رتبة الإسناد (Dart · TypeScript · القواعد)"
echo ""

for ROLE in systemAdmin executiveViewer departmentManager projectOfficer custom; do
  D="$(dart_rank "$ROLE")"
  T="$(ts_rank "$ROLE")"
  R="$(rules_rank "$ROLE")"
  if [ -z "$D" ] || [ -z "$T" ] || [ -z "$R" ]; then
    bad "$ROLE: رتبةٌ غير موجودة في أحد المواضع (Dart='$D' TS='$T' Rules='$R')"
  elif [ "$D" = "$T" ] && [ "$T" = "$R" ]; then
    ok "$ROLE = $D في المواضع الثلاثة"
  else
    bad "$ROLE يختلف: Dart=$D · TS=$T · القواعد=$R"
  fi
done

# «موظف» هو الافتراضي في القواعد (بلا شرط `r ==`)، فيُفحص بالقيمة المكتوبة.
D_EMP="$(dart_rank employee)"
T_EMP="$(ts_rank employee)"
R_EMP="$(awk '/function roleRank\(r\)/ { inside = 1 } inside && /^           : [0-9]+;/ { gsub(/[^0-9]/, ""); print; exit }' "$RULES")"
if [ "$D_EMP" = "$T_EMP" ] && [ "$T_EMP" = "$R_EMP" ] && [ -n "$R_EMP" ]; then
  ok "employee = $D_EMP في المواضع الثلاثة (وهو افتراضي القواعد)"
else
  bad "employee يختلف: Dart=$D_EMP · TS=$T_EMP · القواعد=$R_EMP"
fi

# والقاعدة نفسها — لا الجدول وحده: المقارنة `<=` في المواضع الثلاثة.
grep -q 'assignRank(target.role) <= assignRank(actor.role)' "$DART" \
  && ok "Dart يقارن بـ«أقل أو يساوي»" || bad "Dart لا يقارن بـ«أقل أو يساوي»"
grep -q 'assignRank(targetRole) > actorRank' "$TS" \
  && ok "TypeScript يرفض ما هو **أعلى** فقط" || bad "TypeScript لا يرفض بالرتبة"
grep -q 'rankOfUser(uid) <= roleRank(role())' "$RULES" \
  && ok "القواعد تقارن بـ«أقل أو يساوي»" || bad "القواعد لا تقارن بـ«أقل أو يساوي»"

echo ""
echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ]
