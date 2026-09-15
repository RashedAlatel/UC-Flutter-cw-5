#!/usr/bin/env bash
# حارس: لا يشترك العميلُ بما ترفضه القاعدة.
#
# ــــ العطلُ صنفٌ لا حادثة ــــ
#
# «العميلُ يطلب ما ترفضه القاعدة» وقع في هذه المنصة **ثلاث مرّات**:
#
#   ١. زرُّ تعديل المشروع يظهر ثم يردُّه الخادم        (ae82667)
#   ٢. مفتاحُ `mtd` يُمنح في الشبكة ولا يصل البطاقة    (80d3fdb)
#   ٣. مستمعُ `procedures` يُسجَّل لكلّ مستخدم والقاعدةُ تحصره  (هذا)
#
# وفي كلٍّ منها كان الطرفان مكتوبَين صحيحَين، وبينهما فجوةٌ لا يقرؤها أحد.
#
# ــــ وأثرُ الثالثة كان أوسعَ من منعِ ميزة ــــ
#
# الاشتراكُ المرفوض يُكتب في `dataErrors`، فتظهر لافتةُ «صلاحيات حسابك غير
# مكتملة — بعض بياناتك محجوبة عنك» لكلِّ موظّفٍ ومديرِ إدارة. وهي:
#
#   * تُنذر بما لا ينقص      — ومشاريعُه كاملةٌ أمامه،
#   * وتدلّه على زرِّ «مزامنة صلاحيات حسابي» ولن يُصلح شيئاً أبداً،
#   * وتُعوّده تجاهُلَ اللافتة، فلا يقرؤها يومَ يقع عطلٌ حقيقيّ.
#
# ــــ وما يقيسه هذا الحارس ــــ
#
# كلُّ مجموعةٍ قراءتُها **محصورةٌ** في `firestore.rules` — بمفتاحٍ أو
# بمسؤول النظام — إمّا ألّا يُشترَك بها أصلاً، وإمّا أن يكون اشتراكُها
# داخل شرطٍ يسمّي مرآتَها في العميل.
#
# ــــ وحدُّه ــــ
#
# يحرس **الاشتراكات** (`.snapshots()`): هي التي تنطلق لكلِّ مستخدمٍ عند
# الدخول فتُشعل اللافتة. أمّا القراءةُ الواحدة (`.get()`) فيطلبها المستخدم
# بفعلٍ في شاشةٍ محروسٍ مدخلُها، فلا تقع من تلقائها.
set -eu
cd "$(dirname "$0")/../.."

STORE="lib/data/app_store.dart"
RULES="firestore.rules"

for f in "$STORE" "$RULES"; do
  [ -f "$f" ] || { printf '⛔ لم يُعثر على %s\n' "$f" >&2; exit 1; }
done

