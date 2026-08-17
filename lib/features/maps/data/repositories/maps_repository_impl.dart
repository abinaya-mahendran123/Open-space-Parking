import 'package:open_space_parking/core/utils/geo_utils.dart' as geo;
import 'package:open_space_parking/features/maps/data/services/geocoding_service.dart';
import 'package:open_space_parking/features/maps/data/services/google_maps_navigation_service.dart';
import 'package:open_space_parking/features/maps/data/services/location_service.dart';
import 'package:open_space_parking/features/maps/data/services/saved_coordinates_storage_service.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/domain/entities/saved_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/repositories/maps_repository.dart';

class MapsRepositoryImpl implements MapsRepository {
  MapsRepositoryImpl({
    required LocationService locationService,
    required GoogleMapsNavigationService navigationService,
    required SavedCoordinatesStorageService savedCoordinatesStorage,
    required GeocodingService geocodingService,
  })  : _locationService = locationService,
        _navigationService = navigationService,
        _savedCoordinatesStorage = savedCoordinatesStorage,
        _geocodingService = geocodingService;

  final LocationService _locationService;
  final GoogleMapsNavigationService _navigationService;
  final SavedCoordinatesStorageService _savedCoordinatesStorage;
  final GeocodingService _geocodingService;

  @override
  Future<LocationPermissionStatus> checkLocationPermission() {
    return _locationService.checkPermission();
  }

  @override
  Future<LocationPermissionStatus> requestLocationPermission() {
    return _locationService.requestPermission();
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return _locationService.isServiceEnabled();
  }

  @override
  Future<void> openLocationSettings() {
    return _locationService.openLocationSettings();
  }

  @override
  Future<void> openAppSettings() {
    return _locationService.openAppSettings();
  }

  @override
  Future<MapCoordinate> getCurrentLocation() {
    return _locationService.getCurrentPosition();
  }

  @override
  Future<MapCoordinate?> getLastKnownLocation() {
    return _locationService.getLastKnownPosition();
  }

  @override
  double distanceKmBetween(MapCoordinate from, MapCoordinate to) {
    return geo.distanceKmBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  @override
  Future<void> saveCoordinate({
    required String label,
    required MapCoordinate coordinate,
  }) async {
    await _savedCoordinatesStorage.save(label: label, coordinate: coordinate);
  }

  @override
  Future<List<SavedCoordinate>> getSavedCoordinates() {
    return _savedCoordinatesStorage.getAll();
  }

  @override
  Future<void> deleteSavedCoordinate(String id) {
    return _savedCoordinatesStorage.delete(id);
  }

  @override
  Future<SavedCoordinate?> getSavedCoordinate(String id) {
    return _savedCoordinatesStorage.getById(id);
  }

  @override
  String buildDirectionsUrl(DirectionsRequest request) {
    return _navigationService.buildDirectionsUrl(request);
  }

  @override
  String buildNavigationUrl(DirectionsRequest request) {
    return _navigationService.buildNavigationUrl(request);
  }

  @override
  Future<bool> openDirections(DirectionsRequest request) {
    return _navigationService.openDirections(request);
  }

  @override
  Future<bool> openNavigation(DirectionsRequest request) {
    return _navigationService.openNavigation(request);
  }

  @override
  Future<bool> openLocationInMaps(MapCoordinate coordinate, {String? label}) {
    return _navigationService.openLocation(coordinate, label: label);
  }

  @override
  List<MapMarkerData> sortMarkersByDistance({
    required MapCoordinate origin,
    required List<MapMarkerData> markers,
  }) {
    final sorted = markers.map((marker) {
      final distance = distanceKmBetween(origin, marker.coordinate);
      return MapMarkerData(
        id: marker.id,
        coordinate: marker.coordinate,
        title: marker.title,
        snippet: marker.snippet,
        distanceKm: distance,
        payload: marker.payload,
      );
    }).toList();

    sorted.sort((a, b) => (a.distanceKm ?? double.infinity)
        .compareTo(b.distanceKm ?? double.infinity));
    return sorted;
  }

  @override
  Future<GeocodingResult> geocodeLocationName(String locationName) {
    return _geocodingService.geocode(locationName);
  }

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return _geocodingService.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
