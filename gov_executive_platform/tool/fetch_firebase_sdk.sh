#!/usr/bin/env bash
#
# جلب حزم Firebase JS SDK لتُخدَّم من المنصة نفسها بدل www.gstatic.com.
#
# لماذا؟ إضافة firebase_core_web تحقن — وقت التشغيل وقبل رسم أي شيء — سكربتاً
# لكل خدمة من https://www.gstatic.com/firebasejs/<الإصدار>/. فإن كانت الشبكة
# تحجب هذا النطاق أو تُبطئه (وهو شائع في الشبكات الحكومية وعلى بيانات الجوال)
# تعلَّق المنصة قبل أن تُرسم، ولا يملك المستخدم إلا شاشة انتظار.
#
# بعد تشغيل هذا السكربت تُحمَّل الحزم من نطاق المنصة نفسه، فلا يبقى للنطاق
# الخارجي أثر في مسار الإقلاع.
#
# ــــ ولماذا تُشتقّ القائمة من pubspec لا تُكتب يدوياً؟ ــــ
#
# لأن كتابتها يدوياً **كلّفتنا عطلاً كاملاً**. كانت القائمة أربع خدمات
# (app, auth, firestore, functions) وهي صحيحة يوم كُتبت. ثم أُضيفت
# firebase_storage للمرفقات بعدها بجولات، فتقادمت القائمة **بصمت**.
#
# والصمت هنا ليس مصادفة: firebase_core_web تفحص `window.firebase_core` وحده،
# فإن وجدته مضبوطاً عادت فوراً ولم تحقن شيئاً إطلاقاً
# (firebase_core_web/lib/src/firebase_core_web.dart: `_initializeCore`).
# أي أن ضبطنا لأربع حزم يُلغي حقن الخامسة بدل أن يكمّله. فبقي
# `window.firebase_storage` غير معرَّف، وانهار رفع الملفات بخطأ نوعٍ مشوَّه
# داخل Firebase لا يذكر التخزين ولا يدلّ عليه.
#
# فالقائمة الآن تُشتقّ من الاعتماديات نفسها، وأي حزمة firebase/cloud لا تعرفها
# الخريطة **تُفشل السكربت** بدل أن تُتجاهَل. لا صمت بعد اليوم.
#
# الاستخدام:  ./tool/fetch_firebase_sdk.sh
# يُستدعى تلقائياً من tool/build_web.sh، ويتخطّى العمل إن كانت الملفات موجودة.
set -euo pipefail

cd "$(dirname "$0")/.."

# ــــ خريطة: حزمة Flutter ← اسم خدمة Firebase JS ــــ
#
# الأسماء ليست اجتهاداً: كل إضافة ويب تُسجّل نفسها بـ
# `FirebaseCoreWeb.registerService('<الاسم>')`، والحقن يبني منه اسم الملف
# `firebase-<الاسم>.js` والمتغيّر `window.firebase_<الاسم>`. فمصدر هذه
# الأسماء هو الحزم نفسها.
firebase_service_for() {
  case "$1" in
    firebase_core)          echo core ;;   # حالة خاصة: الملف firebase-app.js والمتغيّر firebase_core
    firebase_auth)          echo auth ;;
    cloud_firestore)        echo firestore ;;
    cloud_functions)        echo functions ;;
    firebase_storage)       echo storage ;;
    firebase_messaging)     echo messaging ;;
    firebase_analytics)     echo analytics ;;
    firebase_database)      echo database ;;
    firebase_performance)   echo performance ;;
    # لا تُخمَّن البقية. أسماء مثل app-check وremote-config تحمل شرطة في اسم
    # الملف واسماً آخر في المتغيّر (productNameOverride)، فكتابتها بالحدس
    # تُنتج مُحمِّلاً يبدو صحيحاً ولا يعمل. اقرأ registerService في حزمة
    # ‎<الحزمة>_web وأضف السطر بيقين.
    *)                      return 1 ;;
  esac
}

