import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/domain/entities/saved_coordinate.dart';

abstract class MapsRepository {
  Future<LocationPermissionStatus> checkLocationPermission();

  Future<LocationPermissionStatus> requestLocationPermission();

  Future<bool> isLocationServiceEnabled();

  Future<void> openLocationSettings();

  Future<void> openAppSettings();

  Future<MapCoordinate> getCurrentLocation();

  Future<MapCoordinate?> getLastKnownLocation();

  double distanceKmBetween(MapCoordinate from, MapCoordinate to);

  Future<void> saveCoordinate({
    required String label,
    required MapCoordinate coordinate,
  });

  Future<List<SavedCoordinate>> getSavedCoordinates();

  Future<void> deleteSavedCoordinate(String id);

  Future<SavedCoordinate?> getSavedCoordinate(String id);

  String buildDirectionsUrl(DirectionsRequest request);

  String buildNavigationUrl(DirectionsRequest request);

  Future<bool> openDirections(DirectionsRequest request);

  Future<bool> openNavigation(DirectionsRequest request);

  Future<bool> openLocationInMaps(MapCoordinate coordinate, {String? label});

  List<MapMarkerData> sortMarkersByDistance({
    required MapCoordinate origin,
    required List<MapMarkerData> markers,
  });

  Future<GeocodingResult> geocodeLocationName(String locationName);

  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}
