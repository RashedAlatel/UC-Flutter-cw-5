#!/usr/bin/env bash
#
# هل يميّز حارس النشر تعديلاً كتبتَه أنت من تعديلٍ كتبته أدواتنا؟
#
# كان الحارس يوقف النشر على أي ملف معدَّل، ولا يقول أيّ ملف. و
# `pubspec.lock` و`functions/package-lock.json` تُعيد أدواتنا كتابتهما عند
# كل بناء ونشر، فكان النشر يتوقّف عند **كل مرة** ويُطلَب من المستخدم أن
# يمحو نسخته — عادةٌ تمحو يوماً تعديلاً حقيقياً.
#
# التشغيل:  ./tool/test/worktree_state_test.sh
set -uo pipefail

cd "$(dirname "$0")/../.."

# الدوال تُستدعى من مصدرها لا تُنسخ هنا: نسخةٌ ثانية تفترق عن الأصل بأول
# تعديل، فيمرّ الاختبار على شيء لا يعمل به أحد.
. ./tool/worktree.sh

pass=0
fail=0

check() {
  local name="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    printf '  ✔ %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  ✘ %s — توقّعنا «%s» فجاء «%s»\n' "$name" "$want" "$got"; fail=$((fail + 1))
  fi
}

PREFIX="$(git rev-parse --show-prefix 2>/dev/null || echo '')"

echo "تمييز درن نسخة العمل:"

check "النسخة النظيفة لا تُوصف بشيء" no "$(worktree_dirt_is_generated "")"

check "قفل الحزم وحده = من أدواتنا" yes \
  "$(worktree_dirt_is_generated "${PREFIX}pubspec.lock")"

check "قفل الدوال وحده = من أدواتنا" yes \
  "$(worktree_dirt_is_generated "${PREFIX}functions/package-lock.json")"

check "القفلان معاً = من أدواتنا" yes \
  "$(worktree_dirt_is_generated "${PREFIX}pubspec.lock
${PREFIX}functions/package-lock.json")"

# وهذه هي التي يجب أن توقف النشر: شيفرة، أو قواعد، أو إعدادات مشروع.
check "ملف شيفرة = تعديلك أنت" no \
  "$(worktree_dirt_is_generated "${PREFIX}lib/screens/dashboard_screen.dart")"

check "قواعد قاعدة البيانات = تعديلك أنت" no \
  "$(worktree_dirt_is_generated "${PREFIX}firestore.rules")"

check "معرّف المشروع = تعديلك أنت" no \
  "$(worktree_dirt_is_generated "${PREFIX}.firebaserc")"

# الخلط هو الحال الخطر: قفلٌ من أدواتنا **ومعه** شيفرة منك. ولو مرّ هذا
# لضاعت تعديلاتك بلا إنذار، وهو ما بُني الحارس ضدّه أصلاً.
check "قفلٌ ومعه شيفرة = يوقف النشر" no \
  "$(worktree_dirt_is_generated "${PREFIX}pubspec.lock
${PREFIX}lib/main.dart")"

echo ""
echo "قراءة الدرن الحقيقي من git:"

# عضّ: يُتّسخ ملفٌ فعلاً ويُشترط أن تراه الدالة باسمه الكامل من جذر
# المستودع — لا من المجلد الحالي. ولولا هذا لمرّ الاختبار وكل المقارنات
# أعلاه تقارن مساراتٍ لا تُنتجها `git` أصلاً.
SENTINEL="tool/.worktree_probe"
cleanup() { rm -f "$SENTINEL"; }
trap cleanup EXIT
echo "probe" > "$SENTINEL"
SEEN="$(worktree_dirty_files)"
cleanup
trap - EXIT

# ولا `case` داخل `$( )`: bash 3.2 على macOS لا تحلّلها، وقد أسقطت حارساً
# سابقاً بخطأ نحوي **فأوقفت نشر المستخدم**. فالمقارنة في دالة.
saw_line() {
  case "
$1
" in
    *"
$2
"*) echo yes ;;
    *)  echo no ;;
  esac
}

check "الملف المتّسخ يُقرأ بمساره من جذر المستودع" yes \
  "$(saw_line "$SEEN" "${PREFIX}${SENTINEL}")"

# ــــ ماذا يقترحه الحارس حين يوقفك؟ ــــ
#
# الرسالة نفسها فِعل: من أُوقف عن النشر ينسخ ما يُقترح عليه وينفّذه على عجل
# ليُكمل عمله. فإن كان المقترَح `git reset --hard` محا كلّ تعديلٍ محلي في
# المستودع لأجل ملفٍّ واحد لم يقصده — وهو ضررٌ أكبر مما أوقفه الحارس لأجله.
#
# فيُقاس المقترَح نصّاً: يسمّي الملفات، ويثبّتها عند الجذر بـ`:/` (وإلا رُدّ
# الأمر لأن السكربت يُنفَّذ من مجلد فرعي)، ولا يعرض المنجنيق.
echo ""
echo "ما يقترحه الحارس حين يوقفك:"

for f in tool/deploy.sh tool/build_web.sh; do
  src="$(cat "$f")"
  case "$src" in
    *'git checkout --'*) r=yes ;;
    *) r=no ;;
  esac
  check "$f يقترح استرجاع الملفات المسمّاة" yes "$r"

  case "$src" in
    *':/'*) r=yes ;;
    *) r=no ;;
  esac
  check "  ويثبّت مساراتها عند جذر المستودع" yes "$r"

  # `git reset --hard origin/...` يبقى مشروعاً لعلاج **التأخّر** عن الخادم:
  # هناك المقصود فعلاً هو مطابقة الفرع كلّه. الممنوع أن يُقترح علاجاً
  # للتعديلات المحلية.
  #
  # وعدّاً لا بحثاً عن السياق: كانت الصياغة الأولى تقرأ الأسطر المحيطة بأول
  # موضع، فتجد فيها «متأخّر» وتمرّ — ولو أُضيف موضعٌ ثانٍ للتعديلات المحلية.
  # وقد قِيست: طفرةٌ تُعيد المنجنيق مرّت عليها. فالموضع المشروع **واحد**،
  # وأيّ زيادةٍ عليه هي بالضبط ما يُحرَس منه.
  HARD="$(printf '%s\n' "$src" | grep -c 'reset --hard.*BRANCH' || true)"
  if [ "$HARD" -le 1 ] && printf '%s' "$src" | grep -B6 'reset --hard.*BRANCH' | grep -q "متأخّر"; then
    r=yes
  else
    r=no
  fi
  check "  ولا يقترح المنجنيق علاجاً للتعديلات المحلية" yes "$r"
done

echo ""
if [ "$fail" -gt 0 ]; then
  echo "نجح: $pass · فشل: $fail"
  exit 1
fi
echo "نجح: $pass · فشل: 0"
