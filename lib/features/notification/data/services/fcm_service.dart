import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/firebase/firebase_messaging_background.dart';

class FcmService {
  FcmService();

  /// Lazily assigned after [Firebase.initializeApp] in [initialize].
  FirebaseMessaging? _messaging;

  final StreamController<NotificationPayload> _foregroundMessages =
      StreamController<NotificationPayload>.broadcast();

  final StreamController<NotificationPayload> _openedMessages =
      StreamController<NotificationPayload>.broadcast();

  final StreamController<String> _tokenRefresh =
      StreamController<String>.broadcast();

  Stream<NotificationPayload> get onForegroundMessage =>
      _foregroundMessages.stream;

  Stream<NotificationPayload> get onMessageOpened => _openedMessages.stream;

  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !EnvironmentConfig.isFirebaseConfigured) return;

    _messaging = FirebaseMessaging.instance;

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    _messaging!.onTokenRefresh.listen(_tokenRefresh.add);

    final initial = await _messaging!.getInitialMessage();
    if (initial != null) {
      _handleOpenedMessage(initial);
    }

    _initialized = true;
    AppLogger.i('FCM service initialized');
  }

  Future<bool> requestPermission() async {
    if (!_initialized || _messaging == null) return false;

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      AppLogger.i(
        'Notification permission ${settings.authorizationStatus.name} — push alerts disabled.',
      );
    }
    return granted;
  }

  Future<String?> getToken() async {
    if (!_initialized || _messaging == null) return null;
    try {
      final settings = await _messaging!.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Expected until the user allows notifications — not an app failure.
        return null;
      }
      return await _messaging!.getToken().timeout(const Duration(seconds: 8));
    } catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('permission-blocked') ||
          text.contains('permission-denied') ||
          text.contains('not granted') ||
          text.contains('timeoutexception') ||
          text.contains('failed-service-worker-registration') ||
          text.contains('unsupported mime type')) {
        // Common on web when push SW is missing or notifications not allowed.
        return null;
      }
      AppLogger.w('Failed to get FCM token: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!_initialized || _messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_initialized || _messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _foregroundMessages.add(_mapMessage(message));
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _openedMessages.add(_mapMessage(message));
  }

  NotificationPayload _mapMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);

    if (notification?.title != null) {
      data['title'] = notification!.title;
    }
    if (notification?.body != null) {
      data['body'] = notification!.body;
    }

    return NotificationPayload.fromFcmData(data);
  }

  void dispose() {
    _foregroundMessages.close();
    _openedMessages.close();
    _tokenRefresh.close();
  }
}
