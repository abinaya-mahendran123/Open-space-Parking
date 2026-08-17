import 'package:flutter/material.dart';

import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/repositories/maps_repository.dart';

class LocationAccess {
  LocationAccess._();

  static Future<LocationPermissionStatus> ensure({
    required BuildContext context,
    required MapsRepository repository,
  }) async {
    var serviceEnabled = await repository.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return LocationPermissionStatus.unknown;
      final openSettings = await _confirm(
        context,
        title: 'Turn on location',
        message:
            'Location services (GPS) are turned off. Enable them so the map '
            'can show your position and help you pick the exact land location.',
        confirmLabel: 'Open settings',
      );
      if (openSettings) {
        await repository.openLocationSettings();
      }
      serviceEnabled = await repository.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }
    }

    var permission = await repository.checkLocationPermission();
    if (permission.isGranted) return permission;

    if (permission == LocationPermissionStatus.deniedForever) {
      if (!context.mounted) return LocationPermissionStatus.unknown;
      await _promptAppSettings(context, repository);
      return repository.checkLocationPermission();
    }

    permission = await repository.requestLocationPermission();
    if (permission.isGranted) return permission;

    if (permission == LocationPermissionStatus.serviceDisabled) {
      await repository.openLocationSettings();
      return repository.checkLocationPermission();
    }

    if (permission == LocationPermissionStatus.deniedForever) {
      if (!context.mounted) return LocationPermissionStatus.unknown;
      await _promptAppSettings(context, repository);
      return repository.checkLocationPermission();
    }

    if (permission == LocationPermissionStatus.denied) {
      if (!context.mounted) return LocationPermissionStatus.unknown;
      await _confirm(
        context,
        title: 'Location permission needed',
        message:
            'Allow location access so the map can center on your area and help '
            'you pin your land accurately.',
        confirmLabel: 'Try again',
      );
      permission = await repository.requestLocationPermission();
    }

    return permission;
  }

  static String messageFor(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        return 'Location services are still off. Enable GPS to verify on the map.';
      case LocationPermissionStatus.deniedForever:
        return 'Location access is blocked. Allow it in app settings to use the map.';
      case LocationPermissionStatus.denied:
        return 'Location permission is required to verify on the map.';
      case LocationPermissionStatus.granted:
        return '';
      case LocationPermissionStatus.unknown:
        return 'Could not determine location permission.';
    }
  }

  static Future<void> _promptAppSettings(
    BuildContext context,
    MapsRepository repository,
  ) async {
    final open = await _confirm(
      context,
      title: 'Allow location in settings',
      message:
          'Location access was denied permanently. Open app settings and '
          'allow location for this app.',
      confirmLabel: 'Open settings',
    );
    if (open) await repository.openAppSettings();
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
