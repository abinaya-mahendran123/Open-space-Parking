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
    this.parkingName,
    this.assignedSlot,
    this.qrPayload,
    this.sessionId,
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
  final String? parkingName;
  final int? assignedSlot;
  final String? qrPayload;
  final String? sessionId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final double? actualDurationHours;
  final double? amountDue;
  final double? paidAmount;
  final String? paymentId;
  final DateTime? paidAt;

  bool get hasQr => (qrPayload ?? bookingRef).isNotEmpty;

  /// Slot booked, waiting for security entry scan.
  bool get isAwaitingEntry =>
      status == BookingStatus.confirmed && checkedInAt == null;

  /// Parking timer is running after first security scan.
  bool get isParked =>
      status == BookingStatus.active &&
      checkedInAt != null &&
      checkedOutAt == null;

  /// Second scan done; driver must pay to release slot.
  bool get isAwaitingPayment =>
      status == BookingStatus.active &&
      checkedOutAt != null &&
      amountDue != null &&
      paidAt == null;

  /// QR stays on the driver phone from slot assignment until payment completes.
  bool get isQrLive =>
      hasQr &&
      paidAt == null &&
      status != BookingStatus.completed &&
      status != BookingStatus.cancelled;

  String get displayQr => qrPayload ?? bookingRef;

  String get displayParkingName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final address = parkingAddress?.trim();
    if (address != null && address.isNotEmpty) return address;
    return parkingType.label;
  }

  String get displaySessionId {
    final id = sessionId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return bookingRef;
  }

  String elapsedClock([DateTime? now]) {
    final start = checkedInAt;
    if (start == null) return '--:--';
    final end = checkedOutAt ?? now ?? DateTime.now();
    var seconds = end.difference(start).inSeconds;
    if (seconds < 0) seconds = 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  String get billedDurationLabel {
    if (checkedInAt != null && checkedOutAt != null) {
      var seconds = checkedOutAt!.difference(checkedInAt!).inSeconds;
      if (seconds < 0) seconds = 0;
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      if (h > 0) {
        if (m == 0) return '$h hr';
        return '$h hr $m min';
      }
      if (m > 0) {
        if (s == 0) return '$m min';
        return '$m min $s sec';
      }
      return '$s sec';
    }

    final hours = actualDurationHours;
    if (hours == null) return elapsedClock();
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h <= 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

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
        parkingName,
        assignedSlot,
        qrPayload,
        sessionId,
        checkedInAt,
        checkedOutAt,
        actualDurationHours,
        amountDue,
        paidAmount,
        paymentId,
        paidAt,
      ];
}
