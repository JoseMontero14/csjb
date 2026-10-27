import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';
import 'utils/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capturar errores de Flutter en producción para diagnóstico
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('>>> [CRASH] Flutter error: ${details.exception}');
    debugPrint('>>> [CRASH] ${details.stack}');
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, // ignore: deprecated_member_use
    );
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      debugPrint('App Check debug token: $token');
    } catch (e) {
      debugPrint('App Check token pendiente de registro: $e');
    }
  }

  if (!kIsWeb) {
    await NotificationService.instance.init();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CsjbApp());
}

class CsjbApp extends StatelessWidget {
  const CsjbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSJB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.initial,
      routes: AppRoutes.all,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child!,
      ),
    );
  }
}
