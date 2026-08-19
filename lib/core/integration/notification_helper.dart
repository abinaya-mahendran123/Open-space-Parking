import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/services/api/push_notification_service.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

/// Unified notification dispatch: local alerts, FCM push, and persistence hooks.
class NotificationHelper {
  NotificationHelper({
    required NotificationService notificationService,
    required PushNotificationService pushNotificationService,
  })  : _notificationService = notificationService,
        _pushNotificationService = pushNotificationService;

  final NotificationService _notificationService;
  final PushNotificationService _pushNotificationService;

  Future<void> notify({
    required String recipientId,
    required NotificationRecipientType recipientType,
    required String title,
    required String message,
    String? referenceId,
    String? route,
    bool push = false,
  }) async {
    if (push) {
      await _pushNotificationService.send(
        recipientId: recipientId,
        recipientType: recipientType,
        title: title,
        body: message,
        route: route,
        referenceId: referenceId,
      );
      return;
    }

    try {
      await _notificationService.showLocal(
        NotificationPayload(
          title: title,
          body: message,
          recipientId: recipientId,
          recipientType: recipientType.value,
          referenceId: referenceId,
          route: route,
        ),
      );
    } catch (e) {
      AppLogger.w('Notification dispatch failed: $e');
    }
  }

  Future<bool> notifyLandOwner({
    required String ownerId,
    required String title,
    required String message,
    String? ticketId,
    String? route,
    bool push = false,
  }) {
    return notify(
      recipientId: ownerId,
      recipientType: NotificationRecipientType.landOwner,
      title: title,
      message: message,
      referenceId: ticketId,
      route: route ?? RoutePaths.landOwnerNotifications,
      push: push,
    ).then((_) => true);
  }

  Future<bool> notifyVehicleOwner({
    required String vehicleOwnerId,
    required String title,
    required String message,
    String? bookingRef,
    String? route,
    bool push = false,
  }) {
    return notify(
      recipientId: vehicleOwnerId,
      recipientType: NotificationRecipientType.vehicleOwner,
      title: title,
      message: message,
      referenceId: bookingRef,
      route: route ?? RoutePaths.vehicleOwnerNotifications,
      push: push,
    ).then((_) => true);
  }

  Future<bool> notifyEmployee({
    required String employeeId,
    required String title,
    required String message,
    String? ticketId,
    String? route,
  }) {
    return _pushNotificationService.send(
      recipientId: employeeId,
      recipientType: NotificationRecipientType.employee,
      title: title,
      body: message,
      route: route ?? RoutePaths.employeeAssigned,
      referenceId: ticketId,
    );
  }
}
