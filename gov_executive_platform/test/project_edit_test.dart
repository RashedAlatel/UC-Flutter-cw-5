// تعديلُ بيانات المشروع — الحقولُ، والفروق، والجوهريّ، والمرحلةُ الأولى.
//
// ــــ لماذا تُقاس هذه الأربعةُ وحدها ــــ
//
// لأن كلَّ واحدةٍ منها قرارُ حوكمةٍ لا عرض:
//
// * **قائمةُ الحقول** تقرّر ما يمرّ بالاعتماد. وحقلٌ يسقط منها يعود يُكتب
//   مباشرةً بلا أن يلحظه أحد.
// * **الفروق** هي ما يراه المعتمِد. وحقلٌ لم يتغيّر يُعرض فرقاً يُتعب العين
//   فيمرّ فيها ما لا يُقصد.
// * **الجوهريّ** هو ما يُميَّز له. وقيمةُ عقدٍ لا تُميَّز تمرّ كتصحيح وصف.
// * **والمرحلةُ الأولى** تقرّر من يعتمد. وخطأٌ فيها يجعل مديرَ الإدارة
//   يعتمد طلبَ نفسه.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/enums.dart';
import 'package:gov_exec_platform/models/project.dart';
import 'package:gov_exec_platform/models/project_edit.dart';

Project _project({
  String name = 'مشروع العدالة الرقمية',
  String description = 'وصفٌ قائم',
  PriorityLevel priority = PriorityLevel.medium,
  List<String> categoryIds = const [],
  DateTime? contractDate,
  double? contractValue,
  int? durationDays,
  String contractorName = '',
}) =>
    Project(
      id: 'p1',
      departmentId: 'd1',
      name: name,
      description: description,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      status: ProjectStatus.onTrack,
      priority: priority,
      progressPercent: 30,
      categoryIds: categoryIds,
      contractDate: contractDate,
      contractValue: contractValue,
      durationDays: durationDays,
      contractorName: contractorName,
    );

