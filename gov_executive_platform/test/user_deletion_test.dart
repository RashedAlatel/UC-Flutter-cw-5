// حذف الحساب — الجانب الذي في العميل.
//
// المنعُ والحذفُ كلاهما على الخادم ويُحرسان هناك (قاعدة `/users` على
// المحاكي، وحارس البوابات على الدالّة). فما يبقى للعميل شيءٌ واحد وهو
// خطِر بقدره: **قراءة الإحصاء**.
//
// وخطرُه أن يُقرأ خطأً فيُعرض «لا شيء على هذا الحساب» لحسابٍ يقود خمسة
// مشاريع — فيضغط مسؤول النظام «احذف» وهو مطمئن. وحقلٌ يُقرأ باسمٍ خطأ
// يعطي صفراً بلا خطأ ولا تحذير.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/user_deletion_report.dart';

void main() {
  group('قراءة إحصاء الحذف', () {
    test('الأعداد والأسماء تُقرأ كما كُتبت', () {
      final r = UserDeletionReport.fromMap(const {
        'ledProjects': [
          {'id': 'p1', 'name': 'مشروع الرقمنة'},
          {'id': 'p2', 'name': 'مشروع الأرشفة'},
        ],
        'memberProjects': 4,
        'openWorks': [
          {'id': 'w1', 'title': 'تقرير شهري'},
        ],
        'openTasks': 3,
        'dailyUpdates': 27,
        'pendingRequests': 1,
        'blockingReason': 'يقود مشروعين',
      });
      expect(r.ledProjects.map((p) => p.label), ['مشروع الرقمنة', 'مشروع الأرشفة']);
      expect(r.memberProjects, 4);
      expect(r.openWorks.single.label, 'تقرير شهري');
      expect(r.openTasks, 3);
      expect(r.dailyUpdates, 27);
      expect(r.pendingRequests, 1);
    });

    // سببُ المنع يأتي من الخادم ولا يُصاغ هنا: هو نفسه النصّ الذي سيُرفض به
    // الحذف لو جُرِّب، فلا تَعِد الشاشةُ بشيءٍ ثم يُرفض بغيره.
    test('ووجودُ سببِ منعٍ يُغلق الحذف', () {
      final r = UserDeletionReport.fromMap(const {'blockingReason': 'يقود مشروعاً'});
      expect(r.canDelete, isFalse);
      expect(r.blockingReason, 'يقود مشروعاً');
    });

    test('وغيابُه يفتحه', () {
      final r = UserDeletionReport.fromMap(const {'blockingReason': null});
      expect(r.canDelete, isTrue);
    });

    // حسابٌ بلا أثر يُحذف بلا قلق، وحسابٌ بأثرٍ الأولى إيقافه — وهذا ما
    // يقرّر ظهور التحذير.
    test('وسجلُّ العمل يُقاس بما بقي منه لا بما يمنع الحذف', () {
      final noHistory = UserDeletionReport.fromMap(const {});
      expect(noHistory.hasHistory, isFalse);

      // تحديثاتٌ يومية وحدها: لا تمنع الحذف — هي سجلّ الوزارة ولا تُحذف —
      // لكنها أثرٌ يستحق أن يُنبَّه إليه.
      final updatesOnly = UserDeletionReport.fromMap(const {'dailyUpdates': 12});
      expect(updatesOnly.canDelete, isTrue);
      expect(updatesOnly.hasHistory, isTrue);
    });

    test('ومستندٌ ناقص يُقرأ أصفاراً بلا انهيار', () {
      final r = UserDeletionReport.fromMap(const {});
      expect(r.ledProjects, isEmpty);
      expect(r.openWorks, isEmpty);
      expect(r.memberProjects, 0);
      expect(r.canDelete, isTrue);
    });
  });
}
