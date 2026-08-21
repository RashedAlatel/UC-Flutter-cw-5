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

# ــــ حرّاس السكربتات ــــ
#
# هذه فحوص نصّية لا يقرؤها `flutter test` ولا `flutter analyze`، وموضعها هنا
# لا في مجلد الاختبارات عمداً: من يبني وينشر لا يشغّل مجموعة اختبارات، فلو
# تُركت جانباً لما حرست أحداً. وقد سقطت حزمة التخزين من القائمة المستضافة
# محلياً جولاتٍ كاملة بلا أن يصيح شيء — وهذا ما يمنع تكراره.
./tool/test/firebase_sdk_modules_test.sh
./tool/test/storage_message_test.sh

# استضافة حزم Firebase محلياً حتى لا تُجلب من www.gstatic.com عند كل فتح.
# السكربت يتخطّى نفسه إن كانت الملفات موجودة، ولا يُفشل البناء إن تعذّر
# الاتصال — عندها تعمل المنصة كما كانت بجلب الحزم من الشبكة.
./tool/fetch_firebase_sdk.sh || echo "⚠ تعذّر تجهيز حزم Firebase المحلية — يُكمَل البناء."

# ــــ أي شيفرة نبني؟ ــــ
#
# البصمة الزمنية وحدها خدعتنا: كان المستخدم يبني وينشر فيتغيّر التاريخ، بينما
# `git pull` قد فشل صامتاً (تعديل محلي يمنع الدمج) فتُنشر **شيفرة قديمة ببصمة
# جديدة**. وضاعت جولة كاملة ونحن نظن أن الإصلاح منشور وهو ليس كذلك. لذلك
# تُطبع هوية الالتزام وتُكتب في build.json، وتُرفع الأعلام عند أي شبهة.
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

DIRTY=""
if [ -n "$(git status --porcelain -- . ':(exclude)build' 2>/dev/null)" ]; then
  DIRTY="yes"
fi

BEHIND=""
if git fetch --quiet origin "$BRANCH" 2>/dev/null; then
  COUNT="$(git rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo 0)"
  [ "${COUNT:-0}" -gt 0 ] && BEHIND="$COUNT"
fi

STAMP="$(date -u '+%Y-%m-%d %H:%M UTC')"
echo "▶ بناء نسخة الويب — بصمة البناء: $STAMP"
echo "  الفرع: $BRANCH · الالتزام: $COMMIT"

if [ -n "$BEHIND" ]; then
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "⛔ توقّف: فرعك متأخّر عن الخادم بـ $BEHIND التزاماً."
  echo "   ستنشر شيفرة قديمة ببصمة جديدة، وهذا ما يُضيّع الوقت في التشخيص."
  echo "   نفّذ أولاً:  git fetch origin && git reset --hard origin/$BRANCH"
  echo "══════════════════════════════════════════════════════════════"
  echo ""
fi

if [ -n "$DIRTY" ]; then
  echo "⚠ لديك تعديلات محلية غير محفوظة — وهي ما يمنع «git pull» من الدمج."
  echo "   للتخلّص منها:  git reset --hard origin/$BRANCH"
fi

flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=BUILD_STAMP="$STAMP" \
  --dart-define=BUILD_COMMIT="$COMMIT"

# تُقرأ من المتصفح بمُبطِّل تخزين لاكتشاف توفّر إصدار أحدث، ولمعرفة أي شيفرة
# منشورة فعلاً — الالتزام هو الحقيقة، والتاريخ مجرّد وقت الضغط على الزر.
printf '{"stamp":"%s","commit":"%s","branch":"%s"}\n' "$STAMP" "$COMMIT" "$BRANCH" \
  > build/web/build.json

echo "✔ اكتمل البناء. build/web جاهز للنشر."
echo "  index.html = $(wc -c < build/web/index.html) بايت"
echo "  الالتزام المنشور: $COMMIT"
if [ -n "$BEHIND" ]; then
  echo "  ⛔ تذكير: هذه شيفرة قديمة — فرعك متأخّر بـ $BEHIND التزاماً."
fi
