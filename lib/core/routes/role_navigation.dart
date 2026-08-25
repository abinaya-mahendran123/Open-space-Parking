import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

/// Resolves the primary dashboard route for an authenticated role.
String dashboardRouteForRole(UserRole? role) {
  return switch (role) {
    UserRole.admin => RoutePaths.adminPortal,
    UserRole.employee => RoutePaths.employeeDashboard,
    UserRole.security => RoutePaths.securityScan,
    UserRole.landOwner => RoutePaths.landOwnerDashboard,
    UserRole.vehicleOwner => RoutePaths.vehicleOwnerSearch,
    _ => RoutePaths.appHome,
  };
}

/// First destination after auth + role selection (onboarding entry points).
String onboardingRouteForRole(UserRole? role) {
  return switch (role) {
    UserRole.landOwner => RoutePaths.landOwnerBuildParking,
    UserRole.vehicleOwner => RoutePaths.vehicleOwnerSearch,
    UserRole.admin => RoutePaths.adminPortal,
    UserRole.employee => RoutePaths.employeeDashboard,
    UserRole.security => RoutePaths.securityScan,
    _ => RoutePaths.appHome,
  };
}
