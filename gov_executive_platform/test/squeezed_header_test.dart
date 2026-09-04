// انسحاق النص في عمودٍ رأسي على شاشة الجوال.
//
// ــــ العطل الذي أوجد هذا الملف ــــ
//
// لقطةٌ من هاتف مسؤول النظام: عنوان المشروع يُرسم **حرفاً أو حرفين في كل
// سطر** — «مشرو / ع ممار / سه و / صيانه» — ومعه اسم الإدارة عموداً رأسياً.
//
// وسببه أن ترويسة صفحة المشروع صفٌّ واحد يجمع العنوان وشارة الحالة وأربعة
// أزرار أيقونات. والأزرار والشارة تأخذ عرضها الثابت أولاً، ولا يبقى
// للعنوان إلا بضعة بكسلات. و`Expanded` لا يشتكي: يأخذ ما بقي مهما ضاق.
//
// ــــ ولماذا ملفٌّ ثانٍ بدل `card_overflow_test.dart`؟ ــــ
//
// لأن المقياس مختلف. ذاك يقيس **الخروج عن حدود الشاشة**، والنص هنا لا
// يخرج: هو داخل البطاقة تماماً، مسحوقاً. فحارس الطفح يمرّ على هذا العطل
// مروراً كاملاً — وقد جُرّب.
//
// فهذا يقيس **الشكل**: نصٌّ ارتفاعه أضعاف عرضه ليس سطراً، بل عمود.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/app_user.dart';
import 'package:gov_exec_platform/models/department.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/work_item.dart';
import 'package:gov_exec_platform/screens/user_management_screen.dart';
import 'package:gov_exec_platform/screens/work_detail_screen.dart';
import 'package:gov_exec_platform/theme/app_theme.dart';
import 'package:gov_exec_platform/widgets/responsive_header_row.dart';
import 'package:gov_exec_platform/widgets/status_chip.dart';

const _dept = 'd-ops';

/// اسم المشروع كما ورد في اللقطة حرفاً — لا اسمٌ مختصر من عندنا.
const _longName = 'مشروع ممارسه و صيانه و دعم اجهزه IBM Power System و ملحقاتها';

/// ــ لماذا مسؤول نظام بالذات؟ ــ
///
/// أزرار الترويسة الأربعة معلَّقة بـ`isAdmin` و`canSendNotifications`. فمدير
/// الإدارة يرى زرّين وتمرّ البطاقة عنده — ولهذا لم يظهر العطل في التجربة
/// العادية. واختبارٌ بمستخدمٍ أقلّ صلاحيةً يفحص شاشةً ليست التي انكسرت.
AppStore _adminStore() => AppStore()
  ..currentUser = AppUser(
    id: 'u-admin',
    name: 'مسؤول النظام',
    email: 'admin@moj.gov.kw',
    phone: '',
    role: UserRole.systemAdmin,
    departmentId: _dept,
    status: UserStatus.approved,
    createdAt: DateTime(2026, 1, 1),
  )
  ..departments = [
    Department(
      id: _dept,
      name: 'إدارة التشغيل',
      headName: 'رئيس الإدارة',
      colorValue: 0xFF1B5E4A,
      iconKey: 'settings',
    ),
  ]
  ..projects = [
    Project(
      id: 'p1',
      departmentId: _dept,
      name: _longName,
      description: 'الجهة ذات الصلة: إدارة الشئون المالية. ملاحظات: تم الإفادة '
          'على مخاطبة الشئون المالية بعدم وجود ملاحظات وإنتظار إستكمال إجراءات '
          'الطرح والترسية من قبلهم.',
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 3, 31),
      status: ProjectStatus.delayed,
      priority: PriorityLevel.high,
      progressPercent: 35,
    ),
  ]
  ..works = [
    WorkItem(
      id: 'w1',
      title: _longName,
      description: 'وصف العمل',
      departmentId: _dept,
      assigneeUid: 'u-admin',
      assigneeName: 'مسؤول النظام',
      status: TaskStatus.inProgress,
      priority: PriorityLevel.high,
      progressPercent: 35,
      dueDate: DateTime(2026, 3, 31),
      createdByUid: 'u-admin',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

/// ترويسةُ صفحة المشروع كما تُبنى في الشاشة: العنوان ومسارُ الإدارة تحته،
/// ومعهما شارةُ الحالة وأربعةُ أزرارٍ لا يراها إلا مسؤول النظام.
///
/// وهي **داخل بطاقةٍ بحشوها وهامش الصفحة** كما في الشاشة — فالعرض المتاح هو
/// ما يصنع العطل، ونسخُ الترويسة بلا هذين يقيس عرضاً لا وجود له.
Widget _projectHeader() => const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 56),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: ResponsiveHeaderRow(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_longName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text('إدارة التشغيل',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ),
                    IconButton(
                      icon: Icon(Icons.drive_file_move_outline, size: 17),
                      visualDensity: VisualDensity.compact,
                      onPressed: null,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              StatusChip(status: ProjectStatus.delayed),
              IconButton(icon: Icon(Icons.forward_to_inbox_rounded, size: 20), onPressed: null),
              IconButton(icon: Icon(Icons.star_border_rounded, size: 20), onPressed: null),
              IconButton(icon: Icon(Icons.push_pin_outlined, size: 20), onPressed: null),
              IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20), onPressed: null),
            ],
          ),
        ),
      ),
    );

