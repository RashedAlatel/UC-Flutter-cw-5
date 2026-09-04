// خروج النص عن حدود البطاقة على شاشة الجوال.
//
// حارس عطلٍ ظهر في لقطة من هاتف مسؤول النظام: سطر المنفّذين يخرج من إطار
// البطاقة ويُقصّ من طرفيه. وسببه أن سطر المعلومات `Wrap`، و`Wrap` يعطي
// أبناءه **عرضاً غير محدود** — فلا يجد النص حدّاً يلتفّ عنده مهما طال.
//
// ولم تكشفه الاختبارات القائمة لأنها كلها تعمل بالمقاس الافتراضي
// (٨٠٠×٦٠٠) حيث يتّسع السطر. فهذه الاختبارات تُثبّت **مقاسات هواتف
// حقيقية**، وتشترط ألّا يسجّل Flutter استثناء تجاوزٍ للحدود.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/department_detail_screen.dart';
import 'package:gov_exec_platform/screens/projects_list_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/meta_row.dart';

const _dept = 'd-systems';

/// أسماء المنفّذين كما وردت في اللقطة فعلاً — بأدوارهم بين قوسين.
const _longExecutors = [
  'إسحاق الخباز (تحليل ودراسة)',
  'أحمد المليجي',
  'هاجر حامد (برمجة واختبار النظام)',
];

Project _project({List<String> executors = _longExecutors}) => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'نظام الاستشارات الأسرية',
      description: 'نظام تمت من خلاله أتمتة إجراءات إدارة الاستشارات الأسرية وتبليغ الأطراف المعنية.',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 80,
      executorNames: executors,
    );

AppStore _store({
  List<String> executors = _longExecutors,
  String deptName = 'قسم صيانة النظم',
}) =>
    AppStore()
  ..currentUser = AppUser(
    id: 'u1',
    name: 'عبدالله',
    email: 'a@moj.gov.kw',
    phone: '',
    role: UserRole.systemAdmin,
    departmentId: _dept,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  )
  ..departments = [
    Department(
      id: _dept,
      name: deptName,
      headName: 'رئيس القسم',
      colorValue: 0xFF1B5E4A,
      iconKey: 'settings',
    ),
  ]
  ..projects = [_project(executors: executors)];

/// يتحقّق أن **كل نصّ مرسوم** يقع داخل عرض الشاشة.
///
/// وهذا هو الفحص الذي يمسك العطل فعلاً. `tester.takeException()` وحده لا
/// يكفي: `Wrap` لا يُبلّغ عن تجاوز أبنائه إطلاقاً، فالنص يخرج من البطاقة
/// **بصمت** بلا استثناء — وقد تحقّقنا من ذلك بطفرة متعمَّدة. أما القياس
/// الهندسي فيرى ما تراه العين.
void _expectAllTextInside(WidgetTester tester, Size size) {
  final offenders = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! Text) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize || !object.attached) continue;
    // الزاويتان تُحوَّلان كلتاهما، لا العرض يُضاف إلى الزاوية اليسرى.
    //
    // عناوين حقول الإدخال تُصغَّر بتحويل مقياس حين تطفو فوق الحقل، فقياس
    // `size.width` وحده يبالغ في عرضها ويُبلّغ عن خروجٍ لا يقع فعلاً. وقد
    // أبلغ عن ذلك بالفعل قبل هذا التصحيح — إنذارٌ كاذب يُفقد الثقة بالحارس.
    final a = object.localToGlobal(Offset.zero).dx;
    final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
    final left = a < b ? a : b;
    final right = a < b ? b : a;
    // هامش نصف بكسل لفروق التقريب في التصيير.
    if (left < -0.5 || right > size.width + 0.5) {
      offenders.add('«${widget.data}» يمتد من ${left.toStringAsFixed(0)} '
          'إلى ${right.toStringAsFixed(0)} وعرض الشاشة ${size.width.toStringAsFixed(0)}');
    }
  }
  expect(offenders, isEmpty, reason: 'نصوص خرجت عن حدود الشاشة:\n${offenders.join('\n')}');
}

