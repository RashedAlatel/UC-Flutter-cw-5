// المواضع الأربعة تُغذّى من القاعدة الواحدة — لا واحدٌ منها.
//
// ــــ لماذا اختبارٌ لكل نافذة على حدة؟ ــــ
//
// لأن العطل الأصلي كان أن **كل شاشة تصفّي بنفسها**. فاختبارٌ واحد يمرّ على
// نافذة واحدة يُثبت أن تلك النافذة صحيحة، ويترك الثلاث الأخرى كما كانت —
// وهو بعينه ما وقع.
//
// فأربعة اختبارات، كلٌّ منها يفتح نافذته بدور «مدير مشروع» في متجرٍ فيه
// مسؤول تنفيذي ومدير إدارة وموظف، ويشترط: **الأولان غائبان والثالث حاضر**.
// وإعادةُ الشرط القديم إلى نافذةٍ واحدة تُسقط اختبارها وحده.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/screens/change_manager_dialog.dart';
import 'package:gov_exec_platform/screens/request_project_dialog.dart';
import 'package:gov_exec_platform/screens/works_list_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/executors_field.dart';

const _dept = 'd-1';
const _me = 'me';

// أسماءٌ مميّزة: `find.text` يبحث في كل الشجرة، فاسمٌ عام مثل «أحمد» قد
// يطابق نصاً آخر في النافذة فيُخفي الفشل.
const _execName = 'مشعل';
const _mgrName = 'فيصل';
const _empName = 'سالم';
const _peerName = 'ناصر';

AppUser _u(String id, String name, UserRole role) => AppUser(
      id: id,
      name: name,
      email: '$id@moj.gov.kw',
      phone: '',
      role: role,
      departmentId: _dept,
      departmentIds: const [_dept],
      status: UserStatus.approved,
      createdAt: DateTime(2026, 1, 1),
    );

final _people = [
  _u(_me, 'أنا مدير المشروع', UserRole.projectOfficer),
  _u('exec', _execName, UserRole.executiveViewer),
  _u('mgr', _mgrName, UserRole.departmentManager),
  _u('emp', _empName, UserRole.employee),
  _u('peer', _peerName, UserRole.projectOfficer),
];

Project _project() => Project(
      id: 'p1',
      departmentId: _dept,
      name: 'مشروع الأرشفة',
      description: '',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: ProjectStatus.onTrack,
      priority: PriorityLevel.medium,
      progressPercent: 10,
      managerUids: const [_me],
      createdAt: DateTime(2026, 1, 1),
    );

AppStore _store() => AppStore()
  ..currentUser = _people.first
  ..users = _people
  ..departments = [
    Department(
        id: _dept,
        name: 'إدارة تقنية المعلومات',
        headName: 'رئيس',
        colorValue: 0xFF1B5E4A,
        iconKey: 'settings'),
  ]
  ..projects = [_project()];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(700, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
    value: _store(),
    child: MaterialApp(
      theme: AppTheme.theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// الأعلى رتبةً غائبون، والأدنى والنظير حاضران.
///
/// و`textContaining` لا `text`: إحدى القوائم تكتب «الاسم — الدور» في السطر
/// نفسه، فالمطابقة الحرفية تفشل فيها لسببٍ لا علاقة له بالتصفية.
void _expectFiltered(String where) {
  expect(find.textContaining(_execName), findsNothing, reason: '$where: المسؤول التنفيذي ظاهر');
  expect(find.textContaining(_mgrName), findsNothing, reason: '$where: مدير الإدارة ظاهر');
  expect(find.textContaining(_empName), findsWidgets, reason: '$where: الموظف غائب');
  expect(find.textContaining(_peerName), findsWidgets, reason: '$where: النظير غائب');
}

void main() {
  testWidgets('نافذة إضافة مشروع: منتقيا المديرين والمنفّذين', (tester) async {
    await _pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const RequestProjectDialog(departmentId: _dept),
        ),
        child: const Text('افتح'),
      ),
    ));
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    _expectFiltered('إضافة مشروع');
  });

  testWidgets('حقل المنفّذين بالاسم: البحث لا يقترح من هو أعلى', (tester) async {
    await _pump(
      tester,
      const SingleChildScrollView(
        child: ExecutorsField(initial: [], departmentId: _dept, onChanged: _noop),
      ),
    );
    _expectFiltered('حقل المنفّذين');
  });

  testWidgets('نموذج العمل: قائمة المسؤول عن التنفيذ', (tester) async {
    await _pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog(context: context, builder: (_) => const WorkFormDialog()),
        child: const Text('افتح'),
      ),
    ));
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    // القائمة تُفتح فعلاً: `DropdownButton` لا يبني عناصره ما لم يكن له
    // قيمة مختارة أو تكن مفتوحة — فقراءتها من الشجرة المغلقة تجد لا شيء
    // دائماً، ويمرّ الاختبار على كل حال بلا أن يفحص شيئاً.
    final dropdown = find.ancestor(
      of: find.text('المسؤول عن التنفيذ'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    _expectFiltered('نموذج العمل');
  });

  testWidgets('نافذة تغيير مدير المشروع', (tester) async {
    await _pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => ChangeManagerDialog(project: _project()),
        ),
        child: const Text('افتح'),
      ),
    ));
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    _expectFiltered('تغيير المدير');
  });
}

void _noop(List<String> _) {}
