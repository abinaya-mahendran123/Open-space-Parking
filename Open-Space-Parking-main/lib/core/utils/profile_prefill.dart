import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';

class ProfilePrefill {
  ProfilePrefill._();

  static String firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static OwnerDetails mergeOwnerDetails({
    OwnerDetails? saved,
    OwnerDetails? fromRequest,
    String? accountDisplayName,
    String? accountEmail,
    AuthSession? session,
  }) {
    return OwnerDetails(
      fullName: firstNonEmpty([
        saved?.fullName,
        fromRequest?.fullName,
        accountDisplayName,
        session?.displayName,
      ]),
      phone: firstNonEmpty([saved?.phone, fromRequest?.phone]),
      email: firstNonEmpty([
        saved?.email,
        fromRequest?.email,
        accountEmail,
        session?.email,
      ]),
      address: firstNonEmpty([saved?.address, fromRequest?.address]),
      aadhaarNumber: saved?.aadhaarNumber ?? fromRequest?.aadhaarNumber,
    );
  }

  static VehicleOwnerProfile mergeVehicleProfile({
    VehicleOwnerProfile? saved,
    String? accountDisplayName,
    String? accountEmail,
    AuthSession? session,
  }) {
    return VehicleOwnerProfile(
      fullName: firstNonEmpty([
        saved?.fullName,
        accountDisplayName,
        session?.displayName,
      ]),
      phone: firstNonEmpty([saved?.phone]),
      email: firstNonEmpty([
        saved?.email,
        accountEmail,
        session?.email,
      ]),
      address: saved?.address,
      vehicleNumber: saved?.vehicleNumber,
      vehicleModel: saved?.vehicleModel,
    );
  }

  static bool hasAnyOwnerDetails(OwnerDetails details) {
    return details.fullName.isNotEmpty ||
        details.phone.isNotEmpty ||
        details.email.isNotEmpty ||
        details.address.isNotEmpty;
  }

  static bool hasAnyVehicleProfile(VehicleOwnerProfile profile) {
    return profile.fullName.isNotEmpty ||
        profile.phone.isNotEmpty ||
        profile.email.isNotEmpty ||
        (profile.address?.isNotEmpty ?? false) ||
        (profile.vehicleNumber?.isNotEmpty ?? false) ||
        (profile.vehicleModel?.isNotEmpty ?? false);
  }
}
