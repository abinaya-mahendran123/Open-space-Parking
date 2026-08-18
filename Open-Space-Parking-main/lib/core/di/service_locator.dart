import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/di/mongo_service_registration.dart';
import 'package:open_space_parking/core/services/logger_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/services/secure_storage_service.dart';
import 'package:open_space_parking/core/services/api/ticket_notification_service.dart';
import 'package:open_space_parking/core/services/api/otp_auth_service.dart';
import 'package:open_space_parking/core/services/api/google_auth_service.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/core/services/snackbar_service.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/admin/data/repositories/mongo_admin_repository.dart';
import 'package:open_space_parking/features/admin/domain/repositories/admin_repository.dart';
import 'package:open_space_parking/features/authentication/data/repositories/mongo_auth_repository.dart';
import 'package:open_space_parking/features/authentication/domain/repositories/auth_repository.dart';
import 'package:open_space_parking/features/employee/data/repositories/mongo_employee_repository.dart';
import 'package:open_space_parking/features/employee/domain/repositories/employee_repository.dart';
import 'package:open_space_parking/features/land_owner/data/repositories/mongo_land_owner_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/repositories/land_owner_repository.dart';
import 'package:open_space_parking/features/vehicle_owner/data/repositories/mongo_vehicle_owner_repository.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/repositories/vehicle_owner_repository.dart';
import 'package:open_space_parking/features/maps/data/repositories/maps_repository_impl.dart';
import 'package:open_space_parking/features/maps/data/services/geocoding_service.dart';
import 'package:open_space_parking/features/maps/data/services/google_maps_navigation_service.dart';
import 'package:open_space_parking/features/maps/data/services/location_service.dart';
import 'package:open_space_parking/features/maps/data/services/saved_coordinates_storage_service.dart';
import 'package:open_space_parking/features/maps/domain/repositories/maps_repository.dart';
import 'package:open_space_parking/core/cloudinary/data/repositories/cloudinary_repository_impl.dart';
import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_api_service.dart';
import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_validation_service.dart';
import 'package:open_space_parking/core/cloudinary/domain/repositories/cloudinary_repository.dart';
import 'package:open_space_parking/core/mongodb/repositories/base_mongo_repository.dart';
import 'package:open_space_parking/core/mongodb/repositories/mongo_repositories.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_index_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_integration_service.dart';
import 'package:open_space_parking/features/notification/data/repositories/mongo_notification_repository.dart';
import 'package:open_space_parking/features/notification/data/services/fcm_service.dart';
import 'package:open_space_parking/features/notification/data/services/local_notification_service.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';
import 'package:open_space_parking/features/notification/domain/repositories/notification_repository.dart';
import 'package:open_space_parking/core/integration/notification_helper.dart';
import 'package:open_space_parking/core/whatsapp/data/services/whatsapp_service.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (!sl.isRegistered<LoggerService>()) {
    sl.registerLazySingleton<LoggerService>(LoggerService.new);
  }

  if (!sl.isRegistered<SnackbarService>()) {
    sl.registerLazySingleton<SnackbarService>(SnackbarService.new);
  }

  registerMongoServices(sl);

  if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
  }

  if (!sl.isRegistered<SessionService>()) {
    sl.registerLazySingleton<SessionService>(
      () => SessionService(sl<SecureStorageService>()),
    );
  }

  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => MongoAuthRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<LandOwnerRepository>()) {
    sl.registerLazySingleton<LandOwnerRepository>(
      () => MongoLandOwnerRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
        notificationHelper: sl<NotificationHelper>(),
      ),
    );
  }

  if (!sl.isRegistered<LandOwnerNotificationRepository>()) {
    sl.registerLazySingleton<LandOwnerNotificationRepository>(
      () => MongoLandOwnerNotificationRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<TicketNotificationService>()) {
    sl.registerLazySingleton<TicketNotificationService>(TicketNotificationService.new);
  }
  if (!sl.isRegistered<OtpAuthService>()) {
    sl.registerLazySingleton<OtpAuthService>(OtpAuthService.new);
  }
  if (!sl.isRegistered<GoogleAuthService>()) {
    sl.registerLazySingleton<GoogleAuthService>(GoogleAuthService.new);
  }

  if (!sl.isRegistered<WhatsAppService>()) {
    sl.registerLazySingleton<WhatsAppService>(WhatsAppService.new);
  }

  if (!sl.isRegistered<AdminRepository>()) {
    sl.registerLazySingleton<AdminRepository>(
      () => MongoAdminRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
        whatsAppService: sl<WhatsAppService>(),
        notificationHelper: sl<NotificationHelper>(),
        ticketNotificationService: sl<TicketNotificationService>(),
      ),
    );
  }

  if (!sl.isRegistered<EmployeeRepository>()) {
    sl.registerLazySingleton<EmployeeRepository>(
      () => MongoEmployeeRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<VehicleOwnerRepository>()) {
    sl.registerLazySingleton<VehicleOwnerRepository>(
      () => MongoVehicleOwnerRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
        notificationHelper: sl<NotificationHelper>(),
      ),
    );
  }

  if (!sl.isRegistered<VehicleOwnerNotificationRepository>()) {
    sl.registerLazySingleton<VehicleOwnerNotificationRepository>(
      () => MongoVehicleOwnerNotificationRepository(
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<LocationService>()) {
    sl.registerLazySingleton<LocationService>(LocationService.new);
  }

  if (!sl.isRegistered<GeocodingService>()) {
    sl.registerLazySingleton<GeocodingService>(GeocodingService.new);
  }

  if (!sl.isRegistered<GoogleMapsNavigationService>()) {
    sl.registerLazySingleton<GoogleMapsNavigationService>(
      GoogleMapsNavigationService.new,
    );
  }

  if (!sl.isRegistered<SavedCoordinatesStorageService>()) {
    sl.registerLazySingleton<SavedCoordinatesStorageService>(
      () => SavedCoordinatesStorageService(sl<SecureStorageService>()),
    );
  }

  if (!sl.isRegistered<MapsRepository>()) {
    sl.registerLazySingleton<MapsRepository>(
      () => MapsRepositoryImpl(
        locationService: sl<LocationService>(),
        navigationService: sl<GoogleMapsNavigationService>(),
        savedCoordinatesStorage: sl<SavedCoordinatesStorageService>(),
        geocodingService: sl<GeocodingService>(),
      ),
    );
  }

  if (!sl.isRegistered<MongoIndexService>()) {
    sl.registerLazySingleton<MongoIndexService>(
      () => MongoIndexService(sl<MongoDataService>()),
    );
  }

  if (!sl.isRegistered<MongoIntegrationService>()) {
    sl.registerLazySingleton<MongoIntegrationService>(
      () => MongoIntegrationService(
        databaseService: sl<MongoDatabaseService>(),
        dataService: sl<MongoDataService>(),
        indexService: sl<MongoIndexService>(),
        collectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<CloudinaryApiService>()) {
    sl.registerLazySingleton<CloudinaryApiService>(CloudinaryApiService.new);
  }

  if (!sl.isRegistered<CloudinaryValidationService>()) {
    sl.registerLazySingleton<CloudinaryValidationService>(
      CloudinaryValidationService.new,
    );
  }

  _registerMongoRepositories();

  if (!sl.isRegistered<CloudinaryRepository>()) {
    sl.registerLazySingleton<CloudinaryRepository>(
      () => CloudinaryRepositoryImpl(
        apiService: sl<CloudinaryApiService>(),
        validationService: sl<CloudinaryValidationService>(),
        documentRepository: sl<DocumentMongoRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<FcmService>()) {
    sl.registerLazySingleton<FcmService>(FcmService.new);
  }

  if (!sl.isRegistered<LocalNotificationService>()) {
    sl.registerLazySingleton<LocalNotificationService>(
      LocalNotificationService.new,
    );
  }

  if (!sl.isRegistered<NotificationRepository>()) {
    sl.registerLazySingleton<NotificationRepository>(
      () => MongoNotificationRepository(
        notificationMongoRepository: sl<NotificationMongoRepository>(),
        mongoDatabaseService: sl<MongoDatabaseService>(),
        mongoCollectionService: sl<MongoCollectionService>(),
      ),
    );
  }

  if (!sl.isRegistered<NotificationService>()) {
    sl.registerLazySingleton<NotificationService>(
      () => NotificationService(
        fcmService: sl<FcmService>(),
        localNotificationService: sl<LocalNotificationService>(),
        notificationRepository: sl<NotificationRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<NotificationHelper>()) {
    sl.registerLazySingleton<NotificationHelper>(
      () => NotificationHelper(
        notificationService: sl<NotificationService>(),
      ),
    );
  }


  AppLogger.attach(sl<LoggerService>());
}

void _registerMongoRepositories() {
  final register = <T extends BaseMongoRepository<dynamic>>(
    T Function(MongoDataService) factory,
  ) {
    if (!sl.isRegistered<T>()) {
      sl.registerLazySingleton<T>(() => factory(sl<MongoDataService>()));
    }
  };

  register<UserMongoRepository>(UserMongoRepository.new);
  register<EmployeeMongoRepository>(EmployeeMongoRepository.new);
  register<VehicleOwnerMongoRepository>(VehicleOwnerMongoRepository.new);
  register<LandOwnerMongoRepository>(LandOwnerMongoRepository.new);
  register<ParkingSpaceMongoRepository>(ParkingSpaceMongoRepository.new);
  register<ConstructionRequestMongoRepository>(
    ConstructionRequestMongoRepository.new,
  );
  register<BookingMongoRepository>(BookingMongoRepository.new);
  register<NotificationMongoRepository>(NotificationMongoRepository.new);
  register<PaymentMongoRepository>(PaymentMongoRepository.new);
  register<ReviewMongoRepository>(ReviewMongoRepository.new);
  register<DocumentMongoRepository>(DocumentMongoRepository.new);
  register<TicketMongoRepository>(TicketMongoRepository.new);
}
