import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';

class FavoriteParking extends Equatable {
  const FavoriteParking({
    required this.id,
    required this.vehicleOwnerId,
    required this.parkingListingId,
    required this.createdAt,
    this.listing,
  });

  final String id;
  final String vehicleOwnerId;
  final String parkingListingId;
  final DateTime createdAt;
  final ParkingListing? listing;

  @override
  List<Object?> get props => [id, vehicleOwnerId, parkingListingId, createdAt, listing];
}
