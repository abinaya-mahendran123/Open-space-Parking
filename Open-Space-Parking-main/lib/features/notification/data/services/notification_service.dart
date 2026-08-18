import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/data/services/fcm_service.dart';
import 'package:open_space_parking/features/notification/data/services/local_notification_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/domain/repositories/notification_repository.dart';

class NotificationService {
  NotificationService({
    required FcmService fcmService,
    required LocalNotificationService localNotificationService,
    required NotificationRepository notificationRepository,
  })  : _fcmService = fcmService,
        _localNotificationService = localNotificationService,
        _notificationRepository = notificationRepository;

  final FcmService _fcmService;
  final LocalNotificationService _localNotificationService;
  final NotificationRepository _notificationRepository;

  final StreamController<NotificationPayload> _tapEvents =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTap => _tapEvents.stream;

  String? _currentUserId;
  NotificationRecipientType? _currentRecipientType;
  StreamSubscription<NotificationPayload>? _fcmForegroundSub;
  StreamSubscription<NotificationPayload>? _fcmOpenedSub;
  StreamSubscription<NotificationPayload>? _localTapSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (EnvironmentConfig.isFirebaseConfigured) {
      try {
        await Firebase.initializeApp();
        AppLogger.i('Firebase initialized');
      } catch (e) {
        AppLogger.w('Firebase initialization skipped: $e');
      }
    }

    await _localNotificationService.initialize();
    await _fcmService.initialize();

    _fcmForegroundSub =
        _fcmService.onForegroundMessage.listen(_handleIncomingPayload);
    _fcmOpenedSub = _fcmService.onMessageOpened.listen(_emitTap);
    _localTapSub =
        _localNotificationService.onNotificationTap.listen(_emitTap);

    _tokenRefreshSub = _fcmService.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await _localNotificationService.requestPermissions();
    return _fcmService.requestPermission();
  }

  Future<void> bindUser({
    required String userId,
    required NotificationRecipientType recipientType,
  }) async {
    _currentUserId = userId;
    _currentRecipientType = recipientType;

    final token = await _fcmService.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    await _fcmService.subscribeToTopic('${recipientType.value}_updates');
  }

  Future<void> unbindUser() async {
    final type = _currentRecipientType;
    if (type != null) {
      await _fcmService.unsubscribeFromTopic('${type.value}_updates');
    }
    _currentUserId = null;
    _currentRecipientType = null;
  }

  Future<void> showLocal(NotificationPayload payload) async {
    await _localNotificationService.show(payload);
    await _persistPayload(payload, source: NotificationSource.local);
  }

  Future<AppNotification> saveToHistory(AppNotification notification) {
    return _notificationRepository.save(notification);
  }

  Future<void> _handleIncomingPayload(NotificationPayload payload) async {
    await _localNotificationService.show(payload);
    await _persistPayload(payload, source: NotificationSource.fcm);
  }

  Future<void> _persistPayload(
    NotificationPayload payload, {
    required NotificationSource source,
  }) async {
    final recipientId = payload.recipientId ?? _currentUserId;
    final recipientTypeValue =
        payload.recipientType ?? _currentRecipientType?.value;

    if (recipientId == null || recipientTypeValue == null) return;
    if (payload.body.isEmpty && payload.title.isEmpty) return;

    await _notificationRepository.save(
      AppNotification(
        id: '',
        recipientId: recipientId,
        recipientType: NotificationRecipientType.fromValue(recipientTypeValue),
        title: payload.title,
        message: payload.body,
        createdAt: DateTime.now().toUtc(),
        referenceId: payload.referenceId,
        source: source,
      ),
    );
  }

  void _emitTap(NotificationPayload payload) {
    _tapEvents.add(payload);
  }

  Future<void> _registerToken(String token) async {
    final userId = _currentUserId;
    final recipientType = _currentRecipientType;
    if (userId == null || recipientType == null) return;

    await _notificationRepository.saveDeviceToken(
      userId: userId,
      token: token,
      recipientType: recipientType,
    );
  }

  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    _localTapSub?.cancel();
    _tokenRefreshSub?.cancel();
    _tapEvents.close();
    _fcmService.dispose();
    _localNotificationService.dispose();
  }
}
