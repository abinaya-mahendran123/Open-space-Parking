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
import 'package:open_space_parking/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/role_selection_page.dart';
import 'package:open_space_parking/features/authentication/presentation/pages/splash_page.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_login_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_shell_page.dart';
import 'package:open_space_parking/features/employee/presentation/pages/employee_ticket_detail_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/build_parking_flow_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/existing_parking_flow_page.dart';
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
      };

      final isVehicleOwnerPath = RoutePaths.isVehicleOwnerRoute(location);

      if (status == AuthStatus.unknown) {
        if (location != RoutePaths.splash) return RoutePaths.splash;
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (RoutePaths.isSecurityRoute(location)) {
          return RoutePaths.authEntry;
        }
        if (isAdminPath) {
          return RoutePaths.authEntry;
        }
        if (isEmployeePath && location != RoutePaths.employeeLogin) {
          return RoutePaths.employeeLogin;
        }
        if (landOwnerRoutes.contains(location) || isVehicleOwnerPath) {
          return RoutePaths.authEntry;
        }
        if (RoutePaths.isMapsRoute(location)) return RoutePaths.authEntry;
        return null;
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
        if (location == RoutePaths.employeeLogin) {
          return RoutePaths.employeeDashboard;
        }
        if (!isEmployeePath) return RoutePaths.employeeDashboard;
        return null;
      }

      if (role == UserRole.vehicleOwner && RoutePaths.isSecurityRoute(location)) {
        return RoutePaths.vehicleOwnerDashboard;
      }

      // Non-admin / non-employee cannot access isolated portals.
      if (isAdminPath || (isEmployeePath && location != RoutePaths.employeeLogin)) {
        if (role == UserRole.landOwner) return RoutePaths.landOwnerDashboard;
        if (role == UserRole.vehicleOwner) return RoutePaths.vehicleOwnerDashboard;
        return RoutePaths.appHome;
      }

      if (role == UserRole.landOwner) {
        if (location == RoutePaths.roleSelection) {
          return RoutePaths.landOwnerDashboard;
        }
        if (location == RoutePaths.appHome ||
            (inAuthFlow && location != RoutePaths.forgotPassword)) {
          return RoutePaths.landOwnerDashboard;
        }
        if (isVehicleOwnerPath && !RoutePaths.isMapsRoute(location)) {
          return RoutePaths.landOwnerDashboard;
        }
      } else if (role == UserRole.vehicleOwner) {
        if (location == RoutePaths.roleSelection) {
          return RoutePaths.vehicleOwnerDashboard;
        }
        if (location == RoutePaths.appHome ||
            (inAuthFlow && location != RoutePaths.forgotPassword)) {
          return RoutePaths.vehicleOwnerDashboard;
        }
        if (landOwnerRoutes.contains(location)) {
          return RoutePaths.vehicleOwnerDashboard;
        }
      } else {
        if (landOwnerRoutes.contains(location) || isVehicleOwnerPath) {
          return RoutePaths.appHome;
        }
        if (inAuthFlow) return RoutePaths.appHome;
      }

      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: RoutePaths.authEntry, builder: (_, __) => const AuthPage()),
      GoRoute(path: RoutePaths.roleSelection, builder: (_, __) => const RoleSelectionPage()),
      GoRoute(path: RoutePaths.login, redirect: (_, __) => RoutePaths.authEntry),
      GoRoute(path: RoutePaths.register, redirect: (_, __) => RoutePaths.authEntry),
      GoRoute(path: RoutePaths.forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: RoutePaths.appHome, builder: (_, __) => const AppHomePage()),

      // Isolated Admin Portal (login via main /auth)
      GoRoute(
        path: RoutePaths.adminLogin,
        redirect: (_, __) => RoutePaths.authEntry,
      ),
      GoRoute(
        path: RoutePaths.adminPortal,
        builder: (_, __) => const AdminShellPage(initialIndex: 0),
      ),
      GoRoute(
        path: RoutePaths.adminTickets,
        builder: (_, __) => const AdminShellPage(initialIndex: 1),
      ),
      GoRoute(
        path: '/admin/tickets/:ticketId',
        builder: (context, state) {
          final ticketId = state.pathParameters['ticketId'] ?? '';
          return AdminTicketDetailPage(ticketId: ticketId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminEmployees,
        builder: (_, __) => const AdminShellPage(initialIndex: 2),
      ),
      GoRoute(
        path: '/admin/employees/:employeeId',
        builder: (context, state) {
          final employeeId = state.pathParameters['employeeId'] ?? '';
          return AdminEmployeeDetailPage(employeeId: employeeId);
        },
      ),
      GoRoute(
        path: RoutePaths.adminStatistics,
        builder: (_, __) => const AdminShellPage(initialIndex: 3),
      ),

      // Isolated Employee Portal
      GoRoute(
        path: RoutePaths.employeeLogin,
        builder: (_, __) => const EmployeeLoginPage(),
      ),
      GoRoute(
        path: RoutePaths.employeeDashboard,
        builder: (_, __) => const EmployeeShellPage(initialIndex: 0),
      ),
      GoRoute(
        path: RoutePaths.employeeAssigned,
        builder: (_, __) => const EmployeeShellPage(initialIndex: 1),
      ),
      GoRoute(
        path: RoutePaths.employeeCompleted,
        builder: (_, __) => const EmployeeShellPage(initialIndex: 2),
      ),
      GoRoute(
        path: RoutePaths.employeeNotifications,
        builder: (_, __) => const EmployeeShellPage(initialIndex: 3),
      ),
      GoRoute(
        path: '/employee/tickets/:ticketId',
        builder: (context, state) {
          final ticketId = state.pathParameters['ticketId'] ?? '';
          return EmployeeTicketDetailPage(ticketId: ticketId);
        },
      ),

      GoRoute(
        path: RoutePaths.landOwnerDashboard,
        builder: (_, __) => const LandOwnerShellPage(initialIndex: 0),
      ),
      GoRoute(
        path: RoutePaths.landOwnerHistory,
        builder: (_, __) => const LandOwnerShellPage(initialIndex: 1),
      ),
      GoRoute(
        path: RoutePaths.landOwnerNotifications,
        builder: (_, __) => const LandOwnerShellPage(initialIndex: 2),
      ),
      GoRoute(
        path: RoutePaths.landOwnerProfile,
        builder: (_, __) => const LandOwnerShellPage(initialIndex: 3),
      ),
      GoRoute(
        path: RoutePaths.landOwnerBuildParking,
        builder: (_, __) => const BuildParkingFlowPage(),
      ),
      GoRoute(
        path: RoutePaths.landOwnerExistingParking,
        builder: (_, __) => const ExistingParkingFlowPage(),
      ),

      GoRoute(
        path: RoutePaths.vehicleOwnerDashboard,
        builder: (_, __) => const VehicleOwnerShellPage(initialIndex: 0),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerSearch,
        builder: (_, __) => const VehicleOwnerShellPage(initialIndex: 1),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerFavorites,
        builder: (_, __) => const VehicleOwnerShellPage(initialIndex: 2),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerBookings,
        builder: (_, __) => const VehicleOwnerShellPage(initialIndex: 3),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerNotifications,
        builder: (_, __) => const VehicleOwnerNotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.vehicleOwnerProfile,
        builder: (_, __) => const VehicleOwnerShellPage(initialIndex: 4),
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId/check-in',
        builder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return ParkingCheckInPage(listingId: listingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId/book',
        builder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return BookingFlowPage(listingId: listingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/parking/:listingId',
        builder: (context, state) {
          final listingId = state.pathParameters['listingId'] ?? '';
          return ParkingDetailPage(listingId: listingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/ticket',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return ParkingTicketPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/pay',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return ParkingPaymentPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId/receipt',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return ParkingReceiptPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/vehicle-owner/bookings/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return BookingDetailPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: RoutePaths.securityScan,
        builder: (_, __) => const SecurityScanPage(),
      ),
      GoRoute(
        path: '/security/scan',
        redirect: (_, __) => RoutePaths.securityScan,
      ),

      GoRoute(
        path: RoutePaths.mapPicker,
        builder: (_, __) => const MapPickerPage(),
      ),
      GoRoute(
        path: RoutePaths.nearbyParkingMap,
        builder: (_, __) => const NearbyParkingMapPage(),
      ),
      GoRoute(
        path: RoutePaths.savedCoordinates,
        builder: (_, __) => const SavedCoordinatesPage(),
      ),
    ],
  );
});
