import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<String>? _tokenSubscription;

  static String? _fcmToken;

  static String? get fcmToken => _fcmToken;

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<void> initialize() async {
    debugPrint('==========================================');
    debugPrint('INITIALIZING FCM');
    debugPrint('==========================================');

    // ----------------------------------------------------------
    // REQUEST PERMISSION
    // ----------------------------------------------------------

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'Notification permission: '
      '${settings.authorizationStatus}',
    );

    // ----------------------------------------------------------
    // GET TOKEN
    // ----------------------------------------------------------

    await _getToken();

    // ----------------------------------------------------------
    // TOKEN REFRESH
    // ----------------------------------------------------------

    await _tokenSubscription?.cancel();

    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;

      debugPrint('==========================================');
      debugPrint('FCM TOKEN REFRESHED');
      debugPrint(newToken);
      debugPrint('==========================================');

      // We'll save this to Supabase in the next step.
    });

    // ----------------------------------------------------------
    // FOREGROUND MESSAGE
    // ----------------------------------------------------------

    await _foregroundSubscription?.cancel();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // ----------------------------------------------------------
    // NOTIFICATION THAT OPENED APP
    // ----------------------------------------------------------

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // ----------------------------------------------------------
    // APP OPENED FROM TERMINATED STATE
    // ----------------------------------------------------------

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('FCM initialization completed.');
  }

  // ============================================================
  // GET TOKEN
  // ============================================================

  static Future<void> _getToken() async {
    try {
      final token = await _messaging.getToken();

      _fcmToken = token;

      debugPrint('==========================================');
      debugPrint('FCM DEVICE TOKEN');
      debugPrint(token ?? 'TOKEN IS NULL');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('FCM TOKEN ERROR: $e');
    }
  }

  // ============================================================
  // FOREGROUND MESSAGE
  // ============================================================

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('==========================================');
    debugPrint('FCM FOREGROUND MESSAGE');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    debugPrint('==========================================');

    // Android foreground notification UI will be added next.
  }

  // ============================================================
  // NOTIFICATION TAP
  // ============================================================

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('==========================================');
    debugPrint('FCM NOTIFICATION OPENED');
    debugPrint('Data: ${message.data}');
    debugPrint('==========================================');

    final announcementId = message.data['announcement_id'];

    if (announcementId != null) {
      debugPrint('Open announcement: $announcementId');

      // Navigation will be connected after we create
      // the notification navigation handler.
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();

    _foregroundSubscription = null;
    _tokenSubscription = null;
  }
}

// ============================================================
// BACKGROUND MESSAGE HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('==========================================');
  debugPrint('FCM BACKGROUND MESSAGE');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
  debugPrint('==========================================');
}
