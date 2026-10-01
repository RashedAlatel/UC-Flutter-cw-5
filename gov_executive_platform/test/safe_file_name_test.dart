import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/utils/safe_file_name.dart';

void main() {
  // كل اختبار هنا يحرس عطلاً وقع فعلاً: اسم التقرير كان عربياً، فأسقط كروم
  // الاسم **والامتداد معاً** وحفظ الملف باسم `download`، فلم يفتحه أي عارض
  // وبدا للمستخدم أن زر التصدير لا يفعل شيئاً.
  test('الاسم العربي يصير لاتينياً مع بقاء الامتداد', () {
    expect(safeFileName('تقرير_monthly_2026-08-19.pdf'), 'monthly_2026-08-19.pdf');
    expect(safeFileName('تقرير.pdf'), 'report.pdf');
  });

  test('الامتداد لا يضيع أبداً — وهو بيت القصيد', () {
    for (final name in ['تقرير.pdf', 'ملف عربي.xlsx', 'a.pdf', '٢٠٢٦.pdf']) {
      expect(safeFileName(name), endsWith('.${name.split('.').last}'),
          reason: 'ضاع الامتداد في «$name» فلن يفتح الملف');
    }
  });

  test('الاسم اللاتيني السليم يمرّ كما هو', () {
    expect(safeFileName('MOJ-report-monthly-2026-08-19.pdf'),
        'MOJ-report-monthly-2026-08-19.pdf');
    expect(safeFileName('weekly_2026-08-19.pdf'), 'weekly_2026-08-19.pdf');
  });

  test('المسافات والرموز الخطرة تُستبدل ولا تتكرّر الشرطات', () {
    expect(safeFileName('تقرير الوزارة/2026 «نهائي».pdf'), '2026.pdf');
    expect(safeFileName('a  b//c.pdf'), 'a-b-c.pdf');
  });

  test('اسم بلا امتداد يبقى بلا امتداد ولا يُخترع له واحد', () {
    expect(safeFileName('README'), 'README');
    expect(safeFileName('تقرير'), 'report');
  });
}
