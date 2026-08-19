#!/usr/bin/env bash
#
# جلب حزم Firebase JS SDK لتُخدَّم من المنصة نفسها بدل www.gstatic.com.
#
# لماذا؟ إضافة firebase_core_web تحقن — وقت التشغيل وقبل رسم أي شيء — أربعة
# سكربتات من https://www.gstatic.com/firebasejs/<الإصدار>/. فإن كانت الشبكة
# تحجب هذا النطاق أو تُبطئه (وهو شائع في الشبكات الحكومية وعلى بيانات الجوال)
# تعلَّق المنصة قبل أن تُرسم، ولا يملك المستخدم إلا شاشة انتظار.
#
# بعد تشغيل هذا السكربت تُحمَّل الحزم من نطاق المنصة نفسه، فلا يبقى للنطاق
# الخارجي أثر في مسار الإقلاع.
#
# الاستخدام:  ./tool/fetch_firebase_sdk.sh
# يُستدعى تلقائياً من tool/build_web.sh، ويتخطّى العمل إن كانت الملفات موجودة.
set -euo pipefail

cd "$(dirname "$0")/.."

# يجب أن يطابق supportedFirebaseJsSdkVersion في حزمة firebase_core_web
# المستخدمة فعلياً — تُقرأ من pubspec.lock لا تُكتب يدوياً، فلا تتخلّف عند
# ترقية الحزم.
CORE_WEB_VERSION="$(awk '/^  firebase_core_web:/{f=1} f&&/^    version:/{gsub(/[" ]/,"",$2); print $2; exit}' pubspec.lock)"
SDK_FILE="$HOME/.pub-cache/hosted/pub.dev/firebase_core_web-${CORE_WEB_VERSION}/lib/src/firebase_sdk_version.dart"

if [[ -f "$SDK_FILE" ]]; then
  VERSION="$(grep -oE "'[0-9]+\.[0-9]+\.[0-9]+'" "$SDK_FILE" | head -1 | tr -d "'")"
else
  echo "⚠ تعذّر العثور على $SDK_FILE — شغّل flutter pub get أولاً." >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  echo "⚠ تعذّر استخراج إصدار Firebase JS SDK." >&2
  exit 1
fi

OUT="web/firebase_sdk"
BASE="https://www.gstatic.com/firebasejs/${VERSION}"
# أسماء الملفات هي أسماء الخدمات التي تحقنها firebase_core_web لهذا المشروع:
# app (core) وauth وfirestore وfunctions.
FILES=(firebase-app.js firebase-auth.js firebase-firestore.js firebase-functions.js)

if [[ -f "$OUT/.version" && "$(cat "$OUT/.version")" == "$VERSION" ]]; then
  echo "✔ حزم Firebase المحلية موجودة بالإصدار $VERSION — لا حاجة لإعادة الجلب."
  exit 0
fi

echo "▶ جلب Firebase JS SDK $VERSION إلى $OUT"
mkdir -p "$OUT"

for f in "${FILES[@]}"; do
  echo "  ↓ $f"
  if ! curl -fsSL --max-time 60 "$BASE/$f" -o "$OUT/$f.tmp"; then
    echo "⚠ تعذّر تنزيل $f — تخطّي الاستضافة الذاتية." >&2
    echo "  ستعمل المنصة كما هي اليوم: ستُجلب الحزم من www.gstatic.com عند كل فتح." >&2
    # يُزال المجلد كاملاً لا الملفات المؤقتة وحدها: مجلد نصف ممتلئ أسوأ من
    # غيابه، لأن الصفحة ستحاول استيراده فتفشل بلا داعٍ.
    rm -rf "$OUT"
    exit 0
  fi
  # الملفات يستورد بعضها بعضاً بروابط مطلقة على gstatic؛ تُحوَّل إلى مسارات
  # نسبية وإلا عاد الاعتماد على النطاق الخارجي من داخل الملفات نفسها.
  sed "s|https://www\.gstatic\.com/firebasejs/${VERSION}/|./|g" "$OUT/$f.tmp" > "$OUT/$f"
  rm -f "$OUT/$f.tmp"
done

# تحقّق صارم: أي أثر متبقٍّ للنطاق يعني أن الاستضافة الذاتية ناقصة، والصمت
# عنه يعيدنا للعطل نفسه دون أن ندري.
if grep -l "www\.gstatic\.com" "$OUT"/*.js > /dev/null 2>&1; then
  echo "✗ ما زال في الملفات المجلوبة روابط إلى www.gstatic.com:" >&2
  grep -l "www\.gstatic\.com" "$OUT"/*.js >&2
  echo "  حُذفت الملفات لتجنّب استضافة ذاتية ناقصة تُخفي العطل." >&2
  rm -rf "$OUT"
  exit 1
fi

echo "$VERSION" > "$OUT/.version"
echo "✔ اكتمل الجلب. لن تُطلب حزم Firebase من www.gstatic.com بعد الآن."
