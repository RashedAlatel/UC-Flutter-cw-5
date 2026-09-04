// أداة تحقّق: تطبيق يُسقط ودجته عمداً، لنرى ماذا يعرضه بناء **الإصدار** فعلاً.
//
// السؤال الذي تجيب عنه: هل يظهر للمستخدم نصّ يُقرأ، أم مستطيل صامت؟ الفرق
// حاسم — بناء التطوير يعرض النصّ دائماً فيخدع من يختبر به، وبناء الإصدار وحده
// يكشف ما يراه المستخدم.
//
//   flutter build web -t lib/dev/throw_probe_main.dart -o build/throwprobe \
//       --no-web-resources-cdn
import 'package:flutter/material.dart';

import '../boot_signal.dart';
import '../widgets/render_error_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => RenderErrorCard(message: details.exceptionAsString());
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    reportDartError(details.exceptionAsString());
  };
  runApp(const MaterialApp(home: _Boom()));
}

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) {
    signalStage('boom');
    WidgetsBinding.instance.addPostFrameCallback((_) => signalUiReady());
    throw StateError('عطل مُتعمَّد للتحقّق من ظهور الرسالة');
  }
}
