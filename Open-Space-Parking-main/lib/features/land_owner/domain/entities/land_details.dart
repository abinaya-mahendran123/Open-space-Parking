import 'package:equatable/equatable.dart';

class LandDetails extends Equatable {
  const LandDetails({
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.areaSqFt,
    required this.roadAccess,
    required this.drainage,
    required this.flood,
    required this.boundary,
    required this.cctv,
    this.landAddress,
  });

  final double gpsLatitude;
  final double gpsLongitude;
  final double areaSqFt;
  final bool roadAccess;
  final bool drainage;
  final bool flood;
  final bool boundary;
  final bool cctv;
  final String? landAddress;

  Map<String, dynamic> toJson() => {
        'gpsLatitude': gpsLatitude,
        'gpsLongitude': gpsLongitude,
        'areaSqFt': areaSqFt,
        'roadAccess': roadAccess,
        'drainage': drainage,
        'flood': flood,
        'boundary': boundary,
        'cctv': cctv,
        'landAddress': landAddress,
      };

  factory LandDetails.fromJson(Map<String, dynamic> json) {
    return LandDetails(
      gpsLatitude: (json['gpsLatitude'] as num?)?.toDouble() ?? 0,
      gpsLongitude: (json['gpsLongitude'] as num?)?.toDouble() ?? 0,
      areaSqFt: (json['areaSqFt'] as num?)?.toDouble() ?? 0,
      roadAccess: json['roadAccess'] as bool? ?? false,
      drainage: json['drainage'] as bool? ?? false,
      flood: json['flood'] as bool? ?? false,
      boundary: json['boundary'] as bool? ?? false,
      cctv: json['cctv'] as bool? ?? false,
      landAddress: json['landAddress'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        gpsLatitude,
        gpsLongitude,
        areaSqFt,
        roadAccess,
        drainage,
        flood,
        boundary,
        cctv,
        landAddress,
      ];
}
