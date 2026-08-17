import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';

class SearchFilters extends Equatable {
  const SearchFilters({
    this.query,
    this.parkingType,
    this.maxDistanceKm,
    this.userLatitude,
    this.userLongitude,
  });

  final String? query;
  final ParkingType? parkingType;
  final double? maxDistanceKm;
  final double? userLatitude;
  final double? userLongitude;

  SearchFilters copyWith({
    String? query,
    ParkingType? parkingType,
    double? maxDistanceKm,
    double? userLatitude,
    double? userLongitude,
    bool clearQuery = false,
    bool clearParkingType = false,
    bool clearMaxDistance = false,
  }) {
    return SearchFilters(
      query: clearQuery ? null : (query ?? this.query),
      parkingType: clearParkingType ? null : (parkingType ?? this.parkingType),
      maxDistanceKm: clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
    );
  }

  bool get hasActiveFilters =>
      (query != null && query!.isNotEmpty) || maxDistanceKm != null;

  @override
  List<Object?> get props => [
        query,
        parkingType,
        maxDistanceKm,
        userLatitude,
        userLongitude,
      ];
}
