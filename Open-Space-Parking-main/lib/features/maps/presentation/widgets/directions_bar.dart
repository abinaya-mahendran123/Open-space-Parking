import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';

class DirectionsBar extends ConsumerWidget {
  const DirectionsBar({
    super.key,
    required this.destination,
    this.destinationLabel,
    this.origin,
  });

  final MapCoordinate destination;
  final String? destinationLabel;
  final MapCoordinate? origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final request = DirectionsRequest(
      destination: destination,
      origin: origin ?? ref.watch(mapSelectionProvider).currentLocation,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              destinationLabel ?? 'Destination',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openDirections(ref, request),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openNavigation(ref, request),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(WidgetRef ref, DirectionsRequest request) async {
    final opened = await ref.read(mapsRepositoryProvider).openDirections(request);
    if (!opened) {
      ref.read(snackbarServiceProvider).showError('Could not open Google Maps.');
    }
  }

  Future<void> _openNavigation(WidgetRef ref, DirectionsRequest request) async {
    final opened = await ref.read(mapsRepositoryProvider).openNavigation(request);
    if (!opened) {
      ref.read(snackbarServiceProvider).showError('Could not start navigation.');
    }
  }
}
