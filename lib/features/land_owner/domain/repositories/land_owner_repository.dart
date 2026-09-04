import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_notification.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/payout_account.dart';

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
    PayoutAccount? payoutAccount,
  });

  /// Saves bank details and asks the backend to create/refresh the Razorpay
  /// Route linked account (`acc_...`). Returns the payout with status fields.
  Future<PayoutAccount> onboardRazorpayPayout({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required PayoutAccount payoutAccount,
  });

  Future<PayoutAccount?> getPayoutAccount(String ownerId);

  Future<PayoutAccount?> refreshRazorpayPayoutStatus(String ownerId);

  /// Whether the land owner accepted the current payout terms version.
  Future<bool> hasAcceptedPayoutTerms(String ownerId);

  /// Persist acceptance of the current payout terms (required before uploads).
  Future<void> acceptPayoutTerms(String ownerId);
}

abstract class LandOwnerNotificationRepository {
  Future<List<LandOwnerNotification>> getNotifications(String ownerId);

  Future<void> markAsRead(String notificationId);

  Future<int> getUnreadCount(String ownerId);
}
