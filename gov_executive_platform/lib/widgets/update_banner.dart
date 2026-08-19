import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../build_stamp.dart';
export '../build_stamp.dart' show kBuildStamp;

import '../theme/app_theme.dart';



/// شريط يظهر حين يُنشر إصدار أحدث بينما المستخدم ما زال على القديم.
///
/// المتصفحات — وسفاري خاصةً — قد تُبقي المستخدم على نسخة مخزّنة دون أن يدري.
/// هذا الشريط يجلب `build.json` بمُبطِّل تخزين، فإن اختلفت بصمته عن البصمة
/// المحمَّلة عرض دعوة صريحة لإعادة التحميل بدل بقاء المستخدم على نسخة قديمة
/// صامتاً.
class UpdateBanner extends StatefulWidget {
  /// الهامش الأفقي، يطابق هوامش بقية أشرطة الصفحة.
  final double horizontalPadding;

  const UpdateBanner({super.key, this.horizontalPadding = 24});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  Timer? _timer;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    // على الويب فقط: لا معنى للفحص خارج المتصفح.
    if (!kIsWeb) return;
    _check();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_updateAvailable) return;
    try {
      // مُبطِّل التخزين ضروري: بدونه قد يُعيد المتصفح نسخة build.json
      // المخزّنة فلا يُكتشف التحديث أبداً.
      final url = Uri.parse('build.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(url, headers: {'Cache-Control': 'no-cache'});
      if (res.statusCode != 200) return;
      final stamp = (jsonDecode(res.body) as Map)['stamp'] as String?;
      if (stamp == null || stamp == kBuildStamp) return;
      if (!mounted) return;
      setState(() => _updateAvailable = true);
    } catch (_) {
      // انقطاع مؤقت أو ملف غير منشور: لا نُزعج المستخدم برسالة خطأ.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_updateAvailable) return const SizedBox.shrink();
    // الشريط يحمل هوامشه بنفسه (بما فيها العلوية) ليُعرض دائماً في الشجرة
    // ويُخفي نفسه حين لا يوجد تحديث، دون أن يترك فراغاً أعلى كل صفحة.
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.horizontalPadding, 14, widget.horizontalPadding, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: AppColors.info, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'يتوفر إصدار أحدث من المنصة. أعد التحميل للحصول عليه.',
                style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            TextButton.icon(
              onPressed: _reloadPage,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة التحميل'),
            ),
          ],
        ),
      ),
    );
  }
}

/// إعادة تحميل الصفحة كاملةً لجلب الإصدار الجديد.
///
/// نضيف مُبطِّل تخزين إلى العنوان بدل reload() المجرّد، لأن سفاري قد يُعيد
/// تقديم المستند المخزّن نفسه عند إعادة التحميل العادية.
void _reloadPage() {
  if (!kIsWeb) return;
  final base = Uri.base;
  final params = Map<String, String>.of(base.queryParameters)
    ..['v'] = DateTime.now().millisecondsSinceEpoch.toString();
  web.window.location.href = base.replace(queryParameters: params).toString();
}
