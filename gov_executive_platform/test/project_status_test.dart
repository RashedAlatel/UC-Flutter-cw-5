// حالة المشروع من مصدر واحد.
//
// حارس شكوى مسؤول النظام حرفياً: «وجدت مشاريع متأخرة مكتوب عليها أنها على
// المسار، ومشاريع على المسار مكتوب عليها أنها متأخرة». وسببه أن البطاقة
// الواحدة كانت تقرأ من مصدرين: حقل مخزَّن استُنتج عند الاستيراد من نصوص
// الملفات، وتاريخ استحقاق محسوب حيّاً. والتاريخ هو الفيصل.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

Project _p(ProjectStatus stored, DateTime due) => Project(
      id: 'p',
      departmentId: 'd',
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: due,
      status: stored,
      priority: PriorityLevel.medium,
      progressPercent: 50,
    );

void main() {
  final past = DateTime.now().subtract(const Duration(days: 30));
  final future = DateTime.now().add(const Duration(days: 30));

  group('التاريخ هو الفيصل', () {
    // الشكوى الأولى حرفياً.
    test('مخزَّن «على المسار» وقد فات موعده ← متأخر', () {
      final p = _p(ProjectStatus.onTrack, past);
      expect(p.effectiveStatus, ProjectStatus.delayed);
      expect(p.statusOutOfSync, isTrue);
    });

    // الشكوى الثانية حرفياً.
    test('مخزَّن «متأخر» وموعده لم يحن ← على المسار', () {
      final p = _p(ProjectStatus.delayed, future);
      expect(p.effectiveStatus, ProjectStatus.onTrack);
      expect(p.statusOutOfSync, isTrue);
    });

    test('المكتمل يبقى مكتملاً مهما مضى من وقت', () {
      final p = _p(ProjectStatus.completed, past);
      expect(p.effectiveStatus, ProjectStatus.completed);
      expect(p.delayDays, 0, reason: 'المكتمل لا يتراكم عليه تأخير');
      expect(p.statusOutOfSync, isFalse);
    });

    test('«مهدد بالخطر» يبقى تقديراً بشرياً محترماً ما لم يفت الموعد', () {
      expect(_p(ProjectStatus.atRisk, future).effectiveStatus, ProjectStatus.atRisk);
    });

    test('لكن فوات الموعد يغلب التقدير البشري', () {
      expect(_p(ProjectStatus.atRisk, past).effectiveStatus, ProjectStatus.delayed);
    });

    test('على المسار وموعده لم يحن ← لا تغيير ولا مخالفة', () {
      final p = _p(ProjectStatus.onTrack, future);
      expect(p.effectiveStatus, ProjectStatus.onTrack);
      expect(p.statusOutOfSync, isFalse);
    });
  });

  group('اتساق البطاقة', () {
    // جوهر العطل: سطر التأخير وشارة الحالة يجب ألا يتناقضا أبداً.
    test('كل مشروع فيه أيام تأخير حالته الفعلية «متأخر»', () {
      for (final stored in ProjectStatus.values) {
        final p = _p(stored, past);
        if (p.delayDays > 0) {
          expect(p.effectiveStatus, ProjectStatus.delayed,
              reason: 'مشروع متأخر $stored يعرض شارة غير «متأخر» — وهو التناقض نفسه');
        }
      }
    });

    test('وكل مشروع بلا أيام تأخير لا تقول شارته «متأخر»', () {
      for (final stored in ProjectStatus.values) {
        final p = _p(stored, future);
        expect(p.delayDays, 0);
        expect(p.effectiveStatus, isNot(ProjectStatus.delayed));
      }
    });
  });
}
