import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/itsm/sla.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/ticket.dart';

final DateTime opened = DateTime(2026, 5, 10, 8, 0);

Ticket t({
  PriorityLevel priority = PriorityLevel.high,
  DateTime? firstResponseAt,
  DateTime? resolvedAt,
  int waitingMs = 0,
  DateTime? waitingSince,
}) =>
    Ticket(
      id: 'k1',
      kind: TicketKind.incident,
      title: 'الطابعة لا تعمل',
      description: '',
      priority: priority,
      status: TicketStatus.open,
      reporterUid: 'u-rep',
      reporterName: 'مبلِّغ',
      createdAt: opened,
      firstResponseAt: firstResponseAt,
      resolvedAt: resolvedAt,
      waitingMs: waitingMs,
      waitingSince: waitingSince,
    );

void main() {
  // السياسةُ المبدئيّة: «مرتفعة» ردٌّ في ساعة، وحلٌّ في ثماني ساعات.
  const p = SlaPolicy.standard;

  group('ساعةُ أوّلِ ردّ', () {
    test('ردٌّ قبل المهلة يُقرأ «ضمن المدّة»', () {
      final c = SlaEngine.respond(t(firstResponseAt: opened.add(const Duration(minutes: 20))), p,
          opened.add(const Duration(hours: 9)));
      expect(c.outcome, SlaOutcome.met);
    });

    test('وردٌّ بعدها يُقرأ «تجاوز» ولو جاء الحلُّ سريعاً', () {
      final c = SlaEngine.respond(t(firstResponseAt: opened.add(const Duration(hours: 3))), p,
          opened.add(const Duration(hours: 9)));
      expect(c.outcome, SlaOutcome.missed);
    });

    // ــ والحدُّ لمن بلغه لا عليه ــ
    //
    // ردٌّ في اللحظة الأخيرة بالضبط وقوعٌ **داخل** المهلة. ولولا هذا
    // الاختبار لمرّت `!isBefore` مكان `isAfter` بلا أن يُعضّ أحد.
    test('وردٌّ في اللحظة الأخيرة بالضبط داخلَ المهلة', () {
      final c = SlaEngine.respond(
          t(firstResponseAt: opened.add(const Duration(hours: 1))), p, opened);
      expect(c.outcome, SlaOutcome.met);
    });

    test('وبلاغٌ لم يُردَّ عليه وانقضت مهلتُه متجاوز', () {
      final c = SlaEngine.respond(t(), p, opened.add(const Duration(hours: 2)));
      expect(c.outcome, SlaOutcome.breached);
      expect(c.remaining.isNegative, isTrue, reason: 'والباقي سالبٌ يقول كم مضى بعدها');
    });

    test('وما بقي منه ربعُ المهلة أو أقلُّ «يوشك»', () {
      // مهلةُ ساعة، فآخرُ خمسَ عشرةَ دقيقةً إنذار.
      final c = SlaEngine.respond(t(), p, opened.add(const Duration(minutes: 50)));
      expect(c.outcome, SlaOutcome.atRisk);
    });

    test('وقبل ذلك «ضمن المدّة» لا إنذار', () {
      final c = SlaEngine.respond(t(), p, opened.add(const Duration(minutes: 10)));
      expect(c.outcome, SlaOutcome.onTrack);
    });
  });

  group('ساعةُ الحلّ تتوقّف حين يكون الدورُ على المستفيد', () {
    // ــ العطل الذي أوجد هذه المجموعة ــ
    //
    // فنّيٌّ سأل المستفيدَ فلم يُجَب يومين. ولولا الإزاحة لَقيل إنّه تجاوز
    // مهلةَ ثماني ساعات — وهي تهمةٌ بما لم يفعل. ومقياسٌ يُتّهم به البريءُ
    // يُهمَل بعد أسبوع.
    test('انتظارٌ مسجَّلٌ يُزيح الموعدَ بقدره', () {
      final waited = const Duration(hours: 20).inMilliseconds;
      final now = opened.add(const Duration(hours: 24));
      expect(SlaEngine.resolve(t(), p, now).outcome, SlaOutcome.breached,
          reason: 'بلا انتظارٍ مسجَّلٍ يكون متجاوزاً — وهذا هو الضابط');
      expect(SlaEngine.resolve(t(waitingMs: waited), p, now).outcome, SlaOutcome.onTrack,
          reason: 'وبعشرين ساعةَ انتظارٍ لم تنقضِ مهلتُه بعد');
    });

    test('والانتظارُ الجاري يُحسب كما يُحسب المسجَّل', () {
      final now = opened.add(const Duration(hours: 24));
      final c = SlaEngine.resolve(t(waitingSince: opened.add(const Duration(hours: 4))), p, now);
      expect(c.outcome, SlaOutcome.onTrack);
    });

    // ــ وساعةُ جهازٍ متأخّرةٌ لا تتّهم أحداً ــ
    test('وبدءُ انتظارٍ في المستقبل لا يُقصّر المهلة', () {
      final now = opened.add(const Duration(hours: 2));
      final c = SlaEngine.resolve(t(waitingSince: opened.add(const Duration(hours: 5))), p, now);
      expect(c.dueAt, opened.add(const Duration(hours: 8)),
          reason: 'فرقٌ سالبٌ يُهمَل ولا يُطرح من المهلة');
    });

    test('وانتظارٌ وقع بعد الحلّ لا يُزيح موعداً انقضى أمرُه', () {
      final resolved = opened.add(const Duration(hours: 9));
      final c = SlaEngine.resolve(
          t(resolvedAt: resolved, waitingSince: opened.add(const Duration(hours: 20))), p,
          opened.add(const Duration(hours: 30)));
      expect(c.outcome, SlaOutcome.missed,
          reason: 'حُلَّ بعد تسعِ ساعاتٍ ومهلتُه ثمانٍ — وانتظارٌ بعده لا يغيّر ذلك');
    });
  });

  group('السياسةُ تُقرأ ولا تنهار', () {
    test('خريطةٌ فارغة تُقرأ المبدئيّة', () {
      final policy = SlaPolicy.fromMap(const {});
      expect(policy.targetFor(PriorityLevel.critical).respondMinutes, 15);
    });

    test('ونصٌّ مكان الخريطة لا يُسقط شيئاً', () {
      expect(SlaPolicy.fromMap('خطأ').targetFor(PriorityLevel.low).resolveMinutes, 72 * 60);
    });

    // ــ ولماذا تُردّ المهلةُ الصفر ــ
    //
    // مهلةٌ صفرٌ تجعل كلَّ بلاغٍ متجاوزاً لحظةَ فتحه. فتمتلئ الشاشةُ حمرةً،
    // فيُهمَل اللونُ — ويضيع معه البلاغُ المتجاوزُ حقّاً.
    test('ومهلةٌ صفرٌ أو سالبةٌ تُردّ إلى المبدئيّ', () {
      final policy = SlaPolicy.fromMap({
        'byPriority': {
          'high': {'respondMinutes': 0, 'resolveMinutes': -5},
        },
      });
      expect(policy.targetFor(PriorityLevel.high).respondMinutes, 60);
      expect(policy.targetFor(PriorityLevel.high).resolveMinutes, 8 * 60);
    });

    test('وكسرُ «يوشك» خارج المدى يُردّ', () {
      expect(SlaPolicy.fromMap({'atRiskFraction': 5}).atRiskFraction, 0.25);
      expect(SlaPolicy.fromMap({'atRiskFraction': -1}).atRiskFraction, 0.25);
      expect(SlaPolicy.fromMap({'atRiskFraction': 0.5}).atRiskFraction, 0.5);
    });

    test('ومهلةٌ صحيحةٌ تُقرأ كما كُتبت', () {
      final policy = SlaPolicy.fromMap({
        'byPriority': {
          'critical': {'respondMinutes': 5, 'resolveMinutes': 60},
        },
      });
      expect(policy.targetFor(PriorityLevel.critical).respondMinutes, 5);
      expect(policy.targetFor(PriorityLevel.critical).resolveMinutes, 60);
    });
  });

  // ــ وحقلٌ جديدٌ لا يُنسى في copyWith ــ
  //
  // `toMap` تكتب المستندَ كاملاً، فحقلٌ غائبٌ عن `copyWith` **يُمحى** في
  // أوّل تعديل. وقد وقع ذلك ثلاث مرّاتٍ في `project.dart`.
  test('copyWith تحمل كلَّ حقلٍ في toMap', () {
    final before = t(waitingMs: 900, waitingSince: opened, firstResponseAt: opened);
    final after = before.copyWith(title: 'عنوانٌ آخر');
    final a = before.toMap()..remove('title');
    final b = after.toMap()..remove('title');
    expect(b, a, reason: 'تعديلُ حقلٍ واحدٍ لا يمحو البقيّة');
  });

  // ــــ والطرفان يقرآن الجدولَ نفسَه ــــ
  //
  // `lib/itsm/sla.dart` يُحسب في المتصفّح، و`functions/src/sla.ts` يُحسب
  // في التقرير اليوميّ على الخادم. فلو افترقا لَعرضت الشاشةُ رقماً وعدَّ
  // التقريرُ غيرَه لشيءٍ واحد — ولا يعرف المسؤولُ أيُّهما الصحيح، وهو أسوأ
  // من ألّا يُعرض الرقمُ أصلاً.
  //
  // ولا يُكتب لكلٍّ جدولُه: عندها يتّفق كلٌّ مع نفسه ويفترقان عن بعضهما،
  // وهو بالضبط ما لا يُمسَك. فالجدولُ واحدٌ خارجَ الاثنين، واتّفاقُهما عليه
  // اتّفاقٌ بينهما.
  group('الجدولُ المشترك مع الخادم', () {
    final raw = File('test_fixtures/sla_cases.json').readAsStringSync();
    final fixture = jsonDecode(raw) as Map<String, dynamic>;
    final opened = DateTime.fromMillisecondsSinceEpoch(fixture['openedMs'] as int, isUtc: true);
    final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

    DateTime? at(Object? minutes) => minutes == null
        ? null
        : opened.add(Duration(minutes: (minutes as num).toInt()));

    test('وكلُّ حالةٍ فيه تُعطي ما يُعطيه', () {
      for (final c in cases) {
        final t = Ticket(
          id: 'x',
          kind: TicketKind.incident,
          title: c['name'] as String,
          description: '',
          priority: PriorityLevel.fromName(c['priority'] as String),
          status: TicketStatus.open,
          reporterUid: 'r',
          reporterName: 'r',
          createdAt: opened,
          firstResponseAt: at(c['firstResponseOffsetMin']),
          resolvedAt: at(c['resolvedOffsetMin']),
          waitingMs: (c['waitingMs'] as num).toInt(),
          waitingSince: at(c['waitingSinceOffsetMin']),
        );
        final now = opened.add(Duration(minutes: (c['nowOffsetMin'] as num).toInt()));
        expect(SlaEngine.respond(t, p, now).outcome.name, c['respond'],
            reason: '${c['name']} — أوّلُ ردّ');
        expect(SlaEngine.resolve(t, p, now).outcome.name, c['resolve'],
            reason: '${c['name']} — الحلّ');
      }
    });

    // ــ وحارسٌ لا يقرأ شيئاً يمرّ صامتاً ــ
    test('والجدولُ ليس فارغاً', () {
      expect(cases.length, greaterThanOrEqualTo(8));
    });
  });
}
