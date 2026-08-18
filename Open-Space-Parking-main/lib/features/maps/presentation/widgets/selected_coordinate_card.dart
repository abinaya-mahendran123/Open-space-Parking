import 'package:flutter/material.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';

class SelectedCoordinateCard extends StatelessWidget {
  const SelectedCoordinateCard({
    super.key,
    required this.coordinate,
    this.title = 'Selected Location',
  });

  final MapCoordinate coordinate;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.place, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(coordinate.label),
        trailing: Text(
          coordinate.accuracyMeters != null
              ? '±${coordinate.accuracyMeters!.toStringAsFixed(0)}m'
              : '',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
