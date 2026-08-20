import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_skeleton.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_detail_dialog.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_tile.dart';

class NotificationHistoryView extends ConsumerStatefulWidget {
  const NotificationHistoryView({
    super.key,
    required this.recipientId,
    required this.recipientType,
    this.showMarkAllRead = true,
  });

  final String recipientId;
  final NotificationRecipientType recipientType;
  final bool showMarkAllRead;

  @override
  ConsumerState<NotificationHistoryView> createState() =>
      _NotificationHistoryViewState();
}

class _NotificationHistoryViewState
    extends ConsumerState<NotificationHistoryView> {
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};

  NotificationHistoryQuery get _query => NotificationHistoryQuery(
        recipientId: widget.recipientId,
        recipientType: widget.recipientType,
      );

  Future<void> _refresh() async {
    ref.invalidate(notificationHistoryProvider(_query));
    ref.invalidate(unifiedUnreadCountProvider(_query));
  }

  void _enterSelectMode([String? initialId]) {
    setState(() {
      _selecting = true;
      _selectedIds.clear();
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AppNotification> notifications) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(notifications.map((n) => n.id));
    });
  }

  Future<void> _deleteOne(String id) async {
    try {
      await ref.read(notificationRepositoryProvider).deleteNotification(id);
      _selectedIds.remove(id);
      await _refresh();
      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess('Notification deleted.');
    } catch (_) {
      await _refresh();
      if (!mounted) return;
      ref
          .read(snackbarServiceProvider)
          .showError('Could not delete notification.');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count notification${count == 1 ? '' : 's'}?'),
        content: const Text('Selected notifications will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(notificationRepositoryProvider)
          .deleteMany(_selectedIds.toList());
      _exitSelectMode();
      await _refresh();
      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess(
            '$count notification${count == 1 ? '' : 's'} deleted.',
          );
    } catch (_) {
      await _refresh();
      if (!mounted) return;
      ref
          .read(snackbarServiceProvider)
          .showError('Could not delete selected notifications.');
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This permanently removes all notifications for your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(notificationRepositoryProvider).deleteAll(
            recipientId: widget.recipientId,
            recipientType: widget.recipientType,
          );
      _exitSelectMode();
      await _refresh();
      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess('All notifications cleared.');
    } catch (_) {
      await _refresh();
      if (!mounted) return;
      ref
          .read(snackbarServiceProvider)
          .showError('Could not clear notifications.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onRetry: _refresh,
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
        final selectedCount = _selectedIds.length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.sm,
                    AppSpacing.pagePadding,
                    0,
                  ),
                  child: _selecting
                      ? Row(
                          children: [
                            TextButton(
                              onPressed: _exitSelectMode,
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => _selectAll(notifications),
                              child: const Text('Select all'),
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              onPressed: selectedCount == 0
                                  ? null
                                  : _deleteSelected,
                              icon: const Icon(Icons.delete_outline),
                              label: Text('Delete ($selectedCount)'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            if (widget.showMarkAllRead && unreadCount > 0)
                              TextButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(notificationRepositoryProvider)
                                      .markAllAsRead(
                                        recipientId: widget.recipientId,
                                        recipientType: widget.recipientType,
                                      );
                                  await _refresh();
                                },
                                icon: const Icon(Icons.done_all),
                                label: Text('Mark all read ($unreadCount)'),
                              ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _enterSelectMode,
                              icon: const Icon(Icons.checklist),
                              label: const Text('Select'),
                            ),
                            TextButton.icon(
                              onPressed: _deleteAll,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear all'),
                            ),
                          ],
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
                    final selected = _selectedIds.contains(notification.id);

                    if (_selecting) {
                      return NotificationTile(
                        notification: notification,
                        selected: selected,
                        selectionMode: true,
                        onTap: () => _toggleSelected(notification.id),
                      );
                    }

                    return Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteOne(notification.id),
                      child: NotificationTile(
                        notification: notification,
                        onDelete: () => _deleteOne(notification.id),
                        onLongPress: () =>
                            _enterSelectMode(notification.id),
                        onTap: () async {
                          await showNotificationDetailDialog(
                            context,
                            notification,
                          );
                          if (!mounted) return;
                          if (!notification.isRead) {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markAsRead(notification.id);
                            await _refresh();
                          }
                        },
                      ),
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
