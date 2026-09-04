// الطلب لا يلزمه منفّذ — ومدير الإدارة يجد ما ينتظر تكليفه.
//
// ــــ لماذا يُقرأ الشرط من المصدر لا يُعاد كتابته هنا؟ ــــ
//
// شرط الإلزام كان في `_submit` داخل ودجت — لا يُستدعى من اختبارٍ بلا بناء
// شجرة كاملة. ولو أُعيدت كتابته هنا لَصار الاختبار يقيس نسخته لا الشيفرة،
// فيبقى أخضر بعد عودة الشرط. فيُقرأ الملف نصّاً: ما يُقاس هو **غياب**
// الشرط من موضعه، وذلك ما يعنيه «رُفع القيد» حرفاً.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/work_item.dart';

String _source(String path) => File(path).readAsStringSync();

WorkItem _work({
  required String id,
  String assigneeUid = '',
  TaskStatus status = TaskStatus.todo,
}) =>
    WorkItem(
      id: id,
      title: 'عمل $id',
      description: '',
      departmentId: 'd-1',
      assigneeUid: assigneeUid,
      assigneeName: assigneeUid.isEmpty ? '' : 'فلان',
      status: status,
      priority: PriorityLevel.medium,
      progressPercent: 0,
      dueDate: DateTime(2026, 12, 31),
      createdByUid: 'u-req',
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  const screen = 'lib/screens/works_list_screen.dart';

  group('الطلب لا يلزمه منفّذ', () {
    test('لا يُردّ الطلب لخلوّ حقل المنفّذ', () {
      final src = _source(screen);
      // نصُّ الردّ الذي كان يمنع الطلب — وهو ما سقط.
      expect(src.contains('يلزمه اسم المسؤول عن التنفيذ'), isFalse,
          reason: 'عاد إلزام المنفّذ: من يطلب من إدارةٍ أخرى لا يعرف '
              'اختصاصاتها، فإلزامه تخمينٌ باسم.');
      expect(src.contains("_assigneeUid.isEmpty)"), isFalse,
          reason: 'شرطٌ يفحص خلوّ المنفّذ قبل الإرسال — وهو صورة الإلزام.');
    });

    test('ويُقال له إن التكليف على مدير الإدارة', () {
      // الحقل الفارغ يُقرأ نسياناً ما لم يُقَل إنه مسارٌ مقصود.
      expect(_source(screen).contains('يكلّف مديرُ الإدارة'), isTrue);
    });
  });

  group('سطح ما ينتظر التكليف', () {
    // العدّ نفسه بحرفه كما في الشاشة: غير منجَز وبلا مُسنَدٍ إليه.
    int awaiting(List<WorkItem> all) =>
        all.where((WorkItem w) => !w.isDone && w.assigneeUid.isEmpty).length;

    test('يُعدّ ما بلا مُسنَدٍ إليه', () {
      final all = [
        _work(id: '1'),
        _work(id: '2', assigneeUid: 'u-a'),
        _work(id: '3'),
      ];
      expect(awaiting(all), 2);
    });

    test('ولا يعدّ المنجَز — فهو لا ينتظر أحداً', () {
      final all = [
        _work(id: '1'),
        _work(id: '2', status: TaskStatus.done),
      ];
      expect(awaiting(all), 1);
    });

    // من رُدّ عمله لعدم الاختصاص يعود بلا مُسنَدٍ إليه — وهو ينتظر تكليفاً
    // كالوارد سواءً. فالسطح يخدم الحالتين بلا زيادة.
    test('ويعدّ ما رُدّ لعدم الاختصاص كذلك', () {
      expect(awaiting([_work(id: '1', status: TaskStatus.todo)]), 1);
    });

    test('والمرشِّح يعرض «غير مُسنَد» ولا يُسقطه', () {
      final src = _source(screen);
      expect(src.contains('غير مُسنَد ('), isTrue,
          reason: 'خيار المرشِّح غائب — فلا سبيل للعثور على ما ينتظر.');
      expect(src.contains('ينتظر التكليف'), isTrue,
          reason: 'بطاقة العدّ غائبة.');
    });

    // ــ وانتقل الثابتُ إلى وحدة التصفية ــ
    //
    // `null` تعني الكل، و`''` تُشبه `assigneeUid` الفارغ — فكلاهما مصدر
    // التباس. والقيمة المختارة لا تصلح معرّفاً لأحد. وهذا لم يتغيّر.
    //
    // والذي تغيّر **موضعُه**: صار في `record_filter.dart` مع بقيّة قرار
    // التصفية، لأن ثلاث شاشاتٍ تصفّي الآن بوحدةٍ واحدة. ولو بقي في الشاشة
    // لَبقي للمنفّذ فلترانِ يفترقان — وهو العطل الذي جمعتها الوحدةُ لأجله.
    test('وقيمة الخيار ليست الفراغ فيلتبس بـ«كل المسؤولين»', () {
      expect(
        _source('lib/models/record_filter.dart')
            .contains("const String kUnassignedFilter = '__unassigned__';"),
        isTrue,
      );
      expect(_source(screen).contains('kUnassignedFilter'), isTrue,
          reason: 'والشاشةُ تستعمله — فلا يبقى الثابتُ بلا قارئ');
    });
  });

  group('التكليف عند الاعتماد', () {
    const center = 'lib/screens/decision_center_screen.dart';

    test('زرّ «اعتمد وكلّف» لمن يبتّ في طلب العمل', () {
      final src = _source(center);
      expect(src.contains('اعتمد وكلّف'), isTrue);
      // ويمرّ بالطريق نفسه: تجاوزٌ بمفتاحٍ واحد لا مسارُ اعتمادٍ ثانٍ.
      expect(src.contains("{'assigneeUid': uid}"), isTrue);
    });

    test('ولا يُرسل معه مفتاحٌ ثانٍ يوسّع التجاوز', () {
      final src = _source(center);
      // الخادم يردّ أي مفتاح سوى `assigneeUid` من غير مسؤول النظام. فلو
      // أرسلت الواجهة `assigneeName` معه لَسقط الاعتماد كلّه عند المدير —
      // ولظهر ذلك عطلاً لا حراسة.
      expect(src.contains("{'assigneeUid': uid, 'assigneeName'"), isFalse);
    });
  });
}
