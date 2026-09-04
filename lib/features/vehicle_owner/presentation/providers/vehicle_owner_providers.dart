import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/favorite_parking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_review.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/search_filters.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_notification.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/repositories/vehicle_owner_repository.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

final vehicleOwnerRepositoryProvider = Provider<VehicleOwnerRepository>(
  (ref) => sl<VehicleOwnerRepository>(),
);

final vehicleOwnerNotificationRepositoryProvider =
    Provider<VehicleOwnerNotificationRepository>(
  (ref) => sl<VehicleOwnerNotificationRepository>(),
);

final searchFiltersProvider = StateProvider<SearchFilters>(
  (ref) => const SearchFilters(),
);

final parkingListingsProvider = FutureProvider<List<ParkingListing>>((ref) async {
  ref.keepAlive();
  final filters = ref.watch(searchFiltersProvider);
  final ownerId = ref.watch(
    authStateProvider.select((state) => state.session?.userId ?? ''),
  );
  return ref.read(vehicleOwnerRepositoryProvider).searchParkingListings(
        filters.copyWith(
          vehicleOwnerId: ownerId.isEmpty ? null : ownerId,
        ),
      );
});

final parkingListingProvider =
    FutureProvider.family<ParkingListing?, String>((ref, listingId) async {
  ref.keepAlive();
  return ref.read(vehicleOwnerRepositoryProvider).getParkingListing(listingId);
});

final parkingAvailabilityProvider =
    FutureProvider.family<ParkingAvailability, String>((ref, listingId) async {
  ref.keepAlive();
  return ref.read(vehicleOwnerRepositoryProvider).getCurrentAvailability(listingId);
});

final parkingReviewsProvider =
    FutureProvider.family<List<ParkingReview>, String>((ref, listingId) async {
  ref.keepAlive();
  return ref.read(vehicleOwnerRepositoryProvider).getReviews(listingId);
});

final parkingRatingSummaryProvider =
    FutureProvider.family<ParkingRatingSummary, String>((ref, listingId) async {
  ref.keepAlive();
  return ref.read(vehicleOwnerRepositoryProvider).getRatingSummary(listingId);
});

final isFavoriteProvider = FutureProvider.family<bool, ({String ownerId, String listingId})>(
  (ref, params) async {
    ref.keepAlive();
    return ref.read(vehicleOwnerRepositoryProvider).isFavorite(
          vehicleOwnerId: params.ownerId,
          parkingListingId: params.listingId,
        );
  },
);

final favoritesProvider =
    FutureProvider.family<List<FavoriteParking>, String>((ref, vehicleOwnerId) async {
  ref.keepAlive();
  if (vehicleOwnerId.trim().isEmpty) return const [];
  return ref.read(vehicleOwnerRepositoryProvider).getFavorites(vehicleOwnerId);
});

final vehicleOwnerBookingsProvider =
    FutureProvider.family<List<Booking>, String>((ref, vehicleOwnerId) async {
  ref.keepAlive();
  if (vehicleOwnerId.trim().isEmpty) return const [];
  return ref.read(vehicleOwnerRepositoryProvider).getBookings(vehicleOwnerId);
});

final bookingDetailProvider =
    FutureProvider.family<Booking?, String>((ref, bookingId) async {
  ref.keepAlive();
  return ref.read(vehicleOwnerRepositoryProvider).getBooking(bookingId);
});

final vehicleOwnerProfileProvider =
    FutureProvider.family<VehicleOwnerProfile?, String>((ref, vehicleOwnerId) async {
  ref.keepAlive();
  if (vehicleOwnerId.trim().isEmpty) return null;
  return ref.read(vehicleOwnerRepositoryProvider).getProfile(vehicleOwnerId);
});

final vehicleOwnerNotificationsProvider =
    FutureProvider.family<List<VehicleOwnerNotification>, String>(
        (ref, vehicleOwnerId) async {
  ref.keepAlive();
  if (vehicleOwnerId.trim().isEmpty) return const [];
  return ref
      .read(vehicleOwnerNotificationRepositoryProvider)
      .getNotifications(vehicleOwnerId);
});

final vehicleOwnerUnreadCountProvider =
    FutureProvider.family<int, String>((ref, vehicleOwnerId) async {
  ref.keepAlive();
  if (vehicleOwnerId.trim().isEmpty) return 0;
  return ref.read(notificationRepositoryProvider).getUnreadCount(
        recipientId: vehicleOwnerId,
        recipientType: NotificationRecipientType.vehicleOwner,
      );
});

final vehicleOwnerLoadingProvider = StateProvider<bool>((ref) => false);

class BookingFormState {
  const BookingFormState({
    this.currentStep = 0,
    this.startDateTime,
    this.endDateTime,
    this.vehicleNumber = '',
    this.vehicleModel = '',
    this.parkingListingId,
    this.availabilityChecked = false,
    this.isAvailable = false,
  });

  final int currentStep;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String vehicleNumber;
  final String vehicleModel;
  final String? parkingListingId;
  final bool availabilityChecked;
  final bool isAvailable;

  static const int totalSteps = 3;

  BookingFormState copyWith({
    int? currentStep,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? vehicleNumber,
    String? vehicleModel,
    String? parkingListingId,
    bool? availabilityChecked,
    bool? isAvailable,
  }) {
    return BookingFormState(
      currentStep: currentStep ?? this.currentStep,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      parkingListingId: parkingListingId ?? this.parkingListingId,
      availabilityChecked: availabilityChecked ?? this.availabilityChecked,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class BookingFormNotifier extends StateNotifier<BookingFormState> {
  BookingFormNotifier() : super(const BookingFormState());

  void init(String parkingListingId) {
    state = BookingFormState(parkingListingId: parkingListingId);
  }

  void nextStep() {
    if (state.currentStep < BookingFormState.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setSchedule(DateTime start, DateTime end) {
    state = state.copyWith(
      startDateTime: start,
      endDateTime: end,
      availabilityChecked: false,
      isAvailable: false,
    );
  }

  void setAvailabilityResult(bool isAvailable) {
    state = state.copyWith(availabilityChecked: true, isAvailable: isAvailable);
  }

  void setVehicleNumber(String value) {
    state = state.copyWith(vehicleNumber: value);
  }

  void setVehicleModel(String value) {
    state = state.copyWith(vehicleModel: value);
  }

  void reset() {
    state = const BookingFormState();
  }
}

final bookingFormProvider =
    StateNotifierProvider<BookingFormNotifier, BookingFormState>(
  (ref) => BookingFormNotifier(),
);

double? estimatedBookingPrice(ParkingListing listing, BookingFormState form) {
  if (!listing.hasVerifiedAmount) return null;
  if (form.startDateTime == null || form.endDateTime == null) return null;
  if (!form.endDateTime!.isAfter(form.startDateTime!)) return null;
  final hours = form.endDateTime!.difference(form.startDateTime!).inMinutes / 60.0;
  if (hours < 0.5) return null;
  return (hours * listing.hourlyRate! * 100).ceil() / 100;
}
