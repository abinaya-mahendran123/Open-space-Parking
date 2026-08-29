import 'package:equatable/equatable.dart';

import 'package:open_space_parking/core/utils/text_format.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';

class ParkingListing extends Equatable {
  const ParkingListing({
    required this.id,
    required this.ticketId,
    required this.landOwnerId,
    required this.parkingType,
    required this.capacity,
    required this.latitude,
    required this.longitude,
    required this.areaSqFt,
    this.hourlyRate,
    this.parkingName,
    this.address,
    this.roadAccess = false,
    this.cctv = false,
    this.distanceKm,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.availableSlots,
    this.verifiedByEmployee = false,
    this.verifiedEmployeeName,
    this.isCompatible = true,
    this.isBestMatch = false,
    this.parkingStatus = 'approved',
  });

  final String id;
  final String ticketId;
  final String landOwnerId;
  final ParkingType parkingType;
  final int capacity;
  final double latitude;
  final double longitude;
  final double areaSqFt;
  /// Hourly amount from the verified ticket only; null if not set on the document.
  final double? hourlyRate;
  /// Display name from verified land/owner details.
  final String? parkingName;
  final String? address;
  final bool roadAccess;
  final bool cctv;
  final double? distanceKm;
  final double averageRating;
  final int reviewCount;
  final int? availableSlots;
  final bool verifiedByEmployee;
  final String? verifiedEmployeeName;
  final bool isCompatible;
  final bool isBestMatch;
  final String parkingStatus;

  String get parkingStatusLabel {
    switch (parkingStatus) {
      case 'approved':
        return 'Approved';
      case 'completed':
        return 'Active';
      default:
        return parkingStatus.replaceAll('_', ' ');
    }
  }

  String get compatibilityLabel => isCompatible ? 'Compatible' : 'Not compatible';

  String? get distanceLabel =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km away' : null;

  String get displayName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (ticketId.trim().isNotEmpty) return ticketId;
    if (address != null && address!.trim().isNotEmpty) return address!.trim();
    return 'Verified Parking';
  }

  /// Shorter label for list rows and detail headers.
  String get shortDisplayName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) {
      return compactDisplayName;
    }
    if (ticketId.trim().isNotEmpty) {
      return '${parkingType.label} · ${ticketId.trim()}';
    }
    return parkingType.label;
  }

  /// First part of the name (before comma) — for titles on small screens.
  String get compactDisplayName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) {
      final firstPart = name.split(',').first.trim();
      return truncateText(firstPart.isNotEmpty ? firstPart : name, 28);
    }
    if (ticketId.trim().isNotEmpty) {
      return truncateText(ticketId.trim(), 28);
    }
    return parkingType.label;
  }

  String get displayTitle => '$displayName — $ticketId';

  String get locationLabel =>
      address ?? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  /// Shorter address for compact UI (first line / first segments only).
  String get shortLocationLabel {
    final addr = address?.trim();
    if (addr == null || addr.isEmpty) {
      return '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}';
    }
    final parts = addr
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return truncateText('${parts[0]}, ${parts[1]}', 50);
    }
    return truncateText(addr, 50);
  }

  bool get hasVerifiedAmount => hourlyRate != null && hourlyRate! > 0;

  String? get amountLabel =>
      hasVerifiedAmount ? '₹${hourlyRate!.toStringAsFixed(0)}/hr' : null;

  List<String> get imageAssets {
    return [
      parkingType.imageAsset,
      if (cctv) 'assets/images/parking_types/${parkingType.value}.png',
    ];
  }

  bool get isAvailableNow => (availableSlots ?? capacity) > 0;

  int get freeSlots => availableSlots ?? capacity;

  /// High = green, medium = orange, none = red.
  ParkingAvailabilityLevel get availabilityLevel {
    final free = freeSlots;
    if (free <= 0) return ParkingAvailabilityLevel.none;
    if (capacity <= 0) return ParkingAvailabilityLevel.none;
    final ratio = free / capacity;
    if (ratio >= 0.5) return ParkingAvailabilityLevel.high;
    return ParkingAvailabilityLevel.medium;
  }

  ParkingListing copyWith({
    String? id,
    String? ticketId,
    int? capacity,
    double? distanceKm,
    double? averageRating,
    int? reviewCount,
    int? availableSlots,
    bool? isCompatible,
    bool? isBestMatch,
    String? parkingStatus,
  }) {
    return ParkingListing(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      landOwnerId: landOwnerId,
      parkingType: parkingType,
      capacity: capacity ?? this.capacity,
      latitude: latitude,
      longitude: longitude,
      areaSqFt: areaSqFt,
      hourlyRate: hourlyRate,
      parkingName: parkingName,
      address: address,
      roadAccess: roadAccess,
      cctv: cctv,
      distanceKm: distanceKm ?? this.distanceKm,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      availableSlots: availableSlots ?? this.availableSlots,
      verifiedByEmployee: verifiedByEmployee,
      verifiedEmployeeName: verifiedEmployeeName,
      isCompatible: isCompatible ?? this.isCompatible,
      isBestMatch: isBestMatch ?? this.isBestMatch,
      parkingStatus: parkingStatus ?? this.parkingStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ticketId,
        landOwnerId,
        parkingType,
        capacity,
        latitude,
        longitude,
        areaSqFt,
        hourlyRate,
        parkingName,
        address,
        roadAccess,
        cctv,
        distanceKm,
        averageRating,
        reviewCount,
        availableSlots,
        verifiedByEmployee,
        verifiedEmployeeName,
        isCompatible,
        isBestMatch,
        parkingStatus,
      ];
}

enum ParkingAvailabilityLevel {
  high,
  medium,
  none,
}
