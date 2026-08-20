import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.onLongPress,
    this.margin,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    if (onTap != null || onLongPress != null) {
      return Card(
        margin: margin ?? EdgeInsets.zero,
        color: color,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }

    return Card(
      margin: margin ?? EdgeInsets.zero,
      color: color,
      child: content,
    );
  }
}
