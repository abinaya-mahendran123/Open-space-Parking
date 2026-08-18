import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/admin/domain/entities/employee.dart';

class CreatedEmployeeResult extends Equatable {
  const CreatedEmployeeResult({
    required this.employee,
    required this.loginEmail,
    required this.temporaryPassword,
  });

  final Employee employee;
  final String loginEmail;
  final String temporaryPassword;

  @override
  List<Object?> get props => [employee, loginEmail, temporaryPassword];
}