/// نصٌّ ارتفاعه أضعاف عرضه ليس سطراً — بل عمودُ حروف.
///
/// ــ لماذا هذه العتبة؟ ــ
///
/// سطرٌ واحد نسبتُه أقلّ من ١، وفقرةٌ من أربعة أسطر في بطاقة ضيّقة تبلغ
/// نحو ٠٫٥. والانسحاق الذي في اللقطة نسبتُه فوق ١٠. فعتبةُ **٣** بعيدة عن
/// الحالتين معاً: لا تصيح على تخطيطٍ سليم، ولا تُفلت عموداً.
///
/// و`_minChars` تستثني ما يُرسم رأسياً بحقّ — حرفٌ أو رمزٌ أو رقمٌ في شارة.
const double _maxHeightToWidth = 3.0;
const int _minChars = 8;

void _expectNoSqueezedText(WidgetTester tester) {
  final offenders = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! Text) continue;
    final data = widget.data;
    if (data == null || data.trim().length < _minChars) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize || !object.attached) continue;
    final size = object.size;
    if (size.width <= 0 || size.height <= 0) continue;
    if (size.height > size.width * _maxHeightToWidth) {
      offenders.add(
        '«${data.length > 40 ? '${data.substring(0, 40)}…' : data}» '
        'عرضه ${size.width.toStringAsFixed(0)} وارتفاعه ${size.height.toStringAsFixed(0)} '
        '— أي ${(size.height / size.width).toStringAsFixed(1)}× ',
      );
    }
  }
  expect(offenders, isEmpty,
      reason: 'نصوص انسحقت في عمودٍ رأسي بدل أن تُرسم أسطراً:\n${offenders.join('\n')}');
}

/// ولا يخرج نصٌّ عن حدود الشاشة.
///
/// نظيرُ ما في `card_overflow_test.dart` — ويُكرَّر هنا لأن الشاشات الثلاث
/// ليست فيه. والمقياسان يكمّل أحدهما الآخر: ذاك يمسك الخارج، وهذا المسحوق،
/// ولا يُغني أحدهما عن الآخر.
void _expectAllTextInside(WidgetTester tester, Size size) {
  final offenders = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! Text || widget.data == null) continue;
    final object = element.renderObject;
    if (object is! RenderBox || !object.hasSize || !object.attached) continue;
    final a = object.localToGlobal(Offset.zero).dx;
    final b = object.localToGlobal(Offset(object.size.width, 0)).dx;
    final left = a < b ? a : b;
    final right = a < b ? b : a;
    if (left < -0.5 || right > size.width + 0.5) {
      offenders.add('«${widget.data}» من ${left.toStringAsFixed(0)} '
          'إلى ${right.toStringAsFixed(0)} وعرض الشاشة ${size.width.toStringAsFixed(0)}');
    }
  }
  expect(offenders, isEmpty, reason: 'نصوص خرجت عن حدود الشاشة:\n${offenders.join('\n')}');
}

