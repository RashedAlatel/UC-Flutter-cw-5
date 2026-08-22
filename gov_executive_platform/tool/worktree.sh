#!/usr/bin/env bash
#
# حالة نسخة العمل: ما الملفات المعدَّلة، ومَن عدّلها — أنت أم أدواتنا؟
# يُستعمل بـ `source ./tool/worktree.sh` من build_web.sh وdeploy.sh.
#
# ــــ لماذا التمييز؟ ــــ
#
# كان الحارس يقول «لديك تعديلات محلية» ويسكت، فيُترك من ينشر أمام أمرٍ
# يمحو نسخته (`git reset --hard`) بلا أن يعرف ما الذي يمحوه. وهذا وحده
# عيب.
#
# والأسوأ منه أنه كان يُسوّي بين تعديلٍ كتبه إنسان وتعديلٍ كتبته أدواتنا:
# `pubspec.lock` يمسّه `flutter pub get`، و`functions/package-lock.json`
# يمسّه `npm install` الذي يشغّله `firebase deploy --only functions`،
# ونسخة Flutter/npm على جهاز الناشر تختلف عن التي بُني بها المستودع. فكان
# النشر يتوقّف عند **كل مرة**، ويتعلّم المستخدم أن يمحو نسخته بلا سبب —
# وهي عادةٌ تمحو يوماً تعديلاً حقيقياً.
#
# ولا يُضاف الملفّان إلى `.gitignore`: مِلفّا القفل يجب أن يبقيا متتبَّعين
# حتى يُبنى الجميع بالإصدارات نفسها. المطلوب أن يُميَّزا لا أن يُخفيا.
#
# ــــ وملاحظتان في التنفيذ ــــ
#
# • `git status --porcelain` يطبع المسارات **من جذر المستودع** لا من
#   المجلد الحالي، والتطبيق في مجلد فرعي. فيُقرأ البادئة من
#   `git rev-parse --show-prefix` بدل افتراضها.
# • `awk '{print $NF}'` لا `cut`: سطر إعادة التسمية يكون
#   `R  قديم -> جديد`، والاسم الأخير هو المقصود.
#
# ولا `bash` حديثة تُفترض: هذا يُشغَّل على macOS ببـ bash 3.2. وقد سقط
# حارسٌ سابق لأنه كُتب على bash 5، فأوقف نشر المستخدم بخطأ نحوي.

# الملفات التي تُعيد أدوات البناء كتابتها بلا تدخّل من أحد.
worktree_regenerated_files() {
  local prefix
  prefix="$(git rev-parse --show-prefix 2>/dev/null || echo '')"
  echo "${prefix}pubspec.lock ${prefix}functions/package-lock.json"
}

# أسماء الملفات المعدَّلة، اسمٌ في كل سطر. فارغ إن كانت النسخة نظيفة.
worktree_dirty_files() {
  git status --porcelain -- . ':(exclude)build' 2>/dev/null | awk '{print $NF}'
}

# "yes" إن كان كل ما تغيّر من الملفات التي تُعيد أدواتنا كتابتها.
# والنسخة النظيفة تُعيد "no": لا دِرن أصلاً فلا يُوصف.
worktree_dirt_is_generated() {
  local files="$1" known f
  [ -z "$files" ] && { echo no; return; }
  known=" $(worktree_regenerated_files) "
  for f in $files; do
    case "$known" in
      *" $f "*) ;;
      *) echo no; return ;;
    esac
  done
  echo yes
}
