import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_operations_analytics.dart';

class AdminOperationsApiService {
  AdminOperationsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  final ApiClient _apiClient;

  Future<AdminOperationsAnalytics> fetchOperations({
    String? listingId,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (listingId != null && listingId.isNotEmpty) {
      params['listingId'] = listingId;
    }
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final result = await _apiClient.get('/api/admin/operations$query');
    return AdminOperationsAnalytics.fromJson(result);
  }
}
