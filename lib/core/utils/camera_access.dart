import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera permission helper for Aadhaar capture and QR scanning flows.
enum CameraPermissionStatus {
  granted,
  denied,
  deniedForever,
  unavailable,
}

class CameraAccess {
  CameraAccess._();

  static bool get isSupported => !kIsWeb;

  /// Requests camera permission when needed. On web, the browser prompts during capture.
  static Future<CameraPermissionStatus> ensure({
    required BuildContext context,
    String purpose = 'scan QR codes and capture ID photos',
  }) async {
    if (kIsWeb) {
      return CameraPermissionStatus.granted;
    }

    var status = await Permission.camera.status;
    if (status.isGranted) {
      return CameraPermissionStatus.granted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return CameraPermissionStatus.deniedForever;
      await _promptAppSettings(context);
      status = await Permission.camera.status;
      if (status.isGranted) return CameraPermissionStatus.granted;
      return CameraPermissionStatus.deniedForever;
    }

    status = await Permission.camera.request();
    if (status.isGranted) {
      return CameraPermissionStatus.granted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return CameraPermissionStatus.deniedForever;
      await _promptAppSettings(context);
      status = await Permission.camera.status;
      if (status.isGranted) return CameraPermissionStatus.granted;
      return CameraPermissionStatus.deniedForever;
    }

    if (status.isDenied) {
      if (!context.mounted) return CameraPermissionStatus.denied;
      final retry = await _confirm(
        context,
        title: 'Camera permission needed',
        message: 'Allow camera access so you can $purpose.',
        confirmLabel: 'Allow camera',
      );
      if (retry) {
        status = await Permission.camera.request();
        if (status.isGranted) return CameraPermissionStatus.granted;
      }
    }

    if (status.isRestricted || status.isLimited) {
      return CameraPermissionStatus.unavailable;
    }

    return status.isPermanentlyDenied
        ? CameraPermissionStatus.deniedForever
        : CameraPermissionStatus.denied;
  }

  static String messageFor(CameraPermissionStatus status, {String purpose = 'use the camera'}) {
    switch (status) {
      case CameraPermissionStatus.granted:
        return '';
      case CameraPermissionStatus.denied:
        return 'Camera permission is required to $purpose.';
      case CameraPermissionStatus.deniedForever:
        return 'Camera access is blocked. Open app settings and allow camera for this app.';
      case CameraPermissionStatus.unavailable:
        return 'Camera is not available on this device.';
    }
  }

  static Future<void> _promptAppSettings(BuildContext context) async {
    final open = await _confirm(
      context,
      title: 'Allow camera in settings',
      message:
          'Camera access was denied. Open app settings and enable camera permission, then try again.',
      confirmLabel: 'Open settings',
    );
    if (open) {
      await openAppSettings();
    }
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
