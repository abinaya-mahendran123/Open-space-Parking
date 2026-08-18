enum ParkingType {
  towerParking,
  shuttleParking,
  hydraulicStack2Post,
  hydraulicStack4Post,
  pitStackParking,
  puzzleParking,
}

extension ParkingTypeX on ParkingType {
  String get label {
    switch (this) {
      case ParkingType.towerParking:
        return 'Tower Parking';
      case ParkingType.shuttleParking:
        return 'Shuttle Parking';
      case ParkingType.hydraulicStack2Post:
        return 'Hydraulic Stack Parking 2 Post';
      case ParkingType.hydraulicStack4Post:
        return 'Hydraulic Stack Parking 4 Post';
      case ParkingType.pitStackParking:
        return 'Pit Stack Parking';
      case ParkingType.puzzleParking:
        return 'Puzzle Parking';
    }
  }

  String get value {
    switch (this) {
      case ParkingType.towerParking:
        return 'tower_parking';
      case ParkingType.shuttleParking:
        return 'shuttle_parking';
      case ParkingType.hydraulicStack2Post:
        return 'hydraulic_stack_2_post';
      case ParkingType.hydraulicStack4Post:
        return 'hydraulic_stack_4_post';
      case ParkingType.pitStackParking:
        return 'pit_stack_parking';
      case ParkingType.puzzleParking:
        return 'puzzle_parking';
    }
  }

  String get imageAsset {
    switch (this) {
      case ParkingType.towerParking:
        return 'assets/images/parking_types/tower_parking.png';
      case ParkingType.shuttleParking:
        return 'assets/images/parking_types/shuttle_parking.png';
      case ParkingType.hydraulicStack2Post:
        return 'assets/images/parking_types/hydraulic_stack_2_post.png';
      case ParkingType.hydraulicStack4Post:
        return 'assets/images/parking_types/hydraulic_stack_4_post.png';
      case ParkingType.pitStackParking:
        return 'assets/images/parking_types/pit_stack_parking.png';
      case ParkingType.puzzleParking:
        return 'assets/images/parking_types/puzzle_parking.png';
    }
  }

  static ParkingType fromValue(String value) {
    return ParkingType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ParkingType.towerParking,
    );
  }
}
