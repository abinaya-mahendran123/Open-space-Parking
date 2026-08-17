import 'package:flutter/material.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/directions_bar.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/google_map_view.dart';

/// Single parking location map — delegates to the Google Maps module.
class ParkingMapWidget extends StatelessWidget {
  const ParkingMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.title,
    this.height = 200,
    this.showDirections = true,
  });

  final double latitude;
  final double longitude;
  final String? title;
  final double height;
  final bool showDirections;

  @override
  Widget build(BuildContext context) {
    final coordinate = MapCoordinate(latitude: latitude, longitude: longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoogleMapView(
          height: height,
          showCurrentLocation: true,
          initialZoom: 15,
          markers: [
            MapMarkerData(
              id: 'parking',
              coordinate: coordinate,
              title: title ?? 'Parking Location',
            ),
          ],
        ),
        if (showDirections) ...[
          const SizedBox(height: 12),
          DirectionsBar(
            destination: coordinate,
            destinationLabel: title,
          ),
        ],
      ],
    );
  }
}