PASS=0
FAIL=0
ok()  { echo "  ✔ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; echo "      $2"; FAIL=$((FAIL + 1)); }

# ــ جدولُ المرايا: المجموعةُ المحصورة ← الشرطُ الذي يحرس اشتراكَها ــ
#
# ومجموعةٌ محصورةٌ جديدةٌ يُشترَك بها ولا سطرَ لها هنا **تُسقط الحارس**،
# فيُجبَر كاتبُها على القرار بدل أن يمرّ صامتاً.
MIRRORS="
procedures:canViewProcedures
procedureVersions:canViewProcedures
auditLog:canViewAuditLog
feedback:canManageFeedback
works:canViewAllDepartments
workUpdates:canViewAllDepartments
approvalRequests:isAdmin
"

# ــ ومجموعاتٌ تبدو محصورةً وليست كذلك، بسببٍ مكتوب ــ
#
# `settings` وحدها: قاعدتُها `id != 'dailyReport' || isAdmin()`، فالقراءةُ
# مفتوحةٌ لكلّ المستندات إلا واحداً. والمستندُ المحصور **لا يُشترَك به**
# أصلاً — يُقرأ بـ`get()` في `loadDailyReportSettings` من شاشةٍ لمسؤول
# النظام. فحصرُها بالاسم يُسقط ستّةَ اشتراكاتٍ مشروعة.
EXPLAINED="settings"

echo "▶ حارس نطاق الاشتراكات"
echo ""

GATED="$(python3 - "$RULES" <<'PY'
import re, sys

src = open(sys.argv[1], encoding='utf-8').read()

# ــ دوالُّ القواعد تُوسَّع ــ
#
# `allow read: if canReadProcedures();` لا يقول شيئاً بنفسه؛ والحصرُ في
# جسم الدالّة. فبلا توسيعٍ يمرّ كلُّ حصرٍ كُتب في دالّة — وهو ما وقع.
funcs = dict(re.findall(r"function\s+(\w+)\s*\([^)]*\)\s*\{(.*?)\}", src, re.S))

def expand(text, depth=3):
    for _ in range(depth):
        for name, body in funcs.items():
            if name + "(" in text:
                text += " " + body
    return text

for m in re.finditer(r"match /(\w+)/\{", src):
    name = m.group(1)
    if name == "databases":
        continue
    block = src[m.end():]
    end = block.find("\n    }")
    block = block[:end] if end != -1 else block
    conds = " ".join(re.findall(r"allow (?:read|list|get)[^;]*;", block))
    if not conds:
        continue
    full = expand(conds)
    if re.search(r"\ballow (?:read|list|get)[^;]*\bfalse\s*;", conds):
        print(name + ":closed")
    elif "perm(" in full or "isAdmin()" in full:
        print(name + ":gated")
PY
)"

# قائمةٌ تُقرأ فارغةً لأنّ صياغةَ المصدر تغيّرت تُعمي الحارسَ فيمرّ كلُّ
# شيء — وهو أخطرُ من العطل الذي يحرسه.
echo "قواعدُ القراءة مقروءة:"
COUNT="$(printf '%s\n' "$GATED" | grep -c ':' || true)"
if [ "$COUNT" -ge 3 ]; then
  ok "قُرئت ${COUNT} مجموعةً محصورةً أو مغلقة"
else
  bad "قُرئت مجموعاتٌ محصورة" \
"لم يُقرأ إلا ${COUNT} — تغيّرت صياغةُ ${RULES} والحارسُ أعمى، لا أنّ لا حصرَ هناك."
fi
echo ""

# ــ اشتراكٌ بالمجموعة **كلِّها**، لا استعلامٌ مضيَّق ــ
#
# والفرقُ جوهريّ: `.where(...)` و`.doc(...)` تطلبان ما تسمح به القاعدةُ
# فعلاً، فلا تُردّان ولا تحتاجان شرطاً — بهما تُقرأ مشاريعُ المستخدم
# وأعمالُه المسنَدة إليه. والمرفوضُ هو من يطلب المجموعةَ كلَّها وليس له
# إلا بعضُها.
#
# وبلا هذا التمييز يشكو الحارسُ من خمسةِ اشتراكاتٍ سليمة، فيُقرأ ضجيجاً
# ويُسكت — وحارسٌ يشكو مما لا عيبَ فيه لا يُقرأ يومَ يشكو من عيب.
#
# والتمييزُ بالملاصقة: `_db.collection('X').` يتبعها `snapshots()` أو
# `orderBy` أو `limit` — وهذه لا تضيّق نطاقاً. أمّا `.where(` و`.doc(`
# و`_whereDeptIn(...)` فلا تلاصق، فتسقط من النمط نفسِه. وكان معها
# `grep -v` صريحان، فقِيسا بطفرةٍ ولم يعضّا: النمطُ يكفيهما.
#
# وحدُّه: يقرأ سطراً واحداً. فاشتراكٌ بمجموعةٍ كاملةٍ يُكتب على سطرين لا
# يراه — ولا واحدَ منها كذلك اليوم، وإن كُتب فليُكتب على سطر.
subscribed_lines() {
  grep -n "_db\.collection('$1')\.\(snapshots()\|orderBy\|limit\)" "$STORE" \
    | grep '\.snapshots()' || true
}

