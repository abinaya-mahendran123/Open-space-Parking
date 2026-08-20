import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/domain/entities/saved_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/repositories/maps_repository.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/search_filters.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

final mapsRepositoryProvider = Provider<MapsRepository>(
  (ref) => sl<MapsRepository>(),
);

final locationPermissionProvider =
    FutureProvider<LocationPermissionStatus>((ref) async {
  return ref.read(mapsRepositoryProvider).checkLocationPermission();
});

final currentLocationProvider = FutureProvider<MapCoordinate?>((ref) async {
  final permission = await ref.read(locationPermissionProvider.future);
  if (!permission.isGranted) return null;

  try {
    return await ref.read(mapsRepositoryProvider).getCurrentLocation();
  } catch (_) {
    return ref.read(mapsRepositoryProvider).getLastKnownLocation();
  }
});

final savedCoordinatesProvider = FutureProvider<List<SavedCoordinate>>((ref) async {
  return ref.read(mapsRepositoryProvider).getSavedCoordinates();
});

class MapSelectionState {
  const MapSelectionState({
    this.selected,
    this.currentLocation,
    this.permission = LocationPermissionStatus.unknown,
    this.isLoadingLocation = false,
  });

  final MapCoordinate? selected;
  final MapCoordinate? currentLocation;
  final LocationPermissionStatus permission;
  final bool isLoadingLocation;

  MapSelectionState copyWith({
    MapCoordinate? selected,
    MapCoordinate? currentLocation,
    LocationPermissionStatus? permission,
    bool? isLoadingLocation,
    bool clearSelected = false,
  }) {
    return MapSelectionState(
      selected: clearSelected ? null : (selected ?? this.selected),
      currentLocation: currentLocation ?? this.currentLocation,
      permission: permission ?? this.permission,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
    );
  }
}

class MapSelectionNotifier extends StateNotifier<MapSelectionState> {
  MapSelectionNotifier(this._repository) : super(const MapSelectionState());

  final MapsRepository _repository;

  Future<void> initialize() async {
    try {
      final permission = await _repository.checkLocationPermission();
      state = state.copyWith(permission: permission);

      if (permission.isGranted) {
        await refreshCurrentLocation();
      }
    } catch (_) {
      state = state.copyWith(
        permission: LocationPermissionStatus.unknown,
        isLoadingLocation: false,
      );
    }
  }

  Future<void> requestPermission() async {
    final permission = await _repository.requestLocationPermission();
    state = state.copyWith(permission: permission);
    if (permission.isGranted) {
      await refreshCurrentLocation();
    }
  }

  /// Sets the known current location and recenters-related UI state.
  void setCurrentLocation(MapCoordinate location) {
    state = state.copyWith(
      currentLocation: location,
      selected: location,
      permission: LocationPermissionStatus.granted,
      isLoadingLocation: false,
    );
  }

  Future<MapCoordinate?> refreshCurrentLocation() async {
    state = state.copyWith(isLoadingLocation: true);
    try {
      final location = await _repository.getCurrentLocation();
      state = state.copyWith(
        currentLocation: location,
        selected: location,
        isLoadingLocation: false,
        permission: LocationPermissionStatus.granted,
      );
      return location;
    } catch (_) {
      final lastKnown = await _repository.getLastKnownLocation();
      state = state.copyWith(
        currentLocation: lastKnown,
        selected: lastKnown,
        isLoadingLocation: false,
      );
      return lastKnown;
    }
  }

  void selectCoordinate(MapCoordinate coordinate) {
    state = state.copyWith(selected: coordinate);
  }

  void selectFromLatLng(LatLng latLng) {
    selectCoordinate(MapCoordinate(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    ));
  }

  void clearSelection() {
    state = state.copyWith(clearSelected: true);
  }

  Future<void> saveSelected({required String label}) async {
    final selected = state.selected;
    if (selected == null) return;
    await _repository.saveCoordinate(label: label, coordinate: selected);
  }
}

final mapSelectionProvider =
    StateNotifierProvider<MapSelectionNotifier, MapSelectionState>((ref) {
  return MapSelectionNotifier(ref.read(mapsRepositoryProvider));
});

final nearbyParkingMarkersProvider =
    FutureProvider<List<MapMarkerData>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final ownerId = ref.watch(
    authStateProvider.select((state) => state.session?.userId ?? ''),
  );
  final filters = SearchFilters(
    userLatitude: location?.latitude,
    userLongitude: location?.longitude,
    vehicleOwnerId: ownerId.isEmpty ? null : ownerId,
  );

  final listings = await ref
      .read(vehicleOwnerRepositoryProvider)
      .searchParkingListings(filters);
  final mapsRepo = ref.read(mapsRepositoryProvider);

  final markers = listings.map(_listingToMarker).toList();

  if (location != null) {
    return mapsRepo.sortMarkersByDistance(origin: location, markers: markers);
  }
  return markers;
});

MapMarkerData _listingToMarker(ParkingListing listing) {
  return MapMarkerData(
    id: listing.id,
    coordinate: MapCoordinate(
      latitude: listing.latitude,
      longitude: listing.longitude,
    ),
    title: listing.displayName,
    snippet: listing.amountLabel != null
        ? '${listing.amountLabel} • ${listing.freeSlots}/${listing.capacity} slots'
        : '${listing.freeSlots}/${listing.capacity} slots',
    distanceKm: listing.distanceKm,
    payload: listing.id,
  );
}

final selectedMarkerProvider = StateProvider<MapMarkerData?>((ref) => null);

final directionsRequestProvider = Provider.family<DirectionsRequest, MapCoordinate>(
  (ref, destination) {
    final origin = ref.watch(mapSelectionProvider).currentLocation;
    return DirectionsRequest(destination: destination, origin: origin);
  },
);

Set<Marker> buildGoogleMarkers({
  required List<MapMarkerData> markers,
  MapCoordinate? selected,
  MapCoordinate? currentLocation,
  MapMarkerData? highlighted,
  void Function(MapMarkerData marker)? onTap,
}) {
  final result = <Marker>{};

  if (currentLocation != null) {
    result.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(currentLocation.latitude, currentLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    );
  }

  if (selected != null) {
    result.add(
      Marker(
        markerId: const MarkerId('selected_pin'),
        position: LatLng(selected.latitude, selected.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Selected Location'),
      ),
    );
  }

  for (final marker in markers) {
    final isHighlighted = highlighted?.id == marker.id;
    result.add(
      Marker(
        markerId: MarkerId(marker.id),
        position: LatLng(marker.coordinate.latitude, marker.coordinate.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isHighlighted ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: marker.title,
          snippet: marker.snippet,
        ),
        onTap: onTap != null ? () => onTap(marker) : null,
      ),
    );
  }

  return result;
}

LatLng? initialCameraTarget({
  MapCoordinate? selected,
  MapCoordinate? currentLocation,
  List<MapMarkerData>? markers,
}) {
  if (selected != null) {
    return LatLng(selected.latitude, selected.longitude);
  }
  if (currentLocation != null) {
    return LatLng(currentLocation.latitude, currentLocation.longitude);
  }
  if (markers != null && markers.isNotEmpty) {
    final first = markers.first.coordinate;
    return LatLng(first.latitude, first.longitude);
  }
  return const LatLng(20.5937, 78.9629);
}
