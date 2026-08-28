// نطاقُ التقارير الدورية — من يفتحها، وماذا يرى فيها، وماذا يخرج في ملفّه.
//
// ــــ الذي قرّرتَه ــــ
//
// «مسؤول النظام والتنفيذي كلَّ الإدارات، ومدير الإدارة إدارتَه». ومقارنةُ
// الإدارات لمن يقرأ الكلَّ وحده.
//
// ــــ ولماذا يُقاس في ثلاثة مواضع لا موضع ــــ
//
// لأن للنطاق ثلاثة أبواب: **مدخلُ القائمة** (يظهر أو لا)، و**الشاشة** (تعرض
// جدول الإدارات أو لا)، و**الملفُّ المُصدَّر** (يحمل ورقة الإدارات أو لا).
// وقد وقع في هذه المنصة أن انفتح بابٌ بينما أُغلق أخواه — فحُجبت شاشةٌ عمّن
// يملك بياناتها. والملفُّ أخطرُها: هو ما يخرج من المنصة ويُرسَل.
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/reports/periodic_report.dart';
import 'package:gov_exec_platform/screens/periodic_reports_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/utils/report_export.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _d1 = 'd-1';
const _d2 = 'd-2';

const _departments = [
  Department(id: _d1, name: 'إدارة النظم', headName: '', colorValue: 0xFF0B6E4F, iconKey: 'work'),
  Department(id: _d2, name: 'إدارة الشؤون', headName: '', colorValue: 0xFF0B6E4F, iconKey: 'work'),
];

AppUser _user(String id, UserRole role, {String? dept}) => AppUser(
      id: id,
      name: 'مستخدم $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      departmentIds: dept == null ? const [] : [dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project(String id, String dept) => Project(
      id: id,
      departmentId: dept,
      name: 'مشروع $id',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 50,
      managerUids: const ['e1'],
    );

DailyUpdate _update(String id, String project, String dept, String author) => DailyUpdate(
      id: id,
      projectId: project,
      departmentId: dept,
      authorUid: author,
      authorName: 'مستخدم $author',
      date: DateTime(2026, 8, 24),
      achievements: 'إنجازُ الأسبوع',
      completedTasks: const [],
      newRisks: const [],
      blockers: const [],
      decisionsRequired: const [],
      progressPercent: 50,
    );

AppStore _store(AppUser me) => AppStore()
  ..currentUser = me
  ..departments = _departments
  ..users = [
    _user('e1', UserRole.employee, dept: _d1),
    _user('e2', UserRole.employee, dept: _d2),
  ]
  ..projects = [_project('p1', _d1), _project('p2', _d2)]
  ..dailyUpdates = [
    _update('u1', 'p1', _d1, 'e1'),
    _update('u2', 'p2', _d2, 'e2'),
  ];

/// يُفكّ الملفُّ المُنتَج فعلاً ويُقرأ منه — لا يُفحص استدعاءٌ زُعم أنه وقع.
List<String> _sheetNames(Uint8List bytes) => xls.Excel.decodeBytes(bytes).tables.keys.toList();

