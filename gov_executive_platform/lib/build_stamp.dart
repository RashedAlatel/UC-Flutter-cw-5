/// بصمة البناء: تاريخ ووقت بناء النسخة المنشورة، تُحقن وقت البناء عبر
/// `tool/build_web.sh`.
///
/// في ملف مستقل عمداً — لا داخل `lib/widgets/update_banner.dart` — لأن ذاك
/// يستورد `package:web` الخاص بالمتصفح، فلا يمكن استيراده من شاشة تُختبر على
/// جهاز Dart الافتراضي. البصمة نصّ خالص تصلح لكل المنصات.
const String kBuildStamp = String.fromEnvironment('BUILD_STAMP', defaultValue: 'تطوير');
