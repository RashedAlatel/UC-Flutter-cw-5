#!/usr/bin/env bash
# حارس: كلُّ استعلامٍ مركَّبٍ له فهرسُه — **وإلا أخفق على الوزارة وحدها**.
#
# ــــ العطلُ الذي أوجب هذا الحارس ــــ
#
# دُفعت في `5d6d288` ثلاثةُ استعلاماتٍ على `dailyStatuses` تجمع تصفيةً على
# حقلٍ ومدىً على حقلٍ آخر. وFirestore يرفض ذلك بلا **فهرسٍ مركَّب** مسجَّل،
# فيردّ بـ`failed-precondition`.
#
# **ولم يكشفه أيُّ اختبار**: محاكي القواعد لا يفرض الفهارس إطلاقاً، فـ٣٤٧
# اختبارَ قواعدٍ مرّت خضراءَ على استعلامٍ لا يعمل في المنصّة الحيّة. وهذه
# ثغرةٌ في شبكة الأمان لا في الشيفرة — والثغرةُ تُسدّ بحارس.
#
# ــــ وما يُقاس ــــ
#
# كلُّ استعلامٍ يحتاج فهرساً بحكم قواعد Firestore:
#
#   (١) تصفيةٌ بالمساواة (أو `in`/`arrayContains`) على حقل + **مدىً أو ترتيبٌ
#       على حقلٍ آخر**.
#   (٢) أو تصفيتان فأكثر بالمساواة + ترتيبٌ على حقلٍ ثالث.
#
# أمّا الاستعلامُ على حقلٍ واحد — تصفيةً كان أو ترتيباً — فله فهرسٌ تلقائيّ
# ولا يحتاج تسجيلاً.
set -eu
cd "$(dirname "$0")/../.."

STORE="lib/data/app_store.dart"
INDEXES="firestore.indexes.json"

for f in "$STORE" "$INDEXES"; do
  [ -f "$f" ] || { printf '⛔ لم يُعثر على %s\n' "$f" >&2; exit 1; }
done

PASS=0
FAIL=0
ok()  { echo "  ✔ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; echo "      $2"; FAIL=$((FAIL + 1)); }

echo "▶ حارس فهارس الاستعلامات"
echo ""

REPORT="$(python3 - "$STORE" "$INDEXES" <<'PY'
import json, re, sys, pathlib

store_path, index_path = sys.argv[1], sys.argv[2]
src = pathlib.Path(store_path).read_text(encoding='utf-8')
indexes = json.loads(pathlib.Path(index_path).read_text(encoding='utf-8'))

# الفهارسُ المسجَّلة: مجموعةُ الحقول لكلّ مجموعة.
registered = {}
for entry in indexes.get('indexes', []):
    col = entry.get('collectionGroup', '')
    fields = tuple(f['fieldPath'] for f in entry.get('fields', []))
    registered.setdefault(col, set()).add(fields)

# سلسلةُ استعلامٍ تبدأ بـ`collection('x')` وتتبعها `.where`/`.orderBy`.
chain = re.compile(
    r"collection\(\s*'(?P<col>\w+)'\s*\)(?P<rest>(?:\s*\.\s*(?:where|orderBy)\([^;]*?\))+)",
    re.S,
)
where_call = re.compile(r"\.\s*where\(\s*'(?P<field>\w+)'\s*,\s*(?P<op>\w+)\s*:")
order_call = re.compile(r"\.\s*orderBy\(\s*'(?P<field>\w+)'")

# عملياتُ المدى — **وترتيبُ الحقول في الفهرس يتبعها**.
#
# Firestore يشترط أن تسبق حقولُ المساواةِ حقلَ المدى في الفهرس. فاستعلامٌ
# يُكتب بالمدى أوّلاً يحتاج فهرساً بالترتيب المقلوب عمّا كُتب.
#
# ــ وطفرتُه لا تعضّ اليوم، وقد قِيس لماذا ــ
#
# نُزعت هذه المجموعةُ فمرّ الحارسُ صامتاً: كلُّ استعلامات المتجر مكتوبةٌ
# بالمساواة أوّلاً، فترتيبُ الحقول واحدٌ بالفرع وبلا الفرع.
#
# فقِيست بطفرةٍ **مركَّبة**: أُعيدت كتابةُ استعلامٍ بالمدى أوّلاً، ثمّ نُزع
# الفرع — فطلب الحارسُ فهرسَ `dayKey+uid` بدل `uid+dayKey`، وهو ترتيبٌ
# يرفضه Firestore. **فالفرعُ حاملٌ في مبدئه**، ولا تعضّ طفرتُه لأنّ المنصّةَ
# خلت من هذه الصيغة — لا لأنّه زائد.
RANGE_OPS = {
    'isGreaterThan', 'isGreaterThanOrEqualTo',
    'isLessThan', 'isLessThanOrEqualTo', 'isNotEqualTo',
}

problems = []
checked = 0

for m in chain.finditer(src):
    col = m.group('col')
    rest = m.group('rest')
    equals, ranges = [], []
    for w in where_call.finditer(rest):
        (ranges if w.group('op') in RANGE_OPS else equals).append(w.group('field'))
    orders = [o.group('field') for o in order_call.finditer(rest)]

    fields = []
    for f in equals + ranges + orders:
        if f not in fields:
            fields.append(f)
    # حقلٌ واحدٌ: فهرسٌ تلقائيّ، ولا يُسجَّل.
    if len(fields) < 2:
        continue
    checked += 1

    have = registered.get(col, set())
    # الفهرسُ يكفي إن سجّل الحقولَ نفسَها بالترتيب نفسِه (المساواةُ أوّلاً).
    if tuple(fields) in have:
        continue
    line = src[:m.start()].count('\n') + 1
    problems.append(f"{col}|{line}|{'+'.join(fields)}")

print(f"CHECKED {checked}")
for p in problems:
    print(f"MISSING {p}")
PY
)"

CHECKED="$(printf '%s\n' "$REPORT" | grep '^CHECKED ' | cut -d' ' -f2)"
MISSING="$(printf '%s\n' "$REPORT" | grep '^MISSING ' | cut -d' ' -f2- || true)"

echo "كلُّ استعلامٍ مركَّبٍ له فهرسُه:"
if [ -z "$MISSING" ]; then
  ok "فُحص ${CHECKED} استعلاماً مركَّباً، وكلُّها مفهرَسة"
else
  printf '%s\n' "$MISSING" | while IFS='|' read -r col line fields; do
    bad "«${col}» في ${STORE}:${line} بلا فهرس" \
"الحقول: ${fields} — سجّلها في ${INDEXES}.
      وبلا الفهرس يردّ Firestore بـfailed-precondition على الوزارة وحدها:
      المحاكي لا يفرض الفهارس، فالاختباراتُ تمرّ خضراءَ على استعلامٍ لا يعمل."
  done
  FAIL=$((FAIL + 1))
fi
echo ""

# ــ ويحرس نفسَه ــ
#
# كاشفٌ لا يجد استعلاماً لأنّ صياغةَ المصدر تغيّرت يمرّ صامتاً، وهو أخطرُ
# من العطل الذي يحرسه.
echo "والكاشفُ يرى:"
if [ "${CHECKED:-0}" -ge 3 ]; then
  ok "قُرئ ${CHECKED} استعلاماً مركَّباً في المتجر"
else
  bad "قُرئت استعلاماتُ المتجر" \
"عُدَّ ${CHECKED:-0} فقط — تغيّرت صياغةُ ${STORE} والكاشفُ أعمى."
fi
echo ""

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
