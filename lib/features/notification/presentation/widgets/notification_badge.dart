import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_history_view.dart';

class NotificationHistoryPage extends ConsumerWidget {
  const NotificationHistoryPage({
    super.key,
    required this.recipientId,
    required this.recipientType,
    this.title = 'Notifications',
  });

  final String recipientId;
  final NotificationRecipientType recipientType;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: NotificationHistoryView(
        recipientId: recipientId,
        recipientType: recipientType,
      ),
    );
  }
}

class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({
    super.key,
    required this.recipientId,
    required this.recipientType,
    required this.child,
  });

  final String recipientId;
  final NotificationRecipientType recipientType;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = NotificationHistoryQuery(
      recipientId: recipientId,
      recipientType: recipientType,
    );
    final unreadAsync = ref.watch(unifiedUnreadCountProvider(query));

    return unreadAsync.when(
      data: (count) {
        if (count <= 0) return child;
        return Badge(
          label: Text(count > 99 ? '99+' : '$count'),
          child: child,
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}
