import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class SavedCoordinate extends Equatable {
  const SavedCoordinate({
    required this.id,
    required this.label,
    required this.coordinate,
    required this.savedAt,
  });

  final String id;
  final String label;
  final MapCoordinate coordinate;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'coordinate': coordinate.toJson(),
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedCoordinate.fromJson(Map<String, dynamic> json) {
    return SavedCoordinate(
      id: json['id'] as String,
      label: json['label'] as String,
      coordinate: MapCoordinate.fromJson(
        json['coordinate'] as Map<String, dynamic>,
      ),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, label, coordinate, savedAt];
}
