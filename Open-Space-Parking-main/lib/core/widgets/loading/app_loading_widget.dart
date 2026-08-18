import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';

class AppLoadingWidget extends StatelessWidget {
  const AppLoadingWidget({
    super.key,
    this.message = 'Loading...',
    this.useSkeleton = false,
    this.skeleton,
  });

  final String message;
  final bool useSkeleton;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    if (useSkeleton && skeleton != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: skeleton,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AppInlineLoader extends StatelessWidget {
  const AppInlineLoader({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
