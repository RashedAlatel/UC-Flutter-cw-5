#!/usr/bin/env bash
# حارس: كلُّ مفتاح صلاحيةٍ حيٌّ في الطرفين — العميلِ والخادمِ والقواعد.
#
# ــــ الصلاحيةُ الميتة ــــ
#
# صلاحيةٌ تُعرَّف في `RolePermission` بالعميل، وتظهر في شبكة الأدوار،
# ويمنحها مسؤولُ النظام لدورٍ أو لفرد — ثم **لا تصل بطاقةَ الدخول أبداً**،
# لأنّ مفتاحَها ليس في `CUSTOM_ROLE_PERM_KEYS` على الخادم:
#
#   basePerms()          تبني الأعلامَ من تلك القائمة وحدَها،
#   loadCustomRolePerms  تُسقط ما ليس فيها: `if (key in perms)`،
#   applyOverrides       تُصفّي ما ليس فيها،
#   setUserPermissionOverrides  ترفض ما ليس فيها بنصّ «صلاحية غير معروفة».
#
# فتصير الصلاحيةُ حبراً: الشاشةُ تعرض زرَّها، والقاعدةُ تفحص `perm('x')`
# فتجده معدوماً، فيُردّ المستخدم. وهو صنفُ العطل الذي تكرّر في هذه المنصّة:
# **الشاشةُ تَعِدُ بما يرفضه الخادم.**
#
# ووقع فعلاً: `mtd` (تعديل مواعيد المهامّ) شُحنت في `38a6c3f` ومفتاحُها لم
# يُختم قط، و`firestore.rules` تفحصه. فبقيت الصلاحيةُ معطّلةً لكلِّ من
# مُنحها. و`bla` معها: تعمل لأنّ بوابتَها في العميل، لكنّ منحَها لفردٍ
# بعينه كان يُردّ.
#
# ــــ ولماذا لم يمسكها اختبارُ القواعد ــــ
#
# `test_rules/task_reschedule.rules.test.mjs` يسلّم البطاقةَ المفتاحَ
# بيده: `asUser('u-plan', {perms: {mtd: true}})`. فهو يقيس **القاعدة**
# وقد أحسن، ولا يقيس **الختم** — ولا يستطيع: المحاكي لا يختم بطاقات.
# فالفجوةُ بين الطرفين لا يسدّها إلا حارسٌ يقرأ الطرفين معاً. هذا هو.
set -eu
cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

ENUM="lib/models/role_permissions.dart"
SERVER="functions/src/index.ts"
RULES="firestore.rules"

for f in "$ENUM" "$SERVER" "$RULES"; do
  [ -f "$f" ] || { printf '⛔ لم يُعثر على %s\n' "$f" >&2; exit 1; }
done

