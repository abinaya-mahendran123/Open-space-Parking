import 'package:open_space_parking/core/services/api/api_client.dart';
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
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await _apiClient.get('/api/parking/nearby?$queryString');
    final raw = response['recommendations'] as List<dynamic>? ?? const [];

    return raw
        .whereType<Map>()
        .map((item) => _mapRecommendation(Map<String, dynamic>.from(item)))
        .toList();
  }

  ParkingListing _mapRecommendation(Map<String, dynamic> item) {
    final parkingTypeValue = item['parkingType'] as String? ?? 'tower_parking';

    return ParkingListing(
      id: '${item['id'] ?? ''}',
      ticketId: item['ticketId'] as String? ?? '',
      landOwnerId: '',
      parkingType: ParkingTypeX.fromValue(parkingTypeValue),
      capacity: item['capacity'] as int? ?? 1,
      latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
      areaSqFt: (item['areaSqFt'] as num?)?.toDouble() ?? 0,
      hourlyRate: (item['hourlyRate'] as num?)?.toDouble(),
      parkingName: item['parkingName'] as String?,
      address: item['address'] as String?,
      distanceKm: (item['distanceKm'] as num?)?.toDouble(),
      availableSlots: item['availableSlots'] as int?,
      verifiedByEmployee: item['documentsVerified'] as bool? ?? true,
      isCompatible: item['isCompatible'] as bool? ?? true,
      isBestMatch: item['isBestMatch'] as bool? ?? false,
      parkingStatus: item['parkingStatus'] as String? ?? 'approved',
    );
  }
}
