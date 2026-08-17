import 'package:flutter/material.dart';

Future<void> showSlotBookedDialog(
  BuildContext context, {
  required int slot,
  required String parkingName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: theme.colorScheme.primary,
          size: 48,
        ),
        title: Text('Slot $slot is booked'),
        content: Text(
          'Assigned first come, first served at $parkingName.\n'
          'Show the QR to security when you enter.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('View ticket'),
          ),
        ],
      );
    },
  );
}
