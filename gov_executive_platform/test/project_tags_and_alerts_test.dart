// وسوم المشاريع، وتجميعها، وبناء تنبيه المتأخرات.
//
// ثلاثة أشياء لا يكشفها النظر إلى الشاشة مرةً واحدة:
//
// ١) **الوسوم متعددة**، والمشروع الذي يحمل وسمين يجب أن يظهر تحت كليهما.
//    ولو صار التجميع فرزاً عادياً لظهر تحت واحد فقط واختفى من الآخر بصمت —
//    أي أن التصفية بالوسم الثاني تُنقص مشاريع صحيحة ولا يشتكي أحد.
//
// ٢) **تنبيه المتأخرات رسالة لكل شخص لا لكل مشروع.** ومن يقود خمسة مشاريع
//    متأخرة كان سيتلقّى خمس رسائل متطابقة في دقيقة — فيتدرّب على تجاهل بريد
//    المنصة، وينتهي التنبيه إلى عكس غرضه.
//
// ٣) **من لا بريد له يسقط من المستلمين.** لأن `deliverMessages` على الخادم
//    ترمي عند أول إخفاق، فمستلم واحد بلا بريد يُفشل الدفعة كلها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/screens/projects_list_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';

import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/late_alert.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_category.dart';
import 'package:gov_exec_platform/models/project_sort.dart';

const _dept = 'd1';