# اسم ملف الحزمة على gstatic. خدمة core وحدها ملفّها firebase-app.js.
firebase_file_for() {
  if [[ "$1" == core ]]; then echo firebase-app.js; else echo "firebase-$1.js"; fi
}

# ــــ أي خدمات يحتاجها هذا المشروع؟ ــــ
#
# تُقرأ من اعتماديات pubspec.yaml مباشرةً: كل ما بدأ بـ firebase_ أو cloud_.
# (تُستثنى ‎*_web و‎*_platform_interface — وهي غير مذكورة في pubspec أصلاً،
# لكن الاستثناء مكتوب صراحةً حتى لا يكسرها أحدٌ لاحقاً.)
PACKAGES="$(awk '
  /^dev_dependencies:/ { exit }
  /^  (firebase|cloud)_[a-z_]+:/ {
    line = $1; sub(/:$/, "", line); sub(/^[ \t]+/, "", line); print line
  }
' pubspec.yaml)"

SERVICES=()
for pkg in $PACKAGES; do
  case "$pkg" in *_web|*_platform_interface) continue ;; esac
  if ! svc="$(firebase_service_for "$pkg")"; then
    echo "✗ الحزمة '$pkg' غير معروفة في خريطة خدمات Firebase أعلى هذا الملف." >&2
    echo "  أضفها إلى firebase_service_for، وإلا لن تُستضاف حزمتها محلياً" >&2
    echo "  وستفشل ميزتها بصمت على شبكة تحجب www.gstatic.com." >&2
    exit 1
  fi
  SERVICES+=("$svc")
done

# core مطلوب دائماً: هو الملف الذي تستورده البقية، وهو المتغيّر الذي تفحصه
# firebase_core_web لتقرّر التخطّي.
case " ${SERVICES[*]} " in *" core "*) ;; *) SERVICES=(core "${SERVICES[@]}") ;; esac

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

# المصدر قابل للتبديل **لغرض واحد**: أن يشغّل الحارس
# (tool/test/firebase_sdk_modules_test.sh) هذا السكربت نفسه على خادم محلي،
# بدل أن يختبر نسخةً منه. ونسخةُ منطقٍ تتقادم كما تقادمت قائمة الحزم.
# لا يُضبط هذا المتغيّر في بناءٍ حقيقي.
BASE="${FIREBASE_SDK_BASE_URL:-https://www.gstatic.com/firebasejs/${VERSION}}"

# البصمة تحمل الخدمات لا الإصدار وحده: لو حملت الإصدار فقط لبقي مجلدٌ قديم
# ناقص خدمةً جديدة صالحاً في نظر السكربت — وهو العطل نفسه من باب آخر.
FINGERPRINT="${VERSION} ${SERVICES[*]}"
if [[ -f "$OUT/.version" && "$(cat "$OUT/.version")" == "$FINGERPRINT" ]]; then
  echo "✔ حزم Firebase المحلية موجودة ($FINGERPRINT) — لا حاجة لإعادة الجلب."
  exit 0
fi

echo "▶ جلب Firebase JS SDK $VERSION إلى $OUT"
echo "  الخدمات المشتقّة من pubspec: ${SERVICES[*]}"

# ــــ يُبنى في مجلد جانبي ثم يُبدَّل دفعةً واحدة ــــ
#
# الجلب كان يكتب في $OUT مباشرةً ويمسحه كاملاً عند أول إخفاق. ومعنى ذلك أن
# ملفاً واحداً يتعذّر تنزيله — لانقطاع شبكة، أو لأن اسم حزمةٍ جديدة ليس كما
# ظننّا — **يمحو نسخةً سليمة كانت تعمل**، فتعود المنصة لطلب الحزم من
# www.gstatic.com. وعلى شبكة الوزارة التي تحجب النطاق لا يعني ذلك بطئاً بل
# منصةً لا تُقلع إطلاقاً.
#
# فالبناء الآن في مجلد جانبي، ولا يُستبدل الأصل إلا بعد اكتمال كل الملفات.
# وأسوأ ما يقع عند الإخفاق: تبقى النسخة السابقة كما هي.
STAGE="${OUT}.incoming"
rm -rf "$STAGE"
mkdir -p "$STAGE"

