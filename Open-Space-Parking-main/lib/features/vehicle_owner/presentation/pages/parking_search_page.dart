import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/utils/location_access.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/google_map_view.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/location_permission_banner.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/parking_listing_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/search_filters_sheet.dart';

class ParkingSearchPage extends ConsumerStatefulWidget {
  const ParkingSearchPage({super.key});

  @override
  ConsumerState<ParkingSearchPage> createState() => _ParkingSearchPageState();
}

class _ParkingSearchPageState extends ConsumerState<ParkingSearchPage> {
  final _searchController = TextEditingController();
  bool _locating = false;
  bool _showMap = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final mapsRepo = ref.read(mapsRepositoryProvider);
      final permission = await LocationAccess.ensure(
        context: context,
        repository: mapsRepo,
      );
      if (!mounted) return;

      if (!permission.isGranted) {
        final message = LocationAccess.messageFor(permission);
        ref.read(snackbarServiceProvider).showError(
              message.isEmpty
                  ? 'Allow location access to find nearby parking.'
                  : message,
            );
        ref.invalidate(locationPermissionProvider);
        return;
      }

      final location =
          await ref.read(mapSelectionProvider.notifier).refreshCurrentLocation();
      if (!mounted) return;

      if (location == null) {
        ref.read(snackbarServiceProvider).showError(
              'Could not read your current location. Check browser/GPS permission.',
            );
        return;
      }

      // Keep filters + map in sync, then reload verified nearby listings.
      final current = ref.read(searchFiltersProvider);
      ref.read(searchFiltersProvider.notifier).state = current.copyWith(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        maxDistanceKm: current.maxDistanceKm ?? 25,
      );
      ref.invalidate(locationPermissionProvider);
      ref.invalidate(parkingListingsProvider);

      ref.read(snackbarServiceProvider).showSuccess(
            'Location found. Showing employee-verified parking nearby.',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError(
            'Could not get your location. Allow location for this site and try again.',
          );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openParking(ParkingListing listing) async {
    final opened = await ref.read(mapsRepositoryProvider).openNavigation(
          DirectionsRequest(
            destination: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
          ),
        );
    if (!opened && mounted) {
      ref
          .read(snackbarServiceProvider)
          .showError('Could not open Google Maps. Opening parking details.');
    }
    if (!mounted) return;
    context.push(RoutePaths.vehicleOwnerParkingDetail(listing.id));
  }

  void _applySearch() {
    final current = ref.read(searchFiltersProvider);
    ref.read(searchFiltersProvider.notifier).state = current.copyWith(
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      clearQuery: _searchController.text.trim().isEmpty,
    );
    ref.invalidate(parkingListingsProvider);
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SearchFiltersSheet(),
    ).then((_) => ref.invalidate(parkingListingsProvider));
  }

  List<MapMarkerData> _listingMarkers(List<ParkingListing> listings) {
    return listings
        .map(
          (listing) => MapMarkerData(
            id: listing.id,
            coordinate: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
            title: listing.displayName,
            snippet: '₹${listing.hourlyRate.toStringAsFixed(0)}/hr',
            distanceKm: listing.distanceKm,
            payload: listing.id,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final listingsAsync = ref.watch(parkingListingsProvider);
    final mapState = ref.watch(mapSelectionProvider);
    final hasLocation =
        filters.userLatitude != null && filters.userLongitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Parking'),
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.nearbyParkingMap),
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Full map',
          ),
          IconButton(
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'List view' : 'Map view',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const LocationPermissionBanner(),
                SearchBar(
                  controller: _searchController,
                  hintText: 'Search by address or ticket ID',
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    ),
                  ],
                  onSubmitted: (_) => _applySearch(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _locating ? null : _useMyLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          hasLocation ? 'Update Location' : 'Current Location',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _showFilters,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          filters.hasActiveFilters ? 'Filters •' : 'Filters',
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasLocation && mapState.currentLocation != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Near ${mapState.currentLocation!.latitude.toStringAsFixed(4)}, '
                      '${mapState.currentLocation!.longitude.toStringAsFixed(4)}'
                      '${filters.maxDistanceKm != null ? ' • within ${filters.maxDistanceKm!.toInt()} km' : ''}'
                      ' • employee-verified only',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: listingsAsync.when(
              loading: () => const AppLoadingWidget(
                message: 'Finding verified parking near you...',
              ),
              error: (_, __) => AppErrorWidget(
                message: 'Search failed',
                onRetry: () => ref.invalidate(parkingListingsProvider),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        hasLocation
                            ? 'No employee-verified parking found near you yet. '
                                'Parking appears here after admin verifies documents, '
                                'assigns an employee, and the employee completes the site.'
                            : 'Tap Current Location to find employee-verified parking near you.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final markers = _listingMarkers(listings);

                if (_showMap) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(parkingListingsProvider),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        GoogleMapView(
                          height: 280,
                          markers: markers,
                          showCurrentLocation: true,
                          initialZoom: hasLocation ? 13 : 12,
                          onMarkerTap: (marker) {
                            final match = listings
                                .where((l) => l.id == marker.payload)
                                .toList();
                            if (match.isNotEmpty) {
                              _openParking(match.first);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${listings.length} verified parking space${listings.length == 1 ? '' : 's'} found',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...listings.map(
                          (listing) => ParkingListingCard(
                            listing: listing,
                            onTap: () => _openParking(listing),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(parkingListingsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ParkingListingCard(
                        listing: listing,
                        onTap: () => _openParking(listing),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
