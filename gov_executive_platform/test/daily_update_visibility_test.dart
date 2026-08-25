// لماذا لا يرى المستخدمُ تحديثاتِ مشروعه — الشاشة تقولها، لا تُخفيها.
//
// ــــ الحال التي أوجدت هذا الملف ــــ
//
// «لا توجد تحديثات بعد» كانت تُعرض في ثلاث حالاتٍ مختلفة تماماً:
//
//   ١) لم يُكتب شيء فعلاً.
//   ٢) كُتب ولم يصل — نطاقُ اشتراكه لا يشمل هذا المشروع.
//   ٣) رُدّت القراءة على الخادم.
//
// فلا سبيل من الشاشة إلى معرفة أيِّها وقع. وقد ضاعت جولةٌ كاملة في تخمين
// ذلك: أُصلح فرعٌ في الاشتراك تبيّن أنه **لا يمرّ به أحد** (دور «مدير
// مشروع» موروثٌ لا يُمنح)، ولم يتغيّر شيء عند صاحب الشكوى.
//
// فما يُقاس هنا هو **أن الشاشة تفرّق**.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/daily_update.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';

const _projectDept = 'd-justice';
const _otherDept = 'd-elsewhere';

AppUser _user(String id, UserRole role, {String? dept = _projectDept}) => AppUser(
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

Project _project() => Project(
      id: 'p1',
      departmentId: _projectDept,
      name: 'مشروع',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      managerUids: const ['m1'],
      executorUids: const ['e1'],
    );

DailyUpdate _update() => DailyUpdate(
      id: 'u1',
      projectId: 'p1',
      departmentId: _projectDept,
      authorUid: 'm1',
      authorName: 'المدير',
      date: DateTime(2026, 6, 1),
      achievements: 'أُنجز',
      completedTasks: const [],
      newRisks: const [],
      blockers: const [],
      decisionsRequired: const [],
      progressPercent: 20,
    );

AppStore _store(AppUser me) => AppStore()
  ..currentUser = me
  ..projects = [_project()]
  ..departments = [
    const Department(
      id: _projectDept,
      name: 'إدارة العدل',
      headName: '',
      colorValue: 0xFF000000,
      iconKey: 'gavel',
    ),
  ];

void main() {
  group('حين لا تُعرض تحديثات', () {
    // (١) الغياب الحقيقي: لا يُقال شيء زائد، فلا يُقلق الناسَ بلا سبب.
    test('عضوٌ في إدارة المشروع ولا تحديثات — لا تفسير، فالغياب حقيقي', () {
      final store = _store(_user('m1', UserRole.employee));

      expect(store.whyNoUpdates(_project()), isNull);
    });

    // (٢) خارج النطاق: يُقال بالضبط لماذا، وتُسمّى الإدارتان.
    test('من ليس عضواً ولا من إدارة المشروع — يُقال إن الإدارة غير إدارته', () {
      final store = _store(_user('x', UserRole.employee, dept: _otherDept));

      final why = store.whyNoUpdates(_project());
      expect(why, isNotNull);
      expect(why, contains('لستَ عضواً'));
      expect(why, contains('إدارة العدل'));
    });

    // (٣) الردّ من الخادم: يُقال نصُّه، لا «حاول مرة أخرى».
    test('ورُدّت القراءة — يُقال ذلك ومعه سببُ الخادم', () {
      final store = _store(_user('m1', UserRole.employee))
        ..dataErrors['dailyUpdates/managerUids'] = 'permission-denied: تعذّرت القراءة';

      final why = store.whyNoUpdates(_project());
      expect(why, isNotNull);
      expect(why, contains('رُدّت قراءة التحديثات'));
      expect(why, contains('permission-denied'));
    });

    // وحالُ من فُتح له الباب بالعضوية وحدها: توابعُه القديمة قد لا تحمل
    // نسخة العضوية، فيُقال إن الختم يُصلحها بدل أن يُترك حائراً.
    test('وعضوٌ من إدارةٍ أخرى — يُشار إلى ختم السجلات القديمة', () {
      final store = _store(_user('m1', UserRole.employee, dept: _otherDept));

      final why = store.whyNoUpdates(_project());
      expect(why, isNotNull);
      expect(why, contains('عضوٌ في هذا المشروع'));
      expect(why, contains('يختمها مسؤول النظام'));
    });
  });

  group('وحين تُعرض', () {
    test('لا تفسير إطلاقاً — التفسير للفراغ وحده', () {
      final store = _store(_user('m1', UserRole.employee))..dailyUpdates = [_update()];

      expect(store.whyNoUpdates(_project()), isNull);
    });

    // ولو كان هناك ردٌّ مسجَّل على مجموعةٍ أخرى: التحديثات وصلت، فلا يُقال
    // للمستخدم كلامٌ عن عطلٍ لا يمسّ ما يراه.
    test('ولو بقي ردٌّ مسجَّل، ما دامت التحديثات قد وصلت', () {
      final store = _store(_user('m1', UserRole.employee))
        ..dailyUpdates = [_update()]
        ..dataErrors['dailyUpdates/managerUids'] = 'permission-denied';

      expect(store.whyNoUpdates(_project()), isNull);
    });
  });
}