void main() {
  group('قائمةُ ما يمرّ بالاعتماد', () {
    test('أحدَ عشرَ حقلاً — هي التي عدّدتَها ممّا لا بوابةَ له', () {
      expect(kEditableProjectFields.length, 11);
      for (final f in [
        'name',
        'description',
        'priority',
        'categoryIds',
        'contractDate',
        'contractStartDate',
        'contractEndDate',
        'invoiceDueDate',
        'durationDays',
        'contractValue',
        'contractorName',
      ]) {
        expect(isEditableField(f), isTrue, reason: 'الحقل «$f»');
      }
    });

    // ما له بوابةٌ قائمة لا يمرّ من هنا: مسارُه الخاصّ لا يُختصر.
    test('والبواباتُ القائمة لا تمرّ من هذا الطلب', () {
      for (final f in ['dueDate', 'departmentId', 'managerUids', 'executorUids']) {
        expect(isEditableField(f), isFalse, reason: 'الحقل «$f»');
      }
    });

    // وما قرّرتَ إبقاءه مباشراً لا يمرّ كذلك.
    test('ولا القسمُ ولا أسماءُ المنفّذين — بقيا مباشرَين', () {
      expect(isEditableField('sectionId'), isFalse);
      expect(isEditableField('executorNames'), isFalse);
    });
  });

  group('والجوهريُّ يُميَّز', () {
    test('التسعةُ التي سمّيتَها جوهرية', () {
      for (final f in [
        'name',
        'departmentId',
        'managerUids',
        'startDate',
        'dueDate',
        'contractStartDate',
        'contractEndDate',
        'invoiceDueDate',
        'contractValue',
        'durationDays',
      ]) {
        expect(isSensitiveField(f), isTrue, reason: 'الحقل «$f»');
      }
    });

    // وتصحيحُ وصفٍ ليس كتغيير قيمة عقد — وإلا لم يعُد التمييزُ يميّز.
    test('وما ليس جوهرياً لا يُميَّز', () {
      expect(isSensitiveField('description'), isFalse);
      expect(isSensitiveField('priority'), isFalse);
      expect(isSensitiveField('categoryIds'), isFalse);
      expect(isSensitiveField('contractorName'), isFalse);
    });

    test('وتُعرف الحمولةُ الجوهرية من غيرها', () {
      final light = [
        const FieldChange(field: 'description', before: 'أ', after: 'ب'),
      ];
      final heavy = [
        const FieldChange(field: 'description', before: 'أ', after: 'ب'),
        const FieldChange(field: 'contractValue', before: 1, after: 2),
      ];
      expect(hasSensitiveChange(light), isFalse);
      expect(hasSensitiveChange(heavy), isTrue);
      expect(priorityForChanges(light), PriorityLevel.medium);
      expect(priorityForChanges(heavy), PriorityLevel.high);
    });
  });

  group('والفروقُ: المتغيّرُ وحده', () {
    test('حقلٌ تغيّر يُعرض، وما لم يتغيّر لا يُعرض', () {
      final changes = diffProjectFields(_project(), {
        'name': 'اسمٌ جديد',
        'description': 'وصفٌ قائم', // لم يتغيّر
      });
      expect(changes.map((c) => c.field), ['name']);
      expect(changes.single.before, 'مشروع العدالة الرقمية');
      expect(changes.single.after, 'اسمٌ جديد');
    });

    test('وما لم يُرسَل أصلاً لا يُعرض', () {
      final changes = diffProjectFields(_project(), {'name': 'اسمٌ جديد'});
      expect(changes.length, 1);
    });

    // من فتح النموذج وأغلقه لا يُنشئ طلباً بلا تغيير.
    test('ولا فرقَ بلا تغيير', () {
      expect(diffProjectFields(_project(), {}), isEmpty);
      expect(
        diffProjectFields(_project(), {
          'name': 'مشروع العدالة الرقمية',
          'description': 'وصفٌ قائم',
        }),
        isEmpty,
      );
    });

    // «غير مسجّل» ونصٌّ فارغ شيءٌ واحد — وإلا أنشأ كلُّ فتحٍ للنموذج طلباً.
    test('والفراغُ لا يُعدّ تغييراً عن «غير مسجّل»', () {
      expect(diffProjectFields(_project(), {'contractorName': ''}), isEmpty);
      expect(diffProjectFields(_project(), {'contractorName': '   '}), isEmpty);
    });

    test('وتشذيبُ الفراغ لا يُعدّ تغييراً', () {
      expect(
        diffProjectFields(_project(), {'name': '  مشروع العدالة الرقمية  '}),
        isEmpty,
      );
    });

    test('والقوائمُ تُقارن بعناصرها', () {
      expect(
        diffProjectFields(_project(categoryIds: ['a', 'b']), {
          'categoryIds': ['a', 'b'],
        }),
        isEmpty,
      );
      expect(
        diffProjectFields(_project(categoryIds: ['a']), {
          'categoryIds': ['a', 'b'],
        }).single.field,
        'categoryIds',
      );
    });

    test('والأرقامُ بقيمتها', () {
      expect(diffProjectFields(_project(contractValue: 5000), {'contractValue': 5000}),
          isEmpty);
      expect(
        diffProjectFields(_project(contractValue: 5000), {'contractValue': 7000})
            .single
            .field,
        'contractValue',
      );
    });

    // تسجيلُ قيمةٍ لم تكن مسجّلة تغييرٌ — و«غير مسجّل» ليست صفراً.
    test('وتسجيلُ ما لم يكن مسجّلاً تغيير', () {
      final changes = diffProjectFields(_project(), {'contractValue': 5000});
      expect(changes.single.before, isNull);
      expect(changes.single.after, 5000);
    });

    test('ومسحُ المسجَّل تغييرٌ كذلك', () {
      final changes = diffProjectFields(_project(contractValue: 5000), {
        'contractValue': null,
      });
      expect(changes.single.before, 5000);
      expect(changes.single.after, isNull);
    });

    // حقلٌ خارج القائمة لا يصير فرقاً ولو أُرسل.
    test('وحقلٌ خارج القائمة لا يُحسب فرقاً', () {
      expect(diffProjectFields(_project(), {'dueDate': '2030-01-01'}), isEmpty);
      expect(diffProjectFields(_project(), {'departmentId': 'd9'}), isEmpty);
    });

    test('والأولويةُ تُقارن باسمها', () {
      expect(
        diffProjectFields(_project(), {'priority': 'medium'}),
        isEmpty,
      );
      expect(
        diffProjectFields(_project(), {'priority': 'critical'}).single.after,
        'critical',
      );
    });
  });

  group('والمرحلةُ الأولى بحسب من يطلب', () {
    // لا يعتمد أحدٌ طلبَ نفسه.
    test('مديرُ الإدارة يبدأ عند مسؤول النظام', () {
      expect(firstStageFor(requesterIsDepartmentManager: true), EditStage.systemAdmin);
    });

    test('ومديرُ المشروع يبدأ عند مدير الإدارة', () {
      expect(
        firstStageFor(requesterIsDepartmentManager: false),
        EditStage.departmentManager,
      );
    });

    test('واسمُ المرحلة يُقرأ ويُكتب', () {
      expect(EditStage.fromName('systemAdmin'), EditStage.systemAdmin);
      expect(EditStage.fromName('departmentManager'), EditStage.departmentManager);
      // ومجهولٌ يُقرأ أطولَ المسارين لا أقصرَهما.
      expect(EditStage.fromName(null), EditStage.departmentManager);
      expect(EditStage.fromName('كلام'), EditStage.departmentManager);
    });
  });

  group('والأسماءُ تُقرأ', () {
    test('لكل حقلٍ اسمٌ عربي', () {
      for (final f in kEditableProjectFields) {
        expect(projectFieldLabel(f), isNot(f), reason: 'الحقل «$f» بلا اسم');
      }
    });

    // شذوذٌ يُرى لا يُخفى خلف ترجمةٍ مختلقة.
    test('ومجهولٌ يُعاد كما هو', () {
      expect(projectFieldLabel('حقلٌ غريب'), 'حقلٌ غريب');
    });

    test('ووصفُ التغييرات يُقرأ', () {
      expect(
        describeChanges([
          const FieldChange(field: 'name', before: 'أ', after: 'ب'),
          const FieldChange(field: 'contractValue', before: 1, after: 2),
        ]),
        'اسم المشروع، قيمة العقد',
      );
      expect(describeChanges(const []), 'لا تغييرات');
    });
  });
}
