import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_badge.dart';

class VehicleOwnerAppBarActions extends ConsumerWidget {
  const VehicleOwnerAppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';

    return NotificationBadge(
      recipientId: vehicleOwnerId,
      recipientType: NotificationRecipientType.vehicleOwner,
      child: IconButton(
        onPressed: () => context.push(RoutePaths.vehicleOwnerNotifications),
        icon: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
