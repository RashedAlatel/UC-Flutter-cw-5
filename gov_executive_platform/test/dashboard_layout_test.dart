// عرض ودجات اللوحة، وترتيبها.
//
// أهم ما يُحرَس هنا: **تخطيطٌ محفوظ قبل وجود حقل العرض** يجب أن يُقرأ بلا
// كسر. مسؤول النظام ضبط لوحته وحفظها، ومستندات لوحات الأدوار مكتوبة في
// المنصة الحيّة — وقراءةٌ تفترض وجود الحقل تُفرغ اللوحة على من ضبطها.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';

void main() {
  group('العرض يُحفظ ويُقرأ', () {
    test('تخطيط قديم بلا حقل عرض يُقرأ بالقيمة المبدئية', () {
      final w = DashboardWidgetConfig.fromMap({
        'id': 'a',
        'type': DashboardWidgetType.projectsTable.name,
      });
      expect(w.width, DashboardWidgetWidth.half);
      expect(w.type, DashboardWidgetType.projectsTable);
    });

    test('والعرض المحفوظ يعود كما حُفظ', () {
      for (final width in DashboardWidgetWidth.values) {
        final original = DashboardWidgetConfig(
          id: 'a',
          type: DashboardWidgetType.deptBarChart,
          width: width,
        );
        expect(DashboardWidgetConfig.fromMap(original.toMap()).width, width);
      }
    });

    test('وعرض مجهول لا يُسقط القراءة', () {
      final w = DashboardWidgetConfig.fromMap({
        'id': 'a',
        'type': DashboardWidgetType.deptBarChart.name,
        'width': 'quarter',
      });
      expect(w.width, DashboardWidgetWidth.half);
    });

    test('copyWith يغيّر العرض ويبقي ما عداه', () {
      const w = DashboardWidgetConfig(id: 'a', type: DashboardWidgetType.statusPieChart);
      final wide = w.copyWith(width: DashboardWidgetWidth.full);
      expect(wide.width, DashboardWidgetWidth.full);
      expect(wide.id, 'a');
      expect(wide.type, DashboardWidgetType.statusPieChart);
    });
  });

  group('التخطيط الافتراضي', () {
    // جدول المشاريع بنصف عرض الشاشة لا تُقرأ أعمدته — وهو سبب وجود العرض أصلاً.
    test('جدول المشاريع يأخذ السطر كاملاً', () {
      final table = DashboardWidgetConfig.defaults()
          .firstWhere((w) => w.type == DashboardWidgetType.projectsTable);
      expect(table.width, DashboardWidgetWidth.full);
    });

    test('والعرض ينجو من التنظيف من التكرار', () {
      final cleaned = DashboardWidgetConfig.dedupe(DashboardWidgetConfig.defaults());
      final table = cleaned.firstWhere((w) => w.type == DashboardWidgetType.projectsTable);
      expect(table.width, DashboardWidgetWidth.full);
    });
  });

  // العرض كسرٌ من السطر لا عدد أعمدة من شبكة ثابتة. وبشبكة الأعمدة الثلاثة
  // كان النصف عمودين، فبطاقتان بنصف العرض تحتاجان أربعة أعمدة ولا تصطفّان —
  // وهو ما كشفته معاينة التصيير: نصفٌ وحده في سطر ونصف السطر فارغ.
  group('العرض كسرٌ من السطر', () {
    test('عدد البطاقات التي تملأ السطر', () {
      expect(DashboardWidgetWidth.third.denominator, 3);
      expect(DashboardWidgetWidth.half.denominator, 2);
      expect(DashboardWidgetWidth.full.denominator, 1);
    });

    test('بطاقتان بنصف العرض تملآن السطر تماماً', () {
      const total = 1200.0;
      const spacing = 18.0;
      double widthFor(DashboardWidgetWidth w) =>
          (total - spacing * (w.denominator - 1)) / w.denominator;

      final half = widthFor(DashboardWidgetWidth.half);
      expect(half * 2 + spacing, closeTo(total, 0.001));

      final third = widthFor(DashboardWidgetWidth.third);
      expect(third * 3 + spacing * 2, closeTo(total, 0.001));

      expect(widthFor(DashboardWidgetWidth.full), closeTo(total, 0.001));
    });
  });
}
