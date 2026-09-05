import 'package:equatable/equatable.dart';

import 'package:open_space_parking/core/utils/text_format.dart';
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
    this.qrExpiresAt,
    this.sessionId,
    this.checkedInAt,
    this.checkedOutAt,
    this.actualDurationHours,
    this.amountDue,
    this.paidAmount,
    this.paymentId,
    this.paidAt,
  });

  /// Entry QR must be scanned within this window or the booking is cancelled.
  static const Duration entryQrValidity = Duration(hours: 2);

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
  final DateTime? qrExpiresAt;
  final String? sessionId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final double? actualDurationHours;
  final double? amountDue;
  final double? paidAmount;
  final String? paymentId;
  final DateTime? paidAt;

  bool get hasQr => (qrPayload ?? bookingRef).isNotEmpty;

  /// Effective entry-QR deadline (defaults to createdAt + 2h).
  DateTime get entryQrDeadline =>
      qrExpiresAt ?? createdAt.add(entryQrValidity);

  /// Slot booked, waiting for security entry scan (and QR still valid).
  bool get isAwaitingEntry =>
      status == BookingStatus.confirmed &&
      checkedInAt == null &&
      !isEntryQrExpired;

  bool get isEntryQrExpired {
    if (checkedInAt != null) return false;
    if (status != BookingStatus.confirmed) return false;
    return DateTime.now().isAfter(entryQrDeadline);
  }

  Duration entryQrRemaining([DateTime? now]) {
    final end = entryQrDeadline;
    final remaining = end.difference(now ?? DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  String entryQrCountdownLabel([DateTime? now]) {
    final remaining = entryQrRemaining(now);
    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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

  /// QR shown on driver phone: valid entry QR, or after check-in until payment.
  bool get isQrLive {
    if (!hasQr) return false;
    if (paidAt != null) return false;
    if (status == BookingStatus.completed ||
        status == BookingStatus.cancelled) {
      return false;
    }
    if (status == BookingStatus.confirmed && checkedInAt == null) {
      return !isEntryQrExpired;
    }
    return true;
  }

  String get displayQr => qrPayload ?? bookingRef;

  String get displayParkingName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final address = parkingAddress?.trim();
    if (address != null && address.isNotEmpty) return address;
    return parkingType.label;
  }

  String get shortDisplayParkingName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) {
      return truncateText(name, 36);
    }
    if (ticketId.trim().isNotEmpty) {
      return '${parkingType.label} · ${ticketId.trim()}';
    }
    return parkingType.label;
  }

  String? get shortParkingAddress {
    final addr = parkingAddress?.trim();
    if (addr == null || addr.isEmpty) return null;
    final parts = addr
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return truncateText('${parts[0]}, ${parts[1]}', 48);
    }
    return truncateText(addr, 48);
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
        qrExpiresAt,
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
