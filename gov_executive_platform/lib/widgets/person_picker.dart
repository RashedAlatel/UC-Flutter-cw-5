import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_theme.dart';

/// ــــ توحيد النص العربي قبل المطابقة ــــ
///
/// «أحمد» و«احمد» و«آحمد» ثلاث كتابات لاسمٍ واحد، والمطابقة الحرفية تجعل من
/// يكتب الهمزة خطأً لا يجد زميله. وهذا ليس تحسيناً تجميلياً في وزارةٍ فيها
/// مئتا موظف: من لا يجد الاسم يكتبه يدوياً، فتتراكم أسماءٌ حرّة لا ترتبط
/// بحساب، وتنكسر بها كل تقارير «من عليه أكثر المشاريع».
///
/// فتُوحَّد صور الألف والياء والتاء المربوطة، وتُحذف التشكيل والتطويل.
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        buffer.write('ا');
      case 'ى':
        buffer.write('ي');
      case 'ة':
        buffer.write('ه');
      case 'ؤ':
        buffer.write('و');
      case 'ئ':
        buffer.write('ي');
      // التطويل والتشكيل: لا يحملان معنىً في البحث.
      case 'ـ':
      case 'ً': // تنوين فتح
      case 'ٌ':
      case 'ٍ':
      case 'َ': // فتحة
      case 'ُ':
      case 'ِ':
      case 'ّ': // شدّة
      case 'ْ': // سكون
        break;
      default:
        buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// هل يطابق المستخدم نصّ البحث؟ يُبحث بالاسم والبريد والهاتف واسم الإدارة.
bool personMatches(AppUser user, String query, {String? departmentName}) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return true;
  final haystack = normalizeArabic(
    '${user.name} ${user.email} ${user.phone} ${departmentName ?? ''}',
  );
  return haystack.contains(q);
}

/// منتقي أشخاص بالبحث: يُكتب جزءٌ من الاسم فتظهر النتائج أثناء الكتابة.
///
/// ــــ لماذا لا قائمة منسدلة؟ ــــ
///
/// لأن القائمة المنسدلة تعرض مئتي اسم بالترتيب الأبجدي، فمن يبحث عن زميله
/// يُمرّر عشرات الشاشات. وهذا ما اشتُكي منه حرفياً عند إضافة مشروع.
///
/// و[selected] تُعدَّل في مكانها ثم يُنادى [onChanged] — وهو العقد نفسه الذي
/// كان عليه المنتقي السابق، فلم تتبدّل الشاشات المستعملة له.
class PersonPicker extends StatefulWidget {
  final String label;
  final String hint;

  /// المرشَّحون — يُصفّيهم المستدعي بالدور والحالة والإدارة قبل تمريرهم.
  final List<AppUser> candidates;

  /// اسم إدارة كل مستخدم، ليُبحث بها كذلك.
  final String Function(AppUser) departmentNameOf;

  final Set<String> selected;
  final VoidCallback onChanged;

  const PersonPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.candidates,
    required this.departmentNameOf,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  final TextEditingController _query = TextEditingController();

  /// أكثر ما يُعرض دفعةً واحدة. ومئتا اسم في صندوقٍ واحد ليست «نتيجة بحث»
  /// بل القائمة كلها من جديد.
  static const int _maxShown = 25;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(AppUser user) {
    setState(() {
      if (!widget.selected.remove(user.id)) widget.selected.add(user.id);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.candidates
        .where((u) => personMatches(u, _query.text, departmentName: widget.departmentNameOf(u)))
        .toList();
    final shown = matches.take(_maxShown).toList();
    final hidden = matches.length - shown.length;

    // المختارون فوق النتائج دائماً: من اختار خمسةً ثم بحث عن السادس يجب أن
    // يرى اختياره باقياً، وإلا ظنّ أن البحث ألغاه.
    final chosen = widget.candidates.where((u) => widget.selected.contains(u.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        Text(widget.hint, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6)),
        const SizedBox(height: 6),
        if (chosen.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final u in chosen)
                InputChip(
                  label: Text(u.name, style: const TextStyle(fontSize: 11.5)),
                  onDeleted: () => _toggle(u),
                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            hintText: 'ابحث بالاسم أو البريد أو الإدارة',
            hintStyle: const TextStyle(fontSize: 12),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    tooltip: 'مسح البحث',
                    onPressed: () => setState(_query.clear),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 190),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: matches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'لا أحد يطابق «${_query.text.trim()}» — جرّب جزءاً من الاسم أو اسم الإدارة.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final u in shown)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                          value: widget.selected.contains(u.id),
                          title: Text(u.name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          // الإدارة تحت الاسم: في وزارةٍ فيها متشابهو الأسماء
                          // لا يُميَّز «محمد العتيبي» عن «محمد العتيبي» إلا بها.
                          subtitle: Text(
                            widget.departmentNameOf(u),
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (_) => _toggle(u),
                        ),
                      if (hidden > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                          child: Text(
                            'و$hidden غيرهم يطابقون — تابع الكتابة لتضييق النتائج.',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