AppUser _user(String id, String name, {String email = ''}) => AppUser(
      id: id,
      name: name,
      email: email.isEmpty ? '$id@moj.gov.kw' : email,
      phone: '',
      role: UserRole.employee,
      departmentId: _dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(
  String id, {
  List<String> categoryIds = const [],
  List<String> managerUids = const [],
  List<String> executorUids = const [],
  DateTime? dueDate,
  double progress = 40,
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: dueDate ?? DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.high,
      progressPercent: progress,
      managerUids: managerUids,
      executorUids: executorUids,
      categoryIds: categoryIds,
    );

const _digital = ProjectCategory(id: 'c1', name: 'رقمنة', colorValue: 0xFF1B5E4A);
const _priority = ProjectCategory(id: 'c2', name: 'أولوية وزارية', colorValue: 0xFFB58B2C);

/// تصنيف بطول ما تكتبه الوزارة فعلاً.
///
/// وسمان قصيران يتّسعان في صفٍّ واحد على آيفون SE، فاختبارٌ بهما وحدهما
/// يمرّ ولو كانت الوسوم في `Row` بعرض غير محدود — أي حارسٌ لا يعضّ. وأسماء
/// التصنيفات الحقيقية جُمَلٌ لا كلمات.
const _longCategory = ProjectCategory(
  id: 'c3',
  name: 'مبادرات التحول الرقمي والخدمات الحكومية المشتركة',
  colorValue: 0xFF2E6F8E,
);

void main() {
  _phoneWidthGuards();

  group('قراءة الوسوم من المستند', () {
    test('مستند بلا حقل التصنيفات يُقرأ بقائمة فارغة', () {
      // كل مشاريع الوزارة المستوردة كُتبت قبل التصنيفات. ولو انهارت القراءة
      // أو أعادت null لسقطت الصفحة كلها على بيانات المستخدم الحقيقية.
      final p = Project.fromMapForTest('p1', {'name': 'مشروع قديم'});
      expect(p.categoryIds, isEmpty);
    });

    test('والحقل يُقرأ ويُكتب كما هو', () {
      final p = Project.fromMapForTest('p1', {
        'name': 'مشروع',
        'categoryIds': ['c1', 'c2'],
      });
      expect(p.categoryIds, ['c1', 'c2']);
      expect(p.toMap()['categoryIds'], ['c1', 'c2']);
    });
  });

  group('التجميع حسب التصنيف', () {
    test('مشروع بوسمين يظهر تحت العنوانين معاً', () {
      final both = _project('p1', categoryIds: ['c1', 'c2']);
      final groups = groupProjects(
        projects: [both],
        sort: ProjectSort.category,
        categories: const [_digital, _priority],
      );

      expect(groups.map((g) => g.label), ['رقمنة', 'أولوية وزارية']);
      for (final g in groups) {
        expect(g.projects.single.id, 'p1', reason: 'تحت ${g.label}');
      }
    });

    test('وبترتيبٍ آخر يظهر مرةً واحدة لا مرتين', () {
      // الازدواج مقصود في التجميع وحده. ولو تسرّب إلى القوائم المسطّحة
      // لعُدّ المشروع مرتين في كل ما يُبنى عليها.
      final groups = groupProjects(
        projects: [_project('p1', categoryIds: ['c1', 'c2'])],
        sort: ProjectSort.name,
        categories: const [_digital, _priority],
      );
      expect(groups.single.projects.length, 1);
      expect(groups.single.label, isEmpty, reason: 'قائمة مسطّحة بلا عنوان');
    });

    test('بلا وسم يقع تحت «بلا تصنيف» في الآخر', () {
      final groups = groupProjects(
        projects: [_project('p1', categoryIds: ['c1']), _project('p2')],
        sort: ProjectSort.category,
        categories: const [_digital, _priority],
      );
      expect(groups.map((g) => g.label), ['رقمنة', kUncategorizedLabel]);
      expect(groups.last.projects.single.id, 'p2');
    });

    test('ومشروعٌ وسمُه محذوف من الإعدادات يقع تحت «بلا تصنيف»', () {
      // التصنيف يُحذف من القائمة ويبقى معرّفه مكتوباً على المشاريع. ولو
      // عُومل كوسم صحيح لصنع مجموعةً بعنوان فارغ لا يعرف أحد ما هي.
      final groups = groupProjects(
        projects: [_project('p1', categoryIds: ['c-محذوف'])],
        sort: ProjectSort.category,
        categories: const [_digital],
      );
      expect(groups.single.label, kUncategorizedLabel);
    });

    test('ترتيب المجموعات ترتيبُ القائمة المعرَّفة لا ترتيب المشاريع', () {
      // المشروع يحمل c2 قبل c1، والمجموعات تبقى بترتيب الإعدادات — وإلا
      // تبدّل شكل الصفحة كلما عُدّل مشروع واحد.
      final groups = groupProjects(
        projects: [_project('p1', categoryIds: ['c2', 'c1'])],
        sort: ProjectSort.category,
        categories: const [_digital, _priority],
      );
      expect(groups.map((g) => g.label), ['رقمنة', 'أولوية وزارية']);
    });
  });

  group('الترتيب المسطّح', () {
    test('الأكثر تأخيراً أولاً', () {
      final old = _project('p1', dueDate: DateTime(2020, 1, 1));
      final recent = _project('p2', dueDate: DateTime(2025, 1, 1));
      final groups = groupProjects(
        projects: [recent, old],
        sort: ProjectSort.delay,
        categories: const [],
      );
      expect(groups.single.projects.map((p) => p.id), ['p1', 'p2']);
    });

    test('والأقل إنجازاً أولاً', () {
      final groups = groupProjects(
        projects: [_project('p1', progress: 80), _project('p2', progress: 10)],
        sort: ProjectSort.progress,
        categories: const [],
      );
      expect(groups.single.projects.map((p) => p.id), ['p2', 'p1']);
    });
  });

  group('تنبيه المشاريع المتأخرة', () {
    final late1 = _project('p1', dueDate: DateTime(2020, 1, 1), managerUids: ['u1']);
    final late2 = _project('p2', dueDate: DateTime(2021, 1, 1), managerUids: ['u1']);

    test('المسؤول عن مشروعين متأخرين يتلقّى رسالة واحدة تسردهما', () {
      final messages = buildLateAlerts(
        lateProjects: [late1, late2],
        users: [_user('u1', 'سعد المطيري')],
      );

      expect(messages.length, 1, reason: 'رسالة واحدة لا رسالة لكل مشروع');
      expect(messages.single.body, contains('مشروع p1'));
      expect(messages.single.body, contains('مشروع p2'));
    });

    test('ولمشروع واحد تُستعمل صياغة القالب القائمة نفسها', () {
      // لا صياغتان لتنبيه التأخير: الفردية من صفحة المشروع والجماعية من هنا
      // يجب أن تقولا الشيء نفسه.
      final messages = buildLateAlerts(
        lateProjects: [late1],
        users: [_user('u1', 'سعد المطيري')],
      );
      expect(messages.single.subject, contains('تنبيه تأخير'));
      expect(messages.single.body, contains('متأخر'));
    });

    test('المنفّذ المُسنَد يُنبَّه كما يُنبَّه المدير', () {
      final messages = buildLateAlerts(
        lateProjects: [_project('p3', dueDate: DateTime(2020, 1, 1), executorUids: ['u2'])],
        users: [_user('u2', 'نورة العجمي')],
      );
      expect(messages.single.user.id, 'u2');
    });

    test('ومن هو مدير ومنفّذ على المشروع نفسه لا يُحسب مرتين', () {
      final messages = buildLateAlerts(
        lateProjects: [
          _project('p4', dueDate: DateTime(2020, 1, 1), managerUids: ['u1'], executorUids: ['u1']),
        ],
        users: [_user('u1', 'سعد المطيري')],
      );
      expect(messages.length, 1);
      expect('مشروع p4'.allMatches(messages.single.body).length, 1);
    });

    test('من لا بريد له يسقط من المستلمين', () {
      // رسالةٌ إليه تفشل على الخادم فتُفشل الدفعة كلها.
      final noEmail = AppUser(
        id: 'u3',
        name: 'بلا بريد',
        email: '',
        phone: '',
        role: UserRole.employee,
        departmentId: _dept,
        status: UserStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );
      final messages = buildLateAlerts(
        lateProjects: [_project('p5', dueDate: DateTime(2020, 1, 1), managerUids: ['u3'])],
        users: [noEmail],
      );
      expect(messages, isEmpty);
    });

    test('والأسماء النصية المستوردة لا تُراسَل — لا حساب لها', () {
      final imported = Project(
        id: 'p6',
        departmentId: _dept,
        name: 'مشروع مستورد',
        description: '',
        startDate: DateTime(2020, 1, 1),
        dueDate: DateTime(2020, 6, 1),
        status: ProjectStatus.onTrack,
        priority: PriorityLevel.high,
        progressPercent: 20,
        executorNames: const ['إسحاق الخباز (تحليل ودراسة)'],
      );
      expect(buildLateAlerts(lateProjects: [imported], users: [_user('u1', 'سعد')]), isEmpty);
    });

    test('والحساب غير المعتمد لا يُنبَّه', () {
      final pending = AppUser(
        id: 'u4',
        name: 'قيد الاعتماد',
        email: 'u4@moj.gov.kw',
        phone: '',
        role: UserRole.employee,
        departmentId: _dept,
        status: UserStatus.pending,
        createdAt: DateTime(2026, 1, 1),
      );
      final messages = buildLateAlerts(
        lateProjects: [_project('p7', dueDate: DateTime(2020, 1, 1), managerUids: ['u4'])],
        users: [pending],
      );
      expect(messages, isEmpty);
    });

    test('الناتج مرتَّب بالاسم فلا يتبدّل بين استدعاءين', () {
      final messages = buildLateAlerts(
        lateProjects: [
          _project('p8', dueDate: DateTime(2020, 1, 1), managerUids: ['u9', 'u1']),
        ],
        users: [_user('u9', 'أحمد'), _user('u1', 'يوسف')],
      );
      expect(messages.map((m) => m.user.name), ['أحمد', 'يوسف']);
    });
  });
}

// ــــ العرض على الهاتف ــــ
//
// صفّ الفلاتر صار خمسة حقول بعد إضافة المستخدم والحالة والتصنيف والترتيب.
// و`FilterBar` تتولّى التكدّس، لكن حقل التصنيف **لا يظهر أصلاً** ما لم يكن
// في المنصة تصنيف واحد على الأقل — فاختبارٌ بلا تصنيفات يقيس صفّاً أضيق مما
// سيراه المستخدم، ويمرّ على عطلٍ واقع. ولذلك تُعرَّف هنا تصنيفات فعلاً.
void _phoneWidthGuards() {
  AppStore phoneStore() => AppStore()
    ..currentUser = AppUser(
      id: 'admin',
      name: 'مسؤول النظام',
      email: 'admin@moj.gov.kw',
      phone: '',
      role: UserRole.systemAdmin,
      departmentId: _dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    )
    ..users = [_user('u1', 'عبدالرحمن بن عبدالعزيز المطيري')]
    ..departments = [
      Department(
        id: _dept,
        name: 'الإدارة العامة لتقنية المعلومات والتحول الرقمي',
        headName: 'رئيس القسم',
        colorValue: 0xFF1B5E4A,
        iconKey: 'settings',
      ),
    ]
    ..categories = const [_digital, _priority, _longCategory]
    ..projects = [
      _project('p1',
          categoryIds: ['c1', 'c2', 'c3'], managerUids: ['u1'], dueDate: DateTime(2020, 1, 1)),
      _project('p2', categoryIds: ['c2']),
    ];

  Future<void> pump(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: ChangeNotifierProvider<AppStore>.value(
        value: phoneStore(),
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ProjectsListScreen()),
        ),
      ),
    ));
    await tester.pump();
  }

  group('صفحة المشاريع بمقاس الهاتف', () {
    for (final phone in const {'iPhone SE': Size(375, 2200), 'iPhone 16 Pro': Size(402, 2200)}.entries) {
      testWidgets('${phone.key}: الفلاتر والوسوم وزرّ التنبيه بلا تجاوز', (tester) async {
        await pump(tester, phone.value);
        expect(tester.takeException(), isNull);

        // قياس هندسي لا `takeException` وحده: `Wrap` لا يُبلّغ عن خروج أبنائه،
        // فالوسم الطويل أو زرّ التنبيه يخرجان بصمت.
        final offenders = <String>[];
        for (final element in tester.allElements) {
          final widget = element.widget;
          if (widget is! Text) continue;
          final object = element.renderObject;
          if (object is! RenderBox || !object.hasSize || !object.attached) continue;

          var scrolls = false;
          element.visitAncestorElements((a) {
            final w = a.widget;
            if (w is Scrollable &&
                (w.axisDirection == AxisDirection.right || w.axisDirection == AxisDirection.left)) {
              scrolls = true;
              return false;
            }
            return true;
          });
          if (scrolls) continue;

          final a = object.localToGlobal(Offset.zero).dx;
          final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
          final left = a < b ? a : b;
          final right = a < b ? b : a;
          if (left < -0.5 || right > phone.value.width + 0.5) {
            offenders.add('«${widget.data}» من ${left.toStringAsFixed(0)} إلى ${right.toStringAsFixed(0)}');
          }
        }
        expect(offenders, isEmpty, reason: 'خرجت نصوص عن الشاشة:\n${offenders.join('\n')}');
      });
    }

    testWidgets('الوسوم تظهر على البطاقة', (tester) async {
      await pump(tester, const Size(402, 2200));
      expect(find.text('رقمنة'), findsWidgets);
      expect(find.text('أولوية وزارية'), findsWidgets);
    });

    testWidgets('وزرّ التنبيه يحمل عدد المتأخرات', (tester) async {
      await pump(tester, const Size(1400, 2200));
      // مشروع واحد متأخر (p1 استحقاقه ٢٠٢٠)، والزرّ يسمّي العدد لا يعمّم.
      expect(find.textContaining('تنبيه 1 مشروعاً متأخراً'), findsOneWidget);
    });
  });
}
