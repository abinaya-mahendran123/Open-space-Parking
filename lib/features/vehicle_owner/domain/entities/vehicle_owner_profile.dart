import 'package:equatable/equatable.dart';

class VehicleOwnerProfile extends Equatable {
  const VehicleOwnerProfile({
    required this.fullName,
    required this.phone,
    this.vehicleNumber,
    this.vehicleModel,
    this.vehicleBrand,
    this.vehicleLengthM,
    this.vehicleWidthM,
    this.vehicleParkingClass,
  });

  final String fullName;
  final String phone;
  final String? vehicleNumber;
  final String? vehicleModel;
  final String? vehicleBrand;
  final double? vehicleLengthM;
  final double? vehicleWidthM;
  final String? vehicleParkingClass;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'vehicleNumber': vehicleNumber,
        'vehicleModel': vehicleModel,
        'vehicleBrand': vehicleBrand,
        'vehicleLengthM': vehicleLengthM,
        'vehicleWidthM': vehicleWidthM,
        'vehicleParkingClass': vehicleParkingClass,
      };

  factory VehicleOwnerProfile.fromJson(Map<String, dynamic> json) {
    return VehicleOwnerProfile(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      vehicleNumber: json['vehicleNumber'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      vehicleBrand: json['vehicleBrand'] as String?,
      vehicleLengthM: (json['vehicleLengthM'] as num?)?.toDouble(),
      vehicleWidthM: (json['vehicleWidthM'] as num?)?.toDouble(),
      vehicleParkingClass: json['vehicleParkingClass'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        phone,
        vehicleNumber,
        vehicleModel,
        vehicleBrand,
        vehicleLengthM,
        vehicleWidthM,
        vehicleParkingClass,
      ];
}