mirror_of() {
  printf '%s\n' "$MIRRORS" | grep "^$1:" | cut -d: -f2
}

# ــ والتصنيفُ نفسُه يُفحص، لا يُصدَّق ــ
#
# `allow read: if canReadProcedures();` لا يقول حصراً بنفسه — الحصرُ في
# جسم الدالّة. فلو انكسر توسيعُ الدوالّ في القارئ أعلاه لصارت المجموعةُ
# «مفتوحة» في عين الحارس، فيمرّ اشتراكٌ مرفوضٌ ولا يشكو أحد.
#
# وقد قِيس ذلك بطفرتين معاً — كُسر التوسيعُ ونُزع الشرط — فمرّ الحارسُ
# راضياً. فصار كلُّ اسمٍ في جدول المرايا **يجب أن يُصنَّف محصوراً**.
# ومن فتح مجموعةً في القواعد يحذف سطرَها من الجدول بقرارٍ مكتوب.
echo "وتصنيفُ القواعد يُصدّقه جدولُ المرايا:"
for row in $MIRRORS; do
  name="${row%%:*}"
  [ -z "$name" ] && continue
  if printf '%s\n' "$GATED" | grep -qx "${name}:gated"; then
    ok "«${name}» قُرئت محصورةً من ${RULES}"
  else
    bad "«${name}» قُرئت محصورةً من ${RULES}" \
"في الجدول ولم تُقرأ محصورة — إمّا فُتحت قراءتُها في القواعد (فيُحذف سطرُها هنا بقرار)، وإمّا انكسر قارئُ القواعد فصار الحارسُ أعمى."
  fi
done
echo ""

echo "كلُّ مجموعةٍ محصورةٍ: لا يُشترَك بها، أو اشتراكُها مشروط:"
for entry in $GATED; do
  name="${entry%%:*}"
  kind="${entry##*:}"

  if printf '%s\n' $EXPLAINED | grep -qx "$name"; then
    ok "«${name}» مستثناةٌ بسببٍ مكتوب في هذا الحارس"
    continue
  fi

  lines="$(subscribed_lines "$name")"

  if [ "$kind" = "closed" ]; then
    if [ -z "$(grep -n "_db\.collection('$name')" "$STORE" || true)" ]; then
      ok "«${name}» مغلقةٌ تماماً ولا يمسّها العميل"
    else
      bad "«${name}» مغلقةٌ تماماً ولا يمسّها العميل" \
"قاعدتُها تردّ كلَّ قراءةٍ وكتابة، والعميلُ يذكرها في ${STORE}."
    fi
    continue
  fi

  if [ -z "$lines" ]; then
    ok "«${name}» محصورةٌ ولا يُشترَك بها"
    continue
  fi

  mirror="$(mirror_of "$name")"
  if [ -z "$mirror" ]; then
    bad "«${name}» محصورةٌ ويُشترَك بها" \
"لا سطرَ لها في جدول المرايا بهذا الحارس — أيُّ شرطٍ يحرس اشتراكَها؟"
    continue
  fi

  # الشرطُ يُطلب في السطر نفسِه أو في الثمانية التي قبله: `if (…) {` يسبق
  # `_listen` بسطرٍ عادةً، والتعليقُ الشارح قد يفصل بينهما.
  missing=""
  for ln in $(printf '%s\n' "$lines" | cut -d: -f1); do
    from=$((ln - 8))
    [ "$from" -lt 1 ] && from=1
    if ! sed -n "${from},${ln}p" "$STORE" | grep -q "$mirror"; then
      missing="$missing $ln"
    fi
  done

  if [ -z "$missing" ]; then
    ok "«${name}» اشتراكُها مشروطٌ بـ${mirror}"
  else
    bad "«${name}» اشتراكُها مشروطٌ بـ${mirror}" \
"اشتراكٌ بلا شرطٍ في ${STORE}:${missing} — يُردّ لمن لا يملكها، فتظهر له لافتةُ «بياناتك محجوبة» وهي تُنذره بما لا ينقصه."
  fi
done
echo ""

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
