import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/mongodb/repositories/mongo_repositories.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_integration_service.dart';

final mongoIntegrationServiceProvider = Provider<MongoIntegrationService>(
  (ref) => sl<MongoIntegrationService>(),
);

final mongoDataServiceProvider = Provider<MongoDataService>(
  (ref) => sl<MongoDataService>(),
);

final userMongoRepositoryProvider = Provider<UserMongoRepository>(
  (ref) => sl<UserMongoRepository>(),
);

final employeeMongoRepositoryProvider = Provider<EmployeeMongoRepository>(
  (ref) => sl<EmployeeMongoRepository>(),
);

final vehicleOwnerMongoRepositoryProvider = Provider<VehicleOwnerMongoRepository>(
  (ref) => sl<VehicleOwnerMongoRepository>(),
);

final landOwnerMongoRepositoryProvider = Provider<LandOwnerMongoRepository>(
  (ref) => sl<LandOwnerMongoRepository>(),
);

final parkingSpaceMongoRepositoryProvider = Provider<ParkingSpaceMongoRepository>(
  (ref) => sl<ParkingSpaceMongoRepository>(),
);

final constructionRequestMongoRepositoryProvider =
    Provider<ConstructionRequestMongoRepository>(
  (ref) => sl<ConstructionRequestMongoRepository>(),
);

final bookingMongoRepositoryProvider = Provider<BookingMongoRepository>(
  (ref) => sl<BookingMongoRepository>(),
);

final notificationMongoRepositoryProvider = Provider<NotificationMongoRepository>(
  (ref) => sl<NotificationMongoRepository>(),
);

final paymentMongoRepositoryProvider = Provider<PaymentMongoRepository>(
  (ref) => sl<PaymentMongoRepository>(),
);

final reviewMongoRepositoryProvider = Provider<ReviewMongoRepository>(
  (ref) => sl<ReviewMongoRepository>(),
);

final documentMongoRepositoryProvider = Provider<DocumentMongoRepository>(
  (ref) => sl<DocumentMongoRepository>(),
);

final ticketMongoRepositoryProvider = Provider<TicketMongoRepository>(
  (ref) => sl<TicketMongoRepository>(),
);

final mongoInitializedProvider = FutureProvider<bool>((ref) async {
  final integration = ref.read(mongoIntegrationServiceProvider);
  if (!integration.isInitialized) {
    await integration.initialize();
  }
  return integration.isConnected;
});
