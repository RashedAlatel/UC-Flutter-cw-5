// حالةُ المشروع من نسبة إنجازه — وحدةٌ نقيّة.
//
// ــــ العطلُ الذي أوجد هذا الملفّ ــــ
//
// بلّغ مسؤول النظام أن مدير الإدارة ومدير المشروع يحتاجان تعديل نسبة
// الإنجاز **بعد اكتمال المشروع**. وقِيس فوُجد أن النسبة تُكتب فعلاً،
// **والمشروع لا يخرج من «مكتمل» أبداً**:
//
//   • `Project.effectiveStatus` تعيد `completed` أوّلَ شيء ومهما كان الرقم.
//   • وحسابُ الحالة في `addDailyUpdate` لا يُنزل مشروعاً عن الاكتمال:
//     شروطُه لا تتحقّق حين تنزل النسبة، فتبقى `completed`.
//
// فمن أدخل ١٠٠٪ سهواً يبقى مشروعُه «مكتملاً» وإن صحّح الرقمَ إلى ٨٠٪ —
// شارةٌ تقول شيئاً ورقمٌ يقول غيرَه.
//
// ــــ ولماذا وحدةٌ نقيّة ــــ
//
// القاعدةُ كانت مكتوبةً داخل `addDailyUpdate` وحدها. ومع بابٍ ثانٍ للتصحيح
// تصير في موضعين يفترقان بأول تعديل: تحديثٌ يوميّ يُخرج من الاكتمال
// وتصحيحٌ لا يُخرج، أو العكس. فأُخرجت لتُقاس وحدها ويُنادَى عليها من
// الموضعين.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project_progress.dart';

void main() {
  group('الاكتمال', () {
    test('مئةٌ تُكمل المشروع', () {
      expect(
        statusForProgress(
          progress: 100,
          current: ProjectStatus.onTrack,
          delayDays: 0,
          hasNewRisk: false,
        ),
        ProjectStatus.completed,
      );
    });

    // ولو كان متأخّراً: الإنجازُ وقع، والتأخيرُ وصفُ ما مضى لا حالُ اليوم.
    test('ومئةٌ تُكمل المتأخّر كذلك', () {
      expect(
        statusForProgress(
          progress: 100,
          current: ProjectStatus.delayed,
          delayDays: 40,
          hasNewRisk: false,
        ),
        ProjectStatus.completed,
      );
    });

    // ــ وهذا هو العطلُ المقيس ــ
    //
    // النزولُ عن مئةٍ يُخرج من الاكتمال. ولولاه لَبقيت الشارةُ «مكتمل»
    // والرقمُ ٨٠٪ — وهو ما بلّغ عنه.
    test('والنزولُ عن مئةٍ يُخرج من الاكتمال', () {
      expect(
        statusForProgress(
          progress: 80,
          current: ProjectStatus.completed,
          delayDays: 0,
          hasNewRisk: false,
        ),
        isNot(ProjectStatus.completed),
      );
    });

    test('ويعود إلى ما يقوله موعدُه: متأخّرٌ إن تجاوزه', () {
      expect(
        statusForProgress(
          progress: 80,
          current: ProjectStatus.completed,
          delayDays: 12,
          hasNewRisk: false,
        ),
        ProjectStatus.delayed,
      );
    });

    test('وعلى المسار إن لم يتجاوزه', () {
      expect(
        statusForProgress(
          progress: 80,
          current: ProjectStatus.completed,
          delayDays: 0,
          hasNewRisk: false,
        ),
        ProjectStatus.onTrack,
      );
    });

    // عائقٌ يُسجَّل مع التصحيح يُنزله «مهدَّداً» لا «على المسار».
    test('ومهدَّدٌ إن سُجّل معه عائق', () {
      expect(
        statusForProgress(
          progress: 80,
          current: ProjectStatus.completed,
          delayDays: 0,
          hasNewRisk: true,
        ),
        ProjectStatus.atRisk,
      );
    });
  });

  group('وما دون المئة يُحسب كما كان', () {
    test('تأخّرٌ يتجاوز خمسة أيام يُقال متأخّراً', () {
      expect(
        statusForProgress(
          progress: 50,
          current: ProjectStatus.onTrack,
          delayDays: 6,
          hasNewRisk: false,
        ),
        ProjectStatus.delayed,
      );
    });

    // خمسةٌ فأقلّ ليست تأخّراً في هذا الحساب — حدٌّ قائمٌ لا يُبدَّل هنا.
    test('وخمسةٌ فأقلّ ليست تأخّراً', () {
      expect(
        statusForProgress(
          progress: 50,
          current: ProjectStatus.onTrack,
          delayDays: 5,
          hasNewRisk: false,
        ),
        isNot(ProjectStatus.delayed),
      );
    });

    test('والعائقُ يُقدَّم على «على المسار»', () {
      expect(
        statusForProgress(
          progress: 50,
          current: ProjectStatus.onTrack,
          delayDays: 0,
          hasNewRisk: true,
        ),
        ProjectStatus.atRisk,
      );
    });

    // والتأخيرُ يُقدَّم على العائق: الأشدُّ يُعرض.
    test('والتأخيرُ يُقدَّم على العائق', () {
      expect(
        statusForProgress(
          progress: 50,
          current: ProjectStatus.onTrack,
          delayDays: 9,
          hasNewRisk: true,
        ),
        ProjectStatus.delayed,
      );
    });

    // تقدّمٌ بلا عائقٍ ولا تأخّر يُعيد المشروعَ إلى المسار — وكان كذلك.
    test('والتقدّمُ يُعيد المهدَّد إلى المسار', () {
      expect(
        statusForProgress(
          progress: 60,
          current: ProjectStatus.atRisk,
          delayDays: 0,
          hasNewRisk: false,
          previousProgress: 40,
        ),
        ProjectStatus.onTrack,
      );
    });

    // وبلا تقدّمٍ ولا سبب: تبقى الحالُ كما هي، ولا تُختلق حركة.
    test('وبلا تقدّمٍ تبقى الحالُ كما هي', () {
      expect(
        statusForProgress(
          progress: 40,
          current: ProjectStatus.atRisk,
          delayDays: 0,
          hasNewRisk: false,
          previousProgress: 40,
        ),
        ProjectStatus.atRisk,
      );
    });
  });
}
