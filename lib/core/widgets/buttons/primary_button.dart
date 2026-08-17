import 'package:flutter/material.dart';

import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = PrimaryButtonVariant.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final PrimaryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const AppInlineLoader(size: 22)
        : icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    final onTap = isLoading ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      child: switch (variant) {
        PrimaryButtonVariant.filled => FilledButton(
            onPressed: onTap,
            child: child,
          ),
        PrimaryButtonVariant.tonal => FilledButton.tonal(
            onPressed: onTap,
            child: child,
          ),
        PrimaryButtonVariant.outlined => OutlinedButton(
            onPressed: onTap,
            child: child,
          ),
      },
    );
  }
}

enum PrimaryButtonVariant { filled, tonal, outlined }
