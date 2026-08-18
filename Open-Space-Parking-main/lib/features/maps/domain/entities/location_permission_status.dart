enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

extension LocationPermissionStatusX on LocationPermissionStatus {
  bool get isGranted => this == LocationPermissionStatus.granted;

  String get label {
    switch (this) {
      case LocationPermissionStatus.granted:
        return 'Granted';
      case LocationPermissionStatus.denied:
        return 'Denied';
      case LocationPermissionStatus.deniedForever:
        return 'Denied Forever';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location Off';
      case LocationPermissionStatus.unknown:
        return 'Unknown';
    }
  }
}
