import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_notification.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

abstract class LandOwnerRepository {
  Future<LandOwnerRequest> submitBuildParkingRequest({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
    required ParkingPreferences parkingPreferences,
  });

  Future<LandOwnerRequest> submitExistingParkingRequest({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
  });

  Future<List<LandOwnerRequest>> getRequestHistory(String ownerId);

  Future<OwnerDetails?> getOwnerProfile(String ownerId);

  Future<void> updateOwnerProfile({
    required String ownerId,
    required OwnerDetails ownerDetails,
  });
}

abstract class LandOwnerNotificationRepository {
  Future<List<LandOwnerNotification>> getNotifications(String ownerId);

  Future<void> markAsRead(String notificationId);

  Future<int> getUnreadCount(String ownerId);
}
