import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_badge.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class VehicleOwnerLiveQrButton extends ConsumerWidget {
  const VehicleOwnerLiveQrButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final liveTicket = ref
        .watch(vehicleOwnerBookingsProvider(vehicleOwnerId))
        .maybeWhen(
          data: (bookings) => bookings.where((b) => b.isQrLive).firstOrNull,
          orElse: () => null,
        );
    if (liveTicket == null) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Show parking QR',
      onPressed: () => context.push(
        RoutePaths.vehicleOwnerParkingTicket(liveTicket.id),
      ),
      icon: const Icon(Icons.qr_code_2),
    );
  }
}

class VehicleOwnerAppBarActions extends ConsumerWidget {
  const VehicleOwnerAppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const VehicleOwnerLiveQrButton(),
        NotificationBadge(
          recipientId: vehicleOwnerId,
          recipientType: NotificationRecipientType.vehicleOwner,
          child: IconButton(
            onPressed: () => context.push(RoutePaths.vehicleOwnerNotifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    );
  }
}
