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

# "yes" إن كان في الدرن ما يمسّه الوارد من الخادم.
#
# ــــ لماذا هذا السؤال بالذات؟ ــــ
#
# كان الحارس يقف على **أي** ملفٍّ متّسخ، ويقول إن ذلك «يمنع git pull من
# الدمج فتبقى شيفرتك قديمة». والحجّة غير صحيحة، وقد اختُبرت لا استُنتجت:
# مستودعان، وملفٌّ متّسخ لا يمسّه الوارد، ثم سحبٌ — فنجح السحب.
#
# فـ`git` لا يرفض الدمج إلا حين يكون المتّسخ **مما يمسّه الوارد نفسه**.
# وهذا ما تسأله هذه الدالّة، لا «هل هناك درن؟».
#
# ومن لا يجد الفرع البعيد (شبكةٌ منقطعة، أو فرعٌ لم يُرفع بعد) يُجاب "no":
# لا وارِدَ يُعرف، فلا يُدَّعى تعارضٌ لا دليل عليه. والحمايةُ التي تهمّ —
# ألّا تُنشر شيفرة قديمة — يحرسها فحصُ التأخّر لا هذه.
worktree_dirt_blocks_pull() {
  local files="$1" branch="$2" incoming f g
  [ -z "$files" ] && { echo no; return; }
  incoming="$(git diff --name-only "HEAD..origin/$branch" 2>/dev/null)" || { echo no; return; }
  [ -z "$incoming" ] && { echo no; return; }
  for f in $files; do
    for g in $incoming; do
      [ "$f" = "$g" ] && { echo yes; return; }
    done
  done
  echo no
}

# أسماء الملفات المتّسخة التي يمسّها الوارد — وهي وحدها ما يُسمّى عند الوقوف.
worktree_conflicting_files() {
  local files="$1" branch="$2" incoming f g
  incoming="$(git diff --name-only "HEAD..origin/$branch" 2>/dev/null)" || return 0
  for f in $files; do
    for g in $incoming; do
      [ "$f" = "$g" ] && { echo "$f"; break; }
    done
  done
}

# "yes" إن كان فرق الملفات المتّسخة يختفي بتجاهل المسافات.
#
# سببٌ يتكرّر بلا أن يُرى: محرّرٌ يبدّل نهايات الأسطر أو يُقلّم مسافةً، فيعود
# الملف «معدَّلاً» بعد كل استرجاع و`git diff` لا يُظهر شيئاً للعين.
worktree_dirt_is_whitespace_only() {
  git diff --quiet 2>/dev/null && { echo no; return; }
  if git diff --quiet --ignore-all-space --ignore-blank-lines 2>/dev/null; then
    echo yes
  else
    echo no
  fi
}
