import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/utils/mongo_json.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';

class ParkingRecommendationService {
  ParkingRecommendationService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ParkingListing>> fetchRecommendations({
    required double latitude,
    required double longitude,
    String? vehicleOwnerId,
    double radiusKm = 25,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radiusKm.toString(),
    };
    if (vehicleOwnerId != null && vehicleOwnerId.isNotEmpty) {
      query['vehicleOwnerId'] = vehicleOwnerId;
    }

    final queryString = query.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await _apiClient.get('/api/parking/nearby?$queryString');
    final raw = response['recommendations'] as List<dynamic>? ?? const [];

    return raw
        .whereType<Map>()
        .map((item) => _mapRecommendation(Map<String, dynamic>.from(item)))
        .where((listing) =>
            listing.id.isNotEmpty &&
            listing.id != '[object Object]' &&
            (listing.ticketId.isNotEmpty || listing.id.length == 24))
        .toList();
  }

  ParkingListing _mapRecommendation(Map<String, dynamic> item) {
    final parkingTypeValue = item['parkingType'] as String? ?? 'tower_parking';
    final ticketId = (item['ticketId'] as String? ?? '').trim();
    var id = MongoJson.objectIdHex(item['id']);
    if (id.isEmpty) {
      id = MongoJson.objectIdHex(item['_id']);
    }
    // Live API previously returned "[object Object]" — fall back to ticket id.
    if (id.isEmpty && ticketId.isNotEmpty) {
      id = ticketId;
    }

    return ParkingListing(
      id: id,
      ticketId: ticketId,
      landOwnerId: '',
      parkingType: ParkingTypeX.fromValue(parkingTypeValue),
      capacity: MongoJson.asInt(item['capacity']) ?? 1,
      latitude: MongoJson.asDouble(item['latitude']) ?? 0,
      longitude: MongoJson.asDouble(item['longitude']) ?? 0,
      areaSqFt: MongoJson.asDouble(item['areaSqFt']) ?? 0,
      hourlyRate: MongoJson.asDouble(item['hourlyRate']),
      parkingName: item['parkingName'] as String?,
      address: item['address'] as String?,
      distanceKm: MongoJson.asDouble(item['distanceKm']),
      availableSlots: MongoJson.asInt(item['availableSlots']),
      verifiedByEmployee: item['documentsVerified'] as bool? ?? true,
      isCompatible: item['isCompatible'] as bool? ?? true,
      isBestMatch: item['isBestMatch'] as bool? ?? false,
      parkingStatus: item['parkingStatus'] as String? ?? 'approved',
    );
  }
}
