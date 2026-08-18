import 'package:equatable/equatable.dart';

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
    required this.hourlyRate,
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
  });

  final String id;
  final String ticketId;
  final String landOwnerId;
  final ParkingType parkingType;
  final int capacity;
  final double latitude;
  final double longitude;
  final double areaSqFt;
  final double hourlyRate;
  /// Display name for the parking area (address or type + ticket).
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

  String get displayName {
    final name = parkingName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (address != null && address!.trim().isNotEmpty) return address!.trim();
    return '${parkingType.label} Parking';
  }

  String get displayTitle => '$displayName — $ticketId';

  String get locationLabel =>
      address ?? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  /// Gallery images for the parking space (type image + amenity visuals).
  List<String> get imageAssets {
    return [
      parkingType.imageAsset,
      if (cctv) 'assets/images/parking_types/${parkingType.value}.png',
      if (roadAccess) parkingType.imageAsset,
    ].toSet().toList();
  }

  bool get isAvailableNow => (availableSlots ?? capacity) > 0;

  ParkingListing copyWith({
    double? distanceKm,
    double? averageRating,
    int? reviewCount,
    int? availableSlots,
  }) {
    return ParkingListing(
      id: id,
      ticketId: ticketId,
      landOwnerId: landOwnerId,
      parkingType: parkingType,
      capacity: capacity,
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
      ];
}
