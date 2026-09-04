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
  DateTime? due,
  double progress = 40,
  PriorityLevel priority = PriorityLevel.high,
  ProjectStatus status = ProjectStatus.onTrack,
}) =>
    Project(
      id: id,
      departmentId: _dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: due ?? dueDate ?? DateTime(2099, 1, 1),
      status: status,
      priority: priority,
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

  group('ترتيب المشاريع', () {
    // زال «التجميع حسب التصنيف» بطلب المستخدم: الوسم صفةٌ تُصفّى بها القائمة،
    // والترتيب طريقة عرض — وخلطُهما جعل المنتقي يَعِد بما لا يفعل. والوسوم
    // باقية في منتقي التصفية وفي شرائح البطاقات.
    test('المنتقي لم يعد يحمل خيار تجميعٍ بالتصنيف', () {
      expect(ProjectSort.values.map((s) => s.name), isNot(contains('category')));
    });

    test('«الأهم أولاً»: المتأخر قبل غيره، والأكثر تأخيراً أولاً', () {
      final ordered = sortProjects(
        projects: [
          _project('ontrack', due: DateTime(2099, 1, 1)),
          _project('late5', due: DateTime.now().subtract(const Duration(days: 5))),
          _project('late30', due: DateTime.now().subtract(const Duration(days: 30))),
        ],
        sort: ProjectSort.smart,
      );
      expect(ordered.map((p) => p.id), ['late30', 'late5', 'ontrack']);
    });

    test('وعند تساوي التأخير يفصل الاستحقاق ثم الأولوية', () {
      final soonLow = _project('soon', due: DateTime(2099, 1, 1), priority: PriorityLevel.low);
      final laterHigh = _project('later', due: DateTime(2099, 6, 1), priority: PriorityLevel.critical);
      final ordered = sortProjects(projects: [laterHigh, soonLow], sort: ProjectSort.smart);
      expect(ordered.map((p) => p.id), ['soon', 'later'],
          reason: 'الاستحقاق يسبق الأولوية في طبقات الترتيب');
    });

    test('والمكتمل ينزل إلى الآخر ولو كان تاريخه أقرب', () {
      final done = _project('done', due: DateTime(2020, 1, 1), status: ProjectStatus.completed);
      final open = _project('open', due: DateTime(2099, 1, 1));
      final ordered = sortProjects(projects: [done, open], sort: ProjectSort.smart);
      expect(ordered.map((p) => p.id), ['open', 'done']);
    });

    test('«الأولوية»: حرجة ثم عالية ثم متوسطة ثم منخفضة', () {
      final ordered = sortProjects(
        projects: [
          _project('low', priority: PriorityLevel.low),
          _project('critical', priority: PriorityLevel.critical),
          _project('medium', priority: PriorityLevel.medium),
          _project('high', priority: PriorityLevel.high),
        ],
        sort: ProjectSort.priority,
      );
      expect(ordered.map((p) => p.id), ['critical', 'high', 'medium', 'low']);
    });

    test('«آخر تحديث»: من لا تحديث له يقع في الآخر لا في الصدارة', () {
      final ordered = sortProjects(
        projects: [_project('never'), _project('old'), _project('fresh')],
        sort: ProjectSort.lastUpdated,
        lastUpdateOf: {
          'old': DateTime(2026, 1, 1),
          'fresh': DateTime(2026, 8, 1),
        },
      );
      expect(ordered.map((p) => p.id), ['fresh', 'old', 'never']);
    });

    test('الترتيب ثابت: المتساوون يُرتَّبون بالاسم لا عشوائياً', () {
      // بغير هذا تقفز القائمة تحت يد المستخدم بين بناءٍ وآخر.
      final ordered = sortProjects(
        projects: [_project('ب'), _project('أ')],
        sort: ProjectSort.progressHigh,
      );
      expect(ordered.map((p) => p.id), ['أ', 'ب']);
    });

    test('«الأكثر تأخيراً» يقدّم من تجاوز موعده بأكثر', () {
      final old = _project('p1', dueDate: DateTime(2020, 1, 1));
      final recent = _project('p2', dueDate: DateTime(2025, 1, 1));
      final ordered = sortProjects(projects: [recent, old], sort: ProjectSort.mostDelayed);
      expect(ordered.map((p) => p.id), ['p1', 'p2']);
    });

    test('و«نسبة الإنجاز: الأقل أولاً» تقدّم الأقل', () {
      final ordered = sortProjects(
        projects: [_project('p1', progress: 80), _project('p2', progress: 10)],
        sort: ProjectSort.progressLow,
      );
      expect(ordered.map((p) => p.id), ['p2', 'p1']);
    });

    test('والاتجاه المعاكس يقدّم الأعلى', () {
      final ordered = sortProjects(
        projects: [_project('p1', progress: 10), _project('p2', progress: 80)],
        sort: ProjectSort.progressHigh,
      );
      expect(ordered.map((p) => p.id), ['p2', 'p1']);
    });

    test('و«الأقرب للاستحقاق» و«الأبعد» متعاكسان', () {
      final soon = _project('soon', dueDate: DateTime(2026, 1, 1));
      final later = _project('later', dueDate: DateTime(2099, 1, 1));
      expect(sortProjects(projects: [later, soon], sort: ProjectSort.dueSoon).map((p) => p.id),
          ['soon', 'later']);
      expect(sortProjects(projects: [soon, later], sort: ProjectSort.dueLate).map((p) => p.id),
          ['later', 'soon']);
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

    test('ولمشروع واحد يبقى النصّ منظَّماً كما للعدّة — لا صياغة ثانية', () {
      // كان هذا الاختبار يشترط أن يُستعمل قالب صفحة المشروع نفسه، بحجّة ألّا
      // تفترق صياغتان. وتبدّل القرار صراحةً: التنبيه الجماعي صار **تقريراً
      // منظَّماً** لكل مشروع (استحقاقه وأيام تأخيره ونسبته ورابطه المباشر)،
      // وقالبُ صفحة المشروع جملةٌ قصيرة قابلة للتحرير قبل الإرسال.
      //
      // وهما غرضان مختلفان لا صياغتان لغرضٍ واحد: الأول يُقرأ في البريد بلا
      // فتح المنصة، والثاني رسالةٌ يكتبها إنسان. والمهمّ أن **الجماعي** لا
      // يفترق عن نفسه بين مشروعٍ وعدّة — وهذا ما يُفحص هنا.
      final messages = buildLateAlerts(
        lateProjects: [late1],
        users: [_user('u1', 'سعد المطيري')],
      );
      expect(messages.single.subject, contains('تنبيه تأخير'));
      expect(messages.single.body, contains('أيام التأخير:'));
      expect(messages.single.body, contains('تاريخ الاستحقاق:'));
      expect(messages.single.body, contains('نسبة الإنجاز:'));
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
