#!/usr/bin/env bash
# حارس: قرارُ لونِ المعنى في موضعٍ واحد، واللونُ الحرفيُّ في موضعٍ واحد.
#
# ــــ القاعدة ــــ
#
# **اللونُ لنقل معنى لا للزينة**: الأحمرُ خطرٌ أو تأخير، والأخضرُ نجاحٌ أو
# إنجاز، والبرتقاليُّ يحتاج انتباهاً، والأزرقُ معلومةٌ أو نشاط، والرماديُّ
# غيرُ نشط. وهذه القاعدةُ تسري على المنصة كلِّها — ولا تسري إن كان كلُّ
# ملفٍّ يقرّر لنفسه.
#
# ــــ ما كان ــــ
#
# **سبعةُ مواضعَ** تقرّر ألوانَ الحالات، فيها **ثلاثُ نسخٍ متطابقةٍ حرفاً**
# من مفتاح نمط الإعلان. ولونُ العائق حرفاً مكرّراً بلا اسم. فانحرف بعضُها
# عن بعض بلا أن يشكو أحد: «متأخّر» في التقرير الدوري كان بلونٍ لا يعرفه
# بقيّةُ النظام.
#
# ــــ وما يُقاس هنا ــــ
#
# (١) لا ذراعَ مفتاحٍ تُسند لوناً دلاليّاً خارج `status_palette.dart`.
# (١‑ب) ولا **دالّةً تعيد لوناً** تختار بين معنيين فأكثر بـ`if` و`return`.
# (٢) ولا `Color(0x…)` حرفيٌّ خارج `app_palette.dart` — إلا بسببٍ مكتوب.
#
# ــــ ولماذا أذرعُ المفاتيح لا العدّ ــــ
#
# أوّلُ صياغةٍ عدّت كم لوناً دلاليّاً في الملفّ، فشكت من **عشرين ملفّاً
# سليماً**: شاشةٌ فيها رسالةُ نجاحٍ وأخرى خطأٍ وثالثةٌ تحذيرٍ ليست موضعَ
# قرار. وحارسٌ يشكو مما لا عيبَ فيه لا يُقرأ يومَ يشكو من عيب. فضُبط على
# **ذراع المفتاح** — وهي صيغةُ القرار نفسِها — فأصاب ستّةَ مواضعَ كلُّها
# حقيقيّ، بلا شكوى كاذبةٍ واحدة.
#
# ــــ وثغرةٌ في الكاشف الأوّل قِيست ــــ
#
# كان `_dueColor` في صفحة المشاريع يقرّر أخضرَ وأحمرَ وأصفرَ بنفسه — «متأخر
# أحمر، وأسبوعٌ أو أقلّ تحذير، وما عداه أخضر» — ومرّ **صامتاً**: هو صيغةُ
# `if`/`return` لا ذراعَ مفتاح. والقرارُ واحدٌ وإن اختلفت الصيغة. فأُضيف
# الكاشفُ (١‑ب).
#
# والصيغةُ الثالثيّة (`شرط ? نجاح : خطر`) **لا تُعدّ وحدَها**: قِيست فوقعت
# في واحدٍ وعشرين موضعاً سليماً — «نجح الحفظ أم أخفق» في الإشعارات — وذلك
# خبرُ عمليةٍ لا خريطةُ حالات. فتُعدّ **داخل دالّةٍ تعيد لوناً وحدَها**،
# وهناك لم تسمِّ إلا الموضعَ الحقيقيّ.
set -eu
cd "$(dirname "$0")/../.."

SRC="lib"
PALETTE="lib/theme/app_palette.dart"
DECIDER="lib/theme/status_palette.dart"

for f in "$PALETTE" "$DECIDER"; do
  [ -f "$f" ] || { printf '⛔ لم يُعثر على %s\n' "$f" >&2; exit 1; }
done

