/// بصمة البناء: تاريخ ووقت بناء النسخة المنشورة، تُحقن وقت البناء عبر
/// `tool/build_web.sh`.
///
/// في ملف مستقل عمداً — لا داخل `lib/widgets/update_banner.dart` — لأن ذاك
/// يستورد `package:web` الخاص بالمتصفح، فلا يمكن استيراده من شاشة تُختبر على
/// جهاز Dart الافتراضي. البصمة نصّ خالص تصلح لكل المنصات.
const String kBuildStamp = String.fromEnvironment('BUILD_STAMP', defaultValue: 'تطوير');

/// هوية الالتزام (commit) الذي بُنيت منه هذه النسخة.
///
/// البصمة الزمنية وحدها لا تكفي — بل خدعتنا مرتين: تتغيّر مع كل بناء حتى لو
/// كانت الشيفرة قديمة (لأن `git pull` فشل صامتاً، أو لأن النشر لم يكتمل).
/// فيرى المستخدم تاريخاً جديداً ويظن أن الإصلاح وصله، وتضيع جولة كاملة في
/// تشخيص عطلٍ مُصلَحٍ أصلاً. أما الالتزام فلا يكذب.
const String kBuildCommit = String.fromEnvironment('BUILD_COMMIT', defaultValue: '');

/// سطر الإصدار كما يُعرض للمستخدم: التاريخ، ومعه الالتزام إن عُرف.
String get buildLabel => kBuildCommit.isEmpty ? kBuildStamp : '$kBuildStamp · $kBuildCommit';
