import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/favorite_parking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_review.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/search_filters.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_notification.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';

abstract class VehicleOwnerRepository {
  Future<List<ParkingListing>> searchParkingListings(SearchFilters filters);

  Future<ParkingListing?> getParkingListing(String listingId);

  Future<ParkingAvailability> checkAvailability({
    required String parkingListingId,
    required DateTime startDateTime,
    required DateTime endDateTime,
  });

  Future<ParkingAvailability> getCurrentAvailability(String parkingListingId);

  Future<Booking> createBooking({
    required String vehicleOwnerId,
    required String parkingListingId,
    required String vehicleNumber,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? vehicleModel,
  });

  /// Walk-in: assign first free slot, start active session, generate QR.
  Future<Booking> startParkingSession({
    required String vehicleOwnerId,
    required String parkingListingId,
    required String vehicleNumber,
    String? vehicleModel,
  });

  Future<Booking?> getBookingByQr(String qrPayload);

  /// Security scan: set checkout time and bill from actual duration.
  Future<Booking> scanQrForCheckout(String qrPayload);

  Future<Booking> payAndCompleteBooking({
    required String bookingId,
    required String paymentMethod,
  });

  Future<List<Booking>> getBookings(String vehicleOwnerId);

  Future<Booking?> getBooking(String bookingId);

  Future<void> cancelBooking(String bookingId);

  Future<List<FavoriteParking>> getFavorites(String vehicleOwnerId);

  Future<bool> isFavorite({
    required String vehicleOwnerId,
    required String parkingListingId,
  });

  Future<void> toggleFavorite({
    required String vehicleOwnerId,
    required String parkingListingId,
  });

  Future<List<ParkingReview>> getReviews(String parkingListingId);

  Future<ParkingRatingSummary> getRatingSummary(String parkingListingId);

  Future<ParkingReview> submitReview({
    required String parkingListingId,
    required String vehicleOwnerId,
    required String reviewerName,
    required int rating,
    required String comment,
  });

  Future<VehicleOwnerProfile?> getProfile(String vehicleOwnerId);

  Future<void> updateProfile({
    required String vehicleOwnerId,
    required VehicleOwnerProfile profile,
  });
}

abstract class VehicleOwnerNotificationRepository {
  Future<List<VehicleOwnerNotification>> getNotifications(String vehicleOwnerId);

  Future<void> markAsRead(String notificationId);

  Future<int> getUnreadCount(String vehicleOwnerId);
}
