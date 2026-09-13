import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'pages/splash_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FIREBASE
  // ============================================================

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ============================================================
  // REGISTER FCM BACKGROUND HANDLER
  // ============================================================

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ============================================================
  // SUPABASE
  // ============================================================

  await Supabase.initialize(
    url: 'https://nvcroeiqgbcxaemsrvsw.supabase.co',
    anonKey: 'sb_publishable__Ns2-9MEAQRS_QV-mNTWVA_3yC5K6wP',
  );

  // ============================================================
  // FCM
  // ============================================================

  await NotificationService.initialize();

  // ============================================================
  // START APP
  // ============================================================

  runApp(const MorPanchayatApp());
}

class MorPanchayatApp extends StatelessWidget {
  const MorPanchayatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mor Panchayat',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B4D),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
      ),

      home: const SplashPage(),
    );
  }
}
