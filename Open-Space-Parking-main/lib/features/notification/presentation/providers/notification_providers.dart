import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => GetIt.I<NotificationRepository>(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => GetIt.I<NotificationService>(),
);

final notificationHistoryProvider = FutureProvider.autoDispose
    .family<List<AppNotification>, NotificationHistoryQuery>(
  (ref, query) async {
    return ref.read(notificationRepositoryProvider).getHistory(
          recipientId: query.recipientId,
          recipientType: query.recipientType,
        );
  },
);

final unifiedUnreadCountProvider = FutureProvider.autoDispose
    .family<int, NotificationHistoryQuery>(
  (ref, query) async {
    return ref.read(notificationRepositoryProvider).getUnreadCount(
          recipientId: query.recipientId,
          recipientType: query.recipientType,
        );
  },
);

final notificationTapProvider = StreamProvider<NotificationPayload>((ref) {
  return ref.watch(notificationServiceProvider).onNotificationTap;
});

class NotificationHistoryQuery {
  const NotificationHistoryQuery({
    required this.recipientId,
    required this.recipientType,
  });

  final String recipientId;
  final NotificationRecipientType recipientType;

  @override
  bool operator ==(Object other) {
    return other is NotificationHistoryQuery &&
        other.recipientId == recipientId &&
        other.recipientType == recipientType;
  }

  @override
  int get hashCode => Object.hash(recipientId, recipientType);
}

NotificationRecipientType recipientTypeForRole(UserRole role) {
  return switch (role) {
    UserRole.landOwner => NotificationRecipientType.landOwner,
    UserRole.vehicleOwner => NotificationRecipientType.vehicleOwner,
    UserRole.employee => NotificationRecipientType.employee,
    UserRole.admin => NotificationRecipientType.admin,
  };
}

Future<void> bindNotificationUser(
  WidgetRef ref, {
  required String userId,
  required UserRole role,
}) async {
  if (userId.isEmpty) return;
  await ref.read(notificationServiceProvider).bindUser(
        userId: userId,
        recipientType: recipientTypeForRole(role),
      );
}

Future<void> unbindNotificationUser(WidgetRef ref) async {
  await ref.read(notificationServiceProvider).unbindUser();
}

void invalidateNotificationCache(
  WidgetRef ref, {
  required String recipientId,
  required NotificationRecipientType recipientType,
}) {
  final query = NotificationHistoryQuery(
    recipientId: recipientId,
    recipientType: recipientType,
  );
  ref.invalidate(notificationHistoryProvider(query));
  ref.invalidate(unifiedUnreadCountProvider(query));
}
