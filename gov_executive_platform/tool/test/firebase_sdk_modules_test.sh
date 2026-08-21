#!/usr/bin/env bash
#
# حارس قائمة حزم Firebase المستضافة محلياً.
#
# العطل الذي يحرسه وقع فعلاً: كانت القائمة أربع حزم مكتوبةً بخط اليد في
# موضعين (tool/fetch_firebase_sdk.sh و web/index.html)، وهي صحيحة يوم كُتبت.
# ثم أُضيفت firebase_storage للمرفقات ولم يلحقها أحد. وبما أن
# `firebase_core_web` تتخطّى حقن **كل** الحزم متى وجدت `window.firebase_core`
# مضبوطاً، لم تكن القائمة الناقصة نقصاً جزئياً بل إسقاطاً كاملاً للتخزين.
# فرأى المستخدم عند رفع ملف خطأ نوعٍ مشوَّهاً لا يذكر التخزين إطلاقاً.
#
# ولم يسقط أي اختبار: القائمة نصٌّ في سكربت، ولا يقرؤه `flutter test` ولا
# `flutter analyze`. فهذا الحارس يقرؤه.
#
# والدالة تُستخرج من السكربت نفسه بـ sed لا تُنسخ هنا: نسخةٌ ثانية تتقادم
# كما تقادمت الأولى، وهو العطل عينه.
#
# الاستخدام:  ./tool/test/firebase_sdk_modules_test.sh
set -uo pipefail

cd "$(dirname "$0")/../.."

SCRIPT="tool/fetch_firebase_sdk.sh"
PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✔ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "      المتوقَّع: $expected"
    echo "      الواقع  : $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ــــ استخراج منطق الاشتقاق من السكربت الحقيقي ــــ
#
# من تعريف `firebase_service_for` حتى قبل قراءة إصدار الـSDK: هذا هو الجزء
# الذي يحوّل pubspec إلى قائمة خدمات، ولا يلمس الشبكة.
DERIVE="$(sed -n '/^firebase_service_for()/,/^# يجب أن يطابق supportedFirebaseJsSdkVersion/p' "$SCRIPT" | sed '$d')"

if [[ -z "$DERIVE" ]]; then
  echo "✗ تعذّر استخراج منطق الاشتقاق من $SCRIPT — تغيّرت بنيته." >&2
  exit 1
fi

# يُشغَّل على ملف pubspec يُمرَّر إليه، فيمكن اختبار حالات لا توجد في المشروع.
services_for_pubspec() {
  local dir
  dir="$(mktemp -d)"
  cp "$1" "$dir/pubspec.yaml"
  (
    cd "$dir" || exit 1
    set -euo pipefail
    eval "$DERIVE"
    echo "${SERVICES[*]}"
  ) 2>/dev/null
  local rc=$?
  rm -rf "$dir"
  return $rc
}

echo "▶ حارس قائمة حزم Firebase المحلية"
echo ""

# ــــ ١) الحالة الحقيقية: pubspec المشروع كما هو ــــ
echo "قائمة اليوم مشتقّة من pubspec.yaml:"
ACTUAL="$(services_for_pubspec pubspec.yaml)"
check "التخزين مذكور — وهو الحزمة التي سقطت" \
  "yes" "$(case " $ACTUAL " in *" storage "*) echo yes ;; *) echo no ;; esac)"
check "القائمة كاملة ومرتّبة كما يتوقّعها المُحمِّل" \
  "core auth firestore functions storage" "$ACTUAL"
echo ""

# ــــ ٢) عضّ: حزمة تُحذف من pubspec فتختفي من القائمة ــــ
#
# لولا هذا لكان الاختبار الأول يمرّ حتى لو كانت القائمة ثابتةً لا مشتقّة.
echo "فحص عضّ — الاشتقاق حقيقي لا قائمة ثابتة:"
TMP="$(mktemp)"
grep -v '^  firebase_storage:' pubspec.yaml > "$TMP"
check "حذف firebase_storage من pubspec يُخرج storage من القائمة" \
  "core auth firestore functions" "$(services_for_pubspec "$TMP")"
rm -f "$TMP"
echo ""

# ــــ ٣) حزمة لا تعرفها الخريطة تُفشل السكربت ــــ
#
# هذا هو الفرق بين «تقادمت القائمة بصمت» و«لن تتقادم»: الإضافة الجديدة توقف
# البناء وتطلب سطراً في الخريطة، بدل أن تُتجاهَل فتفشل ميزتها عند المستخدم.
echo "حزمة غير معروفة توقف البناء بدل أن تُتجاهَل:"
TMP="$(mktemp)"
sed 's/^  firebase_storage:.*/  firebase_messaging: ^15.0.0\n  firebase_zzz_unknown: ^1.0.0/' pubspec.yaml > "$TMP"
if OUT="$(services_for_pubspec "$TMP")"; then
  echo "  ✗ الاشتقاق نجح رغم حزمة مجهولة، والناتج: $OUT"
  FAIL=$((FAIL + 1))
