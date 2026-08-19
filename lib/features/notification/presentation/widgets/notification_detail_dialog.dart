import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';

final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

Future<void> showNotificationDetailDialog(
  BuildContext context,
  AppNotification notification,
) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          Icons.notifications_active_outlined,
          color: colorScheme.primary,
          size: 28,
        ),
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notification.message,
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                _dateFormat.format(notification.createdAt.toLocal()),
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (notification.referenceId != null &&
                  notification.referenceId!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reference: ${notification.referenceId}',
                  style: Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
