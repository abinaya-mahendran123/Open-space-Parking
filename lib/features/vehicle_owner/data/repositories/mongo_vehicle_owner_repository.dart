import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/integration/notification_helper.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/api/mongo_http_codec.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/utils/mongo_json.dart';
import 'package:open_space_parking/core/services/api/parking_recommendation_service.dart';
import 'package:open_space_parking/core/utils/geo_utils.dart';
import 'package:open_space_parking/core/utils/vehicle_compatibility.dart';
import 'package:open_space_parking/core/utils/parking_slot_calculator.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/favorite_parking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_payment_split.dart';
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
    ApiClient? apiClient,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService,
        _notificationHelper = notificationHelper,
        _apiClient = apiClient;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;
  final NotificationHelper _notificationHelper;
  final ApiClient? _apiClient;

  @override
  Future<List<ParkingListing>> searchParkingListings(SearchFilters filters) async {
    await _ensureConnected();

    final hasLocation =
        filters.userLatitude != null && filters.userLongitude != null;
    final api = _apiClient;

    if (api != null && hasLocation) {
      try {
        final service = ParkingRecommendationService(api);
        var listings = await service.fetchRecommendations(
          latitude: filters.userLatitude!,
          longitude: filters.userLongitude!,
          vehicleOwnerId: filters.vehicleOwnerId,
          radiusKm: filters.maxDistanceKm ?? 25,
        );
        listings = await _applySearchFilters(listings, filters);
        return await _enrichListings(listings, skipAvailability: true);
      } catch (_) {
        // Fall back to local filtering when recommendation API is unavailable.
      }
    }

    return _searchParkingListingsLocally(filters);
  }

  Future<List<ParkingListing>> _searchParkingListingsLocally(
    SearchFilters filters,
  ) async {
    final results = await _loadVerifiedParkingDocs();
    VehicleSpec? vehicleSpec;
    if (filters.vehicleOwnerId != null && filters.vehicleOwnerId!.isNotEmpty) {
      final profile = await getProfile(filters.vehicleOwnerId!);
      if (profile != null) {
        vehicleSpec = VehicleCompatibility.resolve(
          vehicleBrand: profile.vehicleBrand,
          vehicleModel: profile.vehicleModel,
          vehicleParkingClass: profile.vehicleParkingClass,
          vehicleLengthM: profile.vehicleLengthM,
          vehicleWidthM: profile.vehicleWidthM,
        );
      }
    }
    vehicleSpec ??= VehicleCompatibility.resolve(
      vehicleModel: filters.query,
    );

    var listings = <ParkingListing>[];
    for (final doc in results) {
      try {
        if (!_isListableRequest(doc)) continue;
        final listing = _mapRequestToListing(doc);
        if (!VehicleCompatibility.isCompatible(
          vehicle: vehicleSpec,
          parkingTypeValue: listing.parkingType.value,
          areaSqFt: listing.areaSqFt,
          capacity: listing.capacity,
        )) {
          continue;
        }
        listings.add(listing);
      } catch (_) {}
    }

    listings = await _applySearchFilters(listings, filters);

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

    listings = await _enrichListings(listings);
    listings = listings.where((l) => l.isAvailableNow && l.isCompatible).toList();

    if (listings.isNotEmpty) {
      listings = [
        listings.first.copyWith(isBestMatch: true),
        ...listings.skip(1),
      ];
    }

    return listings;
  }

  Future<List<ParkingListing>> _applySearchFilters(
    List<ParkingListing> listings,
    SearchFilters filters,
  ) async {
    var filtered = listings;

    if (filters.parkingType != null) {
      filtered = filtered
          .where((l) => l.parkingType == filters.parkingType)
          .toList();
    }

    if (filters.query != null && filters.query!.trim().isNotEmpty) {
      final q = filters.query!.trim().toLowerCase();
      filtered = filtered.where((l) {
        return l.displayName.toLowerCase().contains(q) ||
            l.displayTitle.toLowerCase().contains(q) ||
            l.ticketId.toLowerCase().contains(q) ||
            l.parkingType.label.toLowerCase().contains(q) ||
            (l.address?.toLowerCase().contains(q) ?? false) ||
            (l.verifiedEmployeeName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (filters.maxDistanceKm != null &&
        filtered.any((l) => l.distanceKm != null)) {
      filtered = filtered
          .where((l) => (l.distanceKm ?? double.infinity) <= filters.maxDistanceKm!)
          .toList();
    }

    return filtered;
  }

  Future<List<ParkingListing>> _enrichListings(
    List<ParkingListing> listings, {
    bool skipAvailability = false,
  }) async {
    final enriched = <ParkingListing>[];
    for (final listing in listings) {
      final summary = await getRatingSummary(listing.id);
      if (skipAvailability) {
        enriched.add(listing.copyWith(
          averageRating: summary.averageRating,
          reviewCount: summary.reviewCount,
        ));
        continue;
      }
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
    final hex = _normalizeObjectId(listingId);
    final looksLikeTicket = listingId.trim().toUpperCase().startsWith('OSP-');

    Map<String, dynamic>? doc;
    final api = _apiClient;
    if (api != null) {
      try {
        final body = <String, dynamic>{};
        if (hex.isNotEmpty && hex != '[object Object]') {
          body['id'] = hex;
        }
        if (looksLikeTicket) {
          body['ticketId'] = listingId.trim();
        }
        if (body.isEmpty) return null;

        final response = await api.post('/api/parking/listing', body);
        final raw = response['document'];
        if (raw is Map) {
          doc = Map<String, dynamic>.from(
            MongoHttpCodec.decode(raw) as Map,
          );
        }
      } on NetworkException {
        doc = null;
      }
    } else {
      if (hex.isNotEmpty && hex.length == 24) {
        doc = await _collectionService.findOne(
          collectionName: AppConstants.landOwnerRequestsCollection,
          selector: where.eq('_id', ObjectId.parse(hex)),
        );
      }
      if (doc == null && looksLikeTicket) {
        doc = await _collectionService.findOne(
          collectionName: AppConstants.landOwnerRequestsCollection,
          selector: where.eq('ticketId', listingId.trim()),
        );
      }
      if (doc != null && !_isListableRequest(doc)) doc = null;
    }

    if (doc == null) return null;
    return _mapRequestToListing(doc);
  }

  String _normalizeObjectId(String value) => MongoJson.objectIdHex(value);

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
      // Confirmed (awaiting entry) and active sessions hold an FCFS slot.
      if (status == BookingStatus.active ||
          status == BookingStatus.confirmed) {
        return true;
      }

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
      final parsed = MongoJson.asInt(slot);
      if (parsed != null && parsed > 0) used.add(parsed);
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
    final api = _apiClient;
    if (api != null) {
      try {
        final response = await api.post('/api/bookings/start-session', {
          'parkingListingId': _normalizeObjectId(parkingListingId),
          'vehicleNumber': vehicleNumber,
          if (vehicleModel != null) 'vehicleModel': vehicleModel,
        });
        final raw = response['document'];
        if (raw is Map) {
          return _mapBookingToEntity(
            MongoJson.asMap(MongoHttpCodec.decode(raw))!,
          );
        }
      } on NetworkException catch (e) {
        throw AppException(e.message);
      }
    }

    await _ensureConnected();

    final plate = vehicleNumber.trim().toUpperCase();
    if (Validators.vehicleNumber(plate) != null) {
      throw const AppException(
        'Enter a valid vehicle number (e.g. TN 09 AB 1234).',
      );
    }

    final listing = await _getBaseListing(parkingListingId);
    if (listing == null) {
      throw const AppException('Parking space is no longer available.');
    }
    if (!listing.hasVerifiedAmount) {
      throw const AppException(
        'This parking has no hourly amount on its verified ticket yet.',
      );
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

    final document = {
      '_id': bookingId,
      'bookingRef': bookingRef,
      'vehicleOwnerId': vehicleOwnerId,
      'parkingListingId': parkingListingId,
      'ticketId': listing.ticketId,
      'parkingType': listing.parkingType.value,
      'vehicleNumber': plate,
      'vehicleModel': vehicleModel?.trim(),
      // Open session — duration/price are set only after security exit scan.
      'startDateTime': now.toIso8601String(),
      'endDateTime': now.toIso8601String(),
      'durationHours': 0.0,
      'hourlyRate': listing.hourlyRate!,
      'totalPrice': 0.0,
      'status': BookingStatus.confirmed.value,
      'parkingAddress': listing.address,
      'parkingName': listing.displayName,
      'assignedSlot': slot,
      'qrPayload': bookingRef,
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
          'Slot $slot assigned (FCFS). Show QR ($bookingRef) to security to start parking.',
      bookingRef: bookingRef,
    );

    return _mapBookingToEntity(document);
  }

  @override
  Future<Booking?> getBookingByQr(String qrPayload) async {
    final api = _apiClient;
    if (api != null) {
      try {
        final response = await api.get(
          '/api/security/booking-by-qr?qr=${Uri.encodeComponent(qrPayload.trim())}',
        );
        final raw = response['document'];
        if (raw == null) return null;
        if (raw is Map) {
          return _mapBookingToEntity(
            MongoJson.asMap(MongoHttpCodec.decode(raw))!,
          );
        }
      } on NetworkException catch (e) {
        throw AppException(e.message);
      }
    }

    await _ensureConnected();
    final code = qrPayload.trim();
    if (code.isEmpty) return null;

    final doc = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('qrPayload', code),
    );
    if (doc != null) {
      return _ensureBookingHasSlot(_mapBookingToEntity(doc), doc);
    }

    final byRef = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('bookingRef', code),
    );
    if (byRef == null) return null;
    return _ensureBookingHasSlot(_mapBookingToEntity(byRef), byRef);
  }

  @override
  Future<Booking> scanParkingQr(String qrPayload) async {
    final api = _apiClient;
    if (api != null) {
      try {
        final response = await api.post('/api/security/scan-qr', {
          'qrPayload': qrPayload.trim(),
        });
        final raw = response['document'] ?? response['booking'];
        if (raw is Map) {
          return _mapBookingToEntity(
            MongoJson.asMap(MongoHttpCodec.decode(raw))!,
          );
        }
        final fallback = await getBookingByQr(qrPayload);
        if (fallback != null) return fallback;
        throw const AppException(
          'QR was scanned but the booking could not be updated. Try again.',
        );
      } on NetworkException catch (e) {
        throw AppException(e.message);
      }
    }

    await _ensureConnected();

    final booking = await getBookingByQr(qrPayload);
    if (booking == null) {
      throw const AppException('QR / booking not found.');
    }
    if (booking.status == BookingStatus.completed) {
      throw const AppException('This parking session is already completed.');
    }
    if (booking.status == BookingStatus.cancelled) {
      throw const AppException('This booking was cancelled.');
    }

    // Second scan already done — return bill.
    if (booking.checkedOutAt != null && booking.amountDue != null) {
      return booking;
    }

    final now = DateTime.now().toUtc();
    final listing = await _getBaseListing(booking.parkingListingId);
    final existingName = booking.parkingName?.trim();
    final parkingName = (existingName != null && existingName.isNotEmpty)
        ? existingName
        : listing?.displayName ?? booking.displayParkingName;

    // Always prefer the live parking ticket rate over any stale booking copy.
    final listingRate = listing?.hourlyRate;
    final hourlyRate = (listingRate != null && listingRate > 0)
        ? listingRate
        : (booking.hourlyRate > 0 ? booking.hourlyRate : 0.0);
    if (hourlyRate <= 0) {
      throw const AppException(
        'This parking has no hourly rate. Update the parking ticket amount first.',
      );
    }

    // First scan: start the parking timer.
    if (booking.checkedInAt == null) {
      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.active) {
        throw AppException(
          'Booking is ${booking.status.label.toLowerCase()} and cannot start.',
        );
      }

      final existingSession = booking.sessionId?.trim();
      final sessionId = (existingSession != null && existingSession.isNotEmpty)
          ? existingSession
          : _generateSessionId();

      await _collectionService.updateOne(
        collectionName: AppConstants.bookingsCollection,
        selector: where.eq('_id', ObjectId.parse(booking.id)),
        modifier: modify
            .set('status', BookingStatus.active.value)
            .set('checkedInAt', now.toIso8601String())
            .set('startDateTime', now.toIso8601String())
            .set('sessionId', sessionId)
            .set('parkingName', parkingName)
            .set('hourlyRate', hourlyRate)
            .set('durationHours', 0.0)
            .set('totalPrice', 0.0)
            .unset('amountDue')
            .unset('actualDurationHours')
            .unset('checkedOutAt')
            .set('updatedAt', now.toIso8601String()),
      );

      await _notificationHelper.notifyVehicleOwner(
        vehicleOwnerId: booking.vehicleOwnerId,
        title: 'Parking Started',
        message:
            'Session $sessionId started at $parkingName, slot ${booking.assignedSlot ?? '-'}.',
        bookingRef: booking.bookingRef,
      );

      final started = await getBooking(booking.id);
      if (started == null) {
        throw const AppException('Could not load updated booking.');
      }
      return started;
    }

    // Second scan: stop timer and bill actual elapsed time × parking hourly rate.
    if (booking.status != BookingStatus.active) {
      throw AppException(
        'Booking is ${booking.status.label.toLowerCase()}, not an active park session.',
      );
    }

    final checkedIn = booking.checkedInAt!.toUtc();
    final elapsedSeconds = now.difference(checkedIn).inSeconds;
    // At least 1 second so a same-second double-scan still produces a bill.
    final seconds = elapsedSeconds < 1 ? 1 : elapsedSeconds;
    final billedHours = seconds / 3600.0;
    final amountDue = (billedHours * hourlyRate * 100).ceil() / 100;

    await _collectionService.updateOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(booking.id)),
      modifier: modify
          .set('checkedOutAt', now.toIso8601String())
          .set('endDateTime', now.toIso8601String())
          .set('actualDurationHours', billedHours)
          .set('durationHours', billedHours)
          .set('hourlyRate', hourlyRate)
          .set('parkingName', parkingName)
          .set('amountDue', amountDue)
          .set('totalPrice', amountDue)
          .set('updatedAt', now.toIso8601String()),
    );

    final durationLabel = _formatDurationLabel(seconds);
    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: booking.vehicleOwnerId,
      title: 'Ready to Pay',
      message:
          'Session stopped after $durationLabel at $parkingName '
          '(₹${hourlyRate.toStringAsFixed(0)}/hr). '
          'Pay ₹${amountDue.toStringAsFixed(0)} via Razorpay.',
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
    String? paymentId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
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
        'Ask security to scan your QR at exit before payment.',
      );
    }

    final now = DateTime.now().toUtc();
    final localPaymentId = ObjectId();
    final amount = booking.amountDue!;
    final externalId = razorpayPaymentId ?? paymentId ?? localPaymentId.oid;
    final platformCommission = ParkingPaymentSplit.platformAmount(amount);
    final landOwnerPayout = ParkingPaymentSplit.landOwnerAmount(amount);
    final listing = await _getBaseListing(booking.parkingListingId);
    final landOwnerId = listing?.landOwnerId;
    final split = {
      'totalAmount': amount,
      'commissionPercent': ParkingPaymentSplit.platformCommissionPercent,
      'platformAccountName': ParkingPaymentSplit.platformAccountName,
      'platformCommission': platformCommission,
      'landOwnerPayout': landOwnerPayout,
      'landOwnerId': landOwnerId,
      'settlementStatus': 'pending_manual',
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.paymentsCollection,
      document: {
        '_id': localPaymentId,
        'bookingId': bookingId,
        'bookingRef': booking.bookingRef,
        'vehicleOwnerId': booking.vehicleOwnerId,
        'amount': amount,
        'method': paymentMethod,
        'status': 'paid',
        'split': split,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
        'createdAt': now.toIso8601String(),
      },
    );

    await _collectionService.updateOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(bookingId)),
      modifier: modify
          .set('status', BookingStatus.completed.value)
          .set('paidAmount', amount)
          .set('paymentId', externalId)
          .set('paidAt', now.toIso8601String())
          .set('paymentMethod', paymentMethod)
          .set('split', split)
          .set('updatedAt', now.toIso8601String()),
    );

    await _notificationHelper.notifyVehicleOwner(
      vehicleOwnerId: booking.vehicleOwnerId,
      title: 'Checkout Complete',
      message:
          'Payment of ₹${amount.toStringAsFixed(0)} received via $paymentMethod. Slot ${booking.assignedSlot ?? '-'} released.',
      bookingRef: booking.bookingRef,
    );
    if (landOwnerId != null && landOwnerId.isNotEmpty) {
      await _notificationHelper.notifyLandOwner(
        ownerId: landOwnerId,
        title: 'Parking payout',
        message:
            '₹${landOwnerPayout.toStringAsFixed(0)} (90%) is due to your payout account. '
            'Media account retained ₹${platformCommission.toStringAsFixed(0)} (10%).',
      );
    }

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

    if (Validators.vehicleNumber(vehicleNumber) != null) {
      throw const AppException(
        'Enter a valid vehicle number (e.g. TN 09 AB 1234).',
      );
    }

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

    if (!listing.hasVerifiedAmount) {
      throw const AppException(
        'This parking has no hourly amount on its verified ticket yet.',
      );
    }

    final totalPrice = (durationHours * listing.hourlyRate! * 100).ceil() / 100;
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
      'parkingName': listing.displayName,
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

    final hex = MongoJson.objectIdHex(bookingId);
    if (hex.isEmpty || hex.length != 24) return null;

    final doc = await _collectionService.findOne(
      collectionName: AppConstants.bookingsCollection,
      selector: where.eq('_id', ObjectId.parse(hex)),
    );

    if (doc == null) return null;
    return _ensureBookingHasSlot(_mapBookingToEntity(doc), doc);
  }

  /// Older bookings may have been saved without FCFS slot — assign one now.
  Future<Booking> _ensureBookingHasSlot(
    Booking booking,
    Map<String, dynamic> rawDoc,
  ) async {
    final existing = booking.assignedSlot;
    if (existing != null && existing > 0) return booking;
    if (booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.completed) {
      return booking;
    }

    try {
      final listing = await _getBaseListing(booking.parkingListingId);
      final capacity = listing?.capacity ?? 10;
      final slot = await _allocateNextSlot(
        parkingListingId: booking.parkingListingId,
        capacity: capacity > 0 ? capacity : 10,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await _collectionService.updateOne(
        collectionName: AppConstants.bookingsCollection,
        selector: where.eq('_id', ObjectId.parse(booking.id)),
        modifier: modify.set('assignedSlot', slot).set('updatedAt', now),
      );
      // Booking is immutable — remap with updated slot.
      final updated = Map<String, dynamic>.from(rawDoc)
        ..['assignedSlot'] = slot
        ..['updatedAt'] = now;
      return _mapBookingToEntity(updated);
    } catch (_) {
      return booking;
    }
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
    final ownerId = MongoJson.objectIdHex(vehicleOwnerId);

    VehicleOwnerProfile? saved;
    try {
      final profile = await _collectionService.findOne(
        collectionName: AppConstants.vehicleOwnerProfilesCollection,
        selector: where.eq('vehicleOwnerId', ownerId),
      );
      final nested = MongoJson.asMap(profile?['profile']);
      if (nested != null) {
        saved = VehicleOwnerProfile.fromJson(nested);
      }
    } catch (_) {
      saved = null;
    }

    final user = await _findUserAccount(ownerId);
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: saved,
      accountDisplayName: user?['displayName'] as String?,
      accountEmail: user?['email'] as String?,
      accountPhone: user?['phone'] as String?,
    );

    return merged;
  }

  Future<Map<String, dynamic>?> _findUserAccount(String userId) async {
    final hex = MongoJson.objectIdHex(userId);
    try {
      if (hex.length == 24) {
        final byObjectId = await _collectionService.findOne(
          collectionName: AppConstants.usersCollection,
          selector: where.eq('_id', ObjectId.parse(hex)),
        );
        if (byObjectId != null) return byObjectId;
      }
      return await _collectionService.findOne(
        collectionName: AppConstants.usersCollection,
        selector: where.eq('_id', hex),
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

    final ownerId = MongoJson.objectIdHex(vehicleOwnerId);
    final existing = await _collectionService.findOne(
      collectionName: AppConstants.vehicleOwnerProfilesCollection,
      selector: where.eq('vehicleOwnerId', ownerId),
    );

    if (existing == null) {
      await _collectionService.insertOne(
        collectionName: AppConstants.vehicleOwnerProfilesCollection,
        document: {
          'vehicleOwnerId': ownerId,
          'profile': profile.toJson(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
      return;
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.vehicleOwnerProfilesCollection,
      selector: where.eq('vehicleOwnerId', ownerId),
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
      final id = rawId is ObjectId ? rawId.oid : rawId.toString();
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
        id: rawId is ObjectId ? rawId.oid : rawId.toString(),
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
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();

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

  Future<List<Map<String, dynamic>>> _loadVerifiedParkingDocs() async {
    final api = _apiClient;
    if (api != null) {
      final response = await api.post('/api/parking/nearby', {});
      final documents = response['documents'] as List<dynamic>? ?? const [];
      return documents
          .map((doc) => Map<String, dynamic>.from(doc as Map))
          .toList();
    }
    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.ne('status', RequestStatus.rejected.value),
    );
    return results.where(_isListableRequest).toList();
  }

  /// Only admin-approved public parking with valid GPS appears in nearby search.
  bool _isListableRequest(Map<String, dynamic> doc) {
    final status = RequestStatusX.fromValue(doc['status'] as String? ?? '');
    if (status == RequestStatus.rejected ||
        status == RequestStatus.submitted ||
        status == RequestStatus.underReview ||
        status == RequestStatus.inProgress) {
      return false;
    }
    if (status != RequestStatus.approved && status != RequestStatus.completed) {
      return false;
    }

    if (!MongoJson.asBool(doc['documentsVerified'])) return false;
    if (doc['isActive'] == false) return false;

    final landDetails = MongoJson.asMap(doc['landDetails']);
    if (landDetails == null) return false;
    final lat = MongoJson.asDouble(landDetails['gpsLatitude']);
    final lng = MongoJson.asDouble(landDetails['gpsLongitude']);
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;

    final parkingPrefs = MongoJson.asMap(doc['parkingPreferences']);
    final areaSqFt = MongoJson.asDouble(landDetails['areaSqFt']) ?? 0;
    final capacity = ParkingSlotCalculator.resolveCapacity(
      requestType: doc['requestType'] as String?,
      areaSqFt: areaSqFt,
      storedNumberOfCars: MongoJson.asInt(parkingPrefs?['numberOfCars']) ??
          MongoJson.asInt(doc['capacity']) ??
          MongoJson.asInt(doc['numberOfCars']),
    );
    if (capacity <= 0) return false;

    return true;
  }

  double? _amountFromVerifiedDoc(
    Map<String, dynamic> doc,
    Map<String, dynamic>? parkingPrefs,
  ) {
    final rate = MongoJson.asDouble(doc['hourlyRate']) ??
        MongoJson.asDouble(doc['amountPerHour']) ??
        MongoJson.asDouble(doc['parkingFee']) ??
        MongoJson.asDouble(parkingPrefs?['hourlyRate']) ??
        MongoJson.asDouble(parkingPrefs?['amountPerHour']) ??
        MongoJson.asDouble(parkingPrefs?['parkingFee']);
    if (rate == null || rate <= 0) return null;
    return rate;
  }

  ParkingListing _mapRequestToListing(Map<String, dynamic> doc) {
    final id = MongoJson.objectIdHex(doc['_id']);
    final landDetailsMap = MongoJson.asMap(doc['landDetails']) ?? const {};
    final landDetails = LandDetails.fromJson(landDetailsMap);
    final parkingPrefs = MongoJson.asMap(doc['parkingPreferences']) ?? const {};
    final prefs = ParkingPreferences.fromJson(parkingPrefs);
    final ownerDetails = MongoJson.asMap(doc['ownerDetails']);
    final capacity = ParkingSlotCalculator.resolveCapacity(
      requestType: doc['requestType'] as String?,
      areaSqFt: landDetails.areaSqFt,
      storedNumberOfCars: prefs.numberOfCars > 0
          ? prefs.numberOfCars
          : (MongoJson.asInt(doc['capacity']) ??
              MongoJson.asInt(doc['numberOfCars'])),
    );

    final address = landDetails.landAddress?.trim();
    final ownerName = (ownerDetails?['fullName'] as String?)?.trim();
    final employeeName = (doc['assignedEmployeeName'] as String?)?.trim();
    final ticketId = doc['ticketId'] as String? ?? '';

    final parkingName = (address != null && address.isNotEmpty)
        ? address
        : (ownerName != null && ownerName.isNotEmpty)
            ? "$ownerName's Parking"
            : ticketId;

    return ParkingListing(
      id: id,
      ticketId: ticketId,
      landOwnerId: '${doc['ownerId'] ?? ''}',
      parkingType: prefs.parkingType,
      capacity: capacity,
      latitude: landDetails.gpsLatitude,
      longitude: landDetails.gpsLongitude,
      areaSqFt: landDetails.areaSqFt,
      hourlyRate: _amountFromVerifiedDoc(doc, parkingPrefs),
      parkingName: parkingName,
      address: address,
      roadAccess: landDetails.roadAccess,
      cctv: landDetails.cctv,
      verifiedByEmployee: true,
      verifiedEmployeeName:
          (employeeName != null && employeeName.isNotEmpty)
              ? employeeName
              : null,
    );
  }

  Booking _mapBookingToEntity(Map<String, dynamic> map) {
    final id = MongoJson.objectIdHex(map['_id']);
    if (id.isEmpty) {
      throw const AppException('Booking id is missing.');
    }

    return Booking(
      id: id,
      bookingRef: map['bookingRef'] as String? ?? '',
      vehicleOwnerId: '${map['vehicleOwnerId'] ?? ''}',
      parkingListingId: MongoJson.objectIdHex(map['parkingListingId']).isNotEmpty
          ? MongoJson.objectIdHex(map['parkingListingId'])
          : '${map['parkingListingId'] ?? ''}',
      ticketId: '${map['ticketId'] ?? ''}',
      parkingType: ParkingTypeX.fromValue(map['parkingType'] as String? ?? ''),
      vehicleNumber: map['vehicleNumber'] as String? ?? '',
      vehicleModel: map['vehicleModel'] as String?,
      startDateTime: DateTime.parse(
        map['startDateTime'] as String? ??
            map['checkedInAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      endDateTime: DateTime.parse(
        map['endDateTime'] as String? ??
            map['checkedOutAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      durationHours: (map['durationHours'] as num?)?.toDouble() ?? 0,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      status: BookingStatusX.fromValue(map['status'] as String? ?? ''),
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      ),
      parkingAddress: map['parkingAddress'] as String?,
      parkingName: map['parkingName'] as String?,
      assignedSlot: MongoJson.asInt(map['assignedSlot']),
      qrPayload: map['qrPayload'] as String?,
      sessionId: map['sessionId'] as String?,
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

  String _generateSessionId() {
    final now = DateTime.now().toUtc();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9000) + 1000;
    return 'PS-$datePart-$random';
  }

  String _formatDurationLabel(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
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
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();

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
