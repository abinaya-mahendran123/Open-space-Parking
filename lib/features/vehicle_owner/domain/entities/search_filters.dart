import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';

class SearchFilters extends Equatable {
  const SearchFilters({
    this.query,
    this.parkingType,
    this.maxDistanceKm,
    this.userLatitude,
    this.userLongitude,
    this.searchLatitude,
    this.searchLongitude,
    this.searchPlaceLabel,
    this.vehicleOwnerId,
  });

  final String? query;
  final ParkingType? parkingType;
  final double? maxDistanceKm;
  /// Device GPS (nearby-me).
  final double? userLatitude;
  final double? userLongitude;
  /// Geocoded place center (e.g. "T Nagar") for area search.
  final double? searchLatitude;
  final double? searchLongitude;
  final String? searchPlaceLabel;
  final String? vehicleOwnerId;

  /// Center used for distance sorting: typed place first, else GPS.
  double? get distanceCenterLatitude => searchLatitude ?? userLatitude;
  double? get distanceCenterLongitude => searchLongitude ?? userLongitude;

  SearchFilters copyWith({
    String? query,
    ParkingType? parkingType,
    double? maxDistanceKm,
    double? userLatitude,
    double? userLongitude,
    double? searchLatitude,
    double? searchLongitude,
    String? searchPlaceLabel,
    String? vehicleOwnerId,
    bool clearQuery = false,
    bool clearParkingType = false,
    bool clearMaxDistance = false,
    bool clearSearchLocation = false,
  }) {
    return SearchFilters(
      query: clearQuery ? null : (query ?? this.query),
      parkingType: clearParkingType ? null : (parkingType ?? this.parkingType),
      maxDistanceKm:
          clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      searchLatitude: clearSearchLocation
          ? null
          : (searchLatitude ?? this.searchLatitude),
      searchLongitude: clearSearchLocation
          ? null
          : (searchLongitude ?? this.searchLongitude),
      searchPlaceLabel: clearSearchLocation
          ? null
          : (searchPlaceLabel ?? this.searchPlaceLabel),
      vehicleOwnerId: vehicleOwnerId ?? this.vehicleOwnerId,
    );
  }

  bool get hasActiveFilters =>
      (query != null && query!.isNotEmpty) ||
      maxDistanceKm != null ||
      searchLatitude != null;

  @override
  List<Object?> get props => [
        query,
        parkingType,
        maxDistanceKm,
        userLatitude,
        userLongitude,
        searchLatitude,
        searchLongitude,
        searchPlaceLabel,
        vehicleOwnerId,
      ];
}