/// أخطاءُ التخطيط وحدها تُفحص، وغياب Firebase يُتجاوَز — صراحةً لا صمتاً.
///
/// شاشتا العمل والمستخدمين تلمسان Firestore، ولا Firebase في بيئة الاختبار.
/// وهما تُبنيان وتُرسمان على كل حال، فالقياس الهندسي صحيح.
///
/// وشاشةُ تفصيل المشروع **لا** تُبنى: تنادي `ensureProjectWidgetsSubscribed`
/// في أول `build` فيُجهض البناء — صفر نصوص وصفر أزرار، وقد قِيس. ولذلك
/// تُختبر ترويستها ويدجتاً لا شاشةً كاملة.
///
/// ولا يُبتلع الاستثناء كلّه: يُطابَق نصُّه، وما سواه يُرفع. فابتلاعٌ عام
/// يجعل الاختبار يمرّ على أعطالٍ حقيقية — وقد وجد هذا الملفُ عطلاً بهذه
/// الطريقة بالضبط: طفحٌ في صفحة العمل بمقدار ٢٦ بكسل.
void _expectOnlyMissingFirebase(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  if (error.toString().contains('core/no-app')) return;
  fail('استثناءٌ ليس غياب Firebase: $error');
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

const _phones = {
  'iPhone 16 Pro': Size(402, 874),
  'iPhone SE': Size(375, 667),
};

void main() {
  for (final entry in _phones.entries) {
    group('بمقاس ${entry.key}', () {
      // هذه هي التي انكسرت في اللقطة.
      //
      // وتُختبر الترويسةُ وحدها لا الشاشة كلها: `ProjectDetailScreen` تنادي
      // `ensureProjectWidgetsSubscribed` داخل `build`، فتطلب Firestore
      // وتُجهض البناء في بيئة الاختبار — فلا يُرسم شيء. وقد قِيس: صفر نصوص
      // وصفر أزرار. واختبارٌ لا يُبنى لا يحرس شيئاً مهما بدا أخضر.
      testWidgets('ترويسة صفحة المشروع لا تنسحق', (tester) async {
        await _pump(tester, entry.value, _projectHeader(), _adminStore());
        _expectNoSqueezedText(tester);
        _expectAllTextInside(tester, entry.value);
        _expectOnlyMissingFirebase(tester);
      });

      testWidgets('وصفحة العمل كذلك', (tester) async {
        await _pump(
          tester,
          entry.value,
          const WorkDetailScreen(workId: 'w1'),
          _adminStore(),
        );
        _expectNoSqueezedText(tester);
        _expectAllTextInside(tester, entry.value);
        _expectOnlyMissingFirebase(tester);
      });

      testWidgets('وشاشة المستخدمين كذلك', (tester) async {
        await _pump(
          tester,
          entry.value,
          const UserManagementScreen(),
          _adminStore(),
        );
        _expectNoSqueezedText(tester);
        _expectAllTextInside(tester, entry.value);
        _expectOnlyMissingFirebase(tester);
      });
    });
  }

  // العريض لم يُمسّ: فوق العتبة تبقى الترويسة صفّاً واحداً كما كانت.
  testWidgets('وعلى الشاشة العريضة تبقى الترويسة صفّاً واحداً', (tester) async {
    await _pump(tester, const Size(1280, 900), _projectHeader(), _adminStore());
    _expectNoSqueezedText(tester);
    _expectOnlyMissingFirebase(tester);
    // وصفّاً واحداً فعلاً: العنوان والشارة على ارتفاعٍ واحد.
    final title = tester.getTopLeft(find.text(_longName)).dy;
    final chip = tester.getTopLeft(find.byType(StatusChip)).dy;
    expect((title - chip).abs() < 30, isTrue,
        reason: 'العنوان والشارة على سطرين في الشاشة العريضة — الترويسة انكسرت للعكس.');
  });
}
