import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.bookingRef,
    required this.vehicleOwnerId,
    required this.parkingListingId,
    required this.ticketId,
    required this.parkingType,
    required this.vehicleNumber,
    required this.startDateTime,
    required this.endDateTime,
    required this.durationHours,
    required this.hourlyRate,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.vehicleModel,
    this.parkingAddress,
    this.assignedSlot,
    this.qrPayload,
    this.checkedInAt,
    this.checkedOutAt,
    this.actualDurationHours,
    this.amountDue,
    this.paidAmount,
    this.paymentId,
    this.paidAt,
  });

  final String id;
  final String bookingRef;
  final String vehicleOwnerId;
  final String parkingListingId;
  final String ticketId;
  final ParkingType parkingType;
  final String vehicleNumber;
  final String? vehicleModel;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final double durationHours;
  final double hourlyRate;
  final double totalPrice;
  final BookingStatus status;
  final DateTime createdAt;
  final String? parkingAddress;
  final int? assignedSlot;
  final String? qrPayload;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final double? actualDurationHours;
  final double? amountDue;
  final double? paidAmount;
  final String? paymentId;
  final DateTime? paidAt;

  bool get hasQr => (qrPayload ?? bookingRef).isNotEmpty;
  bool get isAwaitingPayment =>
      status == BookingStatus.active &&
      checkedOutAt != null &&
      amountDue != null &&
      paidAt == null;
  bool get isParked =>
      status == BookingStatus.active && checkedOutAt == null;

  String get displayQr => qrPayload ?? bookingRef;

  @override
  List<Object?> get props => [
        id,
        bookingRef,
        vehicleOwnerId,
        parkingListingId,
        ticketId,
        parkingType,
        vehicleNumber,
        vehicleModel,
        startDateTime,
        endDateTime,
        durationHours,
        hourlyRate,
        totalPrice,
        status,
        createdAt,
        parkingAddress,
        assignedSlot,
        qrPayload,
        checkedInAt,
        checkedOutAt,
        actualDurationHours,
        amountDue,
        paidAmount,
        paymentId,
        paidAt,
      ];
}
