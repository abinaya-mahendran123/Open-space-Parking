import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

class SnackbarService {
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void showSuccess(String message) {
    _show(message, _resolveColor(AppSnackType.success));
  }

  void showError(String message) {
    _show(message, _resolveColor(AppSnackType.error));
  }

  void showInfo(String message) {
    _show(message, _resolveColor(AppSnackType.info));
  }

  Color _resolveColor(AppSnackType type) {
    final context = messengerKey.currentContext;
    if (context == null) {
      return switch (type) {
        AppSnackType.success => AppColors.brandMint,
        AppSnackType.error => const Color(0xFFDC2626),
        AppSnackType.info => AppColors.brandBlue,
      };
    }

    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      AppSnackType.success => AppColors.success(Theme.of(context).brightness),
      AppSnackType.error => scheme.error,
      AppSnackType.info => AppColors.info(Theme.of(context).brightness),
    };
  }

  void _show(String message, Color backgroundColor) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

enum AppSnackType { success, error, info }
