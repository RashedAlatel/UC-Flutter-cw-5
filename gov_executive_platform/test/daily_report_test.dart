// التقرير التنفيذي اليومي — الجانب الذي في العميل.
//
// الحساب كله على الخادم ويُختبر هناك (`functions/test/daily_report.test.mjs`).
// فما يبقى للعميل ثلاثة أشياء، وكلها تُخفق بصمت لو انكسرت:
//
// ١) **من يظهر له المدخل**. وهذا يجب أن يطابق `scopesFor` على الخادم حرفاً:
//    من يُولَّد له مستند هو من يجد الشاشة. ولو افترقا لَوجد مستخدمٌ مدخلاً
//    يفتح كل يوم على «لم يُولَّد تقريرك» بلا سبب مفهوم — أو لَوُلِّد لمن لا
//    يجد أين يقرؤه.
//
// ٢) **قراءة المستند**. حقلٌ يُقرأ بالاسم الخطأ يعطي شاشةً فارغة بلا خطأ.
//
// ٣) **درجةٌ مجهولة**: مستندٌ من نسخة خادمٍ أحدث يجب ألّا يصبغ الشاشة
//    بالأحمر لمجرد أن اسم درجته لم يُعرف بعد.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/daily_report.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/widgets/nav_entries.dart';

const _dept = 'd-1';

AppUser _user(String id, UserRole role, {String? dept = _dept}) => AppUser(
      id: id,
      name: 'صاحب $id',
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: dept,
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

Project _project({List<String> managers = const []}) => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 20,
      managerUids: managers,
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _storeFor(AppUser me, {List<Project> projects = const []}) => AppStore()
  ..currentUser = me
  ..users = [me]
  ..projects = projects;

void main() {
  group('من يستحقّ التقرير — والشرط يطابق الخادم', () {
    test('مسؤول النظام', () {
      expect(_storeFor(_user('u-admin', UserRole.systemAdmin, dept: null)).canReadDailyReport,
          isTrue);
    });

    test('والمسؤول التنفيذي', () {
      expect(_storeFor(_user('u-exec', UserRole.executiveViewer)).canReadDailyReport, isTrue);
    });

    test('ومدير الإدارة', () {
      expect(_storeFor(_user('u-head', UserRole.departmentManager)).canReadDailyReport, isTrue);
    });

    // قيادة المشروع صفةٌ على المشروع لا دورٌ على الشخص — راجع جولة فصل الدور.
    // فمن يقود مشروعاً يستحقّ التقرير ولو كان دوره الأساسي «موظفاً».
    test('والموظف الذي يقود مشروعاً فعلاً', () {
      final me = _user('u-emp', UserRole.employee);
      final store = _storeFor(me, projects: [_project(managers: ['u-emp'])]);
      expect(store.canReadDailyReport, isTrue);
    });

    // وهذا هو القرار الصريح: لا نسخة للموظف العادي.
    test('ولا الموظف الذي لا يقود شيئاً', () {
      final me = _user('u-emp', UserRole.employee);
      final store = _storeFor(me, projects: [_project(managers: ['u-other'])]);
      expect(store.canReadDailyReport, isFalse);
    });

    test('والمدخل يظهر لمن يستحقّه وحده', () {
      final head = _user('u-head', UserRole.departmentManager);
      expect(navKeysFor(_storeFor(head)), contains(NavKey.dailyReport));

      final emp = _user('u-emp', UserRole.employee);
      expect(navKeysFor(_storeFor(emp, projects: [_project()])),
          isNot(contains(NavKey.dailyReport)));
    });
  });

  group('قراءة المستند', () {
    Map<String, dynamic> doc() => {
          'date': '2026-08-22',
          'recipientUid': 'u-head',
          'recipientName': 'مدير الإدارة',
          'scopeLabel': 'إدارتك',
          'criticalCount': 3,
          'attentionCount': 5,
          'headline': '٣ حالات حرجة و٥ تحتاج انتباهاً.',
          'top': [
            {
              'key': 'project:p1',
              'title': 'مشروع الرقمنة',
              'severity': 'critical',
              'reason': 'تجاوز موعده النهائي بـ٥ أيام',
              'fields': [
                {'label': 'أيام التأخير', 'value': '٥'},
              ],
              'linkProjectId': 'p1',
              'linkWorkId': null,
            },
          ],
          'sections': [
            {
              'key': 'urgentProjects',
              'title': 'مشاريع تحتاج تدخلاً عاجلاً',
              'emptyNote': 'لا مشروع يحتاج تدخلاً اليوم.',
              'rows': [],
            },
          ],
          'generatedAt': '2026-08-22T04:00:00Z',
        };

    test('الخلاصة والنطاق يُقرآن', () {
      final r = DailyReport.fromMap(doc());
      expect(r.date, '2026-08-22');
      expect(r.scopeLabel, 'إدارتك');
      expect(r.criticalCount, 3);
      expect(r.attentionCount, 5);
    });

    test('وأهم الحالات معها وجهتها', () {
      final row = DailyReport.fromMap(doc()).top.single;
      expect(row.title, 'مشروع الرقمنة');
      expect(row.severity, ReportSeverity.critical);
      expect(row.linkProjectId, 'p1');
      expect(row.hasTarget, isTrue);
      expect(row.fields.single.value, '٥');
    });

    // الباب الفارغ خبرٌ جيّد لا فراغ، ولا يُحذف: حذفُه يجعل القارئ لا يدري
    // أفُحص الباب أم أُسقط.
    test('والباب الفارغ يحمل خبره', () {
      final s = DailyReport.fromMap(doc()).sections.single;
      expect(s.rows, isEmpty);
      expect(s.emptyNote, 'لا مشروع يحتاج تدخلاً اليوم.');
    });

    test('ومستندٌ فارغ يُقرأ بلا انهيار', () {
      final r = DailyReport.fromMap(const {});
      expect(r.sections, isEmpty);
      expect(r.top, isEmpty);
      expect(r.criticalCount, 0);
    });

    test('وسطرٌ بلا وجهة يُعلَم أنه لا يُضغط', () {
      final row = ReportRow.fromMap(const {
        'key': 'update:u1',
        'title': 'تحديث',
        'severity': 'normal',
        'fields': [],
      });
      expect(row.hasTarget, isFalse);
    });

    // ولولا هذا لَصبغ مستندٌ من نسخةِ خادمٍ أحدث الشاشةَ بأخطر لون لمجرد أن
    // اسم درجته لم يُعرف بعد.
    test('ودرجةٌ مجهولة تُقرأ أدناها لا أعلاها', () {
      expect(ReportSeverity.fromKey('somethingNew'), ReportSeverity.normal);
      expect(ReportSeverity.fromKey(null), ReportSeverity.normal);
      expect(ReportSeverity.fromKey('critical'), ReportSeverity.critical);
    });
  });
}
