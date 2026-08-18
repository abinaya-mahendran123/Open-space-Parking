import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_history_view.dart';

class LandOwnerNotificationsPage extends ConsumerWidget {
  const LandOwnerNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(authStateProvider).session?.userId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: NotificationHistoryView(
        recipientId: ownerId,
        recipientType: NotificationRecipientType.landOwner,
      ),
    );
  }
}
