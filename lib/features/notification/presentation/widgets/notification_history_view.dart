import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_detail_dialog.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_tile.dart';

class NotificationHistoryView extends ConsumerWidget {
  const NotificationHistoryView({
    super.key,
    required this.recipientId,
    required this.recipientType,
    this.showMarkAllRead = true,
  });

  final String recipientId;
  final NotificationRecipientType recipientType;
  final bool showMarkAllRead;

  NotificationHistoryQuery get _query => NotificationHistoryQuery(
        recipientId: recipientId,
        recipientType: recipientType,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationHistoryProvider(_query));
    final unreadAsync = ref.watch(unifiedUnreadCountProvider(_query));

    return notificationsAsync.when(
      loading: () => AppLoadingWidget(
        message: 'Loading notifications...',
        useSkeleton: true,
        skeleton: AppSkeleton.listTiles(count: 6),
      ),
      error: (_, __) => AppErrorWidget(
        message: 'Failed to load notifications.',
        onRetry: () {
          ref.invalidate(notificationHistoryProvider(_query));
          ref.invalidate(unifiedUnreadCountProvider(_query));
        },
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return const AppEmptyState(
            message:
                'No notifications yet. Booking updates and request alerts will appear here.',
            icon: Icons.notifications_off_outlined,
          );
        }

        final unreadCount = unreadAsync.valueOrNull ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationHistoryProvider(_query));
            ref.invalidate(unifiedUnreadCountProvider(_query));
          },
          child: CustomScrollView(
            slivers: [
              if (showMarkAllRead && unreadCount > 0)
                SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markAllAsRead(
                              recipientId: recipientId,
                              recipientType: recipientType,
                            );
                        ref.invalidate(notificationHistoryProvider(_query));
                        ref.invalidate(unifiedUnreadCountProvider(_query));
                      },
                      icon: const Icon(Icons.done_all),
                      label: Text('Mark all read ($unreadCount)'),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.pagePadding,
                ),
                sliver: SliverList.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationTile(
                      notification: notification,
                      onTap: () async {
                        await showNotificationDetailDialog(context, notification);
                        if (!context.mounted) return;
                        if (!notification.isRead) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markAsRead(notification.id);
                          ref.invalidate(notificationHistoryProvider(_query));
                          ref.invalidate(unifiedUnreadCountProvider(_query));
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
