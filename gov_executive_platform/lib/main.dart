import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'boot_signal.dart';
import 'widgets/render_error_card.dart';
import 'data/app_store.dart';
import 'firebase_options.dart';
import 'models/enums.dart';
import 'screens/login_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'screens/preparing_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorReporting();
  // كل مسار يُعلن نفسه، فلا يبقى صفّ «المرحلة» في صفحة الفحص فارغاً على تطبيق
  // يعمل — وصفٌّ فارغ يعني «لم يبلغ Dart أصلاً»، وهذا معنى يجب ألا يلتبس.
  signalStage('booting');
  // تهيئة Firebase قد تفشل على الويب إذا تعذّر تحميل حزم Firebase من
  // www.gstatic.com (شبكة تحجب النطاق، انقطاع مؤقت، أو وكيل مؤسسي). بدون
  // هذا الالتقاط يتوقف الإقلاع فتظهر للمستخدم **صفحة بيضاء فارغة بلا أي
  // رسالة** — وهو أسوأ شكل للعطل لأنه لا يدل على سببه. نعرض بدلاً منها
  // شاشة خطأ عربية واضحة بزر إعادة محاولة.
  //
  // المهلة ضرورية ولا يكفي try/catch وحده: عند حجب النطاق لا ترمي التهيئة
  // استثناءً بل **تتعلّق بلا نهاية** (وعد JavaScript لا يُحسم)، فينتظر
  // التطبيق للأبد ولا يُرسم شيء إطلاقاً.
  //
  // المهلة ثماني ثوانٍ: كانت عشرين ثم اثنتي عشرة. تسجيل شاشة من جوال المستخدم
  // أظهر أنه يغلق الصفحة قبل الثانية الثلاثين، فأي مهلة أطول من صبره لا قيمة
  // لها — الأفضل أن يرى سبب العطل مبكراً على أن ينتظر ما لا يراه.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    signalStage('startup-error');
    runApp(StartupErrorApp(details: e.toString()));
    // شاشة الخطأ واجهة حقيقية أيضاً، فترفع شاشة الإقلاع عنها. بدون هذا السطر
    // تبقى شاشة الإقلاع فوقها (صارت في أعلى طبقة) فيُحجب الخطأ عن المستخدم —
    // وهو أسوأ من العطل نفسه.
    WidgetsBinding.instance.addPostFrameCallback((_) => signalUiReady());
    return;
  }
  runApp(const GovExecutivePlatformApp());
}

/// يجعل أخطاء Dart مرئية بدل أن تبقى في الطرفية وحدها.
///
/// على الجوال لا طرفية يفتحها المستخدم، فاستثناء يقع في Dart كان يضيع تماماً:
/// إن وقع أثناء البناء رسم Flutter مستطيلاً صامتاً (نصّ `ErrorWidget` لا يظهر
/// في بناء الإصدار)، وإن وقع خارجه لم يظهر شيء أصلاً. فكل ما يصل إلينا من
/// المستخدم "المنصة لا تفتح" — بلا سبب يُشخَّص. هنا يُغلق هذا الباب من ثلاث
/// جهات: بطاقة خطأ مقروءة بدل المستطيل، وتمرير النصّ إلى شاشة الإقلاع في
/// الصفحة، مع إبقاء الطباعة الافتراضية كما هي لمن يفتح الطرفية.
void _installErrorReporting() {
  ErrorWidget.builder = (FlutterErrorDetails details) => RenderErrorCard(
        message: details.exceptionAsString(),
        onRetry: kIsWeb ? _reload : null,
      );

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousOnError?.call(details);
    reportDartError(details.exceptionAsString());
  };

  // أخطاء غير متزامنة لا تمرّ بـFlutterError إطلاقاً. `false` تعني أننا
  // أبلغنا عنها ولم نبتلعها، فيبقى سلوك المنصة الافتراضي كما هو.
  PlatformDispatcher.instance.onError = (error, stack) {
    reportDartError(error.toString());
    return false;
  };
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

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  @override
  void initState() {
    super.initState();
    // إخفاء شاشة الإقلاع HTML بعد أول إطار **مرسوم فعلاً** من التطبيق.
    // نُرسل الإشارة من هنا لا من حدث المحرك، لأن هذا الموضع يعني أن شجرة
    // الودجات بُنيت وأن المستخدم يرى شيئاً — سواء كانت شاشة الانتظار أو
    // الدخول أو المنصة نفسها.
    WidgetsBinding.instance.addPostFrameCallback((_) => signalUiReady());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // إعلان المرحلة في كل بناء: حين تظهر شاشة صمّاء على جهاز لا نملكه، هذه
    // الكلمة الواحدة تحسم أين وقف التطبيق — راجع lib/boot_signal.dart.
    if (!store.ready) {
      signalStage('preparing');
      return const PreparingScreen(onRetry: _reload);
    }
    final user = store.currentUser;
    if (user == null) {
      signalStage('login');
      return const LoginScreen();
    }
    // تأكيد البريد يسبق شاشة الانتظار: طلب لم يُؤكَّد بريده يرفض الخادم
    // اعتماده، فإظهار «بانتظار الموافقة» له يوهم الموظف أن دوره انتهى بينما
    // هو لم يبدأ. ولا يُحبس خلفه حساب معتمد أصلاً — الشرط لمن لم يُعتمد بعد.
    if (user.status != UserStatus.approved && store.needsEmailVerification) {
      signalStage('verify-email');
      return const VerifyEmailScreen();
    }
    if (user.status != UserStatus.approved) {
      signalStage('pending');
      return const PendingApprovalScreen();
    }
    signalStage('shell');
    return const AppShell();
  }
}
