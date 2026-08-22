// الفراغ **داخل** بطاقات الشبكات.
//
// شكوى متكرّرة: «فراغ أسفل البطاقات». وسببها في كل مرة واحد: `GridView.count`
// يُعطى `childAspectRatio` رقماً ثابتاً مكتوباً باليد (١٫٣٥، ١٫٥، ١٫٦)، فيصير
// ارتفاع البطاقة = عرضها ÷ ذلك الرقم. والعرض يتبدّل بعرض الشاشة، فالارتفاع
// يتبدّل معه بلا أي علاقة بما في البطاقة — وعلى الجوال، حيث عمود واحد بعرض
// الشاشة كلها، يصير الارتفاع هائلاً والمحتوى في وسطه.
//
// والقياس هنا هندسي: ارتفاع البطاقة ناقص ما رُسم فيها فعلاً، من أعلى ومن
// أسفل معاً — لأن `KpiCard` يُوسّط محتواه، فيتوزّع الفراغ على الطرفين ولا
// يظهر ذيلاً وحده.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/report.dart';
import 'package:gov_exec_platform/screens/department_detail_screen.dart';
import 'package:gov_exec_platform/screens/departments_list_screen.dart';
import 'package:gov_exec_platform/screens/reports_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

const _dept = 'd-tech';

AppUser _admin() => AppUser(
      id: 'admin',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '',
      role: UserRole.systemAdmin,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store() => AppStore()
  ..currentUser = _admin()
  ..users = [_admin()]
  ..departments = [
    // اسمٌ باسم الوزارة الحقيقي: يلتفّ سطرين، وهو أطول ما تحمله البطاقة.
    Department(
      id: _dept,
      name: 'الإدارة العامة لتقنية المعلومات والتحول الرقمي',
      headName: 'عبدالرحمن بن عبدالعزيز المطيري',
      colorValue: 0xFF1B5E4A,
      iconKey: 'settings',
    ),
    Department(id: 'd2', name: 'إدارة التفتيش', headName: 'رئيس', colorValue: 0xFF8A6D1F, iconKey: 'gavel'),
  ]
  ..reports = [
    ReportSnapshot(
      id: 'r1',
      period: ReportPeriod.weekly,
      generatedDate: DateTime(2026, 8, 1),
      executiveSummary: 'ملخّص تنفيذي للأسبوع.',
      avgProgress: 62,
      avgDelayDays: 3.4,
      totalRisks: 2,
      totalBlockers: 1,
      pendingDecisions: 4,
      departmentRanking: [const MapEntry('الإدارة العامة لتقنية المعلومات والتحول الرقمي', 62)],
    ),
  ]
  ..projects = [
    for (var i = 0; i < 4; i++)
      Project(
        id: 'p$i',
        departmentId: _dept,
        name: 'مشروع رقم $i',
        description: 'وصف',
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2099, 1, 1),
        status: ProjectStatus.onTrack,
        priority: PriorityLevel.high,
        progressPercent: (40 + i).toDouble(),
        managerUids: const ['admin'],
      ),
  ];

bool _paints(Widget w) {
  if (w is Text) return (w.data ?? '').trim().isNotEmpty;
  if (w is Icon) return true;
  return false;
}

/// أكبر فراغ (أعلى + أسفل) داخل بطاقة من بطاقات الشبكة، بعد خصم الحشو.
///
/// [padding] حشو البطاقة المقصود — ما زاد عليه فراغٌ فرضته النسبة الثابتة.
({double gap, int cards}) _worstGap(WidgetTester tester, {required double padding}) {
  var worst = 0.0;
  var counted = 0;
  // الحاوية `GridView` أو `Wrap`: صفحة الإدارات تركت الشبكة إلى `Wrap`
  // لتأخذ كل بطاقة ارتفاعها، ولو بقي البحث على `GridView` وحدها لصار
  // الحارس ينظر إلى لا شيء بعد الإصلاح ويمرّ صامتاً.
  final container = find.byWidgetPredicate((w) => w is GridView || w is Wrap);
  final cards = find.descendant(of: container, matching: find.byType(Card));
  for (final cardElement in cards.evaluate()) {
    final card = cardElement.renderObject;
    if (card is! RenderBox || !card.hasSize || !card.attached) continue;
    final cardTop = card.localToGlobal(Offset.zero).dy;
    final cardBottom = card.localToGlobal(Offset(0, card.size.height)).dy;

    var first = cardBottom;
    var last = cardTop;
    var found = false;
    void visit(Element e) {
      final object = e.renderObject;
      if (object is RenderBox && object.hasSize && object.attached && _paints(e.widget)) {
        final t = object.localToGlobal(Offset.zero).dy;
        final b = object.localToGlobal(Offset(0, object.size.height)).dy;
        if (t < first) first = t;
        if (b > last) last = b;
        found = true;
      }
      e.visitChildren(visit);
    }

    cardElement.visitChildren(visit);
    if (!found) continue;
    counted++;

    final gap = (first - cardTop) + (cardBottom - last) - 2 * padding;
    if (gap > worst) worst = gap;
  }
  return (gap: worst, cards: counted);
}

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: _store(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: screen),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

/// المقاسات التي تُرى فيها المنصة فعلاً — والجوال أهمّها: عمودٌ واحد بعرض
/// الشاشة كلها، فأيّ نسبة ثابتة تُضخّم الارتفاع هناك أكثر ما تُضخّمه.
const _sizes = <String, Size>{
  'جوال': Size(390, 1600),
  'لوحي': Size(820, 1600),
  'مكتبي': Size(1400, 1600),
};

void main() {
  final screens = <String, ({Widget widget, double padding})>{
    'الإدارات': (widget: const DepartmentsListScreen(), padding: 18),
    'التقارير': (widget: const ReportsScreen(), padding: 14),
    'صفحة الإدارة': (widget: const DepartmentDetailScreen(departmentId: _dept), padding: 14),
  };

  screens.forEach((name, screen) {
    _sizes.forEach((sizeName, size) {
      testWidgets('$name — بطاقات الشبكة بلا فراغ مفروض ($sizeName)', (tester) async {
        await _pump(tester, screen.widget, size);
        final measured = _worstGap(tester, padding: screen.padding);
        // ignore: avoid_print
        print('DIAG $name/$sizeName :: ${measured.cards} بطاقة · أسوأ فراغ ${measured.gap.toStringAsFixed(1)}');
        // بلا هذا يمرّ الحارس على شاشة لم تُرسم فيها بطاقة أصلاً — وهو أسوأ
        // من ألّا يوجد: يطمئن ولا يقيس.
        expect(measured.cards, greaterThan(0),
            reason: 'لم تُرسم بطاقة في شبكة «$name» — الحارس ينظر إلى لا شيء');
        expect(measured.gap, lessThan(40),
            reason: 'في «$name» على «$sizeName» فراغٌ مفروض قدره '
                '${measured.gap.toStringAsFixed(0)} بكسل داخل البطاقة');
      });
    });
  });
}