String _sheetText(Uint8List bytes, String sheet) {
  final table = xls.Excel.decodeBytes(bytes).tables[sheet];
  if (table == null) return '';
  return [
    for (final row in table.rows)
      for (final cell in row)
        if (cell?.value != null) cell!.value.toString(),
  ].join('\n');
}

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: PeriodicReportsScreen()),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('من يفتح القسم', () {
    test('مسؤول النظام والتنفيذي ومدير الإدارة', () {
      for (final role in [UserRole.systemAdmin, UserRole.executiveViewer]) {
        expect(navKeysFor(_store(_user('a', role))), contains(NavKey.periodicReports),
            reason: 'الدور ${role.name}');
      }
      expect(
        navKeysFor(_store(_user('m', UserRole.departmentManager, dept: _d1))),
        contains(NavKey.periodicReports),
      );
    });

    // التقرير يعرض أداء أشخاصٍ بأسمائهم — وذلك شأنُ من يُتابع لا شأنُ الزميل.
    test('ولا يفتحه الموظف ولا مدير المشروع', () {
      for (final role in [UserRole.employee, UserRole.projectOfficer]) {
        expect(
          navKeysFor(_store(_user('e', role, dept: _d1))),
          isNot(contains(NavKey.periodicReports)),
          reason: 'الدور ${role.name}',
        );
      }
    });
  });

  group('نطاقُ المدخلات', () {
    test('من يقرأ الكلَّ يحمل الإدارتين', () {
      final input = _store(_user('a', UserRole.systemAdmin)).periodicReportInput;
      expect(input.departments.map((d) => d.id), [_d1, _d2]);
      expect(input.projects.length, 2);
    });

    // القواعد **ترفض ولا تُصفّي**، فمديرُ الإدارة لا يحمل غيرَها أصلاً —
    // وهذا إحكامٌ ثانٍ عليه لا الحاجزُ الأول.
    test('ومديرُ الإدارة يحمل إدارتَه وحدها', () {
      final input =
          _store(_user('m', UserRole.departmentManager, dept: _d1)).periodicReportInput;
      expect(input.departments.map((d) => d.id), [_d1]);
      expect(input.projects.map((p) => p.id), ['p1']);
      expect(input.users.map((u) => u.id), ['e1']);
    });
  });

  group('الشاشة', () {
    testWidgets('تعرض المقارنة لمن يقرأ كلَّ الإدارات', (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _store(_user('a', UserRole.systemAdmin)));
      expect(tester.takeException(), isNull);
      expect(find.text('ثانياً: أداء الإدارات'), findsOneWidget);
      expect(find.text('أولاً: أداء الأشخاص'), findsOneWidget);
    });

    test('ولا يقارن مديرُ الإدارة إداراتٍ لا يقرؤها', () {
      expect(_store(_user('m', UserRole.departmentManager, dept: _d1)).canCompareDepartments,
          isFalse);
      expect(_store(_user('a', UserRole.systemAdmin)).canCompareDepartments, isTrue);
      expect(_store(_user('x', UserRole.executiveViewer)).canCompareDepartments, isTrue);
    });

    testWidgets('وشاشتُه بلا جدول إدارات', (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _store(_user('m', UserRole.departmentManager, dept: _d1)));
      expect(tester.takeException(), isNull);
      expect(find.text('ثانياً: أداء الإدارات'), findsNothing);
      expect(find.text('أولاً: أداء الأشخاص'), findsOneWidget);
    });

    // النصُّ الذي نصصتَ عليه: المؤشر أداةُ متابعةٍ لا حكمٌ على موظف.
    testWidgets('والتحفّظ مكتوبٌ حيث يُقرأ المؤشر', (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _store(_user('a', UserRole.systemAdmin)));
      expect(find.text(kActivityDisclaimer), findsOneWidget);
    });
  });

  group('الملفُّ المُصدَّر', () {
    PeriodicReport reportOf(AppStore store) => buildPeriodicReport(
          store.periodicReportInput,
          ReportRange.weekEnding(DateTime(2026, 8, 28)),
        );

    List<String> sheetsOf(AppStore store, {required bool includeDepartments}) {
      final bytes = ReportExporter.buildPeriodicExcelBytes(
        report: reportOf(store),
        includeDepartments: includeDepartments,
      );
      expect(bytes, isNotEmpty);
      return _sheetNames(bytes);
    }

    test('ثلاثُ أوراقٍ بأسمائها لمن يقرأ الكلّ', () {
      final sheets = sheetsOf(_store(_user('a', UserRole.systemAdmin)), includeDepartments: true);
      expect(sheets, containsAll(['الملخص التنفيذي', 'أداء الأشخاص', 'أداء الإدارات']));
    });

    // الملفُّ يخرج من المنصة ويُرسَل — فما لا يُعرض على الشاشة لا يُكتب فيه.
    test('وورقةُ الإدارات لا تخرج في ملفّ مدير الإدارة', () {
      final sheets = sheetsOf(
        _store(_user('m', UserRole.departmentManager, dept: _d1)),
        includeDepartments: false,
      );
      expect(sheets, containsAll(['الملخص التنفيذي', 'أداء الأشخاص']));
      expect(sheets, isNot(contains('أداء الإدارات')));
    });

    test('والتحفّظ مكتوبٌ في ورقة الأشخاص', () {
      final bytes = ReportExporter.buildPeriodicExcelBytes(
        report: reportOf(_store(_user('a', UserRole.systemAdmin))),
        includeDepartments: true,
      );
      expect(_sheetText(bytes, 'أداء الأشخاص'), contains(kActivityDisclaimer));
    });

    // العطل الذي قيس: نصٌّ يبدأ بهمزةٍ تليها حركة يُسقط مولّد PDF كلَّه —
    // فمشروعٌ اسمه «أُفق العدالة» يمنع تصدير التقرير بأسره. راجع
    // `test/pdf_safe_text_test.dart`. ويُقاس هنا من **باب التصدير نفسه** لا
    // من الدالة النقيّة: الدالةُ تُثبت أنها تُنقّي، وهذا يُثبت أنها موصولة.
    testWidgets('واسمٌ يبدأ بهمزةٍ محرّكة لا يُسقط الملفّ', (tester) async {
      // الاسمُ والإدارةُ يدخلان خلايا الجدول مباشرةً — وهما ما يكتبه
      // المستخدم، فمنهما يأتي النصُّ الخام.
      final store = _store(_user('a', UserRole.systemAdmin))
        ..users = [
          AppUser(
            id: 'e1',
            name: 'أُسامة العنزي',
            email: 'e1@moj.gov.kw',
            phone: '',
            role: UserRole.employee,
            departmentId: _d1,
            departmentIds: const [_d1],
            status: UserStatus.approved,
            createdAt: DateTime(2026, 1, 1),
          ),
        ]
        ..departments = const [
          Department(
            id: _d1,
            name: 'إُدارة النظم',
            headName: '',
            colorValue: 0xFF0B6E4F,
            iconKey: 'work',
          ),
        ];

      final bytes = await ReportExporter.buildPeriodicPdfBytes(
        report: reportOf(store),
        includeDepartments: true,
      );
      expect(bytes.length, greaterThan(1000));
    });

    testWidgets('وملفُّ PDF يخرج ببايتاتٍ حقيقية', (tester) async {
      final bytes = await ReportExporter.buildPeriodicPdfBytes(
        report: reportOf(_store(_user('a', UserRole.systemAdmin))),
        includeDepartments: true,
      );
      expect(bytes.length, greaterThan(1000));
      // ترويسةُ ملفّ PDF نفسها: `%PDF`.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
