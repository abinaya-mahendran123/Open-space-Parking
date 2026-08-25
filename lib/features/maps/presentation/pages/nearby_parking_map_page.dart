import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/directions_bar.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/google_map_view.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/location_permission_banner.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class NearbyParkingMapPage extends ConsumerWidget {
  const NearbyParkingMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markersAsync = ref.watch(nearbyParkingMarkersProvider);
    final listingsAsync = ref.watch(parkingListingsProvider);
    final selected = ref.watch(selectedMarkerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Parking Map'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.vehicleOwnerSearch);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(nearbyParkingMarkersProvider);
              ref.invalidate(parkingListingsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: markersAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading nearby parking...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load parking markers',
          onRetry: () {
            ref.invalidate(nearbyParkingMarkersProvider);
            ref.invalidate(parkingListingsProvider);
          },
        ),
        data: (markers) {
          final listings = listingsAsync.valueOrNull ?? const <ParkingListing>[];
          ParkingListing? selectedListing;
          if (selected?.payload != null) {
            final matches =
                listings.where((item) => item.id == selected!.payload).toList();
            if (matches.isNotEmpty) selectedListing = matches.first;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    const LocationPermissionBanner(),
                    if (markers.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No suitable parking found nearby.\n\nWe could not find an approved parking space that is currently available and compatible with your vehicle.',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GoogleMapView(
                    markers: markers,
                    highlightedMarker: selected,
                    showCurrentLocation: true,
                    initialZoom: 12,
                    onMarkerTap: (marker) {
                      ref.read(selectedMarkerProvider.notifier).state = marker;
                    },
                  ),
                ),
              ),
              if (selected != null)
                _SelectedParkingPanel(
                  marker: selected,
                  listing: selectedListing,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectedParkingPanel extends ConsumerWidget {
  const _SelectedParkingPanel({
    required this.marker,
    this.listing,
  });

  final MapMarkerData marker;
  final ParkingListing? listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(marker.title),
              subtitle: Text(
                [
                  if (listing?.distanceLabel != null) listing!.distanceLabel,
                  if (listing != null)
                    '${listing!.freeSlots} spaces available',
                  if (listing != null) listing!.compatibilityLabel,
                  if (listing != null) listing!.parkingStatusLabel,
                  if (listing?.address != null) listing!.address,
                  if (marker.snippet != null) marker.snippet,
                ].whereType<String>().join(' • '),
              ),
            ),
            DirectionsBar(
              destination: marker.coordinate,
              destinationLabel: marker.title,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (marker.payload != null) {
                  context.push(
                    RoutePaths.vehicleOwnerParkingDetail(marker.payload!),
                  );
                }
              },
              child: const Text('View Parking Details'),
            ),
          ],
        ),
      ),
    );
  }
}
