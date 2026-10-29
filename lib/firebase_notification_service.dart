import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseNotificationService instance =
      FirebaseNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Thông báo quan trọng',
    description: 'Thông báo được gửi từ Firebase Cloud Messaging.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize({
    required Future<void> Function(String token) onToken,
  }) async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings: initializationSettings);

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // The assignment requires the FCM registration token specifically. The
    // newer FID registration API is not interchangeable with this token on
    // backends that use Firebase Admin SDK's send(token: ...).
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await onToken(token);

    await _tokenSubscription?.cancel();
    // ignore: deprecated_member_use
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      onToken,
    );

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _notifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title ?? 'Facebook Profile',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Thông báo quan trọng',
          channelDescription: 'Thông báo được gửi từ Firebase Cloud Messaging.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['route']?.toString(),
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
