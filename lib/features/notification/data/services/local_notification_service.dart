import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';

class LocalNotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'open_space_parking_alerts';
  static const String _channelName = 'Parking Alerts';
  static const String _channelDescription =
      'Booking updates, request status, and account alerts';

  final StreamController<NotificationPayload> _tapController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTap => _tapController.stream;

  bool _initialized = false;
  int _notificationId = 0;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      AppLogger.i('Local notifications skipped on web');
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createAndroidChannel();
    _initialized = true;
    AppLogger.i('Local notification service initialized');
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> show(NotificationPayload payload) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();

    final id = ++_notificationId;

    await _plugin.show(
      id,
      payload.title,
      payload.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(payload),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> _createAndroidChannel() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length < 2) return;

    _tapController.add(
      NotificationPayload(
        title: parts[0],
        body: parts[1],
        route: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
        referenceId: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      ),
    );
  }

  String _encodePayload(NotificationPayload payload) {
    return [
      payload.title,
      payload.body,
      payload.route ?? '',
      payload.referenceId ?? '',
    ].join('|');
  }

  void dispose() {
    _tapController.close();
  }
}
