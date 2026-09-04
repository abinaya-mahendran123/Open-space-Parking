import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_employee_detail_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_shell_page.dart';
import 'package:open_space_parking/features/admin/presentation/pages/admin_ticket_detail_page.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/app_home_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/auth_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/auth_welcome_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/role_selection_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/splash_page.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_shell_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_ticket_detail_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/build_parking_flow_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/existing_parking_flow_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_payout_terms_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_shell_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/booking_detail_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/booking_flow_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_check_in_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_detail_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_payment_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_receipt_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/parking_ticket_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/security_scan_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/vehicle_owner_notifications_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/vehicle_owner_shell_page.dart';
import 'package:open_space_parking/features/maps/presentation/pages/map_picker_page.dart';
import 'package:open_space_parking/features/maps/presentation/pages/nearby_parking_map_page.dart';
import 'package:open_space_parking/features/maps/presentation/pages/saved_coordinates_page.dart';

/// Shared page keys keep role shells mounted across tab URL changes so
/// navigation stays instant (no remount / fade transition).
const _adminShellPageKey = ValueKey<String>('admin-shell');
const _employeeShellPageKey = ValueKey<String>('employee-shell');
const _landOwnerShellPageKey = ValueKey<String>('land-owner-shell');
const _vehicleOwnerShellPageKey = ValueKey<String>('vehicle-owner-shell');

Page<void> _noTransitionShellPage({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: key, child: child);
}

