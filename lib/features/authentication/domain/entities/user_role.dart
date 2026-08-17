enum UserRole {
  vehicleOwner,
  landOwner,
  admin,
  employee,
  security,
}

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.vehicleOwner:
        return 'vehicle_owner';
      case UserRole.landOwner:
        return 'land_owner';
      case UserRole.admin:
        return 'admin';
      case UserRole.employee:
        return 'employee';
      case UserRole.security:
        return 'security';
    }
  }

  String get label {
    switch (this) {
      case UserRole.vehicleOwner:
        return 'Vehicle Owner';
      case UserRole.landOwner:
        return 'Land Owner';
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.security:
        return 'Security';
    }
  }

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.vehicleOwner,
    );
  }
}
