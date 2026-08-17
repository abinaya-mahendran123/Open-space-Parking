import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getHistory({
    required String recipientId,
    required NotificationRecipientType recipientType,
  });

  Future<int> getUnreadCount({
    required String recipientId,
    required NotificationRecipientType recipientType,
  });

  Future<AppNotification> save(AppNotification notification);

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead({
    required String recipientId,
    required NotificationRecipientType recipientType,
  });

  Future<void> saveDeviceToken({
    required String userId,
    required String token,
    required NotificationRecipientType recipientType,
  });
}

typedef NotificationTapHandler = void Function(NotificationPayload payload);
