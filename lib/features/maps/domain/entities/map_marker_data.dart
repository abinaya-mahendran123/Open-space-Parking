import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class MapMarkerData extends Equatable {
  const MapMarkerData({
    required this.id,
    required this.coordinate,
    required this.title,
    this.snippet,
    this.distanceKm,
    this.payload,
    this.availabilityTier = 2,
  });

  final String id;
  final MapCoordinate coordinate;
  final String title;
  final String? snippet;
  final double? distanceKm;
  final String? payload;

  /// 0 = full, 1 = limited, 2 = available (see AppColors.availabilityTier).
  final int availabilityTier;

  @override
  List<Object?> get props => [
        id,
        coordinate,
        title,
        snippet,
        distanceKm,
        payload,
        availabilityTier,
      ];
}