else
  echo "  ✔ الاشتقاق فشل كما يجب"
  PASS=$((PASS + 1))
fi
rm -f "$TMP"
echo ""

# ــــ ٤) الصفحة لم تعد تحمل قائمةً خاصة بها ــــ
#
# قائمتان تفترقان حتماً. الصفحة تستورد المُحمِّل المُولَّد ولا تعرف الأسماء.
echo "web/index.html بلا قائمة موازية:"
check "لا تستورد حزم Firebase بأسمائها" \
  "0" "$(grep -c "import('\./firebase_sdk/firebase-" web/index.html)"
check "لا تضبط window.firebase_* بيدها" \
  "0" "$(grep -c "window\.firebase_[a-z]* *=" web/index.html)"
check "تستورد المُحمِّل المُولَّد" \
  "1" "$(grep -c "firebase_sdk/loader\.js" web/index.html)"
echo ""

# ــــ ٥) المُحمِّل يُولَّد لكل خدمة، ومنها التخزين ــــ
echo "المُحمِّل المُولَّد يشمل كل خدمة:"
check "سطر توليد يضبط window.firebase_\$svc لكل خدمة" \
  "1" "$(grep -c 'window\.firebase_\${svc} = modules\[\$i\];' "$SCRIPT")"
echo ""

# ــــ ٦) تشغيل السكربت الحقيقي على مصدر محلي ــــ
#
# ما سبق يقرأ نصّاً. وهذا يشغّل الجلب فعلاً: هل يبني المجلد؟ هل يولّد مُحمِّلاً
# فيه التخزين؟ وهل يُبقي النسخة السليمة إن سقط ملف؟ السؤال الأخير هو الأهم:
# الصيغة السابقة كانت تمسح المجلد كاملاً عند أول إخفاق، فتُسقط المنصة على
# شبكةٍ تحجب www.gstatic.com بدل أن تُبقيها على نسختها العاملة.
echo "تشغيل الجلب فعلياً على مصدر محلي:"

SANDBOX="$(mktemp -d)"
ORIGIN="$SANDBOX/origin"
TREE="$SANDBOX/tree"
mkdir -p "$ORIGIN" "$TREE/tool" "$TREE/web"
for f in app auth firestore functions storage; do
  echo "export const marker = '$f';" > "$ORIGIN/firebase-$f.js"
done
cp pubspec.yaml pubspec.lock "$TREE/"
cp "$SCRIPT" "$TREE/tool/"

# منفذ يُختار وقت التشغيل لا رقم ثابت: خادمٌ ثابت المنفذ بقي حيّاً بعد تشغيل
# سابق فأجاب الطلبات من مجلد محذوف، فأسقط الحارس بلا ذنب. وحارسٌ يكذب أسوأ
# من لا حارس، فالمنفذ يُطلب من النظام والخادم يُقتل بـ trap مهما كان الخروج.
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ORIGIN" >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -fsS "http://127.0.0.1:$PORT/firebase-app.js" -o /dev/null 2>/dev/null && break
  sleep 0.3
done

FIREBASE_SDK_BASE_URL="http://127.0.0.1:$PORT" "$TREE/tool/$(basename "$SCRIPT")" >/dev/null 2>&1
check "الجلب ينتج مُحمِّلاً" "yes" "$([[ -f "$TREE/web/firebase_sdk/loader.js" ]] && echo yes || echo no)"
check "المُحمِّل يضبط window.firebase_storage" \
  "1" "$(grep -c 'window.firebase_storage = ' "$TREE/web/firebase_sdk/loader.js" 2>/dev/null || echo 0)"
check "حزمة التخزين نفسها مجلوبة" "yes" \
  "$([[ -f "$TREE/web/firebase_sdk/firebase-storage.js" ]] && echo yes || echo no)"

# الآن يسقط ملف من المصدر وتُبطَل البصمة، فتُعاد المحاولة وتفشل.
rm -f "$ORIGIN/firebase-storage.js"
rm -f "$TREE/web/firebase_sdk/.version"
FIREBASE_SDK_BASE_URL="http://127.0.0.1:$PORT" "$TREE/tool/$(basename "$SCRIPT")" >/dev/null 2>&1
check "إخفاق الجلب يُبقي النسخة السابقة سليمة" "yes" \
  "$([[ -f "$TREE/web/firebase_sdk/loader.js" && -f "$TREE/web/firebase_sdk/firebase-storage.js" ]] && echo yes || echo no)"
check "لا يُترك مجلد جانبي معلّق" "no" \
  "$([[ -d "$TREE/web/firebase_sdk.incoming" ]] && echo yes || echo no)"

echo ""

echo "══════════════════════════════"
echo "نجح: $PASS · فشل: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