PASS=0
FAIL=0
ok()  { echo "  ✔ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; echo "      $2"; FAIL=$((FAIL + 1)); }

echo "▶ حارس لون المعنى"
echo ""

# ــ (١) أذرعُ المفاتيح ــ
MAPPERS="$(python3 - "$SRC" "$DECIDER" <<'PY'
import re, sys, pathlib

root, decider = sys.argv[1], sys.argv[2]

# ذراعُ مفتاحٍ تُسند لوناً دلاليّاً — بالصيغتين: `case X: … AppColors.y`
# و`X => AppColors.y`. وتشمل الإسنادَ (`color = AppColors.y`) لأنّ مركزَ
# القرارات كتبها كذلك، وأوّلُ صياغةٍ لم ترَه.
#
# وفرعُ الإسناد **حاملٌ**، وقد قِيس: أُعيدت صيغةُ الإسناد إلى مركز القرارات
# فشكا الحارس، ثم نُزع الفرعُ فمرّت الصيغةُ نفسُها صامتة. ولا تعضّ طفرتُه
# وحدَها اليوم لأنّ المنصةَ خلت من هذه الصيغة بعد المهاجرة — لا لأنّه زائد.
arm = re.compile(
    r"(?:case\s+[\w.]+\s*:\s*(?:\w+\s*=\s*|return\s+)?|[\w.'\"]+\s*=>\s*)"
    r"(?:const\s+)?AppColors\.(success|warning|danger|info|textSecondary)\b"
)

for p in sorted(pathlib.Path(root).rglob('*.dart')):
    if str(p) == decider:
        continue
    hits = arm.findall(p.read_text(encoding='utf-8'))
    if len(hits) >= 2:
        print(f"{p}:{len(hits)}")
PY
)"

echo "لا يقرّر لونَ معنىً إلا موضعٌ واحد:"
if [ -z "$MAPPERS" ]; then
  ok "ولا ملفَّ يُسند لوناً دلاليّاً في أذرع مفتاح"
else
  for row in $MAPPERS; do
    bad "«${row%%:*}» لا يقرّر لوناً بنفسه" \
"فيه ${row##*:} أذرعٍ تُسند لوناً دلاليّاً — والقرارُ في ${DECIDER}.
      ولو بقي هنا لانحرف عن بقيّة المنصة بلا أن يشكو أحد."
  done
fi
echo ""

# ــ (١‑ب) الدوالُّ التي تعيد لوناً ــ
DECIDERS="$(python3 - "$SRC" "$DECIDER" <<'PY'
import re, sys, pathlib

root, decider = sys.argv[1], sys.argv[2]

SEM = r"AppColors\.(?:success|warning|danger|info|blocker|textSecondary)\b"
# ترويسةُ دالّةٍ تعيد لوناً — `Color _x(` و`static Color x(` و`Color get x`.
head = re.compile(r"(?:^|\n)[ \t]*(?:static[ \t]+)?Color\??[ \t]+(?:get[ \t]+)?(\w+)[ \t]*[({=]")
ret = re.compile(r"return\s+(?:const\s+)?" + SEM)
# والثالثيّةُ تُعدّ **هنا وحدَها**: داخل دالّةِ لونٍ هي اختيارٌ بين معنيين.
tern = re.compile(r"\?\s*(?:const\s+)?" + SEM + r"\s*:\s*(?:const\s+)?" + SEM)

for p in sorted(pathlib.Path(root).rglob('*.dart')):
    if str(p) == decider:
        continue
    src = p.read_text(encoding='utf-8')
    for m in head.finditer(src):
        open_at = src.find('{', m.end() - 1)
        if open_at < 0:
            continue
        depth, j = 0, open_at
        while j < len(src):
            if src[j] == '{':
                depth += 1
            elif src[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = src[open_at:j]
        n = len(ret.findall(body)) + len(tern.findall(body))
        if n >= 2:
            print(f"{p}:{src[:m.start()].count(chr(10)) + 2}:{m.group(1)}:{n}")
PY
)"