for svc in "${SERVICES[@]}"; do
  f="$(firebase_file_for "$svc")"
  echo "  ↓ $f"
  if ! curl -fsSL --max-time 60 "$BASE/$f" -o "$STAGE/$f.tmp"; then
    echo "⚠ تعذّر تنزيل $f من $BASE" >&2
    if [[ -d "$OUT" ]]; then
      echo "  أُبقيت النسخة المحلية السابقة كما هي — المنصة تعمل بها." >&2
      echo "  لكن خدمة '$svc' قد لا تكون ضمنها؛ إن فشلت ميزتها فهذا سببها." >&2
    else
      echo "  لا توجد نسخة محلية سابقة، فستُجلب الحزم من www.gstatic.com عند كل فتح." >&2
      echo "  وإن كانت شبكتك تحجب هذا النطاق فلن تُقلع المنصة — عالج الاتصال ثم أعد البناء." >&2
    fi
    rm -rf "$STAGE"
    exit 0
  fi
  # الملفات يستورد بعضها بعضاً بروابط مطلقة على gstatic؛ تُحوَّل إلى مسارات
  # نسبية وإلا عاد الاعتماد على النطاق الخارجي من داخل الملفات نفسها.
  sed "s|https://www\.gstatic\.com/firebasejs/${VERSION}/|./|g" "$STAGE/$f.tmp" > "$STAGE/$f"
  rm -f "$STAGE/$f.tmp"
done

# ــــ المُحمِّل: قائمة واحدة، مُولَّدة ــــ
#
# index.html لا تعرف ما في pubspec، فكانت تكرّر القائمة بيدها — وهو المصدر
# الثاني الذي يتقادم. الآن تستورد هذا الملف وحده، ويُولَّد هنا من الخدمات
# نفسها التي جُلبت قبل سطرين. فلا توجد قائمتان لتفترقا.
{
  echo "// ملف مُولَّد بواسطة tool/fetch_firebase_sdk.sh — لا يُحرَّر يدوياً."
  echo "// الخدمات: ${SERVICES[*]} · إصدار Firebase JS SDK: ${VERSION}"
  echo "export default async function installFirebaseSdk() {"
  echo "  const modules = await Promise.all(["
  for svc in "${SERVICES[@]}"; do
    echo "    import('./$(firebase_file_for "$svc")'),"
  done
  echo "  ]);"
  # الترتيب هنا هو ترتيب SERVICES نفسه، والإسناد يقع بعد اكتمال الاستيراد كله.
  i=0
  for svc in "${SERVICES[@]}"; do
    echo "  window.firebase_${svc} = modules[$i];"
    i=$((i + 1))
  done
  echo "}"
} > "$STAGE/loader.js"

# تحقّق صارم: أي أثر متبقٍّ للنطاق يعني أن الاستضافة الذاتية ناقصة، والصمت
# عنه يعيدنا للعطل نفسه دون أن ندري.
if grep -l "www\.gstatic\.com" "$STAGE"/*.js > /dev/null 2>&1; then
  echo "✗ ما زال في الملفات المجلوبة روابط إلى www.gstatic.com:" >&2
  grep -l "www\.gstatic\.com" "$STAGE"/*.js >&2
  echo "  أُلغي التبديل لتجنّب استضافة ذاتية ناقصة تُخفي العطل." >&2
  rm -rf "$STAGE"
  exit 1
fi

echo "$FINGERPRINT" > "$STAGE/.version"

# التبديل: بعد أن اكتمل كل شيء، ولا قبله.
rm -rf "$OUT"
mv "$STAGE" "$OUT"
echo "✔ اكتمل الجلب. لن تُطلب حزم Firebase من www.gstatic.com بعد الآن."
