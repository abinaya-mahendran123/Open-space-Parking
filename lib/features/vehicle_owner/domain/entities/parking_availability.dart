import 'package:equatable/equatable.dart';

class ParkingAvailability extends Equatable {
  const ParkingAvailability({
    required this.totalSlots,
    required this.bookedSlots,
    required this.availableSlots,
    required this.isAvailable,
  });

  final int totalSlots;
  final int bookedSlots;
  final int availableSlots;
  final bool isAvailable;

  double get occupancyPercent =>
      totalSlots > 0 ? (bookedSlots / totalSlots) * 100 : 0;

  @override
  List<Object?> get props =>
      [totalSlots, bookedSlots, availableSlots, isAvailable];
}
