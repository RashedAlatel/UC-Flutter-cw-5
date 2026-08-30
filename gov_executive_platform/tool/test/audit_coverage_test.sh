#!/usr/bin/env bash
#
# حارس تغطية سجل التدقيق.
#
# ــــ الوعد الذي يحرسه ــــ
#
# طلب مسؤول النظام أن يُسجَّل **كل تغيير** على بيانات الوزارة. وهذا وعدٌ
# يسقط بصمت: تُضاف دالّة كتابةٍ جديدة بلا سطر سجل، فلا يصيح تحليلٌ ولا
# اختبار — ويبقى فعلٌ في المنصة بلا أثر، ولا يُكتشف إلا يوم يُسأل «من فعل
# هذا؟» فلا يُجاب.
#
# فيُقاس هنا: كل دالّةٍ تكتب في Firestore من `app_store.dart` إمّا أن
# تُسجّل، وإمّا أن تكون في قائمة استثناءٍ **مكتوبٍ سببُها**.
#
# وهو فحصٌ نصّي، وهو أضعف من اختبار حقيقي ويُقال ذلك بحدّه: يمنع أن **يختفي**
# سطرُ السجل من دالّة — وقد قِيس ذلك بطفرةٍ تحذفه فعضّ. ولا يرى ما بقي
# نصُّه وسقط أثرُه: سطرٌ مُعطَّل بـ`if (false)` يمرّ عليه، وقد جُرّب فمرّ.
# فهو حارسُ حذفٍ لا حارسُ صحّة، ومن أراد الثانية فليكتب اختباراً.
#
# الاستخدام:  ./tool/test/audit_coverage_test.sh
set -uo pipefail

cd "$(dirname "$0")/../.."

STORE="lib/data/app_store.dart"

# ــــ الاستثناءات، بصنفين لا صنفٍ واحد ــــ
#
# (أ) ما يُسجَّل على الخادم: تنادي دالّةً خلفية تكتب السطر بنفسها بصلاحية
#     المدير. وهو **أوثق** من التسجيل من المتصفّح لا أنقص — إذ لا يستطيع
#     العميل تزويره ولا تخطّيه.
LOGGED_ON_SERVER="
approveRequest
rejectRequest
adminCreateUser
setUserRole
setUserStatus
setScopedGrant
setPermissionOverrides
deleteUserAccount
restampUserClaims
stampChildMembership
deleteDailyUpdate
convertRecord
applyRolePermissions
generateDailyReportNow
bootstrapFirstAdmin
returnRequestForRevision
"

# (ب) ما ليس تغييراً على بيانات الوزارة: تفضيلاتٌ شخصية لا يراها غير
#     صاحبها، أو قراءةٌ لا تُغيّر شيئاً، أو ختمُ بطاقةِ الدخول نفسها.
NOT_MINISTRY_DATA="
saveMyDashboardWidgets
resetMyDashboardWidgets
inspectUserForDeletion
checkBootstrapNeeded
syncMyClaims
signUp
"
# ملحوظةٌ على `signUp`: من يُسجّل نفسه **غير معتمد بعد**، وقاعدة `auditLog`
# تشترط الاعتماد — فلا يستطيع أن يكتب سطراً أصلاً. وطلبُ التسجيل نفسه هو
# السجل، واعتمادُه يُكتب على الخادم.

PASS=0
FAIL=0

report() {
  local name="$1" ok="$2" detail="${3:-}"
  if [ "$ok" = "1" ]; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    [ -n "$detail" ] && echo "      $detail"
    FAIL=$((FAIL + 1))
  fi
}

echo "▶ حارس تغطية سجل التدقيق"
echo ""

# يستخرج كل دالّةٍ تكتب، ويقول أتُسجّل أم لا.
UNLOGGED="$(python3 - "$STORE" <<'PY'
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
lines = src.split('\n')
pat = re.compile(r'^  (?:Future<[^>]*>|Future) ([a-z][A-Za-z0-9_]*)\(')
funcs = [(m.group(1), i) for i, l in enumerate(lines) if (m := pat.match(l))]
for idx, (name, i) in enumerate(funcs):
    end = funcs[idx + 1][1] if idx + 1 < len(funcs) else len(lines)
    body = '\n'.join(lines[i:end])
    writes = re.search(r"\.(set|update|delete)\(|batch\.(set|update|delete)|httpsCallable", body)
    if not writes:
        continue
    if '_log(' in body or '_logChange(' in body:
        continue
    print(name)
