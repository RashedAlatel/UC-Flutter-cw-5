// الطلب الواحد لا يصير طلبين.
//
// ــــ ما وقع فعلاً ــــ
//
// ظهر كلُّ مشروعٍ يُطلَب **مرّتين** في مركز القرارات. وليس تكراراً في العرض:
// قائمة الطلبات تُدمج بالمعرّف (`mergeById`) فلا يمرّ منها معرّفٌ مرّتين،
// ومركز القرارات يعرضها في `map` واحدة. فالبطاقتان مستندان حقيقيّان.
//
// وكُتبا لأن كتابة الطلب نجحت ثم ارتفع خطأٌ بعدها (سطرُ سجل التدقيق كان
// مردوداً)، فجمدت النافذة على دوّارة بلا رسالة — فأعاد صاحبها المحاولة
// ظانّاً أنها فشلت.
//
// والنافذة أُصلحت. لكنّ ذلك وحده لا يكفي: أيُّ فشلٍ لاحق — شبكةٍ أو صلاحية —
// يُنتج السلوك نفسه. فالمنعُ هنا، **أيّاً كان سببُ الضغطة الثانية**.
//
// ــــ وما يُقاس ــــ
//
// أن المطابقة تُصيب المكرّر، و**تُخطئ ما ليس مكرّراً**. والثاني أهمّ: حارسٌ
// يمنع طلباتٍ مشروعة أسوأ من غيابه — يوقف عمل الوزارة ولا يُعرف سببه.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/data/app_store.dart';
import 'package:gov_exec_platform/models/approval_request.dart';
import 'package:gov_exec_platform/models/enums.dart';

const _dept = 'd-1';
const _me = 'u-1';
const _title = 'طلب إضافة مشروع جديد: رقمنة الأرشيف';

ApprovalRequest _request({
  ApprovalType type = ApprovalType.projectCreate,
  DecisionStatus status = DecisionStatus.pending,
  String? departmentId = _dept,
  String title = _title,
  String requestedByUid = _me,
}) =>
    ApprovalRequest(
      id: 'r1',
      type: type,
      status: status,
      title: title,
      description: 'وصف',
      priority: PriorityLevel.medium,
      delayImpactDays: 0,
      departmentId: departmentId,
      requestedByUid: requestedByUid,
      requestedByName: 'مستخدم',
      requestedDate: DateTime(2026, 8, 26),
    );

/// يبحث في قائمةٍ فيها [existing] عن طلبٍ مطابقٍ للحالة الأساسية.
ApprovalRequest? _find(List<ApprovalRequest> existing) => AppStore.findDuplicatePending(
      existing: existing,
      type: ApprovalType.projectCreate,
      departmentId: _dept,
      title: _title,
      requestedByUid: _me,
    );

void main() {
  group('المكرّر يُصاب', () {
    test('طلبٌ مطابقٌ ينتظر البتّ', () {
      expect(_find([_request()]), isNotNull);
    });

    // مسافةٌ زائدة ليست طلباً آخر: من أعاد الكتابة قد يزيدها بلا قصد.
    //
    // والطرفان يُشذَّبان لا طرفٌ واحد — وطفرةٌ تُشذّب المخزَّن وحده مرّت على
    // هذا الاختبار وحده أوّل مرّة، فأُضيف نظيرُه المقابل.
    test('ولو حملت النسخة المخزَّنة مسافاتٍ زائدة', () {
      expect(_find([_request(title: '  $_title  ')]), isNotNull);
    });

    test('ولو حملها الطلب الجديد', () {
      final found = AppStore.findDuplicatePending(
        existing: [_request()],
        type: ApprovalType.projectCreate,
        departmentId: _dept,
        title: '  $_title  ',
        requestedByUid: _me,
      );
      expect(found, isNotNull);
    });

    test('ويُصاب ولو كان بين طلباتٍ أخرى', () {
      expect(
        _find([
          _request(title: 'طلبٌ آخر'),
          _request(),
          _request(departmentId: 'd-9'),
        ]),
        isNotNull,
      );
    });
  });

  group('وما ليس مكرّراً يمرّ', () {
    test('قائمةٌ فارغة', () {
      expect(_find([]), isNull);
    });

    // (١) الحالة: طلبٌ رُفض ثم أُعيد بعد التصحيح طلبٌ مشروع.
    test('طلبٌ مطابقٌ لكنه مرفوض', () {
      expect(_find([_request(status: DecisionStatus.rejected)]), isNull);
    });

    test('وطلبٌ مطابقٌ لكنه اعتُمد', () {
      expect(_find([_request(status: DecisionStatus.approved)]), isNull);
    });

    // (٢) النوع: طلبُ مشروعٍ وطلبُ عملٍ بالاسم نفسه شيئان.
    test('ونوعٌ آخر بالعنوان نفسه', () {
      expect(_find([_request(type: ApprovalType.workCreate)]), isNull);
    });

    // (٣) الإدارة: «رقمنة الأرشيف» في إدارتين مبادرتان لا واحدة.
    test('وإدارةٌ أخرى', () {
      expect(_find([_request(departmentId: 'd-9')]), isNull);
    });

    test('وطلبٌ بلا إدارة ليس مطابقاً لطلبٍ له إدارة', () {
      expect(_find([_request(departmentId: null)]), isNull);
    });

    // (٤) مقدّم الطلب: موظفان يطلبان الشيء نفسه أمرٌ يراه مسؤول النظام
    //     ويقرّر — ولا يُخفى عنه أحدهما.
    test('ومقدّمٌ آخر', () {
      expect(_find([_request(requestedByUid: 'u-9')]), isNull);
    });

    // (٥) العنوان: مشروعان مختلفان في الإدارة نفسها.
    test('وعنوانٌ آخر', () {
      expect(_find([_request(title: 'طلب إضافة مشروع جديد: شيءٌ آخر')]), isNull);
    });
  });

  group('وطلبات الأعمال والمواعيد تمرّ بالقاعدة نفسها', () {
    test('عملٌ مكرّرٌ يُصاب', () {
      final found = AppStore.findDuplicatePending(
        existing: [_request(type: ApprovalType.workCreate, title: 'طلب إضافة عمل جديد: جرد')],
        type: ApprovalType.workCreate,
        departmentId: _dept,
        title: 'طلب إضافة عمل جديد: جرد',
        requestedByUid: _me,
      );
      expect(found, isNotNull);
    });

    test('وموعدٌ نهائيٌّ مكرّرٌ يُصاب', () {
      final found = AppStore.findDuplicatePending(
        existing: [
          _request(type: ApprovalType.deadlineChange, title: 'طلب تعديل الموعد النهائي: س'),
        ],
        type: ApprovalType.deadlineChange,
        departmentId: _dept,
        title: 'طلب تعديل الموعد النهائي: س',
        requestedByUid: _me,
      );
      expect(found, isNotNull);
    });
  });
}
