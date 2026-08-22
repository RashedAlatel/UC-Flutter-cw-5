import 'app_user.dart';
import 'enums.dart';
import 'project.dart';
import '../utils/formatters.dart';

/// رسالة تنبيه موجَّهة لشخص بعينه، ومعها المشاريع التي بُنيت منها.
///
/// و[projects] ليست زينة: نافذة المراجعة تعرض لكل مستلم عدد مشاريعه، وتسمح
/// باستبعاد مشروع فتُعاد الرسائل بلا حساب يدوي — ولولاها لَما عرفت النافذة
/// **لماذا** يقع فلانٌ في قائمة المستلمين.
typedef AlertMessage = ({AppUser user, String subject, String body, List<Project> projects});

/// رابط مباشر يفتح المنصة على المشروع بعينه.
///
/// ــــ لماذا مُعامِلٌ يُمرَّر لا `Uri.base` تُقرأ هنا؟ ــــ
///
/// لأن هذا الملف يُختبر على جهاز Dart، و`Uri.base` هناك مجلّد العمل لا عنوان
/// المنصة — فتخرج في نصّ الرسالة روابط `file:///` يقرؤها موظفٌ في الوزارة.
/// فيُقرأ العنوان في الواجهة (حيث المتصفح) ويُمرَّر من هناك.
String projectLink(String baseUrl, String projectId) {
  final base = baseUrl.trim();
  if (base.isEmpty || projectId.isEmpty) return '';
  final sep = base.contains('?') ? '&' : '?';
  return '$base${sep}project=$projectId';
}

/// سطرُ مشروعٍ واحد في نصّ الرسالة — بكل ما طُلب: الاسم وتاريخ الاستحقاق
/// وأيام التأخير ونسبة الإنجاز والرابط المباشر.
String _projectBlock(Project p, String baseUrl) {
  final link = projectLink(baseUrl, p.id);
  return '• ${p.name}\n'
      '   تاريخ الاستحقاق: ${Formatters.date(p.dueDate)}\n'
      '   أيام التأخير: ${p.delayDays}\n'
      '   نسبة الإنجاز: ${Formatters.percent(p.progressPercent)}'
      '${link.isEmpty ? '' : '\n   رابط المشروع: $link'}';
}

const String _callToAction =
    'نأمل تحديث حالة المشروع ونسبة إنجازه على المنصة، وموافاتنا بأسباب '
    'التأخير وخطة الاستدراك.';

/// يبني رسائل تنبيه المشاريع المتأخرة، **رسالة واحدة لكل مسؤول** تسرد كل
/// مشاريعه المتأخرة.
///
/// ــــ لماذا رسالة لكل شخص لا لكل مشروع؟ ــــ
///
/// من يقود خمسة مشاريع متأخرة كان سيتلقّى خمس رسائل متطابقة الصياغة في
/// دقيقة واحدة. وذلك لا يُقرأ، بل يُدرَّب المستلم على تجاهل بريد المنصة —
/// فينتهي التنبيه إلى عكس غرضه.
///
/// المستلمون: مديرو المشروع ومنفّذوه من **أصحاب الحسابات**. أما
/// [Project.executorNames] فأسماء نصية وردت في ملفات الوزارة ولا تقابلها
/// حسابات ولا بريد، فلا سبيل لمراسلتها — وإسقاطها هنا صريح لا سهو.
///
/// ومن لا بريد له يسقط: الرسالة إليه تفشل على الخادم فتُفشل الدفعة كلها
/// (`deliverMessages` ترمي عند أول إخفاق)، فيُمنع من المحاولة من أصله.
///
/// و[excludedUids] هم من استبعدهم المُرسِل في نافذة المراجعة — يخرجون بعد
/// حساب العضوية لا قبله، فيبقى عدد «مسؤولي هذه المشاريع» صادقاً في العرض.
///
/// الترتيب بالاسم ليكون الناتج ثابتاً بين استدعاءين — يقرؤه مسؤول النظام في
/// بطاقة الطلب، والقائمة التي تتبدّل بلا سبب تُفقد الثقة.
List<AlertMessage> buildLateAlerts({
  required List<Project> lateProjects,
  required List<AppUser> users,
  String baseUrl = '',
  Set<String> excludedUids = const {},
}) {
  final byUid = {for (final u in users) u.id: u};
  final assigned = <String, List<Project>>{};

  for (final project in lateProjects) {
    // مجموعة لا قائمة: من كان مديراً ومنفّذاً على المشروع نفسه لا يُحسب مرتين.
    for (final uid in {...project.managerUids, ...project.executorUids}) {
      if (excludedUids.contains(uid)) continue;
      final user = byUid[uid];
      if (user == null || user.email.trim().isEmpty) continue;
      if (user.status != UserStatus.approved) continue;
      assigned.putIfAbsent(uid, () => []).add(project);
    }
  }

  final messages = <AlertMessage>[];
  for (final entry in assigned.entries) {
    final user = byUid[entry.key]!;
    final projects = entry.value..sort((a, b) => b.delayDays.compareTo(a.delayDays));

    if (projects.length == 1) {
      final p = projects.first;
      messages.add((
        user: user,
        subject: 'تنبيه تأخير — ${p.name}',
        body: 'نفيدكم بأن المشروع التالي المسند إليكم تجاوز موعده النهائي:\n\n'
            '${_projectBlock(p, baseUrl)}\n\n'
            '$_callToAction',
        projects: projects,
      ));
      continue;
    }

    messages.add((
      user: user,
      subject: 'تنبيه تأخير — ${projects.length} مشاريع تحت مسؤوليتكم',
      body: 'نفيدكم بأن ${projects.length} من المشاريع المسندة إليكم تجاوزت '
          'مواعيدها النهائية:\n\n'
          '${projects.map((p) => _projectBlock(p, baseUrl)).join('\n\n')}\n\n'
          '$_callToAction',
      projects: projects,
    ));
  }

  messages.sort((a, b) => a.user.name.compareTo(b.user.name));
  return messages;
}
