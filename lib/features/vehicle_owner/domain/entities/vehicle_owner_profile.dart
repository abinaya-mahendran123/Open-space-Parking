import 'package:equatable/equatable.dart';

class VehicleOwnerProfile extends Equatable {
  const VehicleOwnerProfile({
    required this.fullName,
    required this.phone,
    required this.email,
    this.address,
    this.vehicleNumber,
    this.vehicleModel,
  });

  final String fullName;
  final String phone;
  final String email;
  final String? address;
  final String? vehicleNumber;
  final String? vehicleModel;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'address': address,
        'vehicleNumber': vehicleNumber,
        'vehicleModel': vehicleModel,
      };

  factory VehicleOwnerProfile.fromJson(Map<String, dynamic> json) {
    return VehicleOwnerProfile(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        phone,
        email,
        address,
        vehicleNumber,
        vehicleModel,
      ];
}
