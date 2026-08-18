import 'package:equatable/equatable.dart';

class ParkingReview extends Equatable {
  const ParkingReview({
    required this.id,
    required this.parkingListingId,
    required this.vehicleOwnerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String parkingListingId;
  final String vehicleOwnerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        parkingListingId,
        vehicleOwnerId,
        reviewerName,
        rating,
        comment,
        createdAt,
      ];
}

class ParkingRatingSummary extends Equatable {
  const ParkingRatingSummary({
    required this.averageRating,
    required this.reviewCount,
    this.ratingBreakdown = const {},
  });

  final double averageRating;
  final int reviewCount;
  final Map<int, int> ratingBreakdown;

  @override
  List<Object?> get props => [averageRating, reviewCount, ratingBreakdown];
}
