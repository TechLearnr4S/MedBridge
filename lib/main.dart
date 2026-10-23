import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'backend/fcm_service.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await loadPreferences();

  // In-app snackbar notifications (existing)
  try {
    await NotificationService.init();
  } catch (_) {}

  // FCM push notifications -- must be called after Firebase.initializeApp
  try {
    await FcmService.init();
  } catch (_) {}

  runApp(const MedBridgeApp());
}

/// Root widget that reacts to dark-mode changes via [themeNotifier].
class MedBridgeApp extends StatelessWidget {
  const MedBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MedBridge',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          scaffoldMessengerKey: NotificationService.messengerKey,
          home: const SplashScreen(),
        );
      },
    );
  }
}
