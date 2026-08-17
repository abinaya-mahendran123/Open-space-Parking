import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';

class ParkingPreferences extends Equatable {
  const ParkingPreferences({
    required this.priority,
    required this.parkingType,
    required this.numberOfCars,
    this.hourlyRate,
  });

  final RequestPriority priority;
  final ParkingType parkingType;
  final int numberOfCars;
  /// Hourly parking amount entered on the ticket (₹/hr). Null if not provided.
  final double? hourlyRate;

  Map<String, dynamic> toJson() => {
        'priority': priority.value,
        'parkingType': parkingType.value,
        'numberOfCars': numberOfCars,
        if (hourlyRate != null) 'hourlyRate': hourlyRate,
      };

  factory ParkingPreferences.fromJson(Map<String, dynamic> json) {
    final rate = json['hourlyRate'] ?? json['amountPerHour'] ?? json['parkingFee'];
    return ParkingPreferences(
      priority: RequestPriorityX.fromValue(json['priority'] as String? ?? ''),
      parkingType: ParkingTypeX.fromValue(json['parkingType'] as String? ?? ''),
      numberOfCars: (json['numberOfCars'] is num)
          ? (json['numberOfCars'] as num).round()
          : int.tryParse('${json['numberOfCars'] ?? ''}') ?? 0,
      hourlyRate: rate is num && rate > 0 ? rate.toDouble() : null,
    );
  }

  @override
  List<Object?> get props => [priority, parkingType, numberOfCars, hourlyRate];
}
