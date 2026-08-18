enum UserRole {
  vehicleOwner,
  landOwner,
  admin,
  employee,
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
    }
  }

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.vehicleOwner,
    );
  }
}