ok()  { echo "  ✔ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; echo "      $2"; FAIL=$((FAIL + 1)); }

# ــ مفاتيحُ العميل: قيمُ التعداد وحدَها ــ
#
# ويُقتطع جسمُ التعداد قبل `final String key;` حتى لا تُلتقط أسطرٌ أخرى
# في الملفّ تشبه صيغةَ القيمة.
DART_KEYS="$(awk '
  /^enum RolePermission \{/ { inside = 1; next }
  inside && /^  final String key;/ { exit }
  inside && $0 ~ /^  [A-Za-z]+\('"'"'[a-z]+'"'"'/ {
    key = $0
    sub(/^[^'"'"']*'"'"'/, "", key)
    sub(/'"'"'.*$/, "", key)
    print key
  }
' "$ENUM" | sort -u)"

# ــ مفاتيحُ الخادم: مصفوفةٌ تمتدّ سطرين ــ
SERVER_KEYS="$(awk '
  /const CUSTOM_ROLE_PERM_KEYS/ { inside = 1 }
  inside {
    line = $0
    while (match(line, /"[a-z]+"/)) {
      print substr(line, RSTART + 1, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
    }
  }
  inside && /\] as const;/ { exit }
' "$SERVER" | sort -u)"

# ــ ومفاتيحُ القواعد: كلُّ perm('x') ــ
RULE_KEYS="$(grep -o "perm('[a-z]*')" "$RULES" \
  | sed "s/perm('//; s/')//" | sort -u)"

count() { printf '%s\n' "$1" | grep -c '[a-z]' || true; }

echo "▶ حارس تطابق مفاتيح الصلاحيات"
echo ""
echo "عُدَّ في العميل $(count "$DART_KEYS") مفتاحاً، وعلى الخادم $(count "$SERVER_KEYS")، وفي القواعد $(count "$RULE_KEYS")."
echo ""

# والقوائمُ لا تُقرأ فارغةً نجاحاً: صياغةٌ تغيّرت في مصدرٍ تُعمي الحارس
# فيمرّ كلُّ شيء. وهذا أخطرُ من العطل الذي يحرسه.
echo "القوائمُ الثلاث مقروءة:"
for pair in "العميل:$DART_KEYS" "الخادم:$SERVER_KEYS" "القواعد:$RULE_KEYS"; do
  name="${pair%%:*}"
  body="${pair#*:}"
  if [ "$(count "$body")" -ge 1 ]; then
    ok "قائمةُ ${name} قُرئت"
  else
    bad "قائمةُ ${name} قُرئت" "خرجت فارغة — تغيّرت صياغةُ المصدر والحارسُ أعمى، لا أنّ لا مفاتيحَ هناك."
  fi
done
echo ""

# ــ (١) كلُّ مفتاحٍ في العميل يُختم على الخادم ــ
echo "كلُّ صلاحيةٍ في المنصّة تصل بطاقةَ الدخول:"
for key in $DART_KEYS; do
  if printf '%s\n' "$SERVER_KEYS" | grep -qx "$key"; then
    ok "«${key}» مختوم"
  else
    bad "«${key}» مختوم" \
"غائبٌ عن CUSTOM_ROLE_PERM_KEYS في ${SERVER} — فالصلاحيةُ حبرٌ على ورق:
      تُمنح في الشبكة ولا تصل البطاقةَ، فيُردّ من مُنحها."
  fi
done
echo ""

# ــ (٢) وكلُّ perm() في القواعد له مفتاحٌ حيّ ــ
echo "وكلُّ perm() في القواعد تفحص مفتاحاً موجوداً:"
for key in $RULE_KEYS; do
  if printf '%s\n' "$SERVER_KEYS" | grep -qx "$key"; then
    ok "perm('$key') تفحص مفتاحاً مختوماً"
  else
    bad "perm('$key') تفحص مفتاحاً مختوماً" \
"لا يُختم هذا المفتاح، فالقاعدةُ لا تُفتح لأحد غير مسؤول النظام."
  fi
  if printf '%s\n' "$DART_KEYS" | grep -qx "$key"; then
    ok "  وله صلاحيةٌ تُمنح في العميل"
  else
    bad "  وله صلاحيةٌ تُمنح في العميل" \
"لا قيمةَ في RolePermission بهذا المفتاح — فلا سبيل إلى منحه لأحد."
  fi
done
echo ""

# ــ (٣) ولا مفتاحَ على الخادم بلا صلاحيةٍ تقابله ــ
#
# فمفتاحٌ بقي بعد حذف صلاحيته يُختم على كل بطاقة بلا معنى، ويُوهم قارئَ
# الشيفرة بأنّ خلفه باباً.
echo "ولا مفتاحَ مختومٌ بلا صلاحيةٍ تقابله:"
for key in $SERVER_KEYS; do
  if printf '%s\n' "$DART_KEYS" | grep -qx "$key"; then
    ok "«${key}» له قيمةٌ في التعداد"
  else
    bad "«${key}» له قيمةٌ في التعداد" \
"مفتاحٌ مختومٌ لا تقابله صلاحيةٌ في ${ENUM} — أحُذفت الصلاحيةُ وبقي مفتاحُها؟"
  fi
done
echo ""

# ــ وكلُّ اختبارِ قواعدٍ مكتوبٍ يُشغَّل فعلاً ــ
#
# و`test_rules/package.json` يسمّي ملفّاته **واحداً واحداً**. فملفٌّ يُكتب
# ولا يُضاف إلى السطر موجودٌ في المستودع ولا يعمل أبداً: يُقرأ في المراجعة
# فيُظنّ الحدُّ مقيساً، وهو غيرُ مقيس. وهو صنفُ الصمت نفسُه الذي جعل مفتاحَ
# `mtd` ميّتاً — شيءٌ مكتوبٌ لا يصل.
#
# ووقع هذا فعلاً عند كتابة اختبار الإجراءات: أُضيف الملفُّ ومرّت المجموعةُ
# بالعدد نفسِه، فلم يكن قد شُغّل.
echo ""
echo "وكلُّ اختبار قواعدٍ مكتوبٍ مُدرَجٌ ليُشغَّل:"
LIST="test_rules/package.json"
if [ -f "$LIST" ]; then
  for f in test_rules/*.rules.test.mjs; do
    base="$(basename "$f")"
    if grep -q "$base" "$LIST"; then
      ok "${base} مُدرَج"
    else
      bad "${base} مُدرَج" \
"موجودٌ في المجلّد وغائبٌ عن سطر \"test\" في ${LIST} — فلا يُشغَّل أبداً."
    fi
  done
else
  bad "قائمةُ اختبارات القواعد مقروءة" "لم يُعثر على ${LIST}"
fi
echo ""

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
