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
  });

  final String id;
  final MapCoordinate coordinate;
  final String title;
  final String? snippet;
  final double? distanceKm;
  final String? payload;

  @override
  List<Object?> get props => [id, coordinate, title, snippet, distanceKm, payload];
}