Future<void> _pump(WidgetTester tester, Size size, Widget screen, AppStore store) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: screen),
      ),
    ),
  ));
  await tester.pump();
}

/// مقاسات هواتف حقيقية: آيفون ١٦ برو، وآيفون SE (أضيق ما يُستعمل عملياً).
const _phones = {
  'iPhone 16 Pro': Size(402, 874),
  'iPhone SE': Size(375, 667),
};

void main() {
  for (final entry in _phones.entries) {
    group('بمقاس ${entry.key}', () {
      testWidgets('بطاقة المشروع في صفحة المشاريع لا يخرج نصها', (tester) async {
        await _pump(tester, entry.value, const ProjectsListScreen(), _store());
        expect(tester.takeException(), isNull);
        _expectAllTextInside(tester, entry.value);
      });

      testWidgets('وبطاقة المشروع في صفحة الإدارة كذلك', (tester) async {
        await _pump(
          tester,
          entry.value,
          const DepartmentDetailScreen(departmentId: _dept),
          _store(),
        );
        expect(tester.takeException(), isNull);
        _expectAllTextInside(tester, entry.value);
      });

      // اسم واحد طويل جداً بلا فواصل: لا يمكن كسره على مسافة، فهو أقسى ما
      // يواجه التخطيط — ولو نجا منه نجا مما دونه.
      testWidgets('واسم واحد طويل بلا فواصل لا يكسر البطاقة', (tester) async {
        await _pump(
          tester,
          entry.value,
          const ProjectsListScreen(),
          _store(executors: const ['مديريةتقنيةالمعلوماتوالتحولالرقميبوزارةالعدلدولةالكويت']),
        );
        expect(tester.takeException(), isNull);
        _expectAllTextInside(tester, entry.value);
      });
    });
  }

  // شارة الإدارة داخل بطاقة المشروع: تُحشر في عمود ضيّق جداً بين العنوان
  // والشارة وأزرار الإجراءات، فاسم إدارة طويل يخرج منها. وهذه الحالة هي ما
  // يُثبت أن التقييد في `MetaRow` يعمل فعلاً لا أنه سطرٌ بلا أثر.
  testWidgets('اسم إدارة طويل داخل بطاقة ضيّقة يُقتطع ولا يخرج', (tester) async {
    await _pump(
      tester,
      const Size(375, 667),
      const ProjectsListScreen(),
      _store(deptName: 'الإدارة العامة لتقنية المعلومات والتحول الرقمي بوزارة العدل'),
    );
    expect(tester.takeException(), isNull);
    _expectAllTextInside(tester, const Size(375, 667));
  });

  // عقد `MetaRow` نفسه، لا عبر شاشة.
  //
  // `Wrap` يعطي أبناءه عرضاً غير محدود، فبندٌ طويل بداخله يُرسم بطوله كاملاً
  // ويتجاوز الإطار. و`MetaRow` تفرض على كل بند عرض السطر حدّاً أقصى. وبلا
  // هذا الاختبار يبقى ذلك القيد سطراً لا يُعرف أيعمل أم لا — فاليوم كل
  // البنود قصيرة، وأول بند طويل يضيفه أحدٌ لاحقاً هو من يكتشف الأمر.
  testWidgets('MetaRow تُلزم بندها الطويل بعرض السطر', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetaRow(
                  children: [
                    MetaChip(icon: Icons.event_outlined, text: 'الاستحقاق: 2026/12/31'),
                    MetaChip(
                      icon: Icons.badge_outlined,
                      text: 'المنفذ: إسحاق الخباز (تحليل ودراسة)، أحمد المليجي، '
                          'هاجر حامد (برمجة واختبار النظام)، فاطمة العنزي (ضمان الجودة)',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectAllTextInside(tester, const Size(375, 667));
  });

  testWidgets('ولا يخرج شيء على الشاشة العريضة أيضاً', (tester) async {
    await _pump(tester, const Size(1280, 900), const ProjectsListScreen(), _store());
    expect(tester.takeException(), isNull);
    _expectAllTextInside(tester, const Size(1280, 900));
  });
}
