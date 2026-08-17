import 'package:url_launcher/url_launcher.dart';

import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class GoogleMapsNavigationService {
  String buildDirectionsUrl(DirectionsRequest request) {
    final dest =
        '${request.destination.latitude},${request.destination.longitude}';

    if (request.origin == null) {
      return 'https://www.google.com/maps/dir/?api=1'
          '&destination=$dest'
          '&travelmode=${request.travelMode.googleMapsValue}';
    }

    final origin =
        '${request.origin!.latitude},${request.origin!.longitude}';
    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=$origin'
        '&destination=$dest'
        '&travelmode=${request.travelMode.googleMapsValue}';
  }

  String buildNavigationUrl(DirectionsRequest request) {
    final dest =
        '${request.destination.latitude},${request.destination.longitude}';

    if (request.origin == null) {
      return 'google.navigation:q=$dest&mode=${request.travelMode.googleMapsValue}';
    }

    return buildDirectionsUrl(request);
  }

  String buildSearchUrl(MapCoordinate coordinate, {String? label}) {
    final query = label != null && label.isNotEmpty
        ? Uri.encodeComponent(label)
        : '${coordinate.latitude},${coordinate.longitude}';
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<bool> openDirections(DirectionsRequest request) {
    return openUrl(buildDirectionsUrl(request));
  }

  Future<bool> openNavigation(DirectionsRequest request) {
    return openUrl(buildNavigationUrl(request));
  }

  Future<bool> openLocation(MapCoordinate coordinate, {String? label}) {
    return openUrl(buildSearchUrl(coordinate, label: label));
  }
}
