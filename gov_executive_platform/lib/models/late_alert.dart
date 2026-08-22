import 'app_user.dart';
import 'enums.dart';
import 'notify_templates.dart';
import 'project.dart';
import '../utils/formatters.dart';

/// رسالة تنبيه موجَّهة لشخص بعينه.
typedef AlertMessage = ({AppUser user, String subject, String body});

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
/// الترتيب بالاسم ليكون الناتج ثابتاً بين استدعاءين — يقرؤه مسؤول النظام في
/// بطاقة الطلب، والقائمة التي تتبدّل بلا سبب تُفقد الثقة.
List<AlertMessage> buildLateAlerts({
  required List<Project> lateProjects,
  required List<AppUser> users,
}) {
  final byUid = {for (final u in users) u.id: u};
  final assigned = <String, List<Project>>{};

  for (final project in lateProjects) {
    // مجموعة لا قائمة: من كان مديراً ومنفّذاً على المشروع نفسه لا يُحسب مرتين.
    for (final uid in {...project.managerUids, ...project.executorUids}) {
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
      // مشروع واحد: النصّ من القالب القائم حرفياً، فلا تفترق صياغة التنبيه
      // الجماعي عن صياغة التنبيه الفردي من صفحة المشروع.
      final context = NotifyContext.fromProject(projects.first);
      messages.add((
        user: user,
        subject: NotifyTemplate.delayAlert.subjectFor(context),
        body: NotifyTemplate.delayAlert.bodyFor(context),
      ));
      continue;
    }

    final lines = projects
        .map((p) => '• ${p.name} — متأخر ${p.delayDays} يوماً '
            '(نسبة الإنجاز ${Formatters.percent(p.progressPercent)}، '
            'والموعد النهائي كان ${Formatters.date(p.dueDate)}).')
        .join('\n');
    messages.add((
      user: user,
      subject: 'تنبيه تأخير — ${projects.length} مشاريع تحت مسؤوليتكم',
      body: 'نفيدكم بأن ${projects.length} من المشاريع المسندة إليكم تجاوزت مواعيدها النهائية:\n\n'
          '$lines\n\n'
          'نأمل معالجة الأمر وموافاتنا بأسباب التأخير وخطة الاستدراك.',
    ));
  }

  messages.sort((a, b) => a.user.name.compareTo(b.user.name));
  return messages;
}