/// Short fade for pushed detail/flow routes (default MaterialPage feels sluggish).
Page<void> _fastPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(state.error?.toString() ?? 'Page not found'),
          ),
        ),
      );
    },
    redirect: (context, state) {
      final location = state.uri.path;
      final authState = ref.read(authStateProvider);
      final status = authState.status;
      final role = authState.session?.role;
      final isAdminPath = RoutePaths.isAdminRoute(location);
      final isEmployeePath = RoutePaths.isEmployeeRoute(location);

      final inAuthFlow = {
        RoutePaths.splash,
        RoutePaths.authEntry,
        RoutePaths.roleSelection,
        RoutePaths.login,
        RoutePaths.register,
        RoutePaths.forgotPassword,
      }.contains(location);

      final landOwnerRoutes = {
        RoutePaths.landOwnerDashboard,
        RoutePaths.landOwnerHistory,
        RoutePaths.landOwnerNotifications,
        RoutePaths.landOwnerProfile,
        RoutePaths.landOwnerBuildParking,
        RoutePaths.landOwnerExistingParking,
        RoutePaths.landOwnerPayoutTerms,
      };

      final isVehicleOwnerPath = RoutePaths.isVehicleOwnerRoute(location);

      if (status == AuthStatus.unknown) {
        if (location != RoutePaths.splash) return RoutePaths.splash;
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (inAuthFlow || location == RoutePaths.employeeLogin) {
          return null;
        }
        return RoutePaths.authEntry;
      }

      if (status != AuthStatus.authenticated) return null;
      if (role == UserRole.admin) {
        if (RoutePaths.isSecurityRoute(location)) return null;
        if (!isAdminPath) return RoutePaths.adminPortal;
        return null;
      }

      if (role == UserRole.security) {
        if (!RoutePaths.isSecurityRoute(location)) {
          return RoutePaths.securityScan;
        }
        return null;
      }

      // Employee confined to employee routes.
      if (role == UserRole.employee) {
        if (RoutePaths.isSecurityRoute(location)) return null;
        if (location == RoutePaths.employeeLogin ||
            location == RoutePaths.authEntry) {
          return RoutePaths.employeeDashboard;
        }
        if (!isEmployeePath) return RoutePaths.employeeDashboard;
        return null;
      }

      if (role == UserRole.vehicleOwner && RoutePaths.isSecurityRoute(location)) {
        return RoutePaths.vehicleOwnerSearch;
      }

      if (role == UserRole.landOwner && RoutePaths.isSecurityRoute(location)) {
        return RoutePaths.landOwnerDashboard;
      }

      // Non-admin / non-employee cannot access isolated portals.
      if (isAdminPath || (isEmployeePath && location != RoutePaths.employeeLogin)) {
        if (role == UserRole.landOwner) return RoutePaths.landOwnerDashboard;
        if (role == UserRole.vehicleOwner) return RoutePaths.vehicleOwnerSearch;
        return RoutePaths.appHome;
      }

      if (role == UserRole.landOwner) {
        if (location == RoutePaths.roleSelection) {
          return RoutePaths.landOwnerDashboard;
        }
        // Do not bounce logout away from /auth — otherwise logout appears stuck.
        if (location == RoutePaths.authEntry) {
          return null;
        }
        if (location == RoutePaths.appHome ||
            (inAuthFlow && location != RoutePaths.forgotPassword)) {
          return RoutePaths.landOwnerDashboard;
        }
        if (isVehicleOwnerPath && !RoutePaths.isMapsRoute(location)) {
          return RoutePaths.landOwnerDashboard;
        }
      } else if (role == UserRole.vehicleOwner) {
        if (location == RoutePaths.roleSelection ||
            location == RoutePaths.vehicleOwnerDashboard) {
          return RoutePaths.vehicleOwnerSearch;
        }
        if (location == RoutePaths.authEntry) {
          return null;
        }
        if (location == RoutePaths.appHome ||
            (inAuthFlow && location != RoutePaths.forgotPassword)) {
          return RoutePaths.vehicleOwnerSearch;
        }
        if (landOwnerRoutes.contains(location)) {
          return RoutePaths.vehicleOwnerSearch;
        }
      } else {
        if (location == RoutePaths.authEntry) {
          return null;
        }
        if (landOwnerRoutes.contains(location) || isVehicleOwnerPath) {
          return RoutePaths.appHome;
        }
        if (inAuthFlow) return RoutePaths.appHome;
      }

      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: RoutePaths.authEntry, builder: (_, __) => const AuthWelcomePage()),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, __) => const AuthPage(mode: AuthFormMode.signIn),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, __) => const AuthPage(mode: AuthFormMode.signUp),
      ),
      GoRoute(path: RoutePaths.roleSelection, builder: (_, __) => const RoleSelectionPage()),
      GoRoute(path: RoutePaths.forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: RoutePaths.appHome, builder: (_, __) => const AppHomePage()),

      // Isolated Admin Portal (login via main /auth)
      GoRoute(
        path: RoutePaths.adminLogin,
        redirect: (_, __) => RoutePaths.authEntry,
      ),
      GoRoute(
        path: RoutePaths.adminPortal,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _adminShellPageKey,
          child: const AdminShellPage(initialIndex: 0),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminTickets,
        pageBuilder: (_, state) => _noTransitionShellPage(
          key: _adminShellPageKey,
          child: AdminShellPage(
            initialIndex: 1,
            ticketStatusFilter: state.uri.queryParameters['status'],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/tickets/:ticketId',
        pageBuilder: (context, state) {
          final ticketId = state.pathParameters['ticketId'] ?? '';
          final readOnly = state.uri.queryParameters['readonly'] == 'true';
          return _fastPage(
            state: state,
            child: AdminTicketDetailPage(
              ticketId: ticketId,
              readOnly: readOnly,
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminEmployees,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _adminShellPageKey,
          child: const AdminShellPage(initialIndex: 2),
        ),
      ),
      GoRoute(
        path: '/admin/employees/:employeeId',
        pageBuilder: (context, state) {
          final employeeId = state.pathParameters['employeeId'] ?? '';
          return _fastPage(
            state: state,
            child: AdminEmployeeDetailPage(employeeId: employeeId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminStatistics,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _adminShellPageKey,
          child: const AdminShellPage(initialIndex: 3),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminOperations,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _adminShellPageKey,
          child: const AdminShellPage(initialIndex: 4),
        ),
      ),
      GoRoute(
        path: RoutePaths.adminProfile,
        redirect: (_, __) => RoutePaths.adminPortal,
      ),

      // Isolated Employee Portal
      GoRoute(
        path: RoutePaths.employeeLogin,
        redirect: (_, __) => RoutePaths.authEntry,
      ),
      GoRoute(
        path: RoutePaths.employeeDashboard,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _employeeShellPageKey,
          child: const EmployeeShellPage(initialIndex: 0),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeAssigned,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _employeeShellPageKey,
          child: const EmployeeShellPage(initialIndex: 1),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeCompleted,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _employeeShellPageKey,
          child: const EmployeeShellPage(initialIndex: 2),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeNotifications,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _employeeShellPageKey,
          child: const EmployeeShellPage(initialIndex: 3),
        ),
      ),
      GoRoute(
        path: RoutePaths.employeeProfile,
        redirect: (_, __) => RoutePaths.employeeDashboard,
      ),
      GoRoute(
        path: '/employee/tickets/:ticketId',
        pageBuilder: (context, state) {
          final ticketId = state.pathParameters['ticketId'] ?? '';
          return _fastPage(
            state: state,
            child: EmployeeTicketDetailPage(ticketId: ticketId),
          );
        },
      ),

      GoRoute(
        path: RoutePaths.landOwnerPayoutTerms,
        builder: (_, __) => const LandOwnerPayoutTermsPage(),
      ),
      GoRoute(
        path: RoutePaths.landOwnerDashboard,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _landOwnerShellPageKey,
          child: const LandOwnerTermsGate(
            child: LandOwnerShellPage(initialIndex: 0),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.landOwnerHistory,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _landOwnerShellPageKey,
          child: const LandOwnerTermsGate(
            child: LandOwnerShellPage(initialIndex: 1),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.landOwnerNotifications,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _landOwnerShellPageKey,
          child: const LandOwnerTermsGate(
            child: LandOwnerShellPage(initialIndex: 2),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.landOwnerProfile,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _landOwnerShellPageKey,
          child: const LandOwnerTermsGate(
            child: LandOwnerShellPage(initialIndex: 3),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.landOwnerBuildParking,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const LandOwnerTermsGate(
            afterAcceptRoute: RoutePaths.landOwnerBuildParking,
            child: BuildParkingFlowPage(),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.landOwnerExistingParking,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const LandOwnerTermsGate(
            afterAcceptRoute: RoutePaths.landOwnerExistingParking,
            child: ExistingParkingFlowPage(),
          ),
        ),
      ),

      GoRoute(
        path: RoutePaths.vehicleOwnerDashboard,
        redirect: (_, __) => RoutePaths.vehicleOwnerSearch,
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerSearch,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _vehicleOwnerShellPageKey,
          child: const VehicleOwnerShellPage(initialIndex: 0),
        ),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerFavorites,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _vehicleOwnerShellPageKey,
          child: const VehicleOwnerShellPage(initialIndex: 1),
        ),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerBookings,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _vehicleOwnerShellPageKey,
          child: const VehicleOwnerShellPage(initialIndex: 2),
        ),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerNotifications,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const VehicleOwnerNotificationsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerProfile,
        pageBuilder: (_, __) => _noTransitionShellPage(
          key: _vehicleOwnerShellPageKey,
          child: const VehicleOwnerShellPage(initialIndex: 3),
        ),
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId/check-in',
        pageBuilder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return _fastPage(
            state: state,
            child: ParkingCheckInPage(listingId: listingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId/book',
        pageBuilder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return _fastPage(
            state: state,
            child: BookingFlowPage(listingId: listingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId',
        pageBuilder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return _fastPage(
            state: state,
            child: ParkingDetailPage(listingId: listingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/ticket',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return _fastPage(
            state: state,
            child: ParkingTicketPage(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/pay',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return _fastPage(
            state: state,
            child: ParkingPaymentPage(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/receipt',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return _fastPage(
            state: state,
            child: ParkingReceiptPage(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return _fastPage(
            state: state,
            child: BookingDetailPage(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.securityScan,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const SecurityScanPage(),
        ),
      ),
      GoRoute(
        path: '/security/scan',
        redirect: (_, __) => RoutePaths.securityScan,
      ),

      GoRoute(
        path: RoutePaths.mapPicker,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const MapPickerPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.nearbyParkingMap,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const NearbyParkingMapPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.savedCoordinates,
        pageBuilder: (context, state) => _fastPage(
          state: state,
          child: const SavedCoordinatesPage(),
        ),
      ),
    ],
  );
});
