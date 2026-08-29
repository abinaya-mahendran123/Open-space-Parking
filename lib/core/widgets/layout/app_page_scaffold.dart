import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

/// Consistent Open Sky page chrome — #F7F9FC background, white app bar.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: backgroundColor ??
          (isLight ? AppColors.background : Theme.of(context).colorScheme.surface),
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Standard light-mode app bar used across role portals.
PreferredSizeWidget openSkyAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool transparent = false,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isLight = theme.brightness == Brightness.light;

  return AppBar(
    title: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    leading: leading,
    actions: actions,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: transparent
        ? Colors.transparent
        : (isLight ? AppColors.card : colorScheme.surfaceContainer),
    surfaceTintColor: Colors.transparent,
    foregroundColor: colorScheme.onSurface,
  );
}
