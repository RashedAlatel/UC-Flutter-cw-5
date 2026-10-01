// البحث عن الأشخاص، وتقويم التحديث اليومي.
//
// ثلاثة أشياء لا تكشفها القراءة:
//
// ١) **الهمزة**. «أحمد» و«احمد» اسمٌ واحد بكتابتين، والمطابقة الحرفية تجعل
//    من يكتب إحداهما لا يجد الأخرى. وفي وزارةٍ فيها مئتا موظف، من لا يجد
//    الاسم يكتبه يدوياً — فتتراكم أسماء حرّة لا ترتبط بحساب، وتنكسر بها كل
//    تقارير «من عليه أكثر المشاريع».
//
// ٢) **حدود التقويم**. تسجيلُ تحديثٍ ليومٍ لم يأتِ كذبٌ في السجل، وتسجيلُه
//    قبل بدء المشروع كذلك.
//
// ٣) **اليوم الحالي ليس «مضى بلا تحديث»**. نهاره لم ينتهِ بعد.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/widgets/month_calendar.dart';
import 'package:gov_exec_platform/widgets/person_picker.dart';

AppUser _user(String name, {String email = 'x@moj.gov.kw'}) => AppUser(
      id: name,
      name: name,
      email: email,
      phone: '',
      role: UserRole.employee,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('توحيد النص العربي قبل البحث', () {
    test('صور الألف تُوحَّد', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آلاء'), normalizeArabic('الاء'));
    });

    test('والياء المقصورة والتاء المربوطة', () {
      expect(normalizeArabic('مصطفى'), normalizeArabic('مصطفي'));
      expect(normalizeArabic('فاطمة'), normalizeArabic('فاطمه'));
    });

    test('والتشكيل والتطويل يسقطان', () {
      expect(normalizeArabic('مُحَمَّد'), normalizeArabic('محمد'));
      expect(normalizeArabic('محـــمد'), normalizeArabic('محمد'));
    });
  });

  group('مطابقة الشخص', () {
    test('البحث بجزء من الاسم بلا همزة يجد صاحب الهمزة', () {
      expect(personMatches(_user('أحمد المليجي'), 'احمد'), isTrue);
    });

    test('والبحث بالبريد', () {
      expect(personMatches(_user('هاجر', email: 'hajar@moj.gov.kw'), 'hajar'), isTrue);
    });

    test('والبحث باسم الإدارة', () {
      expect(
        personMatches(_user('طارق'), 'تقنية', departmentName: 'الإدارة العامة لتقنية المعلومات'),
        isTrue,
      );
    });

    test('ونصٌّ لا يطابق شيئاً يُقصي', () {
      expect(personMatches(_user('أحمد المليجي'), 'خالد'), isFalse);
    });

    test('والبحث الفارغ يُبقي الجميع — لا يُفرغ القائمة', () {
      expect(personMatches(_user('أحمد'), '   '), isTrue);
    });
  });

  group('منتقي الأشخاص', () {
    Future<void> pump(WidgetTester tester, Set<String> selected, List<AppUser> people) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PersonPicker(
              label: 'مديرو المشروع',
              hint: 'من يقود المشروع',
              candidates: people,
              departmentNameOf: (_) => 'إدارة تقنية المعلومات',
              selected: selected,
              onChanged: () {},
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('الكتابة تُضيّق النتائج أثناءها', (tester) async {
      await pump(tester, <String>{}, [_user('أحمد المليجي'), _user('خالد العنزي')]);
      expect(find.text('أحمد المليجي'), findsOneWidget);
      expect(find.text('خالد العنزي'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'احمد');
      await tester.pump();

      expect(find.text('أحمد المليجي'), findsOneWidget, reason: 'يُوجد رغم اختلاف الهمزة');
      expect(find.text('خالد العنزي'), findsNothing);
    });

    testWidgets('والمختار يبقى ظاهراً ولو لم يطابق البحث', (tester) async {
      // من اختار زميلاً ثم بحث عن آخر يجب أن يرى اختياره باقياً، وإلا ظنّ
      // أن البحث ألغاه فأعاد الاختيار مرتين.
      await pump(tester, {'خالد العنزي'}, [_user('أحمد المليجي'), _user('خالد العنزي')]);
      await tester.enterText(find.byType(TextField), 'احمد');
      await tester.pump();
      expect(find.widgetWithText(InputChip, 'خالد العنزي'), findsOneWidget);
    });

    testWidgets('ولا نتيجة يقول ذلك بدل صندوق فارغ', (tester) async {
      await pump(tester, <String>{}, [_user('أحمد المليجي')]);
      await tester.enterText(find.byType(TextField), 'زياد');
      await tester.pump();
      expect(find.textContaining('لا أحد يطابق'), findsOneWidget);
    });
  });

  group('تقويم التحديث اليومي', () {
    final today = dayOnly(DateTime.now());

    Future<void> pumpCalendar(WidgetTester tester, {required void Function(DateTime) onSelected}) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MonthCalendar(
              selected: today,
              onSelected: onSelected,
              daysWithUpdates: {today.subtract(const Duration(days: 2))},
              firstDay: DateTime(today.year, today.month, 1),
              lastDay: today,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('اليوم الحالي هو المختار عند الفتح', (tester) async {
      await pumpCalendar(tester, onSelected: (_) {});
      expect(find.text('${today.day}'), findsWidgets);
    });

    testWidgets('يومٌ مضى يُختار ويُبلَّغ به', (tester) async {
      DateTime? picked;
      await pumpCalendar(tester, onSelected: (d) => picked = d);
      // يومٌ سابق داخل الشهر نفسه.
      final earlier = today.day > 3 ? today.day - 3 : 1;
      await tester.tap(find.text('$earlier').first);
      await tester.pump();
      expect(picked, isNotNull);
      expect(picked!.day, earlier);
    });

    testWidgets('ويومٌ لم يأتِ لا يُختار', (tester) async {
      // لا يُسجَّل تحديثٌ لغدٍ: ذلك كذبٌ في السجل.
      DateTime? picked;
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final anchor = DateTime(2026, 8, 10);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MonthCalendar(
              selected: anchor,
              onSelected: (d) => picked = d,
              daysWithUpdates: const {},
              firstDay: DateTime(2026, 8, 1),
              lastDay: anchor,
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('20').first);
      await tester.pump();
      expect(picked, isNull, reason: '٢٠ أغسطس بعد آخر يوم مسموح (١٠ أغسطس)');
    });
  });
}
