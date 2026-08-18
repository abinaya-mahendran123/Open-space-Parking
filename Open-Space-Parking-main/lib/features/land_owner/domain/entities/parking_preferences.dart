import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';

class ParkingPreferences extends Equatable {
  const ParkingPreferences({
    required this.priority,
    required this.parkingType,
    required this.numberOfCars,
  });

  final RequestPriority priority;
  final ParkingType parkingType;
  final int numberOfCars;

  Map<String, dynamic> toJson() => {
        'priority': priority.value,
        'parkingType': parkingType.value,
        'numberOfCars': numberOfCars,
      };

  factory ParkingPreferences.fromJson(Map<String, dynamic> json) {
    return ParkingPreferences(
      priority: RequestPriorityX.fromValue(json['priority'] as String? ?? ''),
      parkingType: ParkingTypeX.fromValue(json['parkingType'] as String? ?? ''),
      numberOfCars: json['numberOfCars'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [priority, parkingType, numberOfCars];
}
