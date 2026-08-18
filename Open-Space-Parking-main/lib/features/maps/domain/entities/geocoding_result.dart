import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class GeocodingResult extends Equatable {
  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final double latitude;
  final double longitude;
  final String displayName;

  MapCoordinate get coordinate => MapCoordinate(
        latitude: latitude,
        longitude: longitude,
      );

  @override
  List<Object?> get props => [latitude, longitude, displayName];
}
