import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
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
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class ParkingSearchPage extends ConsumerStatefulWidget {
  const ParkingSearchPage({super.key});

  @override
  ConsumerState<ParkingSearchPage> createState() => _ParkingSearchPageState();
}

class _ParkingSearchPageState extends ConsumerState<ParkingSearchPage> {
  final _searchController = TextEditingController();
  bool _locating = false;
  bool _listOnly = false;
  bool _requestedInitialLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requestedInitialLocation) {
        _requestedInitialLocation = true;
        _useMyLocation(showSuccessMessage: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({bool showSuccessMessage = true}) async {
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

      final current = ref.read(searchFiltersProvider);
      ref.read(searchFiltersProvider.notifier).state = current.copyWith(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
      );
      ref.invalidate(locationPermissionProvider);

      if (showSuccessMessage) {
        ref.read(snackbarServiceProvider).showSuccess('Location found.');
      }
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
    if (!mounted) return;
    final id = listing.id.trim();
    final key = (id.isNotEmpty &&
            id != '[object Object]' &&
            !id.contains('object Object'))
        ? id
        : listing.ticketId.trim();
    if (key.isEmpty) {
      ref.read(snackbarServiceProvider).showError(
            'This parking cannot be opened right now. Pull to refresh and try again.',
          );
      return;
    }
    context.push(RoutePaths.vehicleOwnerParkingDetail(key));
  }

  void _applySearch() {
    final current = ref.read(searchFiltersProvider);
    ref.read(searchFiltersProvider.notifier).state = current.copyWith(
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      clearQuery: _searchController.text.trim().isEmpty,
    );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SearchFiltersSheet(),
    );
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
            title: listing.shortDisplayName,
            snippet: [
              listing.distanceLabel,
              listing.compatibilityLabel,
              AppColors.availabilityShortLabel(
                listing.freeSlots,
                listing.capacity,
              ),
            ].whereType<String>().join(' • '),
            distanceKm: listing.distanceKm,
            payload: listing.id,
            availabilityTier: AppColors.availabilityTier(
              listing.freeSlots,
              listing.capacity,
            ),
          ),
        )
        .toList();
  }

  Widget _emptyResults(BuildContext context, {required bool hasLocation}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_parking_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No parking nearby',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasLocation
                  ? "We couldn't find an available verified parking space near you."
                  : 'Turn on location to find parking near you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listContent(
    List<ParkingListing> listings, {
    required ScrollController scrollController,
    bool isRefreshing = false,
  }) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: listings.length + (isRefreshing ? 1 : 0),
      itemBuilder: (context, index) {
        if (isRefreshing && index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final listing = listings[isRefreshing ? index - 1 : index];
        return ParkingListingCard(
          listing: listing,
          compact: true,
          onTap: () => _openParking(listing),
        );
      },
    );
  }

  Widget _mapFirstLayout(
    BuildContext context,
    List<ParkingListing> listings, {
    required bool hasLocation,
    bool isRefreshing = false,
  }) {
    final theme = Theme.of(context);
    final markers = _listingMarkers(listings);

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMapView(
            markers: markers,
            showCurrentLocation: true,
            initialZoom: hasLocation ? 13 : 12,
            borderRadius: 0,
            onMarkerTap: (marker) {
              final match =
                  listings.where((l) => l.id == marker.payload).toList();
              if (match.isNotEmpty) _openParking(match.first);
            },
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: listings.isEmpty ? 0.22 : 0.38,
          minChildSize: 0.18,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.18, 0.38, 0.88],
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? Colors.white
                    : theme.colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Nearby parking',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${listings.length} found',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: listings.isEmpty
                        ? _emptyResults(context, hasLocation: hasLocation)
                        : RefreshIndicator(
                            onRefresh: () async =>
                                ref.invalidate(parkingListingsProvider),
                            child: _listContent(
                              listings,
                              scrollController: scrollController,
                              isRefreshing: isRefreshing,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _listOnlyLayout(
    BuildContext context,
    List<ParkingListing> listings, {
    bool isRefreshing = false,
  }) {
    if (listings.isEmpty) {
      return _emptyResults(
        context,
        hasLocation: ref.read(searchFiltersProvider).userLatitude != null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(parkingListingsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: listings.length + (isRefreshing ? 1 : 0),
        itemBuilder: (context, index) {
          if (isRefreshing && index == 0) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final listing = listings[isRefreshing ? index - 1 : index];
          return ParkingListingCard(
            listing: listing,
            compact: true,
            onTap: () => _openParking(listing),
          );
        },
      ),
    );
  }

  Widget _searchOverlay(BuildContext context, {required bool hasLocation}) {
    final theme = Theme.of(context);
    final filters = ref.watch(searchFiltersProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LocationPermissionBanner(),
        Material(
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          color: theme.brightness == Brightness.light
              ? Colors.white
              : theme.colorScheme.surfaceContainerHigh,
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search parking or ticket ID',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(Icons.search, size: 24),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 22),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.light
                  ? Colors.white
                  : theme.colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _applySearch(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _locating ? null : () => _useMyLocation(),
                  icon: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 22),
                  label: Text(
                    hasLocation ? 'Update' : 'Location',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _showFilters,
                  icon: const Icon(Icons.tune, size: 22),
                  label: Text(
                    filters.hasActiveFilters ? 'Filters •' : 'Filters',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchHeader(BuildContext context, {required bool hasLocation}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _searchOverlay(context, hasLocation: hasLocation),
    );
  }

  Widget _mapBody(
    BuildContext context,
    List<ParkingListing> listings, {
    required bool hasLocation,
    bool isRefreshing = false,
  }) {
    return Column(
      children: [
        _searchHeader(context, hasLocation: hasLocation),
        Expanded(
          child: _mapFirstLayout(
            context,
            listings,
            hasLocation: hasLocation,
            isRefreshing: isRefreshing,
          ),
        ),
      ],
    );
  }

  Widget _listBody(
    BuildContext context,
    List<ParkingListing> listings, {
    bool isRefreshing = false,
  }) {
    final hasLocation =
        ref.read(searchFiltersProvider).userLatitude != null &&
        ref.read(searchFiltersProvider).userLongitude != null;

    return Column(
      children: [
        _searchHeader(context, hasLocation: hasLocation),
        Expanded(
          child: _listOnlyLayout(
            context,
            listings,
            isRefreshing: isRefreshing,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final listingsAsync = ref.watch(parkingListingsProvider);
    final hasLocation =
        filters.userLatitude != null && filters.userLongitude != null;
    final cachedListings = listingsAsync.valueOrNull;
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppColors.lightBackground : colorScheme.surface,
      appBar: AppBar(
        title: const Text('Nearby'),
        backgroundColor: isLight ? AppColors.card : colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        actions: [
          const VehicleOwnerLiveQrButton(),
          IconButton(
            onPressed: () => context.push(RoutePaths.nearbyParkingMap),
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Full map',
          ),
          IconButton(
            onPressed: () => setState(() => _listOnly = !_listOnly),
            icon: Icon(_listOnly ? Icons.map_outlined : Icons.list),
            tooltip: _listOnly ? 'Map view' : 'List view',
          ),
        ],
      ),
      body: listingsAsync.when(
        loading: () {
          if (cachedListings != null) {
            return _listOnly
                ? _listBody(
                    context,
                    cachedListings,
                    isRefreshing: true,
                  )
                : _mapBody(
                    context,
                    cachedListings,
                    hasLocation: hasLocation,
                    isRefreshing: true,
                  );
          }
          return const AppLoadingWidget(
            message: 'Finding approved parking near you...',
          );
        },
        error: (_, __) => AppErrorWidget(
          message: 'Could not load parking recommendations.',
          onRetry: () => ref.invalidate(parkingListingsProvider),
        ),
        data: (listings) {
          if (_listOnly) {
            return _listBody(context, listings);
          }
          return _mapBody(context, listings, hasLocation: hasLocation);
        },
      ),
    );
  }
}
