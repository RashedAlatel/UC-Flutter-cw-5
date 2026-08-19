#!/usr/bin/env bash
#
# بناء نسخة الويب للنشر. استخدم هذا السكربت بدل `flutter build web --release`
# المجرّد، لأنه يحمل رايتين وبصمة لا يجوز نسيانها:
#
#   --no-web-resources-cdn
#       يجعل محرك الرسم (CanvasKit، نحو ٧ ميغابايت) يُحمَّل من ملفات المنصة
#       نفسها لا من www.gstatic.com. بدونها لا تُقلع المنصة إطلاقاً على أي
#       شبكة تحجب هذا النطاق، وتظهر شاشة بيضاء.
#
#   BUILD_STAMP
#       بصمة زمنية تُطبع في الشريط الجانبي وتُكتب في build/web/build.json،
#       ليعرف كل مستخدم أي إصدار يرى، وليكتشف التطبيق توفّر تحديث فيطلب
#       إعادة التحميل بدل بقاء المستخدم على نسخة قديمة صامتاً.
#
# الاستخدام:  ./tool/build_web.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# استضافة حزم Firebase محلياً حتى لا تُجلب من www.gstatic.com عند كل فتح.
# السكربت يتخطّى نفسه إن كانت الملفات موجودة، ولا يُفشل البناء إن تعذّر
# الاتصال — عندها تعمل المنصة كما كانت بجلب الحزم من الشبكة.
./tool/fetch_firebase_sdk.sh || echo "⚠ تعذّر تجهيز حزم Firebase المحلية — يُكمَل البناء."

STAMP="$(date -u '+%Y-%m-%d %H:%M UTC')"
echo "▶ بناء نسخة الويب — بصمة البناء: $STAMP"

flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=BUILD_STAMP="$STAMP"

# تُقرأ من المتصفح بمُبطِّل تخزين لاكتشاف توفّر إصدار أحدث.
printf '{"stamp":"%s"}\n' "$STAMP" > build/web/build.json

echo "✔ اكتمل البناء. build/web جاهز للنشر."
echo "  index.html = $(wc -c < build/web/index.html) بايت"
