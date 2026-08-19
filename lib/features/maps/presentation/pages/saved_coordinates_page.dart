import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/directions_bar.dart';

class SavedCoordinatesPage extends ConsumerWidget {
  const SavedCoordinatesPage({super.key});

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedCoordinatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Coordinates'),
        actions: [
          IconButton(
            onPressed: () async {
              await context.push<MapCoordinate>(RoutePaths.mapPicker);
              ref.invalidate(savedCoordinatesProvider);
            },
            icon: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
      body: savedAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading saved locations...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load saved coordinates',
          onRetry: () => ref.invalidate(savedCoordinatesProvider),
        ),
        data: (saved) {
          if (saved.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_added_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    const Text('No saved coordinates yet'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.push(RoutePaths.mapPicker),
                      child: const Text('Pick & Save Location'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final item = saved[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.place),
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.coordinate.label}\n${_dateFormat.format(item.savedAt.toLocal())}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DirectionsBar(
                        destination: item.coordinate,
                        destinationLabel: item.label,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(mapsRepositoryProvider)
                                .deleteSavedCoordinate(item.id);
                            ref.invalidate(savedCoordinatesProvider);
                            ref.read(snackbarServiceProvider).showSuccess('Deleted.');
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
