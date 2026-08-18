import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/integration/notification_helper.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/utils/geo_utils.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/favorite_parking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_review.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/search_filters.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_notification.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/repositories/vehicle_owner_repository.dart';

class MongoVehicleOwnerRepository implements VehicleOwnerRepository {
  MongoVehicleOwnerRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
    required NotificationHelper notificationHelper,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService,
        _notificationHelper = notificationHelper;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;
  final NotificationHelper _notificationHelper;

  static const _hourlyRates = {
    ParkingType.towerParking: 60.0,
    ParkingType.shuttleParking: 50.0,
    ParkingType.hydraulicStack2Post: 45.0,
    ParkingType.hydraulicStack4Post: 55.0,
    ParkingType.pitStackParking: 40.0,
    ParkingType.puzzleParking: 65.0,
  };

  @override
  Future<List<ParkingListing>> searchParkingListings(SearchFilters filters) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.oneFrom('status', [
        RequestStatus.completed.value,
        RequestStatus.approved.value,
      ]),
    );

    var listings = results
        .where(_isListableRequest)
        .map(_mapRequestToListing)
        .toList();

    if (filters.parkingType != null) {
      listings = listings
          .where((l) => l.parkingType == filters.parkingType)
          .toList();
    }

    if (filters.query != null && filters.query!.trim().isNotEmpty) {
      final q = filters.query!.trim().toLowerCase();
      listings = listings.where((l) {
        return l.displayName.toLowerCase().contains(q) ||
            l.displayTitle.toLowerCase().contains(q) ||
            l.ticketId.toLowerCase().contains(q) ||
            l.parkingType.label.toLowerCase().contains(q) ||
            (l.address?.toLowerCase().contains(q) ?? false) ||
            (l.verifiedEmployeeName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (filters.userLatitude != null && filters.userLongitude != null) {
      listings = listings.map((listing) {
        final distance = distanceKmBetween(
          filters.userLatitude!,
          filters.userLongitude!,
          listing.latitude,
          listing.longitude,
        );
        return listing.copyWith(distanceKm: distance);
      }).toList();

      if (filters.maxDistanceKm != null) {
        listings = listings
            .where((l) => (l.distanceKm ?? double.infinity) <= filters.maxDistanceKm!)
            .toList();
      }

      listings.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
    }

    return _enrichListings(listings);
  }

  Future<List<ParkingListing>> _enrichListings(List<ParkingListing> listings) async {
    final enriched = <ParkingListing>[];
    for (final listing in listings) {
      final summary = await getRatingSummary(listing.id);
      final availability =
          await _getCurrentAvailabilityRaw(listing.id, listing.capacity);
      enriched.add(listing.copyWith(
        averageRating: summary.averageRating,
        reviewCount: summary.reviewCount,
        availableSlots: availability.availableSlots,
      ));
    }
    return enriched;
  }

  @override
  Future<ParkingListing?> getParkingListing(String listingId) async {
    await _ensureConnected();

    final listing = await _getBaseListing(listingId);
    if (listing == null) return null;

    final summary = await getRatingSummary(listingId);
    final availability = await _getCurrentAvailabilityRaw(listingId, listing.capacity);
    return listing.copyWith(
      averageRating: summary.averageRating,
      reviewCount: summary.reviewCount,
      availableSlots: availability.availableSlots,
    );
  }

  Future<ParkingListing?> _getBaseListing(String listingId) async {
    final doc = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(_normalizeObjectId(listingId))),
    );

    if (doc == null || !_isListableRequest(doc)) return null;
    return _mapRequestToListing(doc);
  }

  String _normalizeObjectId(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') && trimmed.contains('\$oid')) {
      final match = RegExp(r'\$oid["\s:]+([a-fA-F0-9]{24})').firstMatch(trimmed);
      if (match != null) return match.group(1)!;
    }
    return trimmed;
  }

  @override
  Future<ParkingAvailability> checkAvailability({
    required String parkingListingId,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) async {
    final listing = await _getBaseListing(parkingListingId);
    if (listing == null) {
      throw const AppException('Parking space not found.');
    }

    final overlapping = await _countOverlappingBookings(
      parkingListingId: parkingListingId,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );

    final available = listing.capacity - overlapping;
    return ParkingAvailability(
      totalSlots: listing.capacity,
      bookedSlots: overlapping,
      availableSlots: available.clamp(0, listing.capacity),
      isAvailable: available > 0,
    );
  }

  @override
  Future<ParkingAvailability> getCurrentAvailability(String parkingListingId) async {
    final listing = await _getBaseListing(parkingListingId);
    if (listing == null) {
      throw const AppException('Parking space not found.');
    }
    return _getCurrentAvailabilityRaw(parkingListingId, listing.capacity);
  }

  Future<ParkingAvailability> _getCurrentAvailabilityRaw(
    String parkingListingId,
    int capacity,
  ) async {
    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(hours: 1));
    final overlapping = await _countOverlappingBookings(
      parkingListingId: parkingListingId,
      startDateTime: now,
      endDateTime: end,
    );
    final available = capacity - overlapping;
    return ParkingAvailability(
      totalSlots: capacity,
      bookedSlots: overlapping,
      availableSlots: available.clamp(0, capacity),
      isAvailable: available > 0,
    );
  }

  Future<int> _countOverlappingBookings({
    required String parkingListingId,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) async {
    await _ensureConnected();

    final bookings = await _collectionService.findMany(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('parkingListingId', parkingListingId),
    );

    final start = startDateTime.toUtc();
    final end = endDateTime.toUtc();

    return bookings.where((doc) {
      final status = BookingStatusX.fromValue(doc['status'] as String? ?? '');
      if (status == BookingStatus.cancelled ||
          status == BookingStatus.completed) {
        return false;
      }
      // Active park sessions occupy a slot until payment completes.
      if (status == BookingStatus.active) return true;

      final bStart = DateTime.parse(doc['startDateTime'] as String);
      final bEnd = DateTime.parse(doc['endDateTime'] as String);
      return bStart.isBefore(end) && bEnd.isAfter(start);
    }).length;
  }

  Future<int> _allocateNextSlot({
    required String parkingListingId,
    required int capacity,
  }) async {
    final bookings = await _collectionService.findMany(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('parkingListingId', parkingListingId),
    );

    final used = <int>{};
    for (final doc in bookings) {
      final status = BookingStatusX.fromValue(doc['status'] as String? ?? '');
      if (status == BookingStatus.cancelled ||
          status == BookingStatus.completed) {
        continue;
      }
      final slot = doc['assignedSlot'];
      if (slot is int) used.add(slot);
      if (slot is num) used.add(slot.toInt());
    }

    for (var i = 1; i <= capacity; i++) {
      if (!used.contains(i)) return i;
    }
    throw const AppException('No parking slots available right now.');
  }

  @override
  Future<Booking> startParkingSession({
    required String vehicleOwnerId,
    required String parkingListingId,
    required String vehicleNumber,
    String? vehicleModel,
  }) async {
    await _ensureConnected();

    final plate = vehicleNumber.trim().toUpperCase();
    if (plate.length < 4) {
      throw const AppException('Enter a valid vehicle number.');
    }

    final listing = await _getBaseListing(parkingListingId);
    if (listing == null) {
      throw const AppException('Parking space is no longer available.');
    }

    final availability =
        await _getCurrentAvailabilityRaw(parkingListingId, listing.capacity);
    if (!availability.isAvailable) {
      throw const AppException('No slots available at this parking.');
    }

    final slot = await _allocateNextSlot(
      parkingListingId: parkingListingId,
      capacity: listing.capacity,
    );

    final bookingId = ObjectId();
    final bookingRef = _generateBookingRef();
    final now = DateTime.now().toUtc();
    // Placeholder end until security checkout recalculates duration.
    final placeholderEnd = now.add(const Duration(hours: 12));

    final document = {
      '_id': bookingId,
      'bookingRef': bookingRef,
      'vehicleOwnerId': vehicleOwnerId,
      'parkingListingId': parkingListingId,
      'ticketId': listing.ticketId,
      'parkingType': listing.parkingType.value,
      'vehicleNumber': plate,
      'vehicleModel': vehicleModel?.trim(),
      'startDateTime': now.toIso8601String(),
      'endDateTime': placeholderEnd.toIso8601String(),
      'durationHours': 12.0,
      'hourlyRate': listing.hourlyRate,
      'totalPrice': 0.0,
      'status': BookingStatus.active.value,
      'parkingAddress': listing.address,
      'assignedSlot': slot,
      'qrPayload': bookingRef,
      'checkedInAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.bookingsCollection,
      document: document,
    );

    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: vehicleOwnerId,
      title: 'Slot Assigned',
      message:
          'Slot $slot assigned. Show QR ($bookingRef) at exit for checkout.',
      bookingRef: bookingRef,
    );

    return _mapBookingToEntity(document);
  }

  @override
  Future<Booking?> getBookingByQr(String qrPayload) async {
    await _ensureConnected();
    final code = qrPayload.trim();
    if (code.isEmpty) return null;

    final doc = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('qrPayload', code),
    );
    if (doc != null) return _mapBookingToEntity(doc);

    final byRef = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('bookingRef', code),
    );
    if (byRef == null) return null;
    return _mapBookingToEntity(byRef);
  }

  @override
  Future<Booking> scanQrForCheckout(String qrPayload) async {
    await _ensureConnected();

    final booking = await getBookingByQr(qrPayload);
    if (booking == null) {
      throw const AppException('QR / booking not found.');
    }
    if (booking.status != BookingStatus.active) {
      throw AppException(
        'Booking is ${booking.status.label.toLowerCase()}, not an active park session.',
      );
    }
    if (booking.checkedOutAt != null && booking.amountDue != null) {
      return booking;
    }

    final checkedIn = booking.checkedInAt ?? booking.startDateTime;
    final checkedOut = DateTime.now().toUtc();
    var minutes = checkedOut.difference(checkedIn.toUtc()).inMinutes;
    if (minutes < 1) minutes = 1;
    // Bill in 15-minute increments, minimum 1 hour equivalent fraction.
    final actualHours = (minutes / 60.0 * 100).ceil() / 100;
    final billedHours = actualHours < 0.25 ? 0.25 : actualHours;
    final amountDue =
        (billedHours * booking.hourlyRate * 100).ceil() / 100;

    await _collectionService.updateOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(booking.id)),
      modifier: modify
          .set('checkedOutAt', checkedOut.toIso8601String())
          .set('endDateTime', checkedOut.toIso8601String())
          .set('actualDurationHours', billedHours)
          .set('durationHours', billedHours)
          .set('amountDue', amountDue)
          .set('totalPrice', amountDue)
          .set('updatedAt', checkedOut.toIso8601String()),
    );

    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: booking.vehicleOwnerId,
      title: 'Ready to Pay',
      message:
          'Security scanned your QR. Pay ₹${amountDue.toStringAsFixed(0)} to complete checkout.',
      bookingRef: booking.bookingRef,
    );

    final updated = await getBooking(booking.id);
    if (updated == null) {
      throw const AppException('Could not load updated booking.');
    }
    return updated;
  }

  @override
  Future<Booking> payAndCompleteBooking({
    required String bookingId,
    required String paymentMethod,
  }) async {
    await _ensureConnected();

    final booking = await getBooking(bookingId);
    if (booking == null) {
      throw const AppException('Booking not found.');
    }
    if (booking.status != BookingStatus.active) {
      throw const AppException('Only active sessions can be paid.');
    }
    if (booking.amountDue == null || booking.checkedOutAt == null) {
      throw const AppException(
        'Ask security to scan your QR before payment.',
      );
    }

    final now = DateTime.now().toUtc();
    final paymentId = ObjectId();
    final amount = booking.amountDue!;

    await _collectionService.insertOne(
      collectionName: AppConstants.paymentsCollection,
      document: {
        '_id': paymentId,
        'bookingId': bookingId,
        'bookingRef': booking.bookingRef,
        'vehicleOwnerId': booking.vehicleOwnerId,
        'amount': amount,
        'method': paymentMethod,
        'status': 'paid',
        'createdAt': now.toIso8601String(),
      },
    );

    await _collectionService.updateOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(bookingId)),
      modifier: modify
          .set('status', BookingStatus.completed.value)
          .set('paidAmount', amount)
          .set('paymentId', paymentId.toHexString())
          .set('paidAt', now.toIso8601String())
          .set('updatedAt', now.toIso8601String()),
    );

    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: booking.vehicleOwnerId,
      title: 'Checkout Complete',
      message:
          'Payment of ₹${amount.toStringAsFixed(0)} received. Slot ${booking.assignedSlot ?? '-'} released.',
      bookingRef: booking.bookingRef,
    );

    final updated = await getBooking(bookingId);
    if (updated == null) {
      throw const AppException('Could not load receipt booking.');
    }
    return updated;
  }

  @override
  Future<Booking> createBooking({
    required String vehicleOwnerId,
    required String parkingListingId,
    required String vehicleNumber,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? vehicleModel,
  }) async {
    await _ensureConnected();

    if (!endDateTime.isAfter(startDateTime)) {
      throw const AppException('End time must be after start time.');
    }

    final listing = await _getBaseListing(parkingListingId);
    if (listing == null) {
      throw const AppException('Parking space is no longer available.');
    }

    final durationHours =
        endDateTime.difference(startDateTime).inMinutes / 60.0;
    if (durationHours < 0.5) {
      throw const AppException('Minimum booking duration is 30 minutes.');
    }

    final availability = await checkAvailability(
      parkingListingId: parkingListingId,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );
    if (!availability.isAvailable) {
      throw const AppException('No slots available for the selected time.');
    }

    final totalPrice = (durationHours * listing.hourlyRate * 100).ceil() / 100;
    final bookingId = ObjectId();
    final bookingRef = _generateBookingRef();
    final now = DateTime.now().toUtc();

    final document = {
      '_id': bookingId,
      'bookingRef': bookingRef,
      'vehicleOwnerId': vehicleOwnerId,
      'parkingListingId': parkingListingId,
      'ticketId': listing.ticketId,
      'parkingType': listing.parkingType.value,
      'vehicleNumber': vehicleNumber.trim().toUpperCase(),
      'vehicleModel': vehicleModel?.trim(),
      'startDateTime': startDateTime.toUtc().toIso8601String(),
      'endDateTime': endDateTime.toUtc().toIso8601String(),
      'durationHours': durationHours,
      'hourlyRate': listing.hourlyRate,
      'totalPrice': totalPrice,
      'status': BookingStatus.confirmed.value,
      'parkingAddress': listing.address,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.bookingsCollection,
      document: document,
    );

    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: vehicleOwnerId,
      title: 'Booking Confirmed',
      message:
          'Your booking $bookingRef at ${listing.parkingType.label} is confirmed.',
      bookingRef: bookingRef,
    );

    return _mapBookingToEntity(document);
  }

  @override
  Future<List<Booking>> getBookings(String vehicleOwnerId) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
    );

    results.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );

    return results.map(_mapBookingToEntity).toList();
  }

  @override
  Future<Booking?> getBooking(String bookingId) async {
    await _ensureConnected();

    final doc = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(bookingId)),
    );

    if (doc == null) return null;
    return _mapBookingToEntity(doc);
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _ensureConnected();

    final booking = await getBooking(bookingId);
    if (booking == null) {
      throw const AppException('Booking not found.');
    }

    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.cancelled) {
      throw const AppException('This booking cannot be cancelled.');
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(bookingId)),
      modifier: modify
          .set('status', BookingStatus.cancelled.value)
          .set('updatedAt', DateTime.now().toUtc().toIso8601String()),
    );

    await _collectionService.insertOne(
      collectionName: AppConstants.vehicleOwnerNotificationsCollection,
      document: {
        '_id': ObjectId(),
        'vehicleOwnerId': booking.vehicleOwnerId,
        'title': 'Booking Cancelled',
        'message': 'Your booking ${booking.bookingRef} has been cancelled.',
        'bookingRef': booking.bookingRef,
        'isRead': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<VehicleOwnerProfile?> getProfile(String vehicleOwnerId) async {
    await _ensureConnected();

    VehicleOwnerProfile? saved;
    final profile = await _collectionService.findOne(
      collectionName: AppConstants.vehicleOwnerProfilesCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
    );

    if (profile != null) {
      saved = VehicleOwnerProfile.fromJson(
        profile['profile'] as Map<String, dynamic>,
      );
    }

    final user = await _findUserAccount(vehicleOwnerId);
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: saved,
      accountDisplayName: user?['displayName'] as String?,
      accountEmail: user?['email'] as String?,
    );

    if (!ProfilePrefill.hasAnyVehicleProfile(merged)) return null;
    return merged;
  }

  Future<Map<String, dynamic>?> _findUserAccount(String userId) async {
    try {
      return await _collectionService.findOne(
        collectionName: AppConstants.usersCollection,
        selector: where.eq('_id', ObjectId.parse(userId)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateProfile({
    required String vehicleOwnerId,
    required VehicleOwnerProfile profile,
  }) async {
    await _ensureConnected();
    final now = DateTime.now().toUtc();

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.vehicleOwnerProfilesCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
    );

    if (existing == null) {
      await _collectionService.insertOne(
        collectionName: AppConstants.vehicleOwnerProfilesCollection,
        document: {
          'vehicleOwnerId': vehicleOwnerId,
          'profile': profile.toJson(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
      return;
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.vehicleOwnerProfilesCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
      modifier: modify
          .set('profile', profile.toJson())
          .set('updatedAt', now.toIso8601String()),
    );
  }

  @override
  Future<List<FavoriteParking>> getFavorites(String vehicleOwnerId) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.vehicleOwnerFavoritesCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
    );

    results.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );

    final favorites = <FavoriteParking>[];
    for (final doc in results) {
      final rawId = doc['_id'];
      final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
      final listingId = doc['parkingListingId'] as String;
      final baseListing = await _getBaseListing(listingId);
      if (baseListing == null) continue;

      final summary = await getRatingSummary(listingId);
      final availability =
          await _getCurrentAvailabilityRaw(listingId, baseListing.capacity);
      final listing = baseListing.copyWith(
        averageRating: summary.averageRating,
        reviewCount: summary.reviewCount,
        availableSlots: availability.availableSlots,
      );

      favorites.add(FavoriteParking(
        id: id,
        vehicleOwnerId: vehicleOwnerId,
        parkingListingId: listingId,
        createdAt: DateTime.parse(doc['createdAt'] as String),
        listing: listing,
      ));
    }
    return favorites;
  }

  @override
  Future<bool> isFavorite({
    required String vehicleOwnerId,
    required String parkingListingId,
  }) async {
    await _ensureConnected();

    final doc = await _collectionService.findOne(
      collectionName: AppConstants.vehicleOwnerFavoritesCollection,
      selector: where
          .eq('vehicleOwnerId', vehicleOwnerId)
          .eq('parkingListingId', parkingListingId),
    );
    return doc != null;
  }

  @override
  Future<void> toggleFavorite({
    required String vehicleOwnerId,
    required String parkingListingId,
  }) async {
    await _ensureConnected();

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.vehicleOwnerFavoritesCollection,
      selector: where
          .eq('vehicleOwnerId', vehicleOwnerId)
          .eq('parkingListingId', parkingListingId),
    );

    if (existing != null) {
      await _collectionService.deleteOne(
        collectionName: AppConstants.vehicleOwnerFavoritesCollection,
        selector: where
            .eq('vehicleOwnerId', vehicleOwnerId)
            .eq('parkingListingId', parkingListingId),
      );
      return;
    }

    await _collectionService.insertOne(
      collectionName: AppConstants.vehicleOwnerFavoritesCollection,
      document: {
        '_id': ObjectId(),
        'vehicleOwnerId': vehicleOwnerId,
        'parkingListingId': parkingListingId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<ParkingReview>> getReviews(String parkingListingId) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.parkingReviewsCollection,
      selector: where.eq('parkingListingId', parkingListingId),
    );

    results.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );

    return results.map(_mapReviewToEntity).toList();
  }

  @override
  Future<ParkingRatingSummary> getRatingSummary(String parkingListingId) async {
    final reviews = await getReviews(parkingListingId);
    if (reviews.isEmpty) {
      return const ParkingRatingSummary(averageRating: 0, reviewCount: 0);
    }

    final breakdown = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
    var total = 0;
    for (final review in reviews) {
      total += review.rating;
      breakdown[review.rating] = (breakdown[review.rating] ?? 0) + 1;
    }

    return ParkingRatingSummary(
      averageRating: total / reviews.length,
      reviewCount: reviews.length,
      ratingBreakdown: breakdown,
    );
  }

  @override
  Future<ParkingReview> submitReview({
    required String parkingListingId,
    required String vehicleOwnerId,
    required String reviewerName,
    required int rating,
    required String comment,
  }) async {
    await _ensureConnected();

    if (rating < 1 || rating > 5) {
      throw const AppException('Rating must be between 1 and 5.');
    }

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.parkingReviewsCollection,
      selector: where
          .eq('parkingListingId', parkingListingId)
          .eq('vehicleOwnerId', vehicleOwnerId),
    );

    final now = DateTime.now().toUtc();

    if (existing != null) {
      await _collectionService.updateOne(
        collectionName: AppConstants.parkingReviewsCollection,
        selector: where
            .eq('parkingListingId', parkingListingId)
            .eq('vehicleOwnerId', vehicleOwnerId),
        modifier: modify
            .set('rating', rating)
            .set('comment', comment.trim())
            .set('reviewerName', reviewerName)
            .set('updatedAt', now.toIso8601String()),
      );

      final rawId = existing['_id'];
      return ParkingReview(
        id: rawId is ObjectId ? rawId.toHexString() : rawId.toString(),
        parkingListingId: parkingListingId,
        vehicleOwnerId: vehicleOwnerId,
        reviewerName: reviewerName,
        rating: rating,
        comment: comment.trim(),
        createdAt: DateTime.parse(existing['createdAt'] as String),
      );
    }

    final reviewId = ObjectId();
    final document = {
      '_id': reviewId,
      'parkingListingId': parkingListingId,
      'vehicleOwnerId': vehicleOwnerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.parkingReviewsCollection,
      document: document,
    );

    return _mapReviewToEntity(document);
  }

  ParkingReview _mapReviewToEntity(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();

    return ParkingReview(
      id: id,
      parkingListingId: map['parkingListingId'] as String,
      vehicleOwnerId: map['vehicleOwnerId'] as String,
      reviewerName: map['reviewerName'] as String? ?? 'Anonymous',
      rating: map['rating'] as int? ?? 5,
      comment: map['comment'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Document-verified approved/completed land requests are listable.
  /// Uses GPS + land details from the ticket for nearby search.
  bool _isListableRequest(Map<String, dynamic> doc) {
    final documentsVerified = doc['documentsVerified'] as bool? ?? false;
    if (!documentsVerified) return false;

    final status = RequestStatusX.fromValue(doc['status'] as String? ?? '');
    if (status != RequestStatus.approved &&
        status != RequestStatus.completed) {
      return false;
    }

    final landDetails = doc['landDetails'];
    if (landDetails is! Map) return false;
    final lat = landDetails['gpsLatitude'];
    final lng = landDetails['gpsLongitude'];
    if (lat is! num || lng is! num) return false;
    if (lat == 0 && lng == 0) return false;

    return true;
  }

  ParkingListing _mapRequestToListing(Map<String, dynamic> doc) {
    final rawId = doc['_id'];
    final id = rawId is ObjectId
        ? rawId.toHexString()
        : (rawId is Map && rawId['\$oid'] != null)
            ? rawId['\$oid'].toString()
            : rawId.toString();
    final landDetails =
        LandDetails.fromJson(doc['landDetails'] as Map<String, dynamic>);
    final parkingPrefs = doc['parkingPreferences'] as Map<String, dynamic>?;
    final prefs = parkingPrefs != null
        ? ParkingPreferences.fromJson(parkingPrefs)
        : null;
    final ownerDetails = doc['ownerDetails'] as Map<String, dynamic>?;

    final parkingType = prefs?.parkingType ?? ParkingType.towerParking;
    final capacity = prefs?.numberOfCars ?? 1;
    final address = landDetails.landAddress?.trim();
    final ownerName = (ownerDetails?['fullName'] as String?)?.trim();
    final employeeName = (doc['assignedEmployeeName'] as String?)?.trim();
    final ticketId = doc['ticketId'] as String? ?? '';

    final parkingName = (address != null && address.isNotEmpty)
        ? address
        : (ownerName != null && ownerName.isNotEmpty)
            ? "$ownerName's Parking"
            : '${parkingType.label} Parking';

    return ParkingListing(
      id: id,
      ticketId: ticketId,
      landOwnerId: doc['ownerId'] as String? ?? '',
      parkingType: parkingType,
      capacity: capacity,
      latitude: landDetails.gpsLatitude,
      longitude: landDetails.gpsLongitude,
      areaSqFt: landDetails.areaSqFt,
      hourlyRate: _hourlyRates[parkingType] ?? 40.0,
      parkingName: parkingName,
      address: address,
      roadAccess: landDetails.roadAccess,
      cctv: landDetails.cctv,
      verifiedByEmployee: true,
      verifiedEmployeeName:
          (employeeName != null && employeeName.isNotEmpty)
              ? employeeName
              : 'Documents verified',
    );
  }

  Booking _mapBookingToEntity(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();

    return Booking(
      id: id,
      bookingRef: map['bookingRef'] as String,
      vehicleOwnerId: map['vehicleOwnerId'] as String,
      parkingListingId: map['parkingListingId'] as String,
      ticketId: map['ticketId'] as String,
      parkingType: ParkingTypeX.fromValue(map['parkingType'] as String),
      vehicleNumber: map['vehicleNumber'] as String,
      vehicleModel: map['vehicleModel'] as String?,
      startDateTime: DateTime.parse(map['startDateTime'] as String),
      endDateTime: DateTime.parse(map['endDateTime'] as String),
      durationHours: (map['durationHours'] as num).toDouble(),
      hourlyRate: (map['hourlyRate'] as num).toDouble(),
      totalPrice: (map['totalPrice'] as num).toDouble(),
      status: BookingStatusX.fromValue(map['status'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      parkingAddress: map['parkingAddress'] as String?,
      assignedSlot: map['assignedSlot'] is num
          ? (map['assignedSlot'] as num).toInt()
          : null,
      qrPayload: map['qrPayload'] as String?,
      checkedInAt: map['checkedInAt'] != null
          ? DateTime.parse(map['checkedInAt'] as String)
          : null,
      checkedOutAt: map['checkedOutAt'] != null
          ? DateTime.parse(map['checkedOutAt'] as String)
          : null,
      actualDurationHours: map['actualDurationHours'] is num
          ? (map['actualDurationHours'] as num).toDouble()
          : null,
      amountDue: map['amountDue'] is num
          ? (map['amountDue'] as num).toDouble()
          : null,
      paidAmount: map['paidAmount'] is num
          ? (map['paidAmount'] as num).toDouble()
          : null,
      paymentId: map['paymentId'] as String?,
      paidAt: map['paidAt'] != null
          ? DateTime.parse(map['paidAt'] as String)
          : null,
    );
  }

  String _generateBookingRef() {
    final now = DateTime.now().toUtc();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9000) + 1000;
    return 'BK-$datePart-$random';
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}

class MongoVehicleOwnerNotificationRepository
    implements VehicleOwnerNotificationRepository {
  MongoVehicleOwnerNotificationRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;

  @override
  Future<List<VehicleOwnerNotification>> getNotifications(
    String vehicleOwnerId,
  ) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.vehicleOwnerNotificationsCollection,
      selector: where.eq('vehicleOwnerId', vehicleOwnerId),
    );

    results.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );

    return results.map(_mapToEntity).toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _ensureConnected();

    await _collectionService.updateOne(
      collectionName: AppConstants.vehicleOwnerNotificationsCollection,
      selector: where.eq('_id', ObjectId.parse(notificationId)),
      modifier: modify.set('isRead', true),
    );
  }

  @override
  Future<int> getUnreadCount(String vehicleOwnerId) async {
    final notifications = await getNotifications(vehicleOwnerId);
    return notifications.where((n) => !n.isRead).length;
  }

  VehicleOwnerNotification _mapToEntity(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();

    return VehicleOwnerNotification(
      id: id,
      vehicleOwnerId: map['vehicleOwnerId'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
      bookingRef: map['bookingRef'] as String?,
    );
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}
