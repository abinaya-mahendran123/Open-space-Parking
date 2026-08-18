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

  static bool isPlaceholderEmail(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return true;
    if (!text.contains('@')) return true;
    if (text.endsWith('@openspace.local')) return true;

    final local = text.split('@').first;
    if (RegExp(r'^phone\.\d+$').hasMatch(local)) return true;
    if (RegExp(r'^\+?\d{10,15}$').hasMatch(local)) return true;
    return false;
  }

  static String? realEmail(String? value) {
    if (isPlaceholderEmail(value)) return null;
    return value?.trim();
  }

  static String? phoneFromAccount({
    String? savedPhone,
    String? accountEmail,
    String? sessionEmail,
  }) {
    final saved = savedPhone?.trim() ?? '';
    if (saved.isNotEmpty) return saved;

    for (final candidate in [accountEmail, sessionEmail]) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      if (!isPlaceholderEmail(candidate) && candidate.contains('@')) continue;
      final digits = candidate.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      }
    }
    return null;
  }

  static VehicleOwnerProfile mergeVehicleProfile({
    VehicleOwnerProfile? saved,
    String? accountDisplayName,
    String? accountEmail,
    String? accountPhone,
    AuthSession? session,
  }) {
    return VehicleOwnerProfile(
      fullName: firstNonEmpty([
        saved?.fullName,
        accountDisplayName,
        session?.displayName,
      ]),
      phone: firstNonEmpty([
        saved?.phone,
        accountPhone,
        phoneFromAccount(
          accountEmail: accountEmail,
          sessionEmail: session?.email,
        ),
      ]),
      email: firstNonEmpty([
        realEmail(saved?.email),
        realEmail(accountEmail),
        realEmail(session?.email),
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