PY
)"

ALLOWED="$(printf '%s\n%s\n' "$LOGGED_ON_SERVER" "$NOT_MINISTRY_DATA" | grep -v '^$' | sort -u)"

echo "كل دالّة كتابة تُسجّل، أو تُستثنى بسببٍ مكتوب:"
MISSING=""
for fn in $UNLOGGED; do
  if ! printf '%s\n' "$ALLOWED" | grep -qx "$fn"; then
    MISSING="$MISSING $fn"
  fi
done

if [ -z "$MISSING" ]; then
  report "لا دالّة كتابةٍ بلا سجلٍّ ولا استثناء" 1
else
  report "لا دالّة كتابةٍ بلا سجلٍّ ولا استثناء" 0 \
    "بلا سجلّ ولا استثناء:$MISSING — سجّلها بـ_log، أو أضِفها إلى قائمة استثناءٍ في هذا الملف مع سببها."
fi

# ــ والاستثناء لا يتضخّم بصمت ــ
#
# قائمةٌ تُضاف إليها الدوالُّ كلما ضاق الحارس تُبطله بلا أن يُلغى. فالعدد
# نفسه محروس: من زاده يُقرَأ سببه في المراجعة.
#
# ورُفع الحدّ من ٢٠ إلى ٢١ مرّةً واحدة، لـ`convertRecord`: التحويل عمليةٌ
# ذرّية من خطوتين لا تصحّ من العميل أصلاً، وسطرُها يُكتب على الخادم بصلاحية
# المدير — وهو مفحوصٌ في القسم الأخير من هذا الحارس.
#
# ورُفع ثانيةً إلى ٢٢ لـ`returnRequestForRevision`: إعادةُ الطلب للتعديل
# قرارُ معتمِدٍ لا كتابةُ عميل — تفحص الدالّةُ الخلفية المرحلةَ والرتبة ثم
# تكتب السطر بصلاحية المدير («إعادة طلب للتعديل»)، وهو مفحوصٌ أدناه.
ALLOWED_COUNT="$(printf '%s\n' "$ALLOWED" | grep -c .)"
if [ "$ALLOWED_COUNT" -le 22 ]; then
  report "وقائمة الاستثناء لم تتضخّم ($ALLOWED_COUNT من ٢٢)" 1
else
  report "وقائمة الاستثناء لم تتضخّم" 0 \
    "صارت $ALLOWED_COUNT استثناءً — راجعها قبل رفع الحدّ."
fi

# ــ وما يُستثنى لأنه يُسجَّل على الخادم يجب أن يُسجَّل هناك فعلاً ــ
#
# وإلا صار الاستثناء ادّعاءً: اسمٌ في قائمة، ولا سطر في الخادم.
echo ""
echo "وما استُثني لأنه يُسجَّل على الخادم — يُسجَّل هناك فعلاً:"
SRC="functions/src/index.ts"
for fn in $LOGGED_ON_SERVER; do
  [ -z "$fn" ] && continue
  # اسمُ الدالّة في العميل قد يخالف اسمَها على الخادم، فيُبحث عن الاثنين.
  case "$fn" in
    setPermissionOverrides) server="setUserPermissionOverrides" ;;
    restampUserClaims) server="adminRestampClaims" ;;
    applyRolePermissions) server="refreshRolePermissions" ;;
    *) server="$fn" ;;
  esac
  body="$(sed -n "/^export const $server = onCall/,/^});/p" "$SRC")"
  if printf '%s' "$body" | grep -q "logAudit("; then
    report "$server" 1
  else
    report "$server" 0 "لم يوجد logAudit داخلها في $SRC"
  fi
done

echo ""
echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
