/// Vehicle compatibility for parking recommendations.
class VehicleSpec {
  const VehicleSpec({
    required this.parkingClass,
    required this.lengthM,
    required this.widthM,
    required this.requiredAreaSqM,
    this.brand = '',
    this.model = '',
  });

  final String brand;
  final String model;
  final String parkingClass;
  final double lengthM;
  final double widthM;
  final double requiredAreaSqM;
}

class VehicleCompatibility {
  VehicleCompatibility._();

  static const _defaultDimensions = {
    'two_wheeler': (2.0, 0.8),
    'compact': (3.8, 1.7),
    'sedan': (4.5, 1.8),
    'suv': (4.8, 1.9),
    'commercial': (6.2, 2.3),
  };

  static String inferParkingClass({
    String? vehicleModel,
    String? vehicleBrand,
    String? vehicleParkingClass,
  }) {
    final explicit = vehicleParkingClass?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final text =
        '${vehicleBrand ?? ''} ${vehicleModel ?? ''}'.trim().toLowerCase();
    if (RegExp(r'bike|motorcycle|scooter|activa|pulsar|splendor|bullet')
        .hasMatch(text)) {
      return 'two_wheeler';
    }
    if (RegExp(r'truck|bus|tempo|lorry|carrier|van|pickup').hasMatch(text)) {
      return 'commercial';
    }
    if (RegExp(r'suv|jeep|fortuner|creta|xuv|harrier|compass|thar|seltos')
        .hasMatch(text)) {
      return 'suv';
    }
    if (RegExp(r'hatch|swift|i20|polo|alto|wagon|figo|celerio|tiago')
        .hasMatch(text)) {
      return 'compact';
    }
    return 'sedan';
  }

  static VehicleSpec resolve({
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleParkingClass,
    double? vehicleLengthM,
    double? vehicleWidthM,
  }) {
    final parkingClass = inferParkingClass(
      vehicleModel: vehicleModel,
      vehicleBrand: vehicleBrand,
      vehicleParkingClass: vehicleParkingClass,
    );
    final defaults =
        _defaultDimensions[parkingClass] ?? _defaultDimensions['sedan']!;
    final lengthM = vehicleLengthM ?? defaults.$1;
    final widthM = vehicleWidthM ?? defaults.$2;

    return VehicleSpec(
      brand: vehicleBrand?.trim() ?? '',
      model: vehicleModel?.trim() ?? '',
      parkingClass: parkingClass,
      lengthM: lengthM,
      widthM: widthM,
      requiredAreaSqM: lengthM * widthM * 1.15,
    );
  }

  static double slotAreaSqM({
    required double areaSqFt,
    required int capacity,
    required String parkingTypeValue,
  }) {
    if (areaSqFt > 0 && capacity > 0) {
      return (areaSqFt / capacity) * 0.092903;
    }
    switch (parkingTypeValue) {
      case 'tower_parking':
      case 'shuttle_parking':
      case 'puzzle_parking':
        return 14;
      case 'hydraulic_stack_4_post':
        return 12;
      case 'hydraulic_stack_2_post':
        return 10;
      case 'pit_stack_parking':
        return 11;
      default:
        return 12;
    }
  }

  static List<String> _allowedClasses(String parkingTypeValue) {
    switch (parkingTypeValue) {
      case 'hydraulic_stack_2_post':
        return ['two_wheeler', 'compact', 'sedan'];
      case 'hydraulic_stack_4_post':
      case 'pit_stack_parking':
        return ['two_wheeler', 'compact', 'sedan', 'suv'];
      case 'tower_parking':
      case 'shuttle_parking':
      case 'puzzle_parking':
        return ['two_wheeler', 'compact', 'sedan', 'suv', 'commercial'];
      default:
        return ['two_wheeler', 'compact', 'sedan', 'suv'];
    }
  }

  static bool isCompatible({
    required VehicleSpec vehicle,
    required String parkingTypeValue,
    required double areaSqFt,
    required int capacity,
  }) {
    if (!_allowedClasses(parkingTypeValue).contains(vehicle.parkingClass)) {
      return false;
    }
    final slotArea = slotAreaSqM(
      areaSqFt: areaSqFt,
      capacity: capacity,
      parkingTypeValue: parkingTypeValue,
    );
    return vehicle.requiredAreaSqM <= slotArea;
  }
}
