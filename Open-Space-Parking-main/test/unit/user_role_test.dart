import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

void main() {
  group('UserRole', () {
    test('value returns snake_case string', () {
      expect(UserRole.vehicleOwner.value, 'vehicle_owner');
      expect(UserRole.landOwner.value, 'land_owner');
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.employee.value, 'employee');
    });

    test('fromValue parses known roles', () {
      expect(UserRoleX.fromValue('vehicle_owner'), UserRole.vehicleOwner);
      expect(UserRoleX.fromValue('land_owner'), UserRole.landOwner);
      expect(UserRoleX.fromValue('admin'), UserRole.admin);
      expect(UserRoleX.fromValue('employee'), UserRole.employee);
    });

    test('fromValue defaults to vehicleOwner for unknown', () {
      expect(UserRoleX.fromValue('unknown'), UserRole.vehicleOwner);
    });

    test('label returns human-readable name', () {
      expect(UserRole.landOwner.label, 'Land Owner');
      expect(UserRole.employee.label, 'Employee');
    });
  });
}
