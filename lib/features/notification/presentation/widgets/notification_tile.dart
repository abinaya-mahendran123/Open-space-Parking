import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDelete,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : notification.isRead
              ? null
              : colorScheme.primaryContainer.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode) ...[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm, top: 8),
              child: Icon(
                selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification.isRead
                      ? Icons.notifications_none_outlined
                      : Icons.notifications_active_outlined,
                  color: notification.isRead
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
              ),
            if (!selectionMode) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      if (!notification.isRead && !selectionMode)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dateFormat.format(notification.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (!selectionMode && onDelete != null)
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
    );
  }
}
