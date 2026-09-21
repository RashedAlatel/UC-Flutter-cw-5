#!/usr/bin/env python3
"""يُصلح نقصاً في خط Tajawal يُفسد النص العربي في تقارير PDF المصدَّرة.

المشكلة
-------
حزمة `pdf` المستخدمة لتصدير التقارير لا تعتمد على تشكيل OpenType، بل تحوّل
النص العربي إلى "صيغ العرض العربية" (Arabic Presentation Forms-B، النطاق
U+FE70–U+FEFF) ثم تبحث عن كل صيغة في جدول cmap الخاص بالخط.

خط Tajawal كما يُوزَّع من Google Fonts يتضمن صيغ الحروف المتصلة (الأولية
والوسطى والنهائية) لكنه **يفتقد كل صيغ الحروف المنفصلة تقريباً** — منها
U+FEF1 (ياء منفصلة) وU+FEAD (راء منفصلة) وU+FEAF (زاي) وU+FE8D (ألف).

النتيجة أن أي كلمة تنتهي بحرف لا يتصل بما بعده كانت تفقد حرفها الأخير أو
تُرسم بحرف خاطئ في ملف PDF: "تقرير شهري" تُطبع "تقرير شهـو"، و"الملخص
التنفيذي" تُطبع "الملخص التنفيذه". لا يظهر هذا داخل التطبيق نفسه لأن Flutter
يستخدم تشكيل OpenType الحقيقي ولا يمر بصيغ العرض.

الحل
----
إضافة مدخلات cmap لكل صيغة عرض ناقصة تشير إلى مِحرف الحرف الأصلي الموجود
أصلاً في الخط (عبر تفكيك Unicode). بالنسبة للصيغ المنفصلة تحديداً يكون شكل
الحرف الأصلي هو الشكل المنفصل الصحيح، فالنتيجة سليمة طباعياً لا تقريبية.
التعديل إضافي بحت ولا يغيّر أي محرف موجود، ولا يؤثر على عرض التطبيق.

متى تُعيد تشغيله
----------------
عند تحديث ملفات الخط في assets/fonts/ من المصدر (Google Fonts)، لأن النسخة
الأصلية تعود بلا هذه المدخلات فتعود المشكلة صامتة.

الاستخدام:  python3 tool/patch_arabic_fonts.py
يتطلب:      pip install fonttools
"""

import glob
import os
import sys
import unicodedata

try:
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit('هذه الأداة تتطلب fonttools:  pip install fonttools')

FONTS_GLOB = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts', 'Tajawal-*.ttf')
PRESENTATION_FORMS = range(0xFE70, 0xFEFF)


def patch(path: str) -> int:
    font = TTFont(path)
    cmap = font.getBestCmap()

    pairs = []
    for code in PRESENTATION_FORMS:
        if code in cmap:
            continue
        decomposition = unicodedata.decomposition(chr(code))
        if not decomposition:
            continue  # لا مقابل أصلي (مثل U+FE73 ARABIC TAIL FRAGMENT)
        base = int(decomposition.split()[-1], 16)
        if base in cmap:
            pairs.append((code, cmap[base]))

    if not pairs:
        return 0

    for table in font['cmap'].tables:
        if not table.isUnicode():
            continue
        for code, glyph_name in pairs:
            table.cmap.setdefault(code, glyph_name)

    font.save(path)
    return len(pairs)


def main() -> None:
    paths = sorted(glob.glob(FONTS_GLOB))
    if not paths:
        sys.exit('لم يُعثر على ملفات الخط في assets/fonts/')
    for path in paths:
        count = patch(path)
        name = os.path.basename(path)
        print(f'{name}: أُضيفت {count} صيغة عرض ناقصة' if count else f'{name}: مكتمل أصلاً، لا تغيير')


if __name__ == '__main__':
    main()
