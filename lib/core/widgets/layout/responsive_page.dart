import 'package:flutter/material.dart';

import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/responsive.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.all(AppSpacing.pagePadding),
    this.scrollable = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.isDesktop ? maxWidth : double.infinity,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      );
    }
    return content;
  }
}

int responsiveGridCount(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
  if (context.isDesktop) return desktop;
  if (context.isTablet) return tablet;
  return mobile;
}

double responsiveMaxWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= AppConstants.tabletBreakpoint) return 1100;
  if (width >= AppConstants.mobileBreakpoint) return 900;
  return double.infinity;
}
