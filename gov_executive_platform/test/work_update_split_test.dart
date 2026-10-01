// ما يصير إليه العمل بعد تحديثٍ يومي — وما لا يصير إليه.
//
// ــــ لماذا أُخرج هذا المنطق ليُقاس ــــ
//
// كان داخل `addWorkUpdate`، ولا تعمل إلا بـFirestore حيّ — أي خارج مدى أي
// اختبار. ثم نُقلت الدالّة كلُّها حين فُكّت دفعتُها الذرّية، والنقلُ بلا
// قياسٍ مقامرة: هذا المنطق هو **أوسع ثقبٍ في دورة الإغلاق** كان قد سُدّ.
//
// بلوغُ المئة كان يكتب «منجَز» مباشرةً. فلو أُغلق باب «قائمة الحالة» في
// نموذج العمل وحده، لبقي كلُّ منفّذٍ قادراً على إغلاق عمله من **نموذج
// التحديث اليومي** — وهو أكثر ما يُفتح في المنصة.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/closure_trail.dart';
import 'package:gov_exec_platform/models/enums.dart';

final _stamp = DateTime(2026, 8, 26, 12);

/// سجلُّ إغلاقٍ **له معتمِد** — أي عملٌ طلبه غيرُ منفّذه.
const _approved = ClosureTrail(approverUid: 'u-boss', approverName: 'الطالب');

/// وسجلٌّ فارغ: عملٌ بلا معتمِد، وهو حال كل ما كُتب قبل دورة الإغلاق.
const _none = ClosureTrail.none;

({double progressPercent, TaskStatus status, DateTime? completedDate, ClosureTrail? closure})
    outcome(ClosureTrail closure, double progress) => AppStore.workUpdateOutcome(
          closure: closure,
          progressPercent: progress,
          stamp: _stamp,
          actorUid: 'u-worker',
          actorName: 'المنفّذ',
        );

void main() {
  group('المئة مع معتمِدٍ لا تُغلق', () {
    final r = outcome(_approved, 100);

    // الثقب بعينه: لو عادت `done` هنا لأغلق المنفّذُ ما طلبه غيرُه.
    test('الحالة «بانتظار الاعتماد» لا «منجَزة»', () {
      expect(r.status, TaskStatus.awaitingApproval);
      expect(r.status, isNot(TaskStatus.done));
    });

    test('ولا يُكتب تاريخ إنجاز لعملٍ لم يُغلق', () {
      expect(r.completedDate, isNull);
    });

    test('ويُسجَّل من أعلن الإتمام ومتى', () {
      expect(r.closure, isNotNull);
      expect(r.closure!.claimedByUid, 'u-worker');
      expect(r.closure!.claimedByName, 'المنفّذ');
      expect(r.closure!.claimedAt, _stamp);
    });

    test('ويبقى المعتمِد كما هو — الإعلان لا ينقل الاعتماد', () {
      expect(r.closure!.approverUid, 'u-boss');
    });
  });

  group('والمئة بلا معتمِدٍ تُغلق', () {
    final r = outcome(_none, 100);

    test('الحالة «منجَزة»', () {
      expect(r.status, TaskStatus.done);
    });

    test('ويُكتب تاريخ الإنجاز', () {
      expect(r.completedDate, _stamp);
    });

    // لا سجلَّ إغلاقٍ يُكتب: لا معتمِد ولا إعلانَ إتمامٍ ينتظر أحداً.
    test('ولا يُكتب سجلُّ إغلاق', () {
      expect(r.closure, isNull);
    });
  });

  group('وما دون المئة يُخرج العمل من «منجَز»', () {
    test('قيد التنفيذ، بلا تاريخ إنجاز', () {
      final r = outcome(_approved, 40);
      expect(r.status, TaskStatus.inProgress);
      expect(r.completedDate, isNull);
      expect(r.closure, isNull);
    });

    test('وكذلك بلا معتمِد', () {
      final r = outcome(_none, 40);
      expect(r.status, TaskStatus.inProgress);
      expect(r.completedDate, isNull);
    });

    // صفرٌ ليس حالةً خاصة: من أعاد النسبة إلى الصفر عملُه قيد التنفيذ.
    test('والصفر قيد التنفيذ لا شيء آخر', () {
      expect(outcome(_none, 0).status, TaskStatus.inProgress);
    });
  });

  group('وحدُّ المئة', () {
    test('تسعةٌ وتسعون لا تُغلق', () {
      expect(outcome(_none, 99).status, TaskStatus.inProgress);
    });

    test('والمئة تُغلق', () {
      expect(outcome(_none, 100).status, TaskStatus.done);
    });

    // ما فوق المئة يُعامَل معاملتها — لا يُترك «قيد التنفيذ» بمقارنةٍ خاطئة.
    test('وما فوقها كذلك', () {
      expect(outcome(_none, 120).status, TaskStatus.done);
    });
  });

  test('والنسبة تُنقل كما وردت', () {
    expect(outcome(_none, 37.5).progressPercent, 37.5);
  });
}
