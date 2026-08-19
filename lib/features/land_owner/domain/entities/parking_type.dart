import 'package:flutter/material.dart';

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

  IconData get icon {
    switch (this) {
      case ParkingType.towerParking:
        return Icons.apartment_rounded;
      case ParkingType.shuttleParking:
        return Icons.transfer_within_a_station_rounded;
      case ParkingType.hydraulicStack2Post:
        return Icons.vertical_split_rounded;
      case ParkingType.hydraulicStack4Post:
        return Icons.grid_view_rounded;
      case ParkingType.pitStackParking:
        return Icons.layers_rounded;
      case ParkingType.puzzleParking:
        return Icons.extension_rounded;
    }
  }

  String get description {
    switch (this) {
      case ParkingType.towerParking:
        return 'Vertical tower with automated car lifts. Best for small footprint with high capacity.';
      case ParkingType.shuttleParking:
        return 'Cars move on a shuttle platform along tracks. Efficient for medium-sized spaces.';
      case ParkingType.hydraulicStack2Post:
        return 'Two-post hydraulic lift that stacks one car above another. Ideal for 2-car households.';
      case ParkingType.hydraulicStack4Post:
        return 'Four-post system stacking multiple cars. Sturdy and suitable for wider spaces.';
      case ParkingType.pitStackParking:
        return 'Underground pit allows a car to be lowered, freeing surface space for another.';
      case ParkingType.puzzleParking:
        return 'Cars slide horizontally and vertically like puzzle pieces to maximise density.';
    }
  }

  Color get color {
    switch (this) {
      case ParkingType.towerParking:
        return const Color(0xFF1565C0);
      case ParkingType.shuttleParking:
        return const Color(0xFF00838F);
      case ParkingType.hydraulicStack2Post:
        return const Color(0xFF6A1B9A);
      case ParkingType.hydraulicStack4Post:
        return const Color(0xFF2E7D32);
      case ParkingType.pitStackParking:
        return const Color(0xFFE65100);
      case ParkingType.puzzleParking:
        return const Color(0xFFC62828);
    }
  }

  static ParkingType fromValue(String value) {
    return ParkingType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ParkingType.towerParking,
    );
  }
}
