import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';

/// Fetches estimated parking slots from the backend (formula stays server-side).
class ParkingSlotEstimateService {
  ParkingSlotEstimateService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<int> estimateSlots(double areaSqFt) async {
    if (!areaSqFt.isFinite || areaSqFt <= 0) return 0;
    try {
      final result = await _apiClient.post('/api/parking/estimate-slots', {
        'areaSqFt': areaSqFt,
      });
      final slots = result['estimatedSlots'];
      if (slots is num) return slots.round();
      return int.tryParse('$slots') ?? 0;
    } on AppException {
      rethrow;
    }
  }
}
