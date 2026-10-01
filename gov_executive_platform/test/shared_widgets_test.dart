// ودجاتُ النظام: ما تعرضه، وما لا تعرضه.
//
// ــــ ما تبتلعه ــــ
//
// كانت في المنصة **أربعُ حالاتِ فراغ** بثلاث صياغات، و**ثلاثةُ عناوينِ
// أقسام** إحداها شيءٌ آخر، و**بطاقتا رسمٍ منحرفتان** في حجم العنوان،
// و**نسختان متطابقتان** من معلومةٍ صغيرة. فثلاثُ شاشاتٍ تقول «لا بيانات»
// بثلاثة أشكال — وهو ما يجعل المنصةَ تبدو صفحاتٍ صُمّمت في أوقاتٍ مختلفة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/theme/status_palette.dart';
import 'package:gov_exec_platform/widgets/app_card.dart';
import 'package:gov_exec_platform/widgets/app_empty_state.dart';
import 'package:gov_exec_platform/widgets/stat_card.dart';
import 'package:gov_exec_platform/widgets/status_chip.dart';
import 'package:gov_exec_platform/widgets/status_pill.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pump();
}

void main() {
  group('بطاقةُ النظام', () {
    testWidgets('تعرض عنوانَها ووصفَها ومحتواها', (tester) async {
      await _pump(tester, const AppCard(
        title: 'أداءُ الإدارات',
        subtitle: 'آخرُ ثلاثين يوماً',
        height: 200,
        child: Text('المحتوى'),
      ));
      expect(find.text('أداءُ الإدارات'), findsOneWidget);
      expect(find.text('آخرُ ثلاثين يوماً'), findsOneWidget);
      expect(find.text('المحتوى'), findsOneWidget);
    });

    // بطاقةٌ بلا عنوانٍ لا تترك فراغَ رأسٍ فارغاً.
    testWidgets('وبلا عنوانٍ لا رأسَ لها', (tester) async {
      await _pump(tester, const AppCard(child: Text('وحدَه')));
      expect(find.byType(AppCardHeader), findsNothing);
      expect(find.text('وحدَه'), findsOneWidget);
    });

    testWidgets('وما في يمين الرأس يظهر', (tester) async {
      await _pump(tester, const AppCard(
        title: 'عنوان',
        trailing: Icon(Icons.more_horiz_rounded),
        child: Text('م'),
      ));
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });
  });

  group('وعنوانُ القسم', () {
    testWidgets('يعرض نصَّه وعددَه', (tester) async {
      await _pump(tester, const SectionTitle('المشاريعُ المتأخرة', count: '١٢'));
      expect(find.text('المشاريعُ المتأخرة'), findsOneWidget);
      expect(find.text('١٢'), findsOneWidget);
    });

    testWidgets('وبلا عددٍ لا يُعرض شيءٌ زائد', (tester) async {
      await _pump(tester, const SectionTitle('قسم'));
      expect(find.text('قسم'), findsOneWidget);
    });
  });

  group('وحالةُ الفراغ', () {
    // ــ ولا تُقال «لا بيانات» وحدَها ــ
    //
    // فالقارئُ لا يعلم: أهي فارغةٌ لأنّه لا يملك رؤيتها، أم لأنّ مرشِّحاً
    // ضيّقاً، أم لأنّ العملَ لم يبدأ؟
    testWidgets('تقول ما ينقص وسببَه', (tester) async {
      await _pump(tester, const AppEmptyState(
        title: 'لا مشاريعَ في نطاقك',
        message: 'جرّب توسيعَ التصفية، أو اطلب من مسؤول النظام إضافتَك لإدارة.',
      ));
      expect(find.text('لا مشاريعَ في نطاقك'), findsOneWidget);
      expect(find.textContaining('توسيعَ التصفية'), findsOneWidget);
    });

    testWidgets('وتكتفي بالعنوان حين يكفي', (tester) async {
      await _pump(tester, const AppEmptyState(title: 'لا شيء'));
      expect(find.text('لا شيء'), findsOneWidget);
    });
  });

  group('وشارةُ الحالة', () {
    testWidgets('تأخذ سطحَها ونصَّها من نغمة المعنى', (tester) async {
      await _pump(tester, StatusPill(label: 'متأخر', tone: StatusPalette.danger));
      expect(find.text('متأخر'), findsOneWidget);
      final box = tester.widget<Container>(find.ancestor(
        of: find.text('متأخر'),
        matching: find.byType(Container),
      ).first);
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, StatusPalette.danger.soft,
          reason: 'السطحُ درجةٌ مختارةٌ لا شفافيةٌ محسوبة');
    });

    testWidgets('ونصُّها يُقرأ على سطحها', (tester) async {
      await _pump(tester, StatusPill(label: 'تحذير', tone: StatusPalette.warning));
      final text = tester.widget<Text>(find.text('تحذير'));
      expect(text.style?.color, StatusPalette.warning.text);
    });
  });

  group('وبطاقةُ المؤشّر', () {
    testWidgets('تعرض رقمَها وعنوانَها', (tester) async {
      await _pump(tester, StatCard(
        title: 'المشاريعُ المتأخرة',
        value: '١٢',
        icon: Icons.warning_amber_rounded,
        tone: StatusPalette.danger,
        subtitle: 'زيادةُ ٣ عن الأسبوع الماضي',
      ));
      expect(find.text('١٢'), findsOneWidget);
      expect(find.text('المشاريعُ المتأخرة'), findsOneWidget);
      expect(find.text('زيادةُ ٣ عن الأسبوع الماضي'), findsOneWidget);
    });

    // ــ وهذا ما لم يكن يقع: الرقمُ يُضغط فيُفتح أصحابُه ــ
    //
    // و`KpiCard.onTap` كانت موجودةً ولم تُمرَّر قيمةً قطّ في عشرين موضعاً.
    testWidgets('وتُضغط فتفتح تفاصيلَها', (tester) async {
      var taps = 0;
      await _pump(tester, StatCard(
        title: 'المتأخرة',
        value: '٣',
        icon: Icons.warning_amber_rounded,
        tone: StatusPalette.danger,
        onTap: () => taps++,
      ));
      await tester.tap(find.byType(StatCard));
      await tester.pump();
      expect(taps, 1);
    });

    // وبطاقةٌ تبدو قابلةً للضغط ولا تستجيب عطلٌ في عين مستعملها.
    testWidgets('وبلا فعلٍ لا تستجيب ولا تدّعي', (tester) async {
      await _pump(tester, StatCard(
        title: 'عدد',
        value: '٥',
        icon: Icons.numbers_rounded,
        tone: StatusPalette.info,
      ));
      final inkwell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkwell.onTap, isNull);
    });

    testWidgets('والمُبرَزةُ تحمل نصَّها على لون المعنى', (tester) async {
      await _pump(tester, StatCard(
        title: 'حرِج',
        value: '٢',
        icon: Icons.error_outline_rounded,
        tone: StatusPalette.danger,
        emphasize: true,
      ));
      final text = tester.widget<Text>(find.text('٢'));
      expect(text.style?.color, StatusPalette.danger.onFill);
    });
  });

  // ــ وهذه المجموعةُ كُتبت لأنّ طفرةً نجت ــ
  //
  // جُعلت كلُّ حالات المشروع في `StatusChip` محايدةً — «في المسار»
  // و«متعثّر» و«مكتمل» بلونٍ رماديٍّ واحد — **ومرّت المنصةُ كلُّها**. وهي
  // تُقرأ في تسع شاشات، وكانت أطولَ ما في المنصة بلا اختبارٍ يمسّه.
  group('وشارةُ الحالة تترجم الحالةَ إلى نغمتها', () {
    testWidgets('لكلِّ حالةِ مشروعٍ نغمتُها هي', (tester) async {
      for (final status in ProjectStatus.values) {
        await _pump(tester, StatusChip(status: status));
        final pill = tester.widget<StatusPill>(find.byType(StatusPill));
        expect(pill.tone, StatusPalette.projectTone(status.name),
            reason: 'حالةُ «${status.label}» لا تحمل نغمتَها');
        expect(pill.label, status.label);
      }
    });

    // ولا يمرّ ما سبق لأنّ كلَّ الحالات بنغمةٍ واحدة أصلاً.
    testWidgets('ولا تتشارك حالتان نغمةً واحدة', (tester) async {
      final tones = {
        for (final s in ProjectStatus.values) StatusPalette.projectTone(s.name),
      };
      expect(tones.length, ProjectStatus.values.length,
          reason: 'حالتان بلونٍ واحد تُبطلان فائدةَ الشارة كلَّها');
    });

    testWidgets('وشارةُ الأولوية كذلك، وبلا نقطة', (tester) async {
      // بلا نقطة: تقع إلى جانب شارة الحالة في صفٍّ واحد، ونقطتان
      // متجاورتان تُقرآن زينةً لا معنى.
      for (final p in PriorityLevel.values) {
        await _pump(tester, PriorityChip(priority: p));
        final pill = tester.widget<StatusPill>(find.byType(StatusPill));
        expect(pill.tone, StatusPalette.priorityTone(p.name));
        expect(pill.dot, isFalse);
      }
    });
  });
}
