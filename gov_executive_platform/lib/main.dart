import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'firebase_options.dart';
import 'models/enums.dart';
import 'screens/login_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تهيئة Firebase قد تفشل على الويب إذا تعذّر تحميل حزم Firebase من
  // www.gstatic.com (شبكة تحجب النطاق، انقطاع مؤقت، أو وكيل مؤسسي). بدون
  // هذا الالتقاط يتوقف الإقلاع فتظهر للمستخدم **صفحة بيضاء فارغة بلا أي
  // رسالة** — وهو أسوأ شكل للعطل لأنه لا يدل على سببه. نعرض بدلاً منها
  // شاشة خطأ عربية واضحة بزر إعادة محاولة.
  //
  // المهلة ضرورية ولا يكفي try/catch وحده: عند حجب النطاق لا ترمي التهيئة
  // استثناءً بل **تتعلّق بلا نهاية** (وعد JavaScript لا يُحسم)، فينتظر
  // التطبيق للأبد ولا يُرسم شيء إطلاقاً.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    runApp(StartupErrorApp(details: e.toString()));
    return;
  }
  runApp(const GovExecutivePlatformApp());
}

/// شاشة تُعرض حين يتعذّر الاتصال بخدمات المنصة عند الإقلاع، بدل الشاشة
/// البيضاء الصامتة.
class StartupErrorApp extends StatelessWidget {
  final String details;
  const StartupErrorApp({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وزارة العدل — المنصة التنفيذية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.danger),
                      const SizedBox(height: 18),
                      const Text('تعذّر الاتصال بخدمات المنصة',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      const Text(
                        'لم يتمكن المتصفح من تحميل خدمات المنصة. تأكد من اتصال الشبكة، '
                        'وإن كنت داخل شبكة الوزارة فقد يكون الوصول إلى نطاق '
                        'www.gstatic.com محجوباً — يلزم السماح به لتشغيل المنصة.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.8),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('تفاصيل تقنية', style: TextStyle(fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(details,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// إعادة تحميل الصفحة على الويب. نستدعيها عبر `main()` نفسه بدل استيراد
/// `dart:html` (المهجور) أو إضافة حزمة جديدة: إعادة تشغيل التطبيق تكفي هنا
/// لأن الفشل يقع في التهيئة لا في حالة محفوظة.
void _reload() {
  if (kIsWeb) {
    // إعادة تشغيل الإقلاع: أبسط وأضمن من التلاعب بـ window.location عبر
    // interop، ويؤدي الغرض نفسه (إعادة محاولة الاتصال بخدمات المنصة).
    main();
  }
}

class GovExecutivePlatformApp extends StatelessWidget {
  const GovExecutivePlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore()..init(),
      // نستخدم Consumer هنا (بدل قراءة AppTheme.theme مرة واحدة) لأن ألوان
      // الهوية (primary/accent) قابلة للتخصيص من مسؤول النظام في أي وقت
      // (راجع AppColors.applyBrand)، فيجب إعادة بناء الثيم عند أي تغيير.
      child: Consumer<AppStore>(
        builder: (context, store, _) => MaterialApp(
          title: 'وزارة العدل — المنصة التنفيذية',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const _RootGate(),
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.ready) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final user = store.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    if (user.status != UserStatus.approved) {
      return const PendingApprovalScreen();
    }
    return const AppShell();
  }
}
