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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GovExecutivePlatformApp());
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
          title: 'المنصة التنفيذية الحكومية',
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
        backgroundColor: AppColors.primary,
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
