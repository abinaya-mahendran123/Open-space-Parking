class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String authEntry = '/auth';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String appHome = '/app/home';

  /// Hidden admin entry — never linked from normal app navigation.
  static const String adminLogin = '/admin/login';
  static const String adminPortal = '/admin/portal';
  static const String adminTickets = '/admin/tickets';
  static const String adminEmployees = '/admin/employees';
  static const String adminStatistics = '/admin/statistics';

  static String adminTicketDetail(String ticketId) => '/admin/tickets/$ticketId';

  static String adminEmployeeDetail(String employeeId) =>
      '/admin/employees/$employeeId';

  /// Isolated employee portal — never linked from normal app navigation.
  static const String employeeLogin = '/employee/login';
  static const String employeeDashboard = '/employee/dashboard';
  static const String employeeAssigned = '/employee/assigned';
  static const String employeeCompleted = '/employee/completed';
  static const String employeeNotifications = '/employee/notifications';

  static String employeeTicketDetail(String ticketId) =>
      '/employee/tickets/$ticketId';

  static const String landOwnerDashboard = '/land-owner/dashboard';
  static const String landOwnerHistory = '/land-owner/history';
  static const String landOwnerNotifications = '/land-owner/notifications';
  static const String landOwnerProfile = '/land-owner/profile';
  static const String landOwnerBuildParking = '/land-owner/build-parking';
  static const String landOwnerExistingParking = '/land-owner/existing-parking';

  static const String vehicleOwnerDashboard = '/vehicle-owner/dashboard';
  static const String vehicleOwnerSearch = '/vehicle-owner/search';
  static const String vehicleOwnerFavorites = '/vehicle-owner/favorites';
  static const String vehicleOwnerBookings = '/vehicle-owner/bookings';
  static const String vehicleOwnerNotifications = '/vehicle-owner/notifications';
  static const String vehicleOwnerProfile = '/vehicle-owner/profile';

  static String vehicleOwnerParkingDetail(String listingId) =>
      '/vehicle-owner/parking/$listingId';

  static String vehicleOwnerBookParking(String listingId) =>
      '/vehicle-owner/parking/$listingId/book';

  static String vehicleOwnerCheckIn(String listingId) =>
      '/vehicle-owner/parking/$listingId/check-in';

  static String vehicleOwnerBookingDetail(String bookingId) =>
      '/vehicle-owner/bookings/$bookingId';

  static String vehicleOwnerParkingTicket(String bookingId) =>
      '/vehicle-owner/bookings/$bookingId/ticket';

  static String vehicleOwnerPayBooking(String bookingId) =>
      '/vehicle-owner/bookings/$bookingId/pay';

  static String vehicleOwnerBookingReceipt(String bookingId) =>
      '/vehicle-owner/bookings/$bookingId/receipt';

  /// Gate security scanner route.
  static const String securityScan = '/gate-scan';

  static const String mapPicker = '/maps/picker';
  static const String nearbyParkingMap = '/maps/nearby-parking';
  static const String savedCoordinates = '/maps/saved-coordinates';

  static bool isMapsRoute(String location) {
    return location == mapPicker ||
        location == nearbyParkingMap ||
        location == savedCoordinates;
  }

  static bool isSecurityRoute(String location) {
    return location == securityScan ||
        location == '/security/scan' ||
        location == '/security';
  }

  static bool isVehicleOwnerRoute(String location) {
    return location == vehicleOwnerDashboard ||
        location == vehicleOwnerSearch ||
        location == vehicleOwnerFavorites ||
        location == vehicleOwnerBookings ||
        location == vehicleOwnerNotifications ||
        location == vehicleOwnerProfile ||
        location.startsWith('/vehicle-owner/parking/') ||
        location.startsWith('/vehicle-owner/bookings/') ||
        isMapsRoute(location);
  }

  static bool isAdminRoute(String location) {
    return location == adminLogin ||
        location == adminPortal ||
        location == adminTickets ||
        location == adminEmployees ||
        location == adminStatistics ||
        location.startsWith('/admin/tickets/') ||
        location.startsWith('/admin/employees/');
  }

  static bool isEmployeeRoute(String location) {
    return location == employeeLogin ||
        location == employeeDashboard ||
        location == employeeAssigned ||
        location == employeeCompleted ||
        location == employeeNotifications ||
        location.startsWith('/employee/tickets/');
  }
}
