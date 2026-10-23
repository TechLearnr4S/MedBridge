import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Background message handler ────────────────────────────────────────────────
// Must be a top-level function (not a class method) as required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized at this point when called by the OS.
  // Just log or show a local notification here if needed.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging tokens and foreground push notifications.
///
/// Call [FcmService.init] once at app start (after Firebase.initializeApp).
/// Call [FcmService.registerToken] after the user signs in.
/// Call [FcmService.removeToken]  before signing out.
class FcmService {
  FcmService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'medbridge_high_importance',
    'MedBridge Alerts',
    description: 'Appointment confirmations, prescriptions, and chat messages.',
    importance: Importance.max,
  );

  // ── initialisation ────────────────────────────────────────────────────────

  /// Initialise FCM. Call once in [main] **after** Firebase.initializeApp.
  static Future<void> init() async {
    // Register background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (iOS / macOS / Web).
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Configure high-importance Android notification channel.
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Initialise local notifications plugin for foreground display.
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    // Handle foreground FCM messages by showing a local notification.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Ensure foreground notifications are shown as heads-up on iOS.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── token management ──────────────────────────────────────────────────────

  /// Obtains the FCM device token and saves it to
  /// `users/{uid}/fcmTokens/{token}` in Firestore.
  ///
  /// Safe to call multiple times — uses [SetOptions.merge] so it is idempotent.
  static Future<void> registerToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await _tokenDoc(uid, token).set({
        'token': token,
        'platform': _platform(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] Token registered: $token');

      // Refresh listener — called when the OS rotates the token.
      _fcm.onTokenRefresh.listen((newToken) async {
        await _tokenDoc(uid, newToken).set({
          'token': newToken,
          'platform': _platform(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token refreshed: $newToken');
      });
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  /// Deletes the current device token from Firestore.
  /// Call this **before** [FirebaseAuth.signOut].
  static Future<void> removeToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _tokenDoc(uid, token).delete();
      await _fcm.deleteToken();
      debugPrint('[FCM] Token removed.');
    } catch (e) {
      debugPrint('[FCM] removeToken error: $e');
    }
  }

  /// Streams the list of registered FCM tokens for a user.
  /// Useful for admin diagnostics or sending targeted messages.
  static Stream<List<FcmToken>> tokensForUser(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .snapshots()
          .map((s) => s.docs.map(FcmToken.fromDoc).toList());

  // ── foreground message handler ────────────────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> _tokenDoc(
          String uid, String token) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token);

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }
}

// ── model ─────────────────────────────────────────────────────────────────────

/// A persisted FCM device token document at `users/{uid}/fcmTokens/{token}`.
class FcmToken {
  final String token;
  final String platform;
  final DateTime updatedAt;

  const FcmToken({
    required this.token,
    required this.platform,
    required this.updatedAt,
  });

  factory FcmToken.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return FcmToken(
      token: (m['token'] ?? d.id).toString(),
      platform: (m['platform'] ?? 'unknown').toString(),
      updatedAt: m['updatedAt'] is Timestamp
          ? (m['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
