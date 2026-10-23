import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a system notification (Android) and an in-app banner (all platforms)
/// whenever a new document appears in `notifications` for the signed-in user.
/// Works on the free Firebase Spark plan (no Cloud Functions needed).
class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static final Set<String> _seen = <String>{};
  static bool _first = true;
  static DateTime _startedAt = DateTime.now();

  static Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestNotificationsPermission();
    _ready = true;
  }

  static void start(String uid) {
    stop();
    _first = true;
    _seen.clear();
    _startedAt = DateTime.now();
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (_first) {
        for (final d in snap.docs) {
          _seen.add(d.id);
        }
        _first = false;
        return;
      }
      for (final c in snap.docChanges) {
        if (c.type != DocumentChangeType.added) continue;
        if (!_seen.add(c.doc.id)) continue;
        final m = c.doc.data() ?? <String, dynamic>{};
        final created = m['createdAt'];
        if (created is Timestamp &&
            created
                .toDate()
                .isBefore(_startedAt.subtract(const Duration(minutes: 1)))) {
          continue; // old notification, do not pop up
        }
        _show((m['title'] ?? 'MedBridge').toString(),
            (m['body'] ?? '').toString(), c.doc.id);
      }
    }, onError: (_) {});
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<void> _show(String title, String body, String id) async {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
      ),
    );
    if (kIsWeb || !_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'medbridge_channel',
          'MedBridge Notifications',
          channelDescription: 'Appointment and prescription updates',
          importance: Importance.max,
          priority: Priority.high,
        ),
      );
      await _plugin.show(id.hashCode & 0x7fffffff, title, body, details);
    } catch (_) {}
  }
}