echo "ولا دالّةَ لونٍ تختار بين معنيين:"
if [ -z "$DECIDERS" ]; then
  ok "ولا دالّةَ تعيد لوناً تقرّر معنىً بنفسها"
else
  for row in $DECIDERS; do
    file="${row%%:*}"
    rest="${row#*:}"
    line="${rest%%:*}"
    rest="${rest#*:}"
    name="${rest%%:*}"
    bad "«${name}» في ${file}:${line} يقرّر لوناً بنفسه" \
"يختار بين ${rest##*:} معانٍ — والقرارُ في ${DECIDER}.
      وصيغةُ \`if\`/\`return\` قرارٌ كصيغةِ المفتاح سواءً بسواء."
  done
fi
echo ""

# ــ (٢) الألوانُ الحرفية ــ
#
# وما يُستثنى يُستثنى **بسببٍ مكتوبٍ هنا** لا بصمت:
#
#   render_error_card  — تُبنى مكتفيةً بذاتها لأنّ العطل قد يقع فوق شجرة
#                        `MaterialApp` نفسها، فلا `Theme` يُقرأ منه لون.
#                        وهو سببٌ مكتوبٌ في رأس الملفّ.
#   appearance_settings— جاهزاتُ لونِ الهوية التي يختار منها مسؤولُ النظام:
#                        هويةٌ لا معنى، ولا تسري عليها قاعدةُ الدلالة.
#   lib/data/*         — ألوانُ الإدارات تُزرع بياناتٍ وتُخزَّن في فايرستور
#                        لكلّ إدارة، فليست قرارَ تصميم.
EXPLAINED="lib/widgets/render_error_card.dart
lib/screens/appearance_settings_screen.dart"

LITERALS="$(grep -rln "Color(0x" "$SRC" --include=*.dart \
  | grep -v "^${PALETTE}$" \
  | grep -v "^lib/data/" \
  || true)"

echo "ولا لونَ حرفيٍّ خارج اللوحة:"
if [ -z "$LITERALS" ]; then
  ok "ولا ملفَّ فيه لونٌ حرفيّ"
else
  for f in $LITERALS; do
    if printf '%s\n' "$EXPLAINED" | grep -qx "$f"; then
      ok "«${f}» مستثنىً بسببٍ مكتوب"
    else
      n="$(grep -c "Color(0x" "$f")"
      bad "«${f}» بلا لونٍ حرفيّ" \
"فيه ${n} لوناً مكتوباً بالرقم — يُسمّى في ${PALETTE}، أو يُستثنى بسببٍ
      مكتوبٍ في هذا الحارس. ولونٌ بلا اسمٍ يُنسخ ولا يُتبع."
    fi
  done
fi
echo ""

# ــ ويحرس نفسَه ــ
#
# كاشفٌ لا يجد شيئاً لأنّ صياغةَ المصدر تغيّرت يمرّ صامتاً، وهو أخطرُ من
# العطل الذي يحرسه. فيُقاس أنّ الكاشفَين يريان **موضعَ القرار نفسَه**.
echo "والكاشفان يريان:"
DECIDER_ARMS="$(grep -cE "=> (success|warning|danger|info|neutral|blocker)," "$DECIDER" || true)"
if [ "$DECIDER_ARMS" -ge 10 ]; then
  ok "قُرئت ${DECIDER_ARMS} ذراعاً في موضع القرار"
else
  bad "قُرئت أذرعُ موضع القرار" \
"عُدَّ ${DECIDER_ARMS} فقط — تغيّرت صياغةُ ${DECIDER} والكاشفُ أعمى."
fi
PALETTE_COLORS="$(grep -c "Color(0x" "$PALETTE" || true)"
if [ "$PALETTE_COLORS" -ge 20 ]; then
  ok "وقُرئ ${PALETTE_COLORS} لوناً في اللوحة"
else
  bad "وقُرئت ألوانُ اللوحة" \
"عُدَّ ${PALETTE_COLORS} فقط — تغيّرت صياغةُ ${PALETTE}."
fi
echo ""

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
