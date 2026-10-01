// بطاقةُ «المشاريع غير المكتملة» — **وهل تصل من خصّص لوحتَه؟**
//
// ــــ العطل الذي يُخشى، وهو صامتٌ تماماً ــــ
//
// `withKpiRow` تُضيف صفَّ المؤشّرات **مرّةً واحدة**: إن لم تكن علامةُ
// الترحيل مكتوبةً، وإن لم يكن في المحفوظ أيُّ مؤشّر.
//
// فمن خصّص لوحتَه وحفظها — وصاحبُ المنصّة منهم بالضرورة — لوحتُه فيها
// مؤشّراتٌ والعلامةُ مكتوبة. فبطاقةٌ تُضاف إلى `kpiDefaults()` وحدَها **لا
// تبلغه أبداً**: تُكتب الشيفرةُ ويُنشَر ولا يرى شيئاً، فيقول «طلبتُها ولم
// تأتِ» — ولا خطأَ في سجلٍّ ولا اختبارٌ أحمر.
//
// فعلامةٌ ثانيةٌ باسمها، على منوال الأولى ولسببها المكتوب فيها: **على
// المستند لا على قائمة الودجات**، فمن حذف البطاقةَ عمداً بعد ظهورها يبقى
// حذفُه ولا تعود تُصارعه في كلّ تحميل.
import 'package:flutter_test/flutter_test.dart';

import 'package:gov_exec_platform/models/dashboard_widget_config.dart';
import 'package:gov_exec_platform/models/enums.dart';

DashboardWidgetConfig _w(String id, DashboardWidgetType type) =>
    DashboardWidgetConfig(id: id, type: type);

/// لوحةٌ خصّصها صاحبُها: فيها مؤشّراتٌ وجداول، وعلامةُ الترحيل مكتوبة.
List<DashboardWidgetConfig> _customised() => [
      _w('a', DashboardWidgetType.kpiAvgProgress),
      _w('b', DashboardWidgetType.kpiProjectCount),
      _w('c', DashboardWidgetType.projectsTable),
      _w('d', DashboardWidgetType.statusPieChart),
    ];

bool _has(List<DashboardWidgetConfig> l, DashboardWidgetType t) =>
    l.any((w) => w.type == t);

void main() {
  group('البطاقةُ تبلغ من خصّص لوحتَه', () {
    test('لوحةٌ محفوظةٌ فيها مؤشّراتٌ تكسب البطاقة', () {
      final out = DashboardWidgetConfig.withIncompleteKpi(_customised(), added: false);
      expect(_has(out, DashboardWidgetType.kpiIncomplete), isTrue,
          reason: 'وهذا هو ما كان يسقط بصمتٍ لولا العلامة الثانية');
    });

    // ــ وفي موضعها بين المؤشّرات لا في آخر اللوحة ــ
    //
    // بطاقةُ مؤشّرٍ تقع تحت الجداول تُقرأ عطلاً لا ميزة.
    test('وتُدرَج بعد آخر مؤشّرٍ لا في الذيل', () {
      final out = DashboardWidgetConfig.withIncompleteKpi(_customised(), added: false);
      final i = out.indexWhere((w) => w.type == DashboardWidgetType.kpiIncomplete);
      final lastOtherKpi =
          out.lastIndexWhere((w) => w.type.isKpi && w.type != DashboardWidgetType.kpiIncomplete);
      final firstNonKpi = out.indexWhere((w) => !w.type.isKpi);
      expect(i, greaterThan(lastOtherKpi - 1));
      expect(i, lessThan(firstNonKpi), reason: 'قبل أوّل ما ليس مؤشّراً');
    });

    // ــ ومن حذفها عمداً لا تعود إليه ــ
    test('والعلامةُ المكتوبةُ تُحترَم', () {
      final out = DashboardWidgetConfig.withIncompleteKpi(_customised(), added: true);
      expect(_has(out, DashboardWidgetType.kpiIncomplete), isFalse);
    });

    test('ولا تُضاف مرّتين لمن عنده واحدةٌ أصلاً', () {
      final already = [..._customised(), _w('e', DashboardWidgetType.kpiIncomplete)];
      final out = DashboardWidgetConfig.withIncompleteKpi(already, added: false);
      expect(out.where((w) => w.type == DashboardWidgetType.kpiIncomplete), hasLength(1));
    });

    // ــ والقائمةُ الفارغةُ تبقى فارغة ــ
    //
    // الفراغُ يعني «هذه الطبقةُ لم تُضبط» فتتخطّاها `resolveLayers`. وحشوُها
    // ببطاقةٍ يجعل طبقةً غيرَ مضبوطةٍ تبدو مضبوطة — وهو نصُّ التحفّظ المكتوب
    // في `withKpiRow`.
    test('والفارغةُ تُعاد كما هي', () {
      expect(DashboardWidgetConfig.withIncompleteKpi(const [], added: false), isEmpty);
    });

    test('ولوحةٌ مبدئيّةٌ جديدةٌ فيها البطاقة', () {
      expect(_has(DashboardWidgetConfig.kpiDefaults(), DashboardWidgetType.kpiIncomplete), isTrue);
    });

    // ــ و`dedupe` تحميها بذاتها ــ
    test('وتكرارُها يُطوى عند التنظيف', () {
      final doubled = [
        _w('a', DashboardWidgetType.kpiIncomplete),
        _w('b', DashboardWidgetType.kpiIncomplete),
      ];
      expect(DashboardWidgetConfig.dedupe(doubled), hasLength(1));
    });
  });

  group('ونوعُها مؤشّرٌ بحكم اسمه', () {
    test('isKpi تقرؤها', () {
      expect(DashboardWidgetType.kpiIncomplete.isKpi, isTrue);
    });

    test('ولها تسميةٌ وأيقونة', () {
      expect(DashboardWidgetType.kpiIncomplete.label, contains('غير المكتملة'));
      expect(DashboardWidgetType.kpiIncomplete.icon, isNotNull);
    });
  });
}
