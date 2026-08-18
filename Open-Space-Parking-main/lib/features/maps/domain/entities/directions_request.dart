import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class DirectionsRequest extends Equatable {
  const DirectionsRequest({
    required this.destination,
    this.origin,
    this.travelMode = TravelMode.driving,
  });

  final MapCoordinate destination;
  final MapCoordinate? origin;
  final TravelMode travelMode;

  @override
  List<Object?> get props => [destination, origin, travelMode];
}

enum TravelMode { driving, walking, bicycling, transit }

extension TravelModeX on TravelMode {
  String get googleMapsValue {
    switch (this) {
      case TravelMode.driving:
        return 'driving';
      case TravelMode.walking:
        return 'walking';
      case TravelMode.bicycling:
        return 'bicycling';
      case TravelMode.transit:
        return 'transit';
    }
  }
}
