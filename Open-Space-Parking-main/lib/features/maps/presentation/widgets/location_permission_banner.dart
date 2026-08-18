import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';

class LocationPermissionBanner extends ConsumerWidget {
  const LocationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(mapSelectionProvider).permission;
    if (permission.isGranted) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final message = _message(permission);
    final actionLabel = _actionLabel(permission);

    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.location_off, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _handleAction(ref, permission),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  String _message(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'GPS is turned off. Enable location services to use the map.';
      case LocationPermissionStatus.deniedForever:
        return 'Location access is blocked. Open settings to allow it.';
      case LocationPermissionStatus.denied:
        return 'Location permission is required for current location and nearby parking.';
      case LocationPermissionStatus.granted:
        return '';
      case LocationPermissionStatus.unknown:
        return 'Location permission status unknown.';
    }
  }

  String _actionLabel(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'Enable GPS';
      case LocationPermissionStatus.deniedForever:
        return 'Settings';
      default:
        return 'Allow';
    }
  }

  Future<void> _handleAction(
    WidgetRef ref,
    LocationPermissionStatus status,
  ) async {
    final repo = ref.read(mapsRepositoryProvider);
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        await repo.openLocationSettings();
      case LocationPermissionStatus.deniedForever:
        await repo.openAppSettings();
      default:
        await ref.read(mapSelectionProvider.notifier).requestPermission();
    }
    ref.invalidate(locationPermissionProvider);
  }
}
