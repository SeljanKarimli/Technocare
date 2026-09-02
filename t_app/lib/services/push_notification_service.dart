import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/firebase_app_config.dart';

const _updatesTopic = 'technocare-site-updates';
const _channelId = 'technocare_updates';

@pragma('vm:entry-point')
Future<void> technocareFirebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && FirebaseAppConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseAppConfig.current);
  }
}

class PushNotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _configured = false;
  bool get isConfigured => _configured;

  Future<void> initialize() async {
    if (!FirebaseAppConfig.isConfigured) return;
    FirebaseMessaging.onBackgroundMessage(technocareFirebaseBackgroundHandler);
    try {
      await _initializeConfiguredFirebase();
    } catch (error, stackTrace) {
      debugPrint('Push notifications could not be initialized: $error');
      debugPrintStack(stackTrace: stackTrace);
      _configured = false;
    }
  }

  Future<void> _initializeConfiguredFirebase() async {
    await Firebase.initializeApp(options: FirebaseAppConfig.current);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _openUrl(response.payload),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Technocare yenilikləri',
            description: 'Saytda yeni məhsul və məlumat olduqda bildirişlər',
            importance: Importance.high,
          ),
        );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.subscribeToTopic(_updatesTopic);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openUrl(message.data['url']),
    );
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_openUrl(initialMessage.data['url']));
    }
    _configured = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Technocare yenilikləri',
          channelDescription:
              'Saytda yeni məhsul və məlumat olduqda bildirişlər',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['url'],
    );
  }

  Future<void> _openUrl(String? value) async {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
