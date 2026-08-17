import 'package:equatable/equatable.dart';

class MapCoordinate extends Equatable {
  const MapCoordinate({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;

  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  MapCoordinate copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    return MapCoordinate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  factory MapCoordinate.fromJson(Map<String, dynamic> json) {
    return MapCoordinate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, accuracyMeters, timestamp];
}
