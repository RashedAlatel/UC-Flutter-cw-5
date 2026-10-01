// مرفقات التحديث اليومي: القراءة والكتابة، والنوعان معاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:gov_exec_platform/models/attachment.dart';
import 'package:gov_exec_platform/utils/safe_file_name.dart';

void main() {
  group('حفظ المرفق وقراءته', () {
    test('الملف المرفوع يعود كما حُفظ', () {
      const a = Attachment(
        name: 'تقرير الإنجاز.pdf',
        url: 'https://storage.example/x',
        kind: AttachmentKind.upload,
        contentType: 'application/pdf',
        sizeBytes: 2048,
        storagePath: 'projects/p1/dailyUpdates/x.pdf',
      );
      final back = Attachment.fromMap(a.toMap());
      expect(back.name, a.name);
      expect(back.kind, AttachmentKind.upload);
      expect(back.storagePath, a.storagePath);
      expect(back.sizeBytes, 2048);
    });

    test('والرابط الخارجي كذلك، وبلا مسار تخزين', () {
      const a = Attachment(
        name: 'جدول المتابعة',
        url: 'https://sharepoint.example/doc',
        kind: AttachmentKind.link,
      );
      final map = a.toMap();
      expect(map.containsKey('storagePath'), isFalse,
          reason: 'الرابط لا تملك المنصة ملفه فلا مسار له');
      expect(Attachment.fromMap(map).kind, AttachmentKind.link);
    });

    // تحديثات كُتبت قبل وجود المرفقات أصلاً.
    test('حقل غائب أو تالف يُقرأ قائمةً فارغة لا خطأً', () {
      expect(Attachment.listFrom(null), isEmpty);
      expect(Attachment.listFrom('nonsense'), isEmpty);
      expect(Attachment.listFrom([1, 'x']), isEmpty);
    });

    test('وقائمة مختلطة تُقرأ ما يصح منها', () {
      final list = Attachment.listFrom([
        {'name': 'أ', 'url': 'https://a', 'kind': 'link'},
        'مهملات',
      ]);
      expect(list.length, 1);
      expect(list.first.name, 'أ');
    });
  });

  group('ما يُعرض للمستخدم', () {
    test('الحجم بالعربية، والصفر لا يُعرض حجماً كاذباً', () {
      expect(const Attachment(name: 'a', url: 'u', kind: AttachmentKind.link).readableSize, '');
      expect(
        const Attachment(name: 'a', url: 'u', kind: AttachmentKind.upload, sizeBytes: 500).readableSize,
        '500 بايت',
      );
      expect(
        const Attachment(name: 'a', url: 'u', kind: AttachmentKind.upload, sizeBytes: 2 * 1024 * 1024)
            .readableSize,
        '2.0 م.ب',
      );
    });

    test('النوع يُستنتج من الاسم أو من نوع المحتوى', () {
      String t(String name, [String ct = '']) =>
          Attachment(name: name, url: 'u', kind: AttachmentKind.upload, contentType: ct).typeLabel;
      expect(t('تقرير.pdf'), 'PDF');
      expect(t('جدول.xlsx'), 'إكسل');
      expect(t('مذكرة.docx'), 'وورد');
      expect(t('لقطة.png'), 'صورة');
      expect(t('بلا امتداد'), 'ملف');
      expect(t('بلا امتداد', 'image/jpeg'), 'صورة');
    });
  });

  // اسم المرفق يصير جزءاً من مسار التخزين. والأسماء العربية تُسقط الامتداد
  // في Chromium عند التنزيل — درسٌ كلّفنا جولة كاملة في تصدير التقارير.
  test('اسم عربي يُنقّى قبل أن يصير مساراً، ويبقى امتداده', () {
    final clean = safeFileName('تقرير الإنجاز اليومي.pdf', fallbackBase: 'attachment');
    expect(clean.endsWith('.pdf'), isTrue);
    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(clean), isTrue);
  });
}
