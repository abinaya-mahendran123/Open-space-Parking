import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

/// Unified notification dispatch: persists to MongoDB and shows a local alert.
class NotificationHelper {
  NotificationHelper({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  final NotificationService _notificationService;

  Future<void> notify({
    required String recipientId,
    required NotificationRecipientType recipientType,
    required String title,
    required String message,
    String? referenceId,
    String? route,
  }) async {
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

  Future<void> notifyLandOwner({
    required String ownerId,
    required String title,
    required String message,
    String? ticketId,
    String? route,
  }) {
    return notify(
      recipientId: ownerId,
      recipientType: NotificationRecipientType.landOwner,
      title: title,
      message: message,
      referenceId: ticketId,
      route: route ?? RoutePaths.landOwnerNotifications,
    );
  }

  Future<void> notifyVehicleOwner({
    required String vehicleOwnerId,
    required String title,
    required String message,
    String? bookingRef,
    String? route,
  }) {
    return notify(
      recipientId: vehicleOwnerId,
      recipientType: NotificationRecipientType.vehicleOwner,
      title: title,
      message: message,
      referenceId: bookingRef,
      route: route ?? RoutePaths.vehicleOwnerNotifications,
    );
  }

  Future<void> notifyEmployee({
    required String employeeId,
    required String title,
    required String message,
    String? ticketId,
    String? route,
  }) {
    return notify(
      recipientId: employeeId,
      recipientType: NotificationRecipientType.employee,
      title: title,
      message: message,
      referenceId: ticketId,
      route: route ?? RoutePaths.employeeNotifications,
    );
  }
}
