import 'package:equatable/equatable.dart';

class VehicleOwnerNotification extends Equatable {
  const VehicleOwnerNotification({
    required this.id,
    required this.vehicleOwnerId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.bookingRef,
  });

  final String id;
  final String vehicleOwnerId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? bookingRef;

  @override
  List<Object?> get props => [
        id,
        vehicleOwnerId,
        title,
        message,
        createdAt,
        isRead,
        bookingRef,
      ];
}
